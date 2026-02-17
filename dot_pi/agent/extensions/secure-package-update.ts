import { complete, type UserMessage } from "@mariozechner/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { existsSync } from "node:fs";
import { mkdir, mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

type SettingsPackage = string | { source?: string; [key: string]: unknown };
interface SettingsFile {
	packages?: SettingsPackage[];
}

interface ParsedNpmSource {
	name: string;
	version?: string;
}

interface LocatedPackage {
	scope: "project" | "global";
	settingsPath: string;
	settings: SettingsFile;
	index: number;
	name: string;
	version?: string;
}

interface CommandOptions {
	packageName?: string;
	repo?: string;
	yes: boolean;
	force: boolean;
	dryRun: boolean;
	allowNpmDiff: boolean;
	updateAll: boolean;
	ci: boolean;
	help: boolean;
}

interface RollbackCommandOptions {
	packageName?: string;
	yes: boolean;
	help: boolean;
}

interface AnalysisResult {
	verdict: "safe" | "caution" | "high-risk" | "malicious" | "inconclusive";
	risk_score: number;
	summary: string;
	notable_changes: string[];
	suspicious_indicators: string[];
	bug_risks: string[];
	recommended_action: "allow" | "manual-review" | "block";
	raw: string;
}

interface DiffResult {
	diff: string;
	source: "artifact" | "artifact+github" | "github" | "npm";
	diffUrl?: string;
}

interface BumpResult {
	packageName: string;
	scope: "project" | "global";
	settingsPath: string;
	previousSource: string;
	newSource: string;
	backupPath: string;
}

interface RollbackLogEntry {
	timestamp: number;
	packageName: string;
	scope: "project" | "global";
	settingsPath: string;
	previousSource: string;
	newSource: string;
	backupPath: string;
}

interface SecurityPolicyRule {
	expectedRepo?: string;
	maxRiskScore?: number;
	requireSignatures?: boolean;
	requireIntegrity?: boolean;
	allowedMaintainers?: string[];
	allowedPublisherEmails?: string[];
	maxNewMaintainers?: number;
	minReleaseAgeHours?: number;
	allowNpmDiffFallback?: boolean;
	maxNewTransitiveDeps?: number;
	blockLifecycleScripts?: boolean;
	allowLifecycleScriptsFor?: string[];
	blockBundledDependencyChanges?: boolean;
	enforceRepoTarballConsistency?: boolean;
	allowedTarballOnlyPaths?: string[];
}

interface SecurityPolicyFile {
	default?: SecurityPolicyRule;
	packages?: Record<string, SecurityPolicyRule>;
}

interface PackageProvenance {
	version: string;
	integrityPresent: boolean;
	signaturesCount: number;
	maintainers: string[];
	maintainersDisplay: string[];
	publisherName?: string;
	publisherEmail?: string;
	publisherIdentity?: string;
	publishedAt?: number;
	tarballHost?: string;
}

interface ProvenanceEvaluation {
	policyPath: string;
	policy: SecurityPolicyRule;
	current: PackageProvenance;
	latest: PackageProvenance;
	warnings: string[];
	violations: string[];
}

interface TransitivePackageSummary {
	versions: string[];
	lifecycleScripts: string[];
	bundledDependencies: string[];
}

interface TransitiveDepsSnapshot {
	packageName: string;
	version: string;
	packages: Map<string, TransitivePackageSummary>;
}

interface ChangedTransitivePackage {
	packageName: string;
	fromVersions: string[];
	toVersions: string[];
}

interface LifecycleScriptIntroduction {
	packageName: string;
	versions: string[];
	scripts: string[];
}

interface BundledDependencyChange {
	packageName: string;
	fromVersions: string[];
	toVersions: string[];
	removed: string[];
	added: string[];
}

interface TransitiveDepsEvaluation {
	current: TransitiveDepsSnapshot;
	latest: TransitiveDepsSnapshot;
	addedPackages: string[];
	removedPackages: string[];
	changedPackages: ChangedTransitivePackage[];
	lifecycleScriptIntroductions: LifecycleScriptIntroduction[];
	bundledDependencyChanges: BundledDependencyChange[];
	warnings: string[];
	violations: string[];
}

interface RepoTarballConsistencyEvaluation {
	repoSlug?: string;
	gitHead?: string;
	commitReachable: boolean;
	tarballFileCount?: number;
	repoFileCount?: number;
	tarballOnly: string[];
	tarballOnlyAllowed: string[];
	tarballOnlyBlocked: string[];
	repoOnly: string[];
	warnings: string[];
	violations: string[];
}

interface ReportArtifacts {
	reportPath: string;
	diffPath: string;
}

type CiStatus = "success" | "dry-run" | "policy-blocked" | "analysis-blocked" | "failed";

interface CiSummaryArtifact {
	timestamp: string;
	status: CiStatus;
	exitCode: number;
	message: string;
	packageName: string;
	fromVersion: string;
	toVersion: string;
	diffSource: DiffResult["source"];
	diffUrl?: string;
	repoSlug?: string;
	policyPath: string;
	reportPath: string;
	diffPath: string;
	verdict: AnalysisResult["verdict"];
	riskScore: number;
	recommendedAction: AnalysisResult["recommended_action"];
	warnings: {
		total: number;
		provenance: number;
		transitive: number;
		repoTarball: number;
	};
	violations: {
		total: number;
		provenance: number;
		transitive: number;
		repoTarball: number;
	};
	provenanceWarnings: string[];
	provenanceViolations: string[];
	transitiveWarnings: string[];
	transitiveViolations: string[];
	repoTarballWarnings: string[];
	repoTarballViolations: string[];
}

const GLOBAL_SETTINGS = join(homedir(), ".pi", "agent", "settings.json");
const REPORT_ROOT = join(homedir(), ".pi", "agent", "reports", "secure-package-update");
const SECURITY_POLICY_PATH = join(homedir(), ".pi", "agent", "security-policy.json");
const ROLLBACK_LOG = join(REPORT_ROOT, "rollback-log.json");
const MAX_DIFF_CHARS_FOR_ANALYSIS = 120_000;
const COMMAND_TIMEOUT_MS = 240_000;
const DEPENDENCY_SCAN_TIMEOUT_MS = 420_000;
const MANIFEST_FETCH_TIMEOUT_MS = 30_000;
const LIFECYCLE_SCRIPT_NAMES = [
	"preinstall",
	"install",
	"postinstall",
	"prepare",
	"prepublish",
	"prepublishOnly",
] as const;

const DEFAULT_SECURITY_POLICY: SecurityPolicyFile = {
	default: {
		maxRiskScore: 70,
		requireIntegrity: true,
		requireSignatures: false,
		allowNpmDiffFallback: false,
		minReleaseAgeHours: 0,
		maxNewTransitiveDeps: 200,
		blockLifecycleScripts: true,
		allowLifecycleScriptsFor: [],
		blockBundledDependencyChanges: false,
		enforceRepoTarballConsistency: false,
		allowedTarballOnlyPaths: [],
	},
	packages: {},
};

const SECURITY_REVIEW_PROMPT = `You are a strict software supply-chain security reviewer.

Task: review a package diff and identify risks.
Focus on:
- malware/backdoors/exfiltration, credential theft, remote command execution
- suspicious install scripts, postinstall behavior, obfuscation/minified blobs
- dynamic eval/new Function/child_process/network abuse
- typosquatting/dependency confusion patterns
- severe logic bugs/regressions/breaking changes

Return STRICT JSON only (no markdown, no prose outside JSON):
{
  "verdict": "safe|caution|high-risk|malicious|inconclusive",
  "risk_score": <0-100 integer>,
  "summary": "short summary",
  "notable_changes": ["..."],
  "suspicious_indicators": ["..."],
  "bug_risks": ["..."],
  "recommended_action": "allow|manual-review|block"
}

Be conservative. If uncertain, raise risk and choose manual-review.`;

function parseNpmSource(source: string): ParsedNpmSource | undefined {
	if (!source.startsWith("npm:")) return undefined;
	const spec = source.slice(4).trim();
	const match = spec.match(/^(@[^/]+\/[^@]+|[^@]+)(?:@(.+))?$/);
	if (!match) return undefined;
	return { name: match[1], version: match[2] };
}

async function readSettings(path: string): Promise<SettingsFile> {
	if (!existsSync(path)) return {};
	const raw = await readFile(path, "utf-8");
	return JSON.parse(raw) as SettingsFile;
}

function findNearestProjectSettings(cwd: string): string | undefined {
	let dir = resolve(cwd);
	while (true) {
		const candidate = join(dir, ".pi", "settings.json");
		if (existsSync(candidate)) return candidate;
		const parent = dirname(dir);
		if (parent === dir) return undefined;
		dir = parent;
	}
}

function locatePackageInSettings(
	settings: SettingsFile,
	settingsPath: string,
	scope: "project" | "global",
	packageName: string,
): LocatedPackage | undefined {
	const packages = settings.packages ?? [];
	for (let i = 0; i < packages.length; i++) {
		const pkg = packages[i];
		const source = typeof pkg === "string" ? pkg : pkg?.source;
		if (!source) continue;
		const parsed = parseNpmSource(source);
		if (!parsed) continue;
		if (parsed.name !== packageName) continue;
		return {
			scope,
			settingsPath,
			settings,
			index: i,
			name: parsed.name,
			version: parsed.version,
		};
	}
	return undefined;
}

function normalizeVersion(v: string): string {
	return v.trim().replace(/^v/, "");
}

function compareVersion(a: string, b: string): number {
	const na = normalizeVersion(a).split("-")[0];
	const nb = normalizeVersion(b).split("-")[0];
	const pa = na.split(".").map((n) => Number(n));
	const pb = nb.split(".").map((n) => Number(n));
	if (pa.some(Number.isNaN) || pb.some(Number.isNaN)) {
		if (na === nb) return 0;
		return na > nb ? 1 : -1;
	}
	const len = Math.max(pa.length, pb.length);
	for (let i = 0; i < len; i++) {
		const av = pa[i] ?? 0;
		const bv = pb[i] ?? 0;
		if (av > bv) return 1;
		if (av < bv) return -1;
	}
	return 0;
}

function parseArgs(rawArgs: string): { ok: true; options: CommandOptions } | { ok: false; error: string } {
	const tokens = rawArgs.trim().length === 0 ? [] : rawArgs.trim().split(/\s+/);
	const options: CommandOptions = {
		packageName: undefined,
		repo: undefined,
		yes: false,
		force: false,
		dryRun: false,
		allowNpmDiff: false,
		updateAll: false,
		ci: false,
		help: false,
	};

	for (let i = 0; i < tokens.length; i++) {
		const token = tokens[i];
		if (token === "--help" || token === "-h") {
			options.help = true;
			continue;
		}
		if (token === "--yes" || token === "-y") {
			options.yes = true;
			continue;
		}
		if (token === "--force") {
			options.force = true;
			continue;
		}
		if (token === "--dry-run") {
			options.dryRun = true;
			continue;
		}
		if (token === "--allow-npm-diff") {
			options.allowNpmDiff = true;
			continue;
		}
		if (token === "--update-all") {
			options.updateAll = true;
			continue;
		}
		if (token === "--ci") {
			options.ci = true;
			continue;
		}
		if (token === "--repo") {
			const next = tokens[++i];
			if (!next) return { ok: false, error: "--repo requires a value" };
			options.repo = next;
			continue;
		}
		if (token.startsWith("-")) {
			return { ok: false, error: `Unknown flag: ${token}` };
		}
		if (!options.packageName) {
			options.packageName = token;
			continue;
		}
		return { ok: false, error: `Unexpected argument: ${token}` };
	}

	return { ok: true, options };
}

function parseRollbackArgs(rawArgs: string): { ok: true; options: RollbackCommandOptions } | { ok: false; error: string } {
	const tokens = rawArgs.trim().length === 0 ? [] : rawArgs.trim().split(/\s+/);
	const options: RollbackCommandOptions = {
		packageName: undefined,
		yes: false,
		help: false,
	};

	for (let i = 0; i < tokens.length; i++) {
		const token = tokens[i];
		if (token === "--help" || token === "-h") {
			options.help = true;
			continue;
		}
		if (token === "--yes" || token === "-y") {
			options.yes = true;
			continue;
		}
		if (token.startsWith("-")) {
			return { ok: false, error: `Unknown flag: ${token}` };
		}
		if (!options.packageName) {
			options.packageName = token;
			continue;
		}
		return { ok: false, error: `Unexpected argument: ${token}` };
	}

	return { ok: true, options };
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
	if (!value || typeof value !== "object" || Array.isArray(value)) return undefined;
	return value as Record<string, unknown>;
}

function normalizeIdentity(value: string): string {
	return value.trim().toLowerCase();
}

function normalizeRepoSlug(value: string): string | undefined {
	const parsed = parseGitHubSlug(value);
	return parsed ? parsed.toLowerCase() : undefined;
}

function parsePolicyStringArray(value: unknown, path: string): string[] | undefined {
	if (value === undefined) return undefined;
	if (!Array.isArray(value)) {
		throw new Error(`${path} must be an array of strings`);
	}
	const normalized = value.map((item, index) => {
		if (typeof item !== "string" || item.trim().length === 0) {
			throw new Error(`${path}[${index}] must be a non-empty string`);
		}
		return normalizeIdentity(item);
	});
	return Array.from(new Set(normalized));
}

function parsePolicyRawStringArray(value: unknown, path: string): string[] | undefined {
	if (value === undefined) return undefined;
	if (!Array.isArray(value)) {
		throw new Error(`${path} must be an array of strings`);
	}
	const values = value.map((item, index) => {
		if (typeof item !== "string" || item.trim().length === 0) {
			throw new Error(`${path}[${index}] must be a non-empty string`);
		}
		return item.trim();
	});
	return Array.from(new Set(values));
}

function parsePolicyNumber(value: unknown, path: string): number | undefined {
	if (value === undefined) return undefined;
	if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
		throw new Error(`${path} must be a non-negative number`);
	}
	return value;
}

function parsePolicyBoolean(value: unknown, path: string): boolean | undefined {
	if (value === undefined) return undefined;
	if (typeof value !== "boolean") {
		throw new Error(`${path} must be true or false`);
	}
	return value;
}

function withoutUndefinedRuleValues(rule: SecurityPolicyRule): SecurityPolicyRule {
	const clean: SecurityPolicyRule = {};
	for (const [key, value] of Object.entries(rule) as Array<[keyof SecurityPolicyRule, unknown]>) {
		if (value === undefined) continue;
		(clean as Record<string, unknown>)[key] = value;
	}
	return clean;
}

function parseSecurityPolicyRule(value: unknown, path: string): SecurityPolicyRule {
	if (value === undefined) return {};
	const obj = asRecord(value);
	if (!obj) {
		throw new Error(`${path} must be an object`);
	}

	const rule: SecurityPolicyRule = {};

	if (obj.expectedRepo !== undefined) {
		if (typeof obj.expectedRepo !== "string" || obj.expectedRepo.trim().length === 0) {
			throw new Error(`${path}.expectedRepo must be a non-empty GitHub repo slug or URL`);
		}
		const slug = normalizeRepoSlug(obj.expectedRepo);
		if (!slug) {
			throw new Error(`${path}.expectedRepo must be a GitHub repo slug or URL`);
		}
		rule.expectedRepo = slug;
	}

	rule.maxRiskScore = parsePolicyNumber(obj.maxRiskScore, `${path}.maxRiskScore`);
	rule.requireSignatures = parsePolicyBoolean(obj.requireSignatures, `${path}.requireSignatures`);
	rule.requireIntegrity = parsePolicyBoolean(obj.requireIntegrity, `${path}.requireIntegrity`);
	rule.maxNewMaintainers = parsePolicyNumber(obj.maxNewMaintainers, `${path}.maxNewMaintainers`);
	rule.minReleaseAgeHours = parsePolicyNumber(obj.minReleaseAgeHours, `${path}.minReleaseAgeHours`);
	rule.allowNpmDiffFallback = parsePolicyBoolean(obj.allowNpmDiffFallback, `${path}.allowNpmDiffFallback`);
	rule.allowedMaintainers = parsePolicyStringArray(obj.allowedMaintainers, `${path}.allowedMaintainers`);
	rule.allowedPublisherEmails = parsePolicyStringArray(obj.allowedPublisherEmails, `${path}.allowedPublisherEmails`);
	rule.maxNewTransitiveDeps = parsePolicyNumber(obj.maxNewTransitiveDeps, `${path}.maxNewTransitiveDeps`);
	rule.blockLifecycleScripts = parsePolicyBoolean(obj.blockLifecycleScripts, `${path}.blockLifecycleScripts`);
	rule.allowLifecycleScriptsFor = parsePolicyStringArray(obj.allowLifecycleScriptsFor, `${path}.allowLifecycleScriptsFor`);
	rule.blockBundledDependencyChanges = parsePolicyBoolean(
		obj.blockBundledDependencyChanges,
		`${path}.blockBundledDependencyChanges`,
	);
	rule.enforceRepoTarballConsistency = parsePolicyBoolean(
		obj.enforceRepoTarballConsistency,
		`${path}.enforceRepoTarballConsistency`,
	);
	rule.allowedTarballOnlyPaths = parsePolicyRawStringArray(
		obj.allowedTarballOnlyPaths,
		`${path}.allowedTarballOnlyPaths`,
	);

	if (rule.maxRiskScore !== undefined && rule.maxRiskScore > 100) {
		throw new Error(`${path}.maxRiskScore must be <= 100`);
	}

	return withoutUndefinedRuleValues(rule);
}

function parseSecurityPolicyFile(value: unknown): SecurityPolicyFile {
	const obj = asRecord(value);
	if (!obj) {
		throw new Error("Security policy root must be an object");
	}

	const policy: SecurityPolicyFile = {};
	policy.default = parseSecurityPolicyRule(obj.default, "default");

	if (obj.packages !== undefined) {
		const packagesObj = asRecord(obj.packages);
		if (!packagesObj) {
			throw new Error("packages must be an object keyed by npm package name");
		}
		const parsedPackages: Record<string, SecurityPolicyRule> = {};
		for (const [packageName, packageRule] of Object.entries(packagesObj)) {
			parsedPackages[packageName] = parseSecurityPolicyRule(packageRule, `packages.${packageName}`);
		}
		policy.packages = parsedPackages;
	}

	return policy;
}

function mergeMissingPolicyDefaults(policy: SecurityPolicyFile): { policy: SecurityPolicyFile; changed: boolean } {
	const mergedDefault: SecurityPolicyRule = {
		...(DEFAULT_SECURITY_POLICY.default ?? {}),
		...(policy.default ?? {}),
		allowedMaintainers: policy.default?.allowedMaintainers ?? DEFAULT_SECURITY_POLICY.default?.allowedMaintainers,
		allowedPublisherEmails:
			policy.default?.allowedPublisherEmails ?? DEFAULT_SECURITY_POLICY.default?.allowedPublisherEmails,
		allowLifecycleScriptsFor:
			policy.default?.allowLifecycleScriptsFor ?? DEFAULT_SECURITY_POLICY.default?.allowLifecycleScriptsFor,
		allowedTarballOnlyPaths:
			policy.default?.allowedTarballOnlyPaths ?? DEFAULT_SECURITY_POLICY.default?.allowedTarballOnlyPaths,
	};

	const merged: SecurityPolicyFile = {
		default: mergedDefault,
		packages: policy.packages ?? {},
	};

	const changed = JSON.stringify(merged) !== JSON.stringify(policy);
	return { policy: merged, changed };
}

async function loadSecurityPolicy(): Promise<{ path: string; policy: SecurityPolicyFile; created: boolean; updated: boolean }> {
	if (!existsSync(SECURITY_POLICY_PATH)) {
		await mkdir(dirname(SECURITY_POLICY_PATH), { recursive: true });
		await writeFile(SECURITY_POLICY_PATH, `${JSON.stringify(DEFAULT_SECURITY_POLICY, null, 2)}\n`, "utf-8");
		return { path: SECURITY_POLICY_PATH, policy: DEFAULT_SECURITY_POLICY, created: true, updated: false };
	}

	const raw = await readFile(SECURITY_POLICY_PATH, "utf-8");
	let parsed: unknown;
	try {
		parsed = JSON.parse(raw);
	} catch (err) {
		throw new Error(
			`Invalid JSON in security policy file: ${SECURITY_POLICY_PATH} (${err instanceof Error ? err.message : String(err)})`,
		);
	}

	const parsedPolicy = parseSecurityPolicyFile(parsed);
	const merged = mergeMissingPolicyDefaults(parsedPolicy);
	if (merged.changed) {
		await writeFile(SECURITY_POLICY_PATH, `${JSON.stringify(merged.policy, null, 2)}\n`, "utf-8");
	}

	return {
		path: SECURITY_POLICY_PATH,
		policy: merged.policy,
		created: false,
		updated: merged.changed,
	};
}

function resolveSecurityPolicyForPackage(policyFile: SecurityPolicyFile, packageName: string): SecurityPolicyRule {
	const base = policyFile.default ?? {};
	const specific = policyFile.packages?.[packageName] ?? {};
	return {
		...base,
		...specific,
		allowedMaintainers: specific.allowedMaintainers ?? base.allowedMaintainers,
		allowedPublisherEmails: specific.allowedPublisherEmails ?? base.allowedPublisherEmails,
		allowLifecycleScriptsFor: specific.allowLifecycleScriptsFor ?? base.allowLifecycleScriptsFor,
		allowedTarballOnlyPaths: specific.allowedTarballOnlyPaths ?? base.allowedTarballOnlyPaths,
	};
}

function parseMaintainerString(value: string): { name?: string; email?: string } {
	const trimmed = value.trim();
	if (!trimmed) return {};
	const match = trimmed.match(/^([^<]+?)\s*<([^>]+)>$/);
	if (match) {
		return { name: match[1].trim(), email: match[2].trim() };
	}
	if (trimmed.includes("@")) {
		return { email: trimmed };
	}
	return { name: trimmed };
}

function toIdentity(name?: string, email?: string): string | undefined {
	if (email && email.trim().length > 0) return normalizeIdentity(email);
	if (name && name.trim().length > 0) return normalizeIdentity(name);
	return undefined;
}

function toDisplayIdentity(name?: string, email?: string): string | undefined {
	if (name && email) return `${name} <${email}>`;
	if (email) return email;
	if (name) return name;
	return undefined;
}

function extractMaintainers(meta: Record<string, unknown>): { identities: string[]; display: string[] } {
	const maintainers = meta.maintainers;
	if (!Array.isArray(maintainers)) {
		return { identities: [], display: [] };
	}

	const identitySet = new Set<string>();
	const displaySet = new Set<string>();

	for (const entry of maintainers) {
		let name: string | undefined;
		let email: string | undefined;

		if (typeof entry === "string") {
			const parsed = parseMaintainerString(entry);
			name = parsed.name;
			email = parsed.email;
		} else {
			const obj = asRecord(entry);
			if (!obj) continue;
			name = typeof obj.name === "string" ? obj.name.trim() : undefined;
			email = typeof obj.email === "string" ? obj.email.trim() : undefined;
		}

		const identity = toIdentity(name, email);
		if (identity) identitySet.add(identity);
		const display = toDisplayIdentity(name, email);
		if (display) displaySet.add(display);
	}

	return {
		identities: Array.from(identitySet),
		display: Array.from(displaySet),
	};
}

function extractPublisher(meta: Record<string, unknown>): {
	name?: string;
	email?: string;
	identity?: string;
} {
	const rawUser = meta._npmUser ?? meta.npmUser;
	if (typeof rawUser === "string") {
		const parsed = parseMaintainerString(rawUser);
		return {
			name: parsed.name,
			email: parsed.email,
			identity: toIdentity(parsed.name, parsed.email),
		};
	}
	const user = asRecord(rawUser);
	if (!user) return {};
	const name = typeof user.name === "string" ? user.name.trim() : undefined;
	const email = typeof user.email === "string" ? user.email.trim() : undefined;
	return {
		name,
		email,
		identity: toIdentity(name, email),
	};
}

function extractVersionPublishedAt(timeValue: unknown, version: string): number | undefined {
	const timeObj = asRecord(timeValue);
	if (!timeObj) return undefined;
	const publishedAtRaw = timeObj[version];
	if (typeof publishedAtRaw !== "string") return undefined;
	const timestamp = Date.parse(publishedAtRaw);
	return Number.isNaN(timestamp) ? undefined : timestamp;
}

async function fetchPackageProvenance(
	pi: ExtensionAPI,
	packageName: string,
	version: string,
	timeValue: unknown,
): Promise<PackageProvenance> {
	const spec = `${packageName}@${version}`;
	const metadata = await npmViewJson(pi, spec);
	const meta = asRecord(metadata);
	if (!meta) {
		throw new Error(`npm view ${spec} did not return an object`);
	}

	const dist = asRecord(meta.dist);
	const tarball = typeof dist?.tarball === "string" ? dist.tarball : undefined;
	let tarballHost: string | undefined;
	if (tarball) {
		try {
			tarballHost = new URL(tarball).host.toLowerCase();
		} catch {
			tarballHost = undefined;
		}
	}

	const signatures = Array.isArray(dist?.signatures) ? dist.signatures.length : 0;
	const integrityPresent = typeof dist?.integrity === "string" && dist.integrity.trim().length > 0;
	const maintainers = extractMaintainers(meta);
	const publisher = extractPublisher(meta);

	return {
		version,
		integrityPresent,
		signaturesCount: signatures,
		maintainers: maintainers.identities,
		maintainersDisplay: maintainers.display,
		publisherName: publisher.name,
		publisherEmail: publisher.email,
		publisherIdentity: publisher.identity,
		publishedAt: extractVersionPublishedAt(timeValue, version),
		tarballHost,
	};
}

function formatAgeHours(timestamp: number): number {
	return (Date.now() - timestamp) / (60 * 60 * 1000);
}

async function evaluateProvenance(
	pi: ExtensionAPI,
	policyPath: string,
	policy: SecurityPolicyRule,
	packageName: string,
	currentVersion: string,
	latestVersion: string,
	repoSlug: string | undefined,
	diff: DiffResult,
	analysis: AnalysisResult,
): Promise<ProvenanceEvaluation> {
	const timeValue = await npmViewJson(pi, packageName, "time").catch(() => undefined);
	const [current, latest] = await Promise.all([
		fetchPackageProvenance(pi, packageName, currentVersion, timeValue),
		fetchPackageProvenance(pi, packageName, latestVersion, timeValue),
	]);

	const warnings: string[] = [];
	const violations: string[] = [];

	if (!latest.integrityPresent) {
		warnings.push(`Candidate ${latest.version} has no dist.integrity field.`);
	}
	if (policy.requireIntegrity && !latest.integrityPresent) {
		violations.push(`Policy requires dist.integrity for ${packageName}.`);
	}

	if (latest.signaturesCount === 0) {
		warnings.push(`Candidate ${latest.version} has no dist.signatures entries.`);
	}
	if (policy.requireSignatures && latest.signaturesCount === 0) {
		violations.push(`Policy requires npm signatures for ${packageName}.`);
	}

	if (policy.maxRiskScore !== undefined && analysis.risk_score > policy.maxRiskScore) {
		violations.push(`Model risk score ${analysis.risk_score} exceeds policy maxRiskScore ${policy.maxRiskScore}.`);
	}

	if (diff.source === "npm" && policy.allowNpmDiffFallback === false) {
		violations.push("Policy disallows npm diff fallback as primary evidence.");
	}

	const expectedRepo = policy.expectedRepo;
	if (expectedRepo) {
		if (!repoSlug) {
			violations.push(`Policy expects GitHub repo ${expectedRepo}, but none could be resolved.`);
		} else if (normalizeRepoSlug(repoSlug) !== expectedRepo) {
			violations.push(`Resolved repo ${repoSlug} does not match policy expectedRepo ${expectedRepo}.`);
		}
	}

	if (current.tarballHost && latest.tarballHost && current.tarballHost !== latest.tarballHost) {
		warnings.push(`Tarball host changed: ${current.tarballHost} -> ${latest.tarballHost}`);
	}
	if (latest.tarballHost && !latest.tarballHost.includes("npm")) {
		warnings.push(`Candidate tarball host is unusual: ${latest.tarballHost}`);
	}

	const oldMaintainers = new Set(current.maintainers);
	const newMaintainers = new Set(latest.maintainers);
	const addedMaintainers = Array.from(newMaintainers).filter((m) => !oldMaintainers.has(m));
	const removedMaintainers = Array.from(oldMaintainers).filter((m) => !newMaintainers.has(m));

	if (addedMaintainers.length > 0) {
		warnings.push(`New maintainer identities: ${addedMaintainers.join(", ")}`);
	}
	if (removedMaintainers.length > 0) {
		warnings.push(`Removed maintainer identities: ${removedMaintainers.join(", ")}`);
	}
	if (policy.maxNewMaintainers !== undefined && addedMaintainers.length > policy.maxNewMaintainers) {
		violations.push(
			`Added maintainer count ${addedMaintainers.length} exceeds policy maxNewMaintainers ${policy.maxNewMaintainers}.`,
		);
	}

	if (policy.allowedMaintainers && policy.allowedMaintainers.length > 0) {
		const allowedSet = new Set(policy.allowedMaintainers.map(normalizeIdentity));
		const disallowed = Array.from(newMaintainers).filter((m) => !allowedSet.has(m));
		if (disallowed.length > 0) {
			violations.push(`Maintainer allowlist violation: ${disallowed.join(", ")}`);
		}
	}

	if (current.publisherIdentity && latest.publisherIdentity && current.publisherIdentity !== latest.publisherIdentity) {
		warnings.push(
			`Publisher identity changed: ${current.publisherIdentity} -> ${latest.publisherIdentity}`,
		);
	}

	if (policy.allowedPublisherEmails && policy.allowedPublisherEmails.length > 0) {
		if (!latest.publisherEmail) {
			violations.push("Policy requires publisher email allowlist, but candidate has no publisher email.");
		} else {
			const allowed = new Set(policy.allowedPublisherEmails.map(normalizeIdentity));
			if (!allowed.has(normalizeIdentity(latest.publisherEmail))) {
				violations.push(`Publisher email ${latest.publisherEmail} not in policy allowlist.`);
			}
		}
	}

	if (policy.minReleaseAgeHours !== undefined) {
		if (!latest.publishedAt) {
			violations.push(`Policy requires release age >= ${policy.minReleaseAgeHours}h, but publish time is unavailable.`);
		} else {
			const ageHours = formatAgeHours(latest.publishedAt);
			if (ageHours < policy.minReleaseAgeHours) {
				violations.push(
					`Release age ${ageHours.toFixed(2)}h is below policy minReleaseAgeHours ${policy.minReleaseAgeHours}.`,
				);
			}
		}
	}

	if (!latest.publisherIdentity) {
		warnings.push("Candidate version has no publisher identity metadata (_npmUser).");
	}
	if (latest.maintainers.length === 0) {
		warnings.push("Candidate version has no maintainer identities.");
	}

	return {
		policyPath,
		policy,
		current,
		latest,
		warnings,
		violations,
	};
}

async function npmViewJson(pi: ExtensionAPI, spec: string, field?: string): Promise<unknown> {
	const args = ["view", spec];
	if (field) args.push(field);
	args.push("--json");
	const result = await pi.exec("npm", args, { timeout: COMMAND_TIMEOUT_MS });
	if (result.code !== 0) {
		throw new Error(result.stderr?.trim() || `npm view failed for ${spec}`);
	}
	const out = result.stdout.trim();
	if (!out || out === "null" || out === "undefined") return undefined;
	try {
		return JSON.parse(out);
	} catch {
		return out;
	}
}

function toStringValue(value: unknown): string | undefined {
	if (typeof value === "string") return value;
	if (value && typeof value === "object") {
		const maybeUrl = (value as { url?: unknown }).url;
		if (typeof maybeUrl === "string") return maybeUrl;
	}
	return undefined;
}

function parseGitHubSlug(input?: string): string | undefined {
	if (!input) return undefined;
	let raw = input.trim();
	if (!raw) return undefined;

	if (raw.startsWith("github:")) {
		raw = raw.slice("github:".length);
	}
	raw = raw.replace(/^git\+/, "");

	if (/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(raw)) {
		return raw.replace(/\.git$/i, "");
	}

	const match = raw.match(/github\.com[:/]([A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+)(?:\.git)?(?:[#?].*)?$/i);
	if (match) {
		return match[1].replace(/\.git$/i, "");
	}

	return undefined;
}

async function resolveGitHubRepo(pi: ExtensionAPI, packageName: string, explicitRepo?: string): Promise<string | undefined> {
	const explicit = parseGitHubSlug(explicitRepo);
	if (explicit) return explicit;

	const candidates: string[] = [];

	try {
		const repository = await npmViewJson(pi, packageName, "repository");
		const repoUrl = toStringValue(repository);
		if (repoUrl) candidates.push(repoUrl);
	} catch {
		// Ignore
	}

	try {
		const repositoryUrl = await npmViewJson(pi, packageName, "repository.url");
		const repoUrl = toStringValue(repositoryUrl);
		if (repoUrl) candidates.push(repoUrl);
	} catch {
		// Ignore
	}

	try {
		const homepage = await npmViewJson(pi, packageName, "homepage");
		const homepageUrl = toStringValue(homepage);
		if (homepageUrl) candidates.push(homepageUrl);
	} catch {
		// Ignore
	}

	for (const candidate of candidates) {
		const slug = parseGitHubSlug(candidate);
		if (slug) return slug;
	}

	const scopedGuess = packageName.match(/^@([^/]+)\/([^/]+)$/);
	if (scopedGuess) {
		return `${scopedGuess[1]}/${scopedGuess[2]}`;
	}

	return undefined;
}

async function fetchText(url: string, timeoutMs = 20_000): Promise<string | undefined> {
	const controller = new AbortController();
	const timeout = setTimeout(() => controller.abort(), timeoutMs);
	try {
		const response = await fetch(url, {
			headers: { "user-agent": "pi-secure-package-update" },
			signal: controller.signal,
		});
		if (!response.ok) return undefined;
		return await response.text();
	} catch {
		return undefined;
	} finally {
		clearTimeout(timeout);
	}
}

async function npmPackToDir(pi: ExtensionAPI, spec: string, destination: string): Promise<string> {
	const result = await pi.exec("npm", ["pack", spec, "--json", "--pack-destination", destination], {
		timeout: COMMAND_TIMEOUT_MS,
	});
	if (result.code !== 0) {
		throw new Error(result.stderr?.trim() || `npm pack failed for ${spec}`);
	}
	const out = result.stdout.trim();
	if (!out) {
		throw new Error(`npm pack returned no output for ${spec}`);
	}

	try {
		const parsed = JSON.parse(out) as Array<{ filename?: string }>;
		const filename = parsed?.[0]?.filename;
		if (!filename) throw new Error("missing filename");
		return join(destination, filename);
	} catch {
		const fallbackParts = out
			.split("\n")
			.map((v) => v.trim())
			.filter((v) => v.length > 0);
		const fallbackFile = fallbackParts[fallbackParts.length - 1];
		if (!fallbackFile) {
			throw new Error(`Could not parse npm pack output for ${spec}`);
		}
		return join(destination, fallbackFile);
	}
}

async function resolveArtifactDiff(
	pi: ExtensionAPI,
	packageName: string,
	currentVersion: string,
	latestVersion: string,
): Promise<DiffResult> {
	const tempRoot = await mkdtemp(join(tmpdir(), "pi-secure-update-"));
	try {
		const oldSpec = `${packageName}@${currentVersion}`;
		const newSpec = `${packageName}@${latestVersion}`;
		const [oldTarballPath, newTarballPath] = await Promise.all([
			npmPackToDir(pi, oldSpec, tempRoot),
			npmPackToDir(pi, newSpec, tempRoot),
		]);

		const oldDir = join(tempRoot, "old");
		const newDir = join(tempRoot, "new");
		await Promise.all([mkdir(oldDir, { recursive: true }), mkdir(newDir, { recursive: true })]);

		const unpackOld = await pi.exec("tar", ["-xzf", oldTarballPath, "-C", oldDir], { timeout: COMMAND_TIMEOUT_MS });
		if (unpackOld.code !== 0) {
			throw new Error(unpackOld.stderr?.trim() || `Failed to unpack ${oldSpec}`);
		}
		const unpackNew = await pi.exec("tar", ["-xzf", newTarballPath, "-C", newDir], { timeout: COMMAND_TIMEOUT_MS });
		if (unpackNew.code !== 0) {
			throw new Error(unpackNew.stderr?.trim() || `Failed to unpack ${newSpec}`);
		}

		const diffResult = await pi.exec(
			"git",
			["diff", "--no-index", "--no-ext-diff", "--", join(oldDir, "package"), join(newDir, "package")],
			{ timeout: COMMAND_TIMEOUT_MS },
		);
		if (diffResult.code !== 0 && diffResult.code !== 1) {
			throw new Error(diffResult.stderr?.trim() || "Failed to compute artifact diff");
		}

		const oldTarballUrl = toStringValue(await npmViewJson(pi, oldSpec, "dist.tarball"));
		const newTarballUrl = toStringValue(await npmViewJson(pi, newSpec, "dist.tarball"));
		const diffBody = (diffResult.stdout || diffResult.stderr || "").trim() || "(No file-level differences detected)";
		const header = [
			`# Artifact diff (npm pack tarballs)`,
			`- ${oldSpec}`,
			`- ${newSpec}`,
			...(oldTarballUrl ? [`- old tarball: ${oldTarballUrl}`] : []),
			...(newTarballUrl ? [`- new tarball: ${newTarballUrl}`] : []),
			"",
		].join("\n");

		return {
			source: "artifact",
			diff: `${header}\n${diffBody}`,
		};
	} finally {
		await rm(tempRoot, { recursive: true, force: true });
	}
}

async function resolveGitHubDiff(
	pi: ExtensionAPI,
	packageName: string,
	currentVersion: string,
	latestVersion: string,
	repoSlug?: string,
): Promise<DiffResult | undefined> {
	if (!repoSlug) return undefined;

	let oldHead: string | undefined;
	let newHead: string | undefined;
	try {
		oldHead = toStringValue(await npmViewJson(pi, `${packageName}@${currentVersion}`, "gitHead"));
		newHead = toStringValue(await npmViewJson(pi, `${packageName}@${latestVersion}`, "gitHead"));
	} catch {
		// Ignore and try tags below.
	}

	const ranges: string[] = [];
	if (oldHead && newHead) ranges.push(`${oldHead}...${newHead}`);
	ranges.push(`v${currentVersion}...v${latestVersion}`);
	ranges.push(`${currentVersion}...${latestVersion}`);

	for (const range of ranges) {
		const url = `https://github.com/${repoSlug}/compare/${range}.diff`;
		const diff = await fetchText(url);
		if (!diff) continue;
		if (!diff.includes("diff --git ")) continue;
		return { diff, source: "github", diffUrl: url };
	}

	return undefined;
}

function combineDiffs(primary: DiffResult, supplemental: DiffResult | undefined): DiffResult {
	if (!supplemental) return primary;
	return {
		source: "artifact+github",
		diffUrl: supplemental.diffUrl,
		diff: [
			primary.diff,
			"",
			"# GitHub compare diff (supplemental)",
			supplemental.diffUrl ? `Source: ${supplemental.diffUrl}` : "",
			supplemental.diff,
		]
			.filter(Boolean)
			.join("\n\n"),
	};
}

async function resolveDiff(
	pi: ExtensionAPI,
	packageName: string,
	currentVersion: string,
	latestVersion: string,
	repoSlug: string | undefined,
	requireGithubSupplement: boolean,
	allowNpmFallback: boolean,
): Promise<DiffResult> {
	let artifactError: Error | undefined;
	try {
		const artifact = await resolveArtifactDiff(pi, packageName, currentVersion, latestVersion);
		const github = await resolveGitHubDiff(pi, packageName, currentVersion, latestVersion, repoSlug);
		if (requireGithubSupplement && !github) {
			throw new Error(`Could not fetch GitHub diff for ${repoSlug ?? "(unknown repo)"}`);
		}
		return combineDiffs(artifact, github);
	} catch (err) {
		artifactError = err instanceof Error ? err : new Error(String(err));
	}

	if (!allowNpmFallback) {
		throw new Error(
			`${artifactError?.message ?? "Artifact diff failed"}. Re-run with --allow-npm-diff to fallback to npm diff.`,
		);
	}

	const npmDiff = await pi.exec(
		"npm",
		["diff", `--diff=${packageName}@${currentVersion}`, `--diff=${packageName}@${latestVersion}`],
		{ timeout: COMMAND_TIMEOUT_MS },
	);
	const out = (npmDiff.stdout || "").trim();
	if (!out) {
		throw new Error(npmDiff.stderr?.trim() || "Could not build fallback diff with npm diff.");
	}
	return { diff: out, source: "npm" };
}

function truncateMiddle(input: string, maxChars: number): { text: string; truncated: boolean } {
	if (input.length <= maxChars) return { text: input, truncated: false };
	const headLen = Math.floor(maxChars * 0.7);
	const tailLen = maxChars - headLen;
	const head = input.slice(0, headLen);
	const tail = input.slice(input.length - tailLen);
	return {
		text: `${head}\n\n... [diff truncated for analysis] ...\n\n${tail}`,
		truncated: true,
	};
}

function extractResponseText(rawContent: ReadonlyArray<{ type: string; text?: string }>): string {
	return rawContent
		.filter((c): c is { type: "text"; text: string } => c.type === "text" && typeof c.text === "string")
		.map((c) => c.text)
		.join("\n")
		.trim();
}

function parseAnalysis(raw: string): AnalysisResult {
	const fallback: AnalysisResult = {
		verdict: "inconclusive",
		risk_score: 50,
		summary: raw.slice(0, 500) || "No structured analysis returned.",
		notable_changes: [],
		suspicious_indicators: [],
		bug_risks: [],
		recommended_action: "manual-review",
		raw,
	};

	const jsonMatch = raw.match(/\{[\s\S]*\}/);
	if (!jsonMatch) return fallback;

	try {
		const obj = JSON.parse(jsonMatch[0]) as Record<string, unknown>;
		const verdictRaw = typeof obj.verdict === "string" ? obj.verdict : "inconclusive";
		const verdict = ["safe", "caution", "high-risk", "malicious", "inconclusive"].includes(verdictRaw)
			? (verdictRaw as AnalysisResult["verdict"])
			: "inconclusive";

		const actionRaw = typeof obj.recommended_action === "string" ? obj.recommended_action : "manual-review";
		const recommendedAction = ["allow", "manual-review", "block"].includes(actionRaw)
			? (actionRaw as AnalysisResult["recommended_action"])
			: "manual-review";

		const toStringArray = (value: unknown): string[] => {
			if (!Array.isArray(value)) return [];
			return value.filter((v): v is string => typeof v === "string");
		};

		return {
			verdict,
			risk_score:
				typeof obj.risk_score === "number"
					? Math.max(0, Math.min(100, Math.round(obj.risk_score)))
					: fallback.risk_score,
			summary: typeof obj.summary === "string" ? obj.summary : fallback.summary,
			notable_changes: toStringArray(obj.notable_changes),
			suspicious_indicators: toStringArray(obj.suspicious_indicators),
			bug_risks: toStringArray(obj.bug_risks),
			recommended_action: recommendedAction,
			raw,
		};
	} catch {
		return fallback;
	}
}

async function analyzeDiffWithModel(
	ctx: ExtensionContext,
	packageName: string,
	currentVersion: string,
	latestVersion: string,
	diffText: string,
	diffSourceLabel: string,
): Promise<AnalysisResult> {
	if (!ctx.model) {
		throw new Error("No active model selected. Pick a model first.");
	}
	const apiKey = await ctx.modelRegistry.getApiKey(ctx.model);
	if (!apiKey) {
		throw new Error(`No API key configured for ${ctx.model.provider}/${ctx.model.id}.`);
	}

	const trimmed = truncateMiddle(diffText, MAX_DIFF_CHARS_FOR_ANALYSIS);
	const userMessage: UserMessage = {
		role: "user",
		content: [
			{
				type: "text",
				text:
					`Package: ${packageName}\n` +
					`Current version: ${currentVersion}\n` +
					`Candidate version: ${latestVersion}\n` +
					`Diff source: ${diffSourceLabel}\n` +
					`Diff truncated for analysis: ${trimmed.truncated ? "yes" : "no"}\n\n` +
					`Diff:\n\n${trimmed.text}`,
			},
		],
		timestamp: Date.now(),
	};

	const response = await complete(
		ctx.model,
		{ systemPrompt: SECURITY_REVIEW_PROMPT, messages: [userMessage] },
		{ apiKey },
	);

	if (response.stopReason === "aborted") {
		throw new Error("Security analysis was aborted.");
	}

	const raw = extractResponseText(response.content);
	return parseAnalysis(raw);
}

function toSortedUnique(values: Iterable<string>): string[] {
	return Array.from(new Set(values)).sort((a, b) => a.localeCompare(b));
}

function diffArrays(nextValues: string[], previousValues: string[]): string[] {
	const previousSet = new Set(previousValues);
	return nextValues.filter((value) => !previousSet.has(value));
}

function arraysEqual(a: string[], b: string[]): boolean {
	if (a.length !== b.length) return false;
	for (let i = 0; i < a.length; i++) {
		if (a[i] !== b[i]) return false;
	}
	return true;
}

function summarizeList(values: string[], limit = 10): string {
	if (values.length === 0) return "none";
	if (values.length <= limit) return values.join(", ");
	return `${values.slice(0, limit).join(", ")} (+${values.length - limit} more)`;
}

function readLifecycleScripts(packageJson: Record<string, unknown>): string[] {
	const scriptsObj = asRecord(packageJson.scripts);
	if (!scriptsObj) return [];

	const scripts: string[] = [];
	for (const scriptName of LIFECYCLE_SCRIPT_NAMES) {
		if (typeof scriptsObj[scriptName] === "string") {
			scripts.push(scriptName);
		}
	}
	return scripts;
}

function readBundledDependencies(packageJson: Record<string, unknown>): string[] {
	const bundledRaw = packageJson.bundledDependencies ?? packageJson.bundleDependencies;
	if (Array.isArray(bundledRaw)) {
		return bundledRaw.filter((item): item is string => typeof item === "string" && item.trim().length > 0);
	}
	const bundledObj = asRecord(bundledRaw);
	if (bundledObj) {
		return Object.entries(bundledObj)
			.filter(([, value]) => value === true)
			.map(([name]) => name)
			.filter((name) => name.trim().length > 0);
	}
	if (bundledRaw === true) {
		return ["*"];
	}
	return [];
}

async function readInstalledPackageMetadata(packageDir: string): Promise<{ lifecycleScripts: string[]; bundledDependencies: string[] }> {
	try {
		const raw = await readFile(join(packageDir, "package.json"), "utf-8");
		const parsed = JSON.parse(raw) as unknown;
		const packageJson = asRecord(parsed);
		if (!packageJson) return { lifecycleScripts: [], bundledDependencies: [] };
		return {
			lifecycleScripts: toSortedUnique(readLifecycleScripts(packageJson)),
			bundledDependencies: toSortedUnique(readBundledDependencies(packageJson)),
		};
	} catch {
		return { lifecycleScripts: [], bundledDependencies: [] };
	}
}

interface MutableTransitivePackageSummary {
	versions: Set<string>;
	lifecycleScripts: Set<string>;
	bundledDependencies: Set<string>;
}

async function collectTransitiveNode(
	node: Record<string, unknown>,
	packages: Map<string, MutableTransitivePackageSummary>,
	visited: Set<string>,
	metadataCache: Map<string, Promise<{ lifecycleScripts: string[]; bundledDependencies: string[] }>>,
): Promise<void> {
	const name = typeof node.name === "string" ? node.name : undefined;
	const version = typeof node.version === "string" ? node.version : undefined;
	const path = typeof node.path === "string" ? node.path : undefined;
	const dependencies = asRecord(node.dependencies);
	const visitKey = path ?? `${name ?? "(unknown)"}@${version ?? "(unknown)"}:${Object.keys(dependencies ?? {}).length}`;
	if (visited.has(visitKey)) return;
	visited.add(visitKey);

	if (name && version) {
		let summary = packages.get(name);
		if (!summary) {
			summary = {
				versions: new Set<string>(),
				lifecycleScripts: new Set<string>(),
				bundledDependencies: new Set<string>(),
			};
			packages.set(name, summary);
		}
		summary.versions.add(version);

		if (path) {
			let metadataPromise = metadataCache.get(path);
			if (!metadataPromise) {
				metadataPromise = readInstalledPackageMetadata(path);
				metadataCache.set(path, metadataPromise);
			}
			const metadata = await metadataPromise;
			for (const script of metadata.lifecycleScripts) summary.lifecycleScripts.add(script);
			for (const bundled of metadata.bundledDependencies) summary.bundledDependencies.add(bundled);
		}
	}

	if (!dependencies) return;
	for (const child of Object.values(dependencies)) {
		const childRecord = asRecord(child);
		if (!childRecord) continue;
		await collectTransitiveNode(childRecord, packages, visited, metadataCache);
	}
}

async function buildTransitiveDepsSnapshot(
	pi: ExtensionAPI,
	packageName: string,
	version: string,
): Promise<TransitiveDepsSnapshot> {
	const tempRoot = await mkdtemp(join(tmpdir(), "pi-secure-update-deps-"));
	try {
		const packageJsonPath = join(tempRoot, "package.json");
		await writeFile(
			packageJsonPath,
			`${JSON.stringify({ name: "pi-secure-update-deps-scan", private: true, version: "1.0.0" }, null, 2)}\n`,
			"utf-8",
		);

		const install = await pi.exec(
			"npm",
			["install", "--ignore-scripts", "--no-audit", "--no-fund", "--no-package-lock", "--legacy-peer-deps", `${packageName}@${version}`],
			{ timeout: DEPENDENCY_SCAN_TIMEOUT_MS, cwd: tempRoot },
		);
		if (install.code !== 0) {
			throw new Error(install.stderr?.trim() || `npm install failed while building dependency snapshot for ${packageName}@${version}`);
		}

		const treeResult = await pi.exec("npm", ["ls", "--json", "--all", "--long"], {
			timeout: DEPENDENCY_SCAN_TIMEOUT_MS,
			cwd: tempRoot,
		});
		if (treeResult.code !== 0 && treeResult.code !== 1) {
			throw new Error(treeResult.stderr?.trim() || "npm ls failed while building transitive dependency snapshot");
		}
		if (!treeResult.stdout.trim()) {
			throw new Error("npm ls produced no JSON output while building transitive dependency snapshot");
		}

		let parsedTree: unknown;
		try {
			parsedTree = JSON.parse(treeResult.stdout);
		} catch (err) {
			throw new Error(`Could not parse npm ls output: ${err instanceof Error ? err.message : String(err)}`);
		}

		const root = asRecord(parsedTree);
		const rootDeps = asRecord(root?.dependencies);
		if (!rootDeps) {
			throw new Error("npm ls output missing root dependencies");
		}

		let targetNode = asRecord(rootDeps[packageName]);
		if (!targetNode) {
			for (const dep of Object.values(rootDeps)) {
				const depRecord = asRecord(dep);
				if (!depRecord) continue;
				if (typeof depRecord.name === "string" && depRecord.name === packageName) {
					targetNode = depRecord;
					break;
				}
			}
		}
		if (!targetNode) {
			throw new Error(`Could not find ${packageName} in npm dependency tree for version ${version}`);
		}

		const transitiveRoot = asRecord(targetNode.dependencies);
		const summaries = new Map<string, MutableTransitivePackageSummary>();
		const visited = new Set<string>();
		const metadataCache = new Map<string, Promise<{ lifecycleScripts: string[]; bundledDependencies: string[] }>>();
		if (transitiveRoot) {
			for (const dep of Object.values(transitiveRoot)) {
				const depRecord = asRecord(dep);
				if (!depRecord) continue;
				await collectTransitiveNode(depRecord, summaries, visited, metadataCache);
			}
		}

		const normalized = new Map<string, TransitivePackageSummary>();
		for (const [name, summary] of Array.from(summaries.entries()).sort((a, b) => a[0].localeCompare(b[0]))) {
			normalized.set(name, {
				versions: toSortedUnique(summary.versions),
				lifecycleScripts: toSortedUnique(summary.lifecycleScripts),
				bundledDependencies: toSortedUnique(summary.bundledDependencies),
			});
		}

		return {
			packageName,
			version,
			packages: normalized,
		};
	} finally {
		await rm(tempRoot, { recursive: true, force: true });
	}
}

async function evaluateTransitiveDependencies(
	pi: ExtensionAPI,
	policy: SecurityPolicyRule,
	packageName: string,
	currentVersion: string,
	latestVersion: string,
): Promise<TransitiveDepsEvaluation> {
	const [current, latest] = await Promise.all([
		buildTransitiveDepsSnapshot(pi, packageName, currentVersion),
		buildTransitiveDepsSnapshot(pi, packageName, latestVersion),
	]);

	const currentNames = new Set(current.packages.keys());
	const latestNames = new Set(latest.packages.keys());

	const addedPackages = Array.from(latestNames).filter((name) => !currentNames.has(name)).sort((a, b) => a.localeCompare(b));
	const removedPackages = Array.from(currentNames).filter((name) => !latestNames.has(name)).sort((a, b) => a.localeCompare(b));

	const changedPackages: ChangedTransitivePackage[] = [];
	for (const name of Array.from(currentNames).sort((a, b) => a.localeCompare(b))) {
		if (!latestNames.has(name)) continue;
		const currentSummary = current.packages.get(name);
		const latestSummary = latest.packages.get(name);
		if (!currentSummary || !latestSummary) continue;
		if (!arraysEqual(currentSummary.versions, latestSummary.versions)) {
			changedPackages.push({
				packageName: name,
				fromVersions: currentSummary.versions,
				toVersions: latestSummary.versions,
			});
		}
	}

	const lifecycleScriptIntroductions: LifecycleScriptIntroduction[] = [];
	for (const [name, latestSummary] of latest.packages.entries()) {
		const previousScripts = current.packages.get(name)?.lifecycleScripts ?? [];
		const introducedScripts = diffArrays(latestSummary.lifecycleScripts, previousScripts);
		if (introducedScripts.length === 0) continue;
		lifecycleScriptIntroductions.push({
			packageName: name,
			versions: latestSummary.versions,
			scripts: introducedScripts,
		});
	}
	lifecycleScriptIntroductions.sort((a, b) => a.packageName.localeCompare(b.packageName));

	const bundledDependencyChanges: BundledDependencyChange[] = [];
	const allNames = new Set([...currentNames, ...latestNames]);
	for (const name of Array.from(allNames).sort((a, b) => a.localeCompare(b))) {
		const previous = current.packages.get(name);
		const next = latest.packages.get(name);
		const previousBundled = previous?.bundledDependencies ?? [];
		const nextBundled = next?.bundledDependencies ?? [];
		if (arraysEqual(previousBundled, nextBundled)) continue;
		bundledDependencyChanges.push({
			packageName: name,
			fromVersions: previous?.versions ?? [],
			toVersions: next?.versions ?? [],
			removed: diffArrays(previousBundled, nextBundled),
			added: diffArrays(nextBundled, previousBundled),
		});
	}

	const warnings: string[] = [];
	const violations: string[] = [];

	if (addedPackages.length > 0) {
		warnings.push(`Added transitive packages (${addedPackages.length}): ${summarizeList(addedPackages)}`);
	}
	if (removedPackages.length > 0) {
		warnings.push(`Removed transitive packages (${removedPackages.length}): ${summarizeList(removedPackages)}`);
	}
	if (changedPackages.length > 0) {
		warnings.push(`Changed transitive package versions (${changedPackages.length} packages).`);
	}

	if (policy.maxNewTransitiveDeps !== undefined && addedPackages.length > policy.maxNewTransitiveDeps) {
		violations.push(
			`Added transitive package count ${addedPackages.length} exceeds policy maxNewTransitiveDeps ${policy.maxNewTransitiveDeps}.`,
		);
	}

	const lifecycleAllowlist = new Set((policy.allowLifecycleScriptsFor ?? []).map((value) => normalizeIdentity(value)));
	const disallowedLifecycleIntroductions = lifecycleScriptIntroductions.filter(
		(entry) => !lifecycleAllowlist.has(normalizeIdentity(entry.packageName)),
	);
	if (lifecycleScriptIntroductions.length > 0) {
		const message =
			`New lifecycle scripts detected in ${lifecycleScriptIntroductions.length} package(s): ` +
			summarizeList(
				lifecycleScriptIntroductions.map((entry) => `${entry.packageName}(${entry.scripts.join("/")})`),
				8,
			);
		if (policy.blockLifecycleScripts !== false && disallowedLifecycleIntroductions.length > 0) {
			violations.push(message);
		} else {
			warnings.push(message);
		}
	}

	if (bundledDependencyChanges.length > 0) {
		const bundledMessage =
			`bundledDependencies changed in ${bundledDependencyChanges.length} package(s): ` +
			summarizeList(bundledDependencyChanges.map((entry) => entry.packageName), 10);
		if (policy.blockBundledDependencyChanges === true) {
			violations.push(bundledMessage);
		} else {
			warnings.push(bundledMessage);
		}
	}

	return {
		current,
		latest,
		addedPackages,
		removedPackages,
		changedPackages,
		lifecycleScriptIntroductions,
		bundledDependencyChanges,
		warnings,
		violations,
	};
}

function normalizeManifestPath(pathValue: string): string {
	return pathValue.replace(/\\/g, "/").replace(/^\.\//, "").replace(/^\/+/, "").replace(/\/+/g, "/").trim();
}

async function listFilesRecursive(rootPath: string, relative = ""): Promise<string[]> {
	const directoryPath = relative ? join(rootPath, relative) : rootPath;
	const entries = await readdir(directoryPath, { withFileTypes: true });
	const files: string[] = [];

	for (const entry of entries) {
		const entryRelative = relative ? `${relative}/${entry.name}` : entry.name;
		if (entry.isDirectory()) {
			files.push(...(await listFilesRecursive(rootPath, entryRelative)));
			continue;
		}
		if (entry.isFile() || entry.isSymbolicLink()) {
			files.push(normalizeManifestPath(entryRelative));
		}
	}

	return files.sort((a, b) => a.localeCompare(b));
}

function globPatternToRegExp(pattern: string): RegExp {
	const normalized = normalizeManifestPath(pattern);
	const placeholder = "__DOUBLE_STAR__";
	let source = normalized.replace(/[.+^${}()|[\]\\]/g, "\\$&");
	source = source.replace(/\*\*/g, placeholder);
	source = source.replace(/\*/g, "[^/]*");
	source = source.replace(/\?/g, "[^/]");
	source = source.replace(new RegExp(placeholder, "g"), ".*");
	return new RegExp(`^${source}$`);
}

function isPathAllowed(pathValue: string, patterns: string[]): boolean {
	if (patterns.length === 0) return false;
	const normalizedPath = normalizeManifestPath(pathValue);
	for (const pattern of patterns) {
		try {
			if (globPatternToRegExp(pattern).test(normalizedPath)) {
				return true;
			}
		} catch {
			// Ignore invalid patterns and continue.
		}
	}
	return false;
}

async function fetchWithTimeout(url: string, timeoutMs = MANIFEST_FETCH_TIMEOUT_MS): Promise<Response | undefined> {
	const controller = new AbortController();
	const timeout = setTimeout(() => controller.abort(), timeoutMs);
	try {
		const response = await fetch(url, {
			headers: { "user-agent": "pi-secure-package-update" },
			signal: controller.signal,
		});
		return response;
	} catch {
		return undefined;
	} finally {
		clearTimeout(timeout);
	}
}

async function downloadToFile(url: string, destinationPath: string): Promise<boolean> {
	const response = await fetchWithTimeout(url);
	if (!response || !response.ok) return false;
	const buffer = Buffer.from(await response.arrayBuffer());
	await writeFile(destinationPath, buffer);
	return true;
}

async function isGitHubCommitReachable(repoSlug: string, gitHead: string): Promise<boolean> {
	const response = await fetchWithTimeout(`https://api.github.com/repos/${repoSlug}/commits/${gitHead}`);
	return Boolean(response?.ok);
}

async function evaluateRepoTarballConsistency(
	pi: ExtensionAPI,
	policy: SecurityPolicyRule,
	packageName: string,
	latestVersion: string,
	repoSlug?: string,
): Promise<RepoTarballConsistencyEvaluation> {
	const warnings: string[] = [];
	const violations: string[] = [];
	const result: RepoTarballConsistencyEvaluation = {
		repoSlug,
		gitHead: undefined,
		commitReachable: false,
		tarballOnly: [],
		tarballOnlyAllowed: [],
		tarballOnlyBlocked: [],
		repoOnly: [],
		warnings,
		violations,
	};

	const enforce = policy.enforceRepoTarballConsistency === true;
	if (!repoSlug) {
		warnings.push("No GitHub repository resolved for repo↔tarball consistency check.");
		if (enforce) {
			violations.push("Policy enforces repo↔tarball consistency, but no GitHub repo could be resolved.");
		}
		return result;
	}

	const gitHeadValue = await npmViewJson(pi, `${packageName}@${latestVersion}`, "gitHead").catch(() => undefined);
	const gitHead = toStringValue(gitHeadValue);
	result.gitHead = gitHead;
	if (!gitHead) {
		warnings.push(`npm metadata for ${packageName}@${latestVersion} does not expose gitHead.`);
		if (enforce) {
			violations.push("Policy enforces repo↔tarball consistency, but candidate version has no gitHead.");
		}
		return result;
	}

	result.commitReachable = await isGitHubCommitReachable(repoSlug, gitHead);
	if (!result.commitReachable) {
		warnings.push(`gitHead ${gitHead} is not reachable in https://github.com/${repoSlug}.`);
		if (enforce) {
			violations.push(`Policy enforces repo↔tarball consistency and gitHead ${gitHead} is unreachable.`);
		}
	}

	const tempRoot = await mkdtemp(join(tmpdir(), "pi-secure-update-consistency-"));
	try {
		const npmTarballPath = await npmPackToDir(pi, `${packageName}@${latestVersion}`, tempRoot);
		const npmExtractDir = join(tempRoot, "npm");
		await mkdir(npmExtractDir, { recursive: true });
		const unpackNpm = await pi.exec("tar", ["-xzf", npmTarballPath, "-C", npmExtractDir], { timeout: COMMAND_TIMEOUT_MS });
		if (unpackNpm.code !== 0) {
			throw new Error(unpackNpm.stderr?.trim() || `Failed to unpack npm tarball for ${packageName}@${latestVersion}`);
		}
		const npmManifest = await listFilesRecursive(join(npmExtractDir, "package"));
		result.tarballFileCount = npmManifest.length;

		if (!result.commitReachable) {
			return result;
		}

		const repoTarballPath = join(tempRoot, "repo.tar.gz");
		const repoTarballUrl = `https://codeload.github.com/${repoSlug}/tar.gz/${gitHead}`;
		const downloaded = await downloadToFile(repoTarballUrl, repoTarballPath);
		if (!downloaded) {
			throw new Error(`Could not download GitHub snapshot tarball: ${repoTarballUrl}`);
		}

		const repoExtractDir = join(tempRoot, "repo");
		await mkdir(repoExtractDir, { recursive: true });
		const unpackRepo = await pi.exec("tar", ["-xzf", repoTarballPath, "-C", repoExtractDir], { timeout: COMMAND_TIMEOUT_MS });
		if (unpackRepo.code !== 0) {
			throw new Error(unpackRepo.stderr?.trim() || "Failed to unpack GitHub snapshot tarball");
		}

		const rootEntries = await readdir(repoExtractDir, { withFileTypes: true });
		const repoRoot = rootEntries.find((entry) => entry.isDirectory())
			? join(repoExtractDir, rootEntries.find((entry) => entry.isDirectory())!.name)
			: repoExtractDir;
		const repoManifest = await listFilesRecursive(repoRoot);
		result.repoFileCount = repoManifest.length;

		const repoSet = new Set(repoManifest);
		const npmSet = new Set(npmManifest);
		result.tarballOnly = npmManifest.filter((file) => !repoSet.has(file));
		result.repoOnly = repoManifest.filter((file) => !npmSet.has(file));

		const allowedPatterns = policy.allowedTarballOnlyPaths ?? [];
		result.tarballOnlyAllowed = result.tarballOnly.filter((file) => isPathAllowed(file, allowedPatterns));
		result.tarballOnlyBlocked = result.tarballOnly.filter((file) => !isPathAllowed(file, allowedPatterns));

		if (result.tarballOnlyBlocked.length > 0) {
			const mismatchMessage =
				`Tarball contains ${result.tarballOnlyBlocked.length} file(s) not present in repo snapshot at gitHead: ` +
				summarizeList(result.tarballOnlyBlocked, 12);
			warnings.push(mismatchMessage);
			if (enforce) {
				violations.push(mismatchMessage);
			}
		}

		if (result.tarballOnlyAllowed.length > 0) {
			warnings.push(
				`${result.tarballOnlyAllowed.length} tarball-only file(s) matched allowedTarballOnlyPaths allowlist.`,
			);
		}
	} catch (err) {
		const message = `Repo↔tarball consistency check failed: ${err instanceof Error ? err.message : String(err)}`;
		warnings.push(message);
		if (enforce) {
			violations.push(message);
		}
	} finally {
		await rm(tempRoot, { recursive: true, force: true });
	}

	return result;
}

function sanitizeName(input: string): string {
	return input.replace(/^@/, "").replace(/[^a-zA-Z0-9._-]+/g, "_");
}

function formatTimestamp(timestamp?: number): string {
	if (!timestamp) return "unknown";
	return new Date(timestamp).toISOString();
}

function asBulletedList(items: string[], emptyLabel = "- None", maxItems = 120): string[] {
	if (items.length === 0) return [emptyLabel];
	const lines = items.slice(0, maxItems).map((item) => `- ${item}`);
	if (items.length > maxItems) {
		lines.push(`- ... ${items.length - maxItems} more`);
	}
	return lines;
}

async function writeReportArtifacts(
	packageName: string,
	currentVersion: string,
	latestVersion: string,
	diff: DiffResult,
	analysis: AnalysisResult,
	provenance: ProvenanceEvaluation,
	transitive: TransitiveDepsEvaluation,
	repoConsistency: RepoTarballConsistencyEvaluation,
): Promise<ReportArtifacts> {
	const stamp = new Date().toISOString().replace(/[:.]/g, "-");
	const pkgSafe = sanitizeName(packageName);
	const dir = join(REPORT_ROOT, pkgSafe);
	await mkdir(dir, { recursive: true });

	const base = `${stamp}-${currentVersion}-to-${latestVersion}`;
	const diffPath = join(dir, `${base}.diff`);
	const reportPath = join(dir, `${base}.md`);

	const changedTransitiveLines = transitive.changedPackages.map(
		(change) => `${change.packageName}: [${change.fromVersions.join(", ")}] -> [${change.toVersions.join(", ")}]`,
	);
	const lifecycleLines = transitive.lifecycleScriptIntroductions.map(
		(item) => `${item.packageName}@${item.versions.join(", ")}: ${item.scripts.join(", ")}`,
	);
	const bundledLines = transitive.bundledDependencyChanges.map((item) => {
		const removed = item.removed.length > 0 ? `removed=${item.removed.join(", ")}` : "removed=none";
		const added = item.added.length > 0 ? `added=${item.added.join(", ")}` : "added=none";
		const fromVersions = item.fromVersions.length > 0 ? item.fromVersions.join(", ") : "none";
		const toVersions = item.toVersions.length > 0 ? item.toVersions.join(", ") : "none";
		return `${item.packageName} [${fromVersions} -> ${toVersions}] (${removed}; ${added})`;
	});

	const report = [
		`# Secure Package Update Report`,
		``,
		`- Package: \`${packageName}\``,
		`- From: \`${currentVersion}\``,
		`- To: \`${latestVersion}\``,
		`- Diff source: \`${diff.source}\`${diff.diffUrl ? ` (${diff.diffUrl})` : ""}`,
		``,
		`## Verdict`,
		`- Verdict: **${analysis.verdict}**`,
		`- Risk score: **${analysis.risk_score}/100**`,
		`- Recommended action: **${analysis.recommended_action}**`,
		``,
		`## Policy`,
		`- Policy file: \`${provenance.policyPath}\``,
		"```json",
		JSON.stringify(provenance.policy, null, 2),
		"```",
		``,
		`## Provenance snapshots`,
		`- Current version \`${provenance.current.version}\`: publisher=${provenance.current.publisherIdentity ?? "unknown"}, integrity=${provenance.current.integrityPresent}, signatures=${provenance.current.signaturesCount}, published=${formatTimestamp(provenance.current.publishedAt)}`,
		`- Candidate version \`${provenance.latest.version}\`: publisher=${provenance.latest.publisherIdentity ?? "unknown"}, integrity=${provenance.latest.integrityPresent}, signatures=${provenance.latest.signaturesCount}, published=${formatTimestamp(provenance.latest.publishedAt)}`,
		`- Candidate maintainer identities: ${provenance.latest.maintainers.length > 0 ? provenance.latest.maintainers.join(", ") : "none"}`,
		``,
		`## Policy/provenance warnings`,
		...asBulletedList(provenance.warnings, "- None"),
		``,
		`## Policy/provenance violations`,
		...asBulletedList(provenance.violations, "- None"),
		``,
		`## transitive-deps`,
		`- Current transitive package count: ${transitive.current.packages.size}`,
		`- Candidate transitive package count: ${transitive.latest.packages.size}`,
		`- Added packages: ${transitive.addedPackages.length}`,
		`- Removed packages: ${transitive.removedPackages.length}`,
		`- Changed package versions: ${transitive.changedPackages.length}`,
		`- Lifecycle script introductions: ${transitive.lifecycleScriptIntroductions.length}`,
		`- bundledDependencies changes: ${transitive.bundledDependencyChanges.length}`,
		``,
		`### transitive-deps added-packages`,
		...asBulletedList(transitive.addedPackages, "- None"),
		``,
		`### transitive-deps removed-packages`,
		...asBulletedList(transitive.removedPackages, "- None"),
		``,
		`### transitive-deps changed-packages`,
		...asBulletedList(changedTransitiveLines, "- None"),
		``,
		`### transitive-deps lifecycle-scripts`,
		...asBulletedList(lifecycleLines, "- None"),
		``,
		`### transitive-deps bundled-dependency-changes`,
		...asBulletedList(bundledLines, "- None"),
		``,
		`### transitive-deps warnings`,
		...asBulletedList(transitive.warnings, "- None"),
		``,
		`### transitive-deps violations`,
		...asBulletedList(transitive.violations, "- None"),
		``,
		`## repo-tarball-consistency`,
		`- Repository: ${repoConsistency.repoSlug ?? "unknown"}`,
		`- Candidate gitHead: ${repoConsistency.gitHead ?? "unknown"}`,
		`- gitHead reachable: ${repoConsistency.commitReachable}`,
		`- npm tarball manifest file count: ${repoConsistency.tarballFileCount ?? "unknown"}`,
		`- repo snapshot manifest file count: ${repoConsistency.repoFileCount ?? "unknown"}`,
		`- tarball-only files: ${repoConsistency.tarballOnly.length}`,
		`- tarball-only allowlisted files: ${repoConsistency.tarballOnlyAllowed.length}`,
		`- tarball-only suspicious files: ${repoConsistency.tarballOnlyBlocked.length}`,
		`- repo-only files: ${repoConsistency.repoOnly.length}`,
		``,
		`### repo-tarball-consistency suspicious-tarball-only-paths`,
		...asBulletedList(repoConsistency.tarballOnlyBlocked, "- None"),
		``,
		`### repo-tarball-consistency allowlisted-tarball-only-paths`,
		...asBulletedList(repoConsistency.tarballOnlyAllowed, "- None"),
		``,
		`### repo-tarball-consistency warnings`,
		...asBulletedList(repoConsistency.warnings, "- None"),
		``,
		`### repo-tarball-consistency violations`,
		...asBulletedList(repoConsistency.violations, "- None"),
		``,
		`## Summary`,
		analysis.summary,
		``,
		`## Notable changes`,
		...(analysis.notable_changes.length > 0 ? analysis.notable_changes.map((v) => `- ${v}`) : ["- None listed"]),
		``,
		`## Suspicious indicators`,
		...(analysis.suspicious_indicators.length > 0
			? analysis.suspicious_indicators.map((v) => `- ${v}`)
			: ["- None listed"]),
		``,
		`## Bug risks`,
		...(analysis.bug_risks.length > 0 ? analysis.bug_risks.map((v) => `- ${v}`) : ["- None listed"]),
		``,
		`## Raw model output`,
		"```",
		analysis.raw,
		"```",
		"",
	].join("\n");

	await writeFile(diffPath, diff.diff, "utf-8");
	await writeFile(reportPath, report, "utf-8");
	return { reportPath, diffPath };
}

async function writeCiSummaryArtifact(reportPath: string, summary: CiSummaryArtifact): Promise<string> {
	const summaryPath = reportPath.replace(/\.md$/i, ".summary.json");
	await writeFile(summaryPath, `${JSON.stringify(summary, null, 2)}\n`, "utf-8");
	return summaryPath;
}

function emitCiLine(summary: CiSummaryArtifact, summaryPath: string): void {
	console.log(
		[
			"secure-update-ci",
			`status=${summary.status}`,
			`exit=${summary.exitCode}`,
			`package=${summary.packageName}`,
			`from=${summary.fromVersion}`,
			`to=${summary.toVersion}`,
			`risk=${summary.riskScore}`,
			`warnings=${summary.warnings.total}`,
			`violations=${summary.violations.total}`,
			`report=${summary.reportPath}`,
			`summary=${summaryPath}`,
		].join(" "),
	);
}

function setCiExitCode(ciMode: boolean, code: number): void {
	if (!ciMode) return;
	process.exitCode = code;
}

async function bumpPinnedVersion(located: LocatedPackage, nextVersion: string): Promise<BumpResult> {
	const newSource = `npm:${located.name}@${nextVersion}`;
	const currentRaw = await readFile(located.settingsPath, "utf-8");
	const backupPath = `${located.settingsPath}.bak.${Date.now()}`;
	await writeFile(backupPath, currentRaw, "utf-8");

	if (!located.settings.packages) {
		throw new Error("Settings file has no packages array.");
	}

	const currentEntry = located.settings.packages[located.index];
	const previousSource =
		typeof currentEntry === "string"
			? currentEntry
			: currentEntry && typeof currentEntry === "object" && typeof currentEntry.source === "string"
				? currentEntry.source
				: "";
	if (!previousSource) {
		throw new Error("Could not capture previous package source.");
	}

	if (typeof currentEntry === "string") {
		located.settings.packages[located.index] = newSource;
	} else if (currentEntry && typeof currentEntry === "object") {
		located.settings.packages[located.index] = { ...currentEntry, source: newSource };
	} else {
		throw new Error("Package entry has invalid shape.");
	}

	await writeFile(located.settingsPath, `${JSON.stringify(located.settings, null, 2)}\n`, "utf-8");
	return {
		packageName: located.name,
		scope: located.scope,
		settingsPath: located.settingsPath,
		previousSource,
		newSource,
		backupPath,
	};
}

async function readRollbackLog(): Promise<RollbackLogEntry[]> {
	if (!existsSync(ROLLBACK_LOG)) return [];
	try {
		const raw = await readFile(ROLLBACK_LOG, "utf-8");
		const parsed = JSON.parse(raw) as unknown;
		if (!Array.isArray(parsed)) return [];
		return parsed.filter(
			(v): v is RollbackLogEntry =>
				!!v &&
				typeof v === "object" &&
				typeof (v as RollbackLogEntry).packageName === "string" &&
				typeof (v as RollbackLogEntry).settingsPath === "string" &&
				typeof (v as RollbackLogEntry).previousSource === "string" &&
				typeof (v as RollbackLogEntry).newSource === "string",
		);
	} catch {
		return [];
	}
}

async function appendRollbackLog(entry: RollbackLogEntry): Promise<void> {
	const entries = await readRollbackLog();
	entries.push(entry);
	const keep = entries.slice(-200);
	await mkdir(dirname(ROLLBACK_LOG), { recursive: true });
	await writeFile(ROLLBACK_LOG, `${JSON.stringify(keep, null, 2)}\n`, "utf-8");
}

function selectRollbackEntry(entries: RollbackLogEntry[], packageName?: string): RollbackLogEntry | undefined {
	for (let i = entries.length - 1; i >= 0; i--) {
		const entry = entries[i];
		if (!packageName || entry.packageName === packageName) {
			return entry;
		}
	}
	return undefined;
}

async function setPinnedSource(settingsPath: string, packageName: string, source: string): Promise<void> {
	const settings = await readSettings(settingsPath);
	const packages = settings.packages;
	if (!packages) {
		throw new Error(`Settings has no packages array: ${settingsPath}`);
	}

	let changed = false;
	for (let i = 0; i < packages.length; i++) {
		const entry = packages[i];
		const currentSource = typeof entry === "string" ? entry : entry?.source;
		if (!currentSource) continue;
		const parsed = parseNpmSource(currentSource);
		if (!parsed || parsed.name !== packageName) continue;

		if (typeof entry === "string") {
			packages[i] = source;
		} else {
			packages[i] = { ...entry, source };
		}
		changed = true;
		break;
	}

	if (!changed) {
		throw new Error(`Package ${packageName} not found in ${settingsPath}`);
	}

	await writeFile(settingsPath, `${JSON.stringify(settings, null, 2)}\n`, "utf-8");
}

async function rollbackToEntry(pi: ExtensionAPI, entry: RollbackLogEntry): Promise<void> {
	try {
		await setPinnedSource(entry.settingsPath, entry.packageName, entry.previousSource);
	} catch (err) {
		if (!existsSync(entry.backupPath)) {
			throw err;
		}
		const backupRaw = await readFile(entry.backupPath, "utf-8");
		await writeFile(entry.settingsPath, backupRaw, "utf-8");
	}

	const installArgs = ["install"];
	if (entry.scope === "project") installArgs.push("-l");
	installArgs.push(entry.previousSource);

	const install = await pi.exec("pi", installArgs, { timeout: COMMAND_TIMEOUT_MS });
	if (install.code !== 0) {
		throw new Error(install.stderr?.trim() || `Failed reinstall during rollback: ${entry.previousSource}`);
	}
}

async function tryAutomaticRollback(pi: ExtensionAPI, bump: BumpResult): Promise<string> {
	const rollbackEntry: RollbackLogEntry = {
		timestamp: Date.now(),
		packageName: bump.packageName,
		scope: bump.scope,
		settingsPath: bump.settingsPath,
		previousSource: bump.previousSource,
		newSource: bump.newSource,
		backupPath: bump.backupPath,
	};
	await rollbackToEntry(pi, rollbackEntry);
	return `Automatic rollback restored ${bump.previousSource}.`;
}

function usage(): string {
	return [
		"Usage: /secure-update <npm-package> [--repo <owner/repo|url>] [--dry-run] [--yes] [--force] [--allow-npm-diff] [--update-all] [--ci]",
		"",
		"Notes:",
		"  - Default is artifact-first diff (published npm tarballs).",
		"  - If repo is available, GitHub compare diff is added as supplemental context.",
		"  - Does NOT run 'pi update' by default. Add --update-all to update everything.",
		"  - Security policy loaded from ~/.pi/agent/security-policy.json.",
		"  - Use --allow-npm-diff only as fallback if policy allows it.",
		"  - --ci implies --yes, writes JSON summary next to report, emits one-line stdout summary.",
		"",
		"Examples:",
		"  /secure-update @marckrenn/pi-sub-bar --repo owner/repo --dry-run",
		"  /secure-update @marckrenn/pi-sub-bar --repo owner/repo",
		"  /secure-update @marckrenn/pi-sub-bar --update-all",
		"  /secure-update @marckrenn/pi-sub-bar --repo owner/repo --dry-run --ci",
	].join("\n");
}

function rollbackUsage(): string {
	return [
		"Usage: /secure-update-rollback [<npm-package>] [--yes]",
		"",
		"Examples:",
		"  /secure-update-rollback @marckrenn/pi-sub-bar",
		"  /secure-update-rollback --yes",
	].join("\n");
}

function shellEscapeArg(value: string): string {
	if (/^[A-Za-z0-9@%_+=:,./-]+$/.test(value)) return value;
	return `'${value.replace(/'/g, `'\\''`)}'`;
}

function buildSecureUpdateCommand(
	packageName: string,
	options: CommandOptions,
	overrides: Partial<CommandOptions> = {},
): string {
	const effective: CommandOptions = {
		...options,
		...overrides,
		packageName,
	};

	const parts = ["/secure-update", shellEscapeArg(packageName)];
	if (effective.repo) {
		parts.push("--repo", shellEscapeArg(effective.repo));
	}
	if (effective.dryRun) parts.push("--dry-run");
	if (effective.yes) parts.push("--yes");
	if (effective.force) parts.push("--force");
	if (effective.allowNpmDiff) parts.push("--allow-npm-diff");
	if (effective.updateAll) parts.push("--update-all");
	if (effective.ci) parts.push("--ci");
	return parts.join(" ");
}

function pasteCommandSuggestion(ctx: ExtensionContext, command: string, reason: string): void {
	if (!ctx.hasUI) return;
	ctx.ui.pasteToEditor(command);
	ctx.ui.notify(`${reason} Pasted command into editor.`, "info");
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("secure-update", {
		description: "Review package update (artifact-first), then bump pinned version safely",
		handler: async (args, ctx) => {
			const parsed = parseArgs(args);
			if (!parsed.ok) {
				ctx.ui.notify(`${parsed.error}\n${usage()}`, "error");
				return;
			}
			const options = parsed.options;
			if (options.help || !options.packageName) {
				ctx.ui.notify(usage(), "info");
				if (options.ci && !options.help) {
					setCiExitCode(true, 4);
					console.log("secure-update-ci status=failed exit=4 package=(missing) message=Missing package name");
					if (!ctx.hasUI) {
						process.exit(4);
					}
				}
				return;
			}

			const packageName = options.packageName;
			const ciMode = options.ci;
			const autoApprove = options.yes || ciMode;
			let bumped: BumpResult | undefined;
			let currentVersionForSummary: string | undefined;
			let latestVersionForSummary: string | undefined;
			let policyPathForSummary: string | undefined;
			let repoSlugForSummary: string | undefined;
			let diffForSummary: DiffResult | undefined;
			let analysisForSummary: AnalysisResult | undefined;
			let provenanceForSummary: ProvenanceEvaluation | undefined;
			let transitiveForSummary: TransitiveDepsEvaluation | undefined;
			let repoConsistencyForSummary: RepoTarballConsistencyEvaluation | undefined;
			let artifactsForSummary: ReportArtifacts | undefined;
			let stage: "precheck" | "analysis" | "apply" = "precheck";

			const maybeHardExitForCi = (exitCode: number): void => {
				if (!ciMode) return;
				if (exitCode === 0) return;
				if (ctx.hasUI) return;
				process.exit(exitCode);
			};

			const emitCiSimple = (status: CiStatus, exitCode: number, message: string): void => {
				if (!ciMode) return;
				setCiExitCode(true, exitCode);
				const compactMessage = message.replace(/\s+/g, " ").trim().slice(0, 260);
				console.log(
					[
						"secure-update-ci",
						`status=${status}`,
						`exit=${exitCode}`,
						`package=${packageName}`,
						...(currentVersionForSummary ? [`from=${currentVersionForSummary}`] : []),
						...(latestVersionForSummary ? [`to=${latestVersionForSummary}`] : []),
						`message=${compactMessage}`,
					].join(" "),
				);
				maybeHardExitForCi(exitCode);
			};

			const emitCiStructured = async (status: CiStatus, exitCode: number, message: string): Promise<void> => {
				if (!ciMode) return;
				if (
					!currentVersionForSummary ||
					!latestVersionForSummary ||
					!policyPathForSummary ||
					!diffForSummary ||
					!analysisForSummary ||
					!provenanceForSummary ||
					!transitiveForSummary ||
					!repoConsistencyForSummary ||
					!artifactsForSummary
				) {
					emitCiSimple(status, exitCode, message);
					return;
				}

				const warnings = {
					total:
						provenanceForSummary.warnings.length +
						transitiveForSummary.warnings.length +
						repoConsistencyForSummary.warnings.length,
					provenance: provenanceForSummary.warnings.length,
					transitive: transitiveForSummary.warnings.length,
					repoTarball: repoConsistencyForSummary.warnings.length,
				};
				const violations = {
					total:
						provenanceForSummary.violations.length +
						transitiveForSummary.violations.length +
						repoConsistencyForSummary.violations.length,
					provenance: provenanceForSummary.violations.length,
					transitive: transitiveForSummary.violations.length,
					repoTarball: repoConsistencyForSummary.violations.length,
				};

				const summary: CiSummaryArtifact = {
					timestamp: new Date().toISOString(),
					status,
					exitCode,
					message,
					packageName,
					fromVersion: currentVersionForSummary,
					toVersion: latestVersionForSummary,
					diffSource: diffForSummary.source,
					diffUrl: diffForSummary.diffUrl,
					repoSlug: repoSlugForSummary,
					policyPath: policyPathForSummary,
					reportPath: artifactsForSummary.reportPath,
					diffPath: artifactsForSummary.diffPath,
					verdict: analysisForSummary.verdict,
					riskScore: analysisForSummary.risk_score,
					recommendedAction: analysisForSummary.recommended_action,
					warnings,
					violations,
					provenanceWarnings: provenanceForSummary.warnings,
					provenanceViolations: provenanceForSummary.violations,
					transitiveWarnings: transitiveForSummary.warnings,
					transitiveViolations: transitiveForSummary.violations,
					repoTarballWarnings: repoConsistencyForSummary.warnings,
					repoTarballViolations: repoConsistencyForSummary.violations,
				};

				try {
					const summaryPath = await writeCiSummaryArtifact(artifactsForSummary.reportPath, summary);
					setCiExitCode(true, exitCode);
					emitCiLine(summary, summaryPath);
					maybeHardExitForCi(exitCode);
				} catch (err) {
					emitCiSimple(
						status,
						exitCode,
						`${message} (failed to write summary: ${err instanceof Error ? err.message : String(err)})`,
					);
				}
			};

			try {
				const projectSettingsPath = findNearestProjectSettings(ctx.cwd);
				const [projectSettings, globalSettings] = await Promise.all([
					projectSettingsPath ? readSettings(projectSettingsPath) : Promise.resolve<SettingsFile>({}),
					readSettings(GLOBAL_SETTINGS),
				]);

				const located =
					(projectSettingsPath
						? locatePackageInSettings(projectSettings, projectSettingsPath, "project", packageName)
						: undefined) ?? locatePackageInSettings(globalSettings, GLOBAL_SETTINGS, "global", packageName);

				if (!located) {
					ctx.ui.notify(
						`Package not found in pinned settings: ${packageName}. Add it to .pi/settings.json or ~/.pi/agent/settings.json first.`,
						"error",
					);
					emitCiSimple("failed", 4, "Package not found in pinned settings");
					return;
				}

				if (!located.version) {
					ctx.ui.notify(
						`Package is not pinned in ${located.scope} settings. Pin it first (npm:${packageName}@x.y.z).`,
						"error",
					);
					emitCiSimple("failed", 4, "Package is not pinned to an exact npm version");
					return;
				}
				currentVersionForSummary = located.version;

				const policyBundle = await loadSecurityPolicy();
				policyPathForSummary = policyBundle.path;
				if (policyBundle.created) {
					ctx.ui.notify(`Created default security policy at ${policyBundle.path}. Review it before production use.`, "warning");
				} else if (policyBundle.updated) {
					ctx.ui.notify(`Updated policy defaults at ${policyBundle.path} with newly added keys.`, "info");
				}
				const policy = resolveSecurityPolicyForPackage(policyBundle.policy, packageName);

				const latestVersionValue = await npmViewJson(pi, packageName, "version");
				const latestVersion = toStringValue(latestVersionValue);
				if (!latestVersion) {
					ctx.ui.notify(`Could not resolve latest npm version for ${packageName}.`, "error");
					emitCiSimple("failed", 4, "Could not resolve latest npm version");
					return;
				}
				latestVersionForSummary = latestVersion;

				if (compareVersion(latestVersion, located.version) <= 0) {
					ctx.ui.notify(`${packageName} is up to date (${located.version}).`, "info");
					emitCiSimple("success", 0, "Package already up to date");
					return;
				}

				ctx.ui.notify(`Analyzing ${packageName}: ${located.version} → ${latestVersion}`, "info");

				const repoHint = options.repo ?? policy.expectedRepo;
				const repoSlug = await resolveGitHubRepo(pi, packageName, repoHint);
				repoSlugForSummary = repoSlug;
				const allowNpmFallback = options.allowNpmDiff && policy.allowNpmDiffFallback !== false;
				if (options.allowNpmDiff && policy.allowNpmDiffFallback === false) {
					ctx.ui.notify("Policy disallows npm diff fallback; artifact/GitHub evidence required.", "warning");
				}

				stage = "analysis";
				const diff = await resolveDiff(
					pi,
					packageName,
					located.version,
					latestVersion,
					repoSlug,
					Boolean(options.repo || policy.expectedRepo),
					allowNpmFallback,
				);
				diffForSummary = diff;
				const diffLabel = diff.diffUrl ?? diff.source;

				const analysis = await analyzeDiffWithModel(
					ctx,
					packageName,
					located.version,
					latestVersion,
					diff.diff,
					diffLabel,
				);
				analysisForSummary = analysis;
				const provenance = await evaluateProvenance(
					pi,
					policyBundle.path,
					policy,
					packageName,
					located.version,
					latestVersion,
					repoSlug,
					diff,
					analysis,
				);
				provenanceForSummary = provenance;

				const transitive = await evaluateTransitiveDependencies(
					pi,
					policy,
					packageName,
					located.version,
					latestVersion,
				);
				transitiveForSummary = transitive;

				const repoConsistency = await evaluateRepoTarballConsistency(
					pi,
					policy,
					packageName,
					latestVersion,
					repoSlug,
				);
				repoConsistencyForSummary = repoConsistency;

				const artifacts = await writeReportArtifacts(
					packageName,
					located.version,
					latestVersion,
					diff,
					analysis,
					provenance,
					transitive,
					repoConsistency,
				);
				artifactsForSummary = artifacts;

				const totalWarnings =
					provenance.warnings.length + transitive.warnings.length + repoConsistency.warnings.length;
				const totalViolations =
					provenance.violations.length + transitive.violations.length + repoConsistency.violations.length;
				const severity =
					totalViolations > 0 ? "error" : totalWarnings > 0 || analysis.risk_score >= 70 ? "warning" : "info";
				ctx.ui.notify(
					`Review: ${analysis.verdict} (${analysis.risk_score}/100), warnings=${totalWarnings}, violations=${totalViolations}. Report: ${artifacts.reportPath}`,
					severity,
				);

				if (provenance.warnings.length > 0) {
					ctx.ui.notify(`Provenance warnings: ${provenance.warnings.join(" | ")}`, "warning");
				}
				if (transitive.warnings.length > 0) {
					ctx.ui.notify(`Transitive dependency warnings: ${transitive.warnings.join(" | ")}`, "warning");
				}
				if (repoConsistency.warnings.length > 0) {
					ctx.ui.notify(`Repo/tarball consistency warnings: ${repoConsistency.warnings.join(" | ")}`, "warning");
				}

				if (totalViolations > 0) {
					const violationMessages = [
						...provenance.violations,
						...transitive.violations,
						...repoConsistency.violations,
					];
					ctx.ui.notify(
						`Policy gate blocked update: ${violationMessages.join(" | ")}`,
						"error",
					);
					await emitCiStructured(
						"policy-blocked",
						2,
						`Policy gate blocked update with ${totalViolations} violation(s).`,
					);
					return;
				}

				if (analysis.recommended_action === "block" && !options.force) {
					ctx.ui.notify("Update blocked by analysis. Re-run with --force to override.", "error");
					pasteCommandSuggestion(
						ctx,
						buildSecureUpdateCommand(packageName, options, { force: true }),
						"Force-override draft ready.",
					);
					await emitCiStructured("analysis-blocked", 3, "Model recommended blocking this update.");
					return;
				}

				if (options.dryRun) {
					ctx.ui.notify("Dry run complete. No settings were changed.", "info");
					pasteCommandSuggestion(
						ctx,
						buildSecureUpdateCommand(packageName, options, { dryRun: false, yes: options.yes || options.ci }),
						"Ready-to-run command drafted.",
					);
					await emitCiStructured("dry-run", 0, "Dry run completed without applying changes.");
					return;
				}

				if (!autoApprove) {
					if (!ctx.hasUI) {
						ctx.ui.notify("No interactive UI available. Re-run with --yes or --ci.", "error");
						emitCiSimple("failed", 4, "No interactive UI available and auto-approve disabled");
						return;
					}
					const proceed = await ctx.ui.confirm(
						`Apply update for ${packageName}?`,
						[
							`Pinned ${located.version} → ${latestVersion}`,
							`Verdict: ${analysis.verdict} (${analysis.risk_score}/100)`,
							`Policy warnings: ${provenance.warnings.length}`,
							`Update all packages after install: ${options.updateAll ? "yes" : "no"}`,
							"Proceed?",
						].join("\n"),
					);
					if (!proceed) {
						ctx.ui.notify("Update cancelled.", "info");
						return;
					}
				}

				stage = "apply";
				bumped = await bumpPinnedVersion(located, latestVersion);

				const installArgs = ["install"];
				if (located.scope === "project") installArgs.push("-l");
				installArgs.push(bumped.newSource);

				const install = await pi.exec("pi", installArgs, { timeout: COMMAND_TIMEOUT_MS });
				if (install.code !== 0) {
					throw new Error(install.stderr?.trim() || "pi install failed");
				}

				if (options.updateAll) {
					const updated = await pi.exec("pi", ["update"], { timeout: COMMAND_TIMEOUT_MS });
					if (updated.code !== 0) {
						throw new Error(updated.stderr?.trim() || "pi update failed");
					}
				}

				try {
					await appendRollbackLog({
						timestamp: Date.now(),
						packageName: bumped.packageName,
						scope: bumped.scope,
						settingsPath: bumped.settingsPath,
						previousSource: bumped.previousSource,
						newSource: bumped.newSource,
						backupPath: bumped.backupPath,
					});
				} catch (logErr) {
					ctx.ui.notify(
						`Updated, but could not write rollback log: ${logErr instanceof Error ? logErr.message : String(logErr)}`,
						"warning",
					);
				}

				ctx.ui.notify(
					`Updated ${packageName} to ${latestVersion}. ${options.updateAll ? "Ran pi update." : "Skipped global pi update."} Backup: ${bumped.backupPath}. Report: ${artifacts.reportPath}`,
					"success",
				);
				await emitCiStructured("success", 0, "Update applied successfully.");
			} catch (err) {
				if (bumped) {
					try {
						const rollbackMessage = await tryAutomaticRollback(pi, bumped);
						ctx.ui.notify(rollbackMessage, "warning");
					} catch (rollbackErr) {
						ctx.ui.notify(
							`Automatic rollback failed. Manual fallback: ${bumped.backupPath}. Error: ${rollbackErr instanceof Error ? rollbackErr.message : String(rollbackErr)}`,
							"error",
						);
					}
				}
				const errorMessage = err instanceof Error ? err.message : String(err);
				ctx.ui.notify(`secure-update failed: ${errorMessage}`, "error");

				const exitCode = stage === "apply" ? 4 : 2;
				if (artifactsForSummary) {
					await emitCiStructured("failed", exitCode, errorMessage);
				} else {
					emitCiSimple("failed", exitCode, errorMessage);
				}
			}
		},
	});

	pi.registerCommand("secure-update-rollback", {
		description: "Rollback latest secure-update operation (or a specific package)",
		handler: async (args, ctx) => {
			const parsed = parseRollbackArgs(args);
			if (!parsed.ok) {
				ctx.ui.notify(`${parsed.error}\n${rollbackUsage()}`, "error");
				return;
			}
			const options = parsed.options;
			if (options.help) {
				ctx.ui.notify(rollbackUsage(), "info");
				return;
			}

			try {
				const entries = await readRollbackLog();
				if (entries.length === 0) {
					ctx.ui.notify("No rollback entries found.", "info");
					return;
				}

				const entry = selectRollbackEntry(entries, options.packageName);
				if (!entry) {
					ctx.ui.notify(`No rollback entry found for ${options.packageName}.`, "error");
					return;
				}

				if (!options.yes) {
					if (!ctx.hasUI) {
						ctx.ui.notify("No interactive UI available. Re-run with --yes.", "error");
						return;
					}
					const proceed = await ctx.ui.confirm(
						`Rollback ${entry.packageName}?`,
						[
							`Current pinned source will be reset to: ${entry.previousSource}`,
							`Backup snapshot: ${entry.backupPath}`,
							"Proceed?",
						].join("\n"),
					);
					if (!proceed) {
						ctx.ui.notify("Rollback cancelled.", "info");
						return;
					}
				}

				await rollbackToEntry(pi, entry);
				ctx.ui.notify(`Rolled back ${entry.packageName} to ${entry.previousSource}.`, "success");
			} catch (err) {
				ctx.ui.notify(`secure-update-rollback failed: ${err instanceof Error ? err.message : String(err)}`, "error");
			}
		},
	});
}

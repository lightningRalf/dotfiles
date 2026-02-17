import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { existsSync } from "node:fs";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";

type SettingsPackage = string | { source?: string };

interface SettingsFile {
	packages?: SettingsPackage[];
}

interface NpmPackageSpec {
	name: string;
	version?: string;
	source: string;
}

interface PackageUpdate {
	name: string;
	current: string;
	latest: string;
}

interface AutoCheckCache {
	lastCheckedAt?: number;
}

const GLOBAL_SETTINGS = join(homedir(), ".pi", "agent", "settings.json");
const CACHE_FILE = join(homedir(), ".pi", "agent", ".cache", "package-update-notify.json");
const AUTO_CHECK_INTERVAL_MS = 6 * 60 * 60 * 1000; // 6 hours

function parseNpmSource(source: string): NpmPackageSpec | undefined {
	if (!source.startsWith("npm:")) return undefined;
	const spec = source.slice(4).trim();
	const match = spec.match(/^(@?[^@]+(?:\/[^@]+)?)(?:@(.+))?$/);
	if (!match) return undefined;
	return {
		name: match[1],
		version: match[2],
		source,
	};
}

async function readSettings(path: string): Promise<SettingsFile> {
	if (!existsSync(path)) return {};
	try {
		const content = await readFile(path, "utf-8");
		return JSON.parse(content) as SettingsFile;
	} catch {
		return {};
	}
}

function extractNpmPackages(settings: SettingsFile): NpmPackageSpec[] {
	const pkgs = settings.packages ?? [];
	const out: NpmPackageSpec[] = [];
	for (const pkg of pkgs) {
		const source = typeof pkg === "string" ? pkg : pkg?.source;
		if (!source) continue;
		const parsed = parseNpmSource(source);
		if (parsed) out.push(parsed);
	}
	return out;
}

function mergeByName(globalPkgs: NpmPackageSpec[], projectPkgs: NpmPackageSpec[]): NpmPackageSpec[] {
	const merged = new Map<string, NpmPackageSpec>();
	for (const pkg of globalPkgs) merged.set(pkg.name, pkg);
	for (const pkg of projectPkgs) merged.set(pkg.name, pkg); // project overrides global
	return Array.from(merged.values());
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

async function fetchLatestVersion(pkgName: string, timeoutMs = 4500): Promise<string | undefined> {
	const controller = new AbortController();
	const timeout = setTimeout(() => controller.abort(), timeoutMs);
	try {
		const url = `https://registry.npmjs.org/${encodeURIComponent(pkgName)}/latest`;
		const response = await fetch(url, { signal: controller.signal });
		if (!response.ok) return undefined;
		const json = (await response.json()) as { version?: string };
		return json.version;
	} catch {
		return undefined;
	} finally {
		clearTimeout(timeout);
	}
}

async function readAutoCheckCache(): Promise<AutoCheckCache> {
	if (!existsSync(CACHE_FILE)) return {};
	try {
		const content = await readFile(CACHE_FILE, "utf-8");
		return JSON.parse(content) as AutoCheckCache;
	} catch {
		return {};
	}
}

async function writeAutoCheckCache(cache: AutoCheckCache): Promise<void> {
	try {
		await mkdir(dirname(CACHE_FILE), { recursive: true });
		await writeFile(CACHE_FILE, JSON.stringify(cache), "utf-8");
	} catch {
		// Ignore cache write failures
	}
}

async function shouldRunAutoCheck(now = Date.now()): Promise<boolean> {
	const cache = await readAutoCheckCache();
	const lastCheckedAt = cache.lastCheckedAt ?? 0;
	return now - lastCheckedAt >= AUTO_CHECK_INTERVAL_MS;
}

async function markAutoCheck(now = Date.now()): Promise<void> {
	await writeAutoCheckCache({ lastCheckedAt: now });
}

async function checkPackageUpdates(cwd: string): Promise<{ updates: PackageUpdate[]; skippedUnpinned: string[] }> {
	const projectSettingsPath = resolve(cwd, ".pi", "settings.json");
	const [globalSettings, projectSettings] = await Promise.all([
		readSettings(GLOBAL_SETTINGS),
		readSettings(projectSettingsPath),
	]);

	const merged = mergeByName(extractNpmPackages(globalSettings), extractNpmPackages(projectSettings));
	const pinned = merged.filter((p) => !!p.version);
	const skippedUnpinned = merged.filter((p) => !p.version).map((p) => p.name);

	const checks = await Promise.all(
		pinned.map(async (pkg) => {
			const latest = await fetchLatestVersion(pkg.name);
			if (!latest || !pkg.version) return undefined;
			if (compareVersion(latest, pkg.version) > 0) {
				return { name: pkg.name, current: pkg.version, latest } as PackageUpdate;
			}
			return undefined;
		}),
	);

	return {
		updates: checks.filter((u): u is PackageUpdate => !!u),
		skippedUnpinned,
	};
}

function formatUpdateSummary(updates: PackageUpdate[]): string {
	const short = updates.slice(0, 2).map((u) => `${u.name} ${u.current}→${u.latest}`).join(", ");
	const more = updates.length > 2 ? ` (+${updates.length - 2} more)` : "";
	return `${short}${more}`;
}

async function runCheck(ctx: ExtensionContext, notifyWhenUpToDate = false): Promise<void> {
	const { updates, skippedUnpinned } = await checkPackageUpdates(ctx.cwd);
	if (updates.length > 0) {
		ctx.ui.setStatus("package-updates", `updates: ${updates.length}`);
		ctx.ui.notify(
			`Package updates available (${updates.length}): ${formatUpdateSummary(updates)}. Run 'pi update'.`,
			"warning",
		);
		return;
	}

	ctx.ui.setStatus("package-updates", undefined);
	if (notifyWhenUpToDate) {
		if (skippedUnpinned.length > 0) {
			ctx.ui.notify(
				`No updates for pinned packages. Unpinned packages: ${skippedUnpinned.join(", ")}`,
				"info",
			);
		} else {
			ctx.ui.notify("All pinned npm packages are up to date.", "info");
		}
	}
}

export default function (pi: ExtensionAPI): void {
	pi.on("session_start", (_event, ctx) => {
		if (!ctx.hasUI) return;
		// Fire-and-forget with 6h cooldown so startup stays snappy.
		void (async () => {
			if (!(await shouldRunAutoCheck())) return;
			await markAutoCheck();
			await runCheck(ctx, false);
		})();
	});

	pi.registerCommand("package-updates", {
		description: "Check for updates to pinned npm packages in pi settings",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;
			try {
				await markAutoCheck();
				await runCheck(ctx, true);
			} catch {
				ctx.ui.notify("Package update check failed.", "error");
			}
		},
	});
}

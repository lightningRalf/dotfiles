import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { planPromptTemplateTransform } from "../src/planPromptTemplateTransform.js";
import { loadPtxPolicyConfig, resolveTemplatePolicy } from "../src/ptxPolicyConfig.js";
import { PtxAutocompleteEditor } from "../src/ptxAutocompleteEditor.js";

const ACCELERATOR_PREFIX = "$$";

function stripAcceleratorPrefix(text: string): string | null {
  if (!text.startsWith(ACCELERATOR_PREFIX)) return null;
  return text.slice(ACCELERATOR_PREFIX.length).trimStart();
}

function stripOptionalAcceleratorPrefix(text: string): string {
  const stripped = stripAcceleratorPrefix(text);
  return stripped === null ? text.trim() : stripped.trim();
}

function asErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function formatQuotedArgs(args: string[]): string {
  if (args.length === 0) return "  (none)";
  return args
    .map((arg, index) => {
      const normalized = arg.length > 0 ? JSON.stringify(arg) : '""';
      return `  ${index + 1}. ${normalized}`;
    })
    .join("\n");
}

function formatPlaceholderUsage(usage: {
  positionalIndexes: number[];
  usesAllArgs: boolean;
  slices: Array<{ start: number; length?: number }>;
}): string {
  const positional =
    usage.positionalIndexes.length > 0
      ? usage.positionalIndexes.map((index) => `$${index}`).join(", ")
      : "(none)";

  const slices =
    usage.slices.length > 0
      ? usage.slices
          .map((slice) => (slice.length ? `\${@:${slice.start}:${slice.length}}` : `\${@:${slice.start}}`))
          .join(", ")
      : "(none)";

  return [
    `  positional: ${positional}`,
    `  uses all args ($@/$ARGUMENTS): ${usage.usesAllArgs ? "yes" : "no"}`,
    `  slices: ${slices}`,
  ].join("\n");
}

function formatContractView(args: string[]): string {
  const quote = (value: string | undefined) => {
    if (value === undefined || value.length === 0) return '""';
    return JSON.stringify(value);
  };

  const rest = args.slice(3);
  const restLines =
    rest.length > 0
      ? rest
          .map((arg, index) => {
            const position = index + 4;
            return `  ${position}. ${quote(arg)}`;
          })
          .join("\n")
      : "  (none)";

  return [
    "arg contract view ($1/$2/$3/${@:4}):",
    `  arg1 ($1 rough prompt): ${quote(args[0])}`,
    `  arg2 ($2 workflow context): ${quote(args[1])}`,
    `  arg3 ($3 system4d_mode): ${quote(args[2])}`,
    "  rest args (${@:4}):",
    restLines,
  ].join("\n");
}

function formatPolicyView(policy: { allowed: boolean; fallback: string; reason: string }): string {
  return [
    "policy:",
    `  allowed: ${policy.allowed ? "yes" : "no"}`,
    `  fallback: ${policy.fallback}`,
    `  reason: ${policy.reason}`,
  ].join("\n");
}

function formatTemplateHintView(hints: {
  positionalHints?: Record<number, string>;
  restHints?: Array<{ start: number; hint: string }>;
}): string {
  const positionalEntries = Object.entries(hints.positionalHints ?? {})
    .sort(([a], [b]) => Number(a) - Number(b))
    .map(([index, hint]) => `  $${index}: ${hint}`);

  const restEntries = (hints.restHints ?? [])
    .sort((a, b) => a.start - b.start)
    .map((entry) => `  start ${entry.start}: ${entry.hint}`);

  return [
    "template line hints:",
    "  positional:",
    positionalEntries.length > 0 ? positionalEntries.join("\n") : "  (none)",
    "  rest:",
    restEntries.length > 0 ? restEntries.join("\n") : "  (none)",
  ].join("\n");
}

function formatPolicyList(values: string[]): string {
  if (!values || values.length === 0) return "  (none)";
  return values.map((value) => `  - /${value}`).join("\n");
}

function formatPolicyOverrides(templates: Record<string, { policy?: string; fallback?: string }>): string {
  const entries = Object.entries(templates || {});
  if (entries.length === 0) return "  (none)";

  return entries
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([name, override]) => {
      const policy = override.policy ?? "(inherit)";
      const fallback = override.fallback ?? "(inherit)";
      return `  - /${name}: policy=${policy}, fallback=${fallback}`;
    })
    .join("\n");
}

function formatPolicyConfigReport(policyLoad: any, requestedTemplate?: string): string {
  const config = policyLoad.config;
  const templateName = requestedTemplate?.trim().replace(/^\/+/, "") || undefined;

  const lines = [
    "ptx policy",
    "",
    "source:",
    `  path: ${policyLoad.configPath}`,
    `  loaded from file: ${policyLoad.loadedFromFile ? "yes" : "no"}`,
    `  parse status: ${
      policyLoad.error
        ? `invalid (${asErrorMessage(policyLoad.error)}); using defaults`
        : policyLoad.loadedFromFile
          ? "ok"
          : "default config (file not found)"
    }`,
    "",
    "defaults:",
    `  defaultPolicy: ${config.defaultPolicy}`,
    `  defaultFallback: ${config.defaultFallback}`,
    "",
    "allowlist:",
    formatPolicyList(config.allowlist),
    "",
    "blocklist:",
    formatPolicyList(config.blocklist),
    "",
    "template overrides:",
    formatPolicyOverrides(config.templates),
  ];

  if (templateName) {
    const decision = resolveTemplatePolicy(templateName, config);
    lines.push(
      "",
      `decision for /${decision.commandName}:`,
      `  allowed: ${decision.allowed ? "yes" : "no"}`,
      `  fallback: ${decision.fallback}`,
      `  reason: ${decision.reason}`,
    );
  }

  return lines.join("\n");
}

function resolveFallbackMode(policy: { fallback?: string } | undefined): "passthrough" | "block" {
  return policy?.fallback === "block" ? "block" : "passthrough";
}

function suggestInEditor(ctx: any, text: string, message: string, type: "info" | "warning" = "info") {
  if (ctx.hasUI) {
    ctx.ui.setEditorText(text);
    ctx.ui.notify(message, type);
  }

  return { action: "handled" };
}

function applyFallback(
  ctx: any,
  fallbackMode: "passthrough" | "block",
  stripped: string,
  _images: any,
  message: string,
) {
  if (fallbackMode === "block") {
    if (ctx.hasUI) {
      ctx.ui.notify(`${message} (fallback=block)`, "warning");
    }
    return { action: "handled" };
  }

  return suggestInEditor(
    ctx,
    stripped,
    `${message} (fallback=passthrough). Suggested command inserted into editor; review and press Enter to run.`,
    "warning",
  );
}

function formatPreviewReport(rawInput: string, plan: any): string {
  return [
    "ptx preview",
    "",
    "raw input:",
    `  ${rawInput}`,
    "",
    "template:",
    `  command: /${plan.templateCommand.name}`,
    `  location: ${plan.templateCommand.location ?? "unknown"}`,
    `  path: ${plan.templateCommand.path}`,
    "",
    formatPolicyView(plan.policy),
    "",
    "placeholder usage:",
    formatPlaceholderUsage(plan.usage),
    "",
    formatTemplateHintView(plan.hints),
    "",
    "provided args:",
    formatQuotedArgs(plan.parsed.args),
    "",
    "mapped args:",
    formatQuotedArgs(plan.mappedArgs),
    "",
    formatContractView(plan.mappedArgs),
    "",
    "inferred context:",
    `  repo: ${plan.inferred.repoName}`,
    `  cwd: ${plan.inferred.cwd}`,
    `  branch: ${plan.inferred.branch ?? "(none)"}`,
    `  objective hint: ${plan.inferred.objectiveHint ?? "(none)"}`,
    "",
    "transformed command:",
    `  ${plan.transformed}`,
  ].join("\n");
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (!ctx.hasUI) return;

    ctx.ui.setEditorComponent((tui, theme, keybindings) => {
      return new PtxAutocompleteEditor(tui, theme, keybindings);
    });
  });

  pi.on("input", async (event, ctx) => {
    if (event.source === "extension") {
      return { action: "continue" };
    }

    const stripped = stripAcceleratorPrefix(event.text);
    if (stripped === null) {
      return { action: "continue" };
    }

    if (!stripped) {
      if (ctx.hasUI) {
        ctx.ui.notify(`Usage: ${ACCELERATOR_PREFIX} /template \"arg\"`, "warning");
      }
      return { action: "handled" };
    }

    const policyLoad = await loadPtxPolicyConfig({ cwd: ctx.cwd });
    if (policyLoad.error && ctx.hasUI) {
      ctx.ui.notify(
        `Invalid PTX config (${policyLoad.configPath}): ${asErrorMessage(policyLoad.error)}. Using defaults.`,
        "warning",
      );
    }

    const plan = await planPromptTemplateTransform({
      pi,
      ctx,
      rawText: stripped,
      policyConfig: policyLoad.config,
    });

    switch (plan.status) {
      case "parse-error": {
        if (ctx.hasUI) {
          ctx.ui.notify(`Could not parse command: ${plan.error.message}`, "warning");
        }
        return { action: "handled" };
      }

      case "not-slash-command": {
        if (ctx.hasUI) {
          ctx.ui.notify(`Expected slash command after '${ACCELERATOR_PREFIX}', e.g. ${ACCELERATOR_PREFIX} /template \"arg\"`, "warning");
        }
        return { action: "handled" };
      }

      case "non-template-command":
        return suggestInEditor(
          ctx,
          stripped,
          `Non-template command detected. Suggested command inserted into editor; review and press Enter to run.`,
        );

      case "policy-blocked": {
        const fallbackMode = resolveFallbackMode(plan.policy);
        return applyFallback(
          ctx,
          fallbackMode,
          stripped,
          event.images,
          `PTX policy blocked /${plan.parsed.commandName} (${plan.policy.reason})`,
        );
      }

      case "template-path-missing": {
        const fallbackMode = resolveFallbackMode(plan.policy);
        return applyFallback(
          ctx,
          fallbackMode,
          stripped,
          event.images,
          `Prompt template path unavailable: /${plan.parsed.commandName}`,
        );
      }

      case "template-read-error": {
        const fallbackMode = resolveFallbackMode(plan.policy);
        return applyFallback(
          ctx,
          fallbackMode,
          stripped,
          event.images,
          `Failed to read template /${plan.parsed.commandName}: ${asErrorMessage(plan.error)}`,
        );
      }

      case "ok":
        return suggestInEditor(
          ctx,
          plan.transformed,
          `PTX suggestion inserted into editor for /${plan.parsed.commandName}. Review and press Enter to run.`,
        );

      default:
        return { action: "handled" };
    }
  });

  pi.registerCommand("ptx", {
    description: "Show prompt-template accelerator status",
    handler: async (_args, ctx) => {
      if (!ctx.hasUI) return;
      ctx.ui.notify(`ptx active: prefix commands with '${ACCELERATOR_PREFIX}' to generate suggested commands (no auto-run)`, "info");
      ctx.ui.notify(
        `Autocomplete enabled for '${ACCELERATOR_PREFIX} /template' and '/ptx-preview /template' command names`,
        "info",
      );
      ctx.ui.notify(`Preview mapping with: /ptx-preview /template \"arg\"`, "info");
      ctx.ui.notify(`Inspect policy with: /ptx-policy [/template]`, "info");
      ctx.ui.notify(`Optional policy config: .pi/ptx-config.json (allowlist/blocklist/fallback)`, "info");
    },
  });

  pi.registerCommand("ptx-policy", {
    description: "Show effective PTX policy config for current cwd",
    handler: async (args, ctx) => {
      if (!ctx.hasUI) return;

      const policyLoad = await loadPtxPolicyConfig({ cwd: ctx.cwd });
      const requestedTemplate = args.trim().length > 0 ? args.trim().split(/\s+/)[0] : undefined;

      const report = formatPolicyConfigReport(policyLoad, requestedTemplate);
      await ctx.ui.editor("ptx policy", report);
    },
  });

  pi.registerCommand("ptx-preview", {
    description: "Preview $$ prompt-template argument mapping without executing",
    handler: async (args, ctx) => {
      if (!ctx.hasUI) return;

      const rawInput = stripOptionalAcceleratorPrefix(args);
      if (!rawInput) {
        ctx.ui.notify("Usage: /ptx-preview /template \"arg\"", "warning");
        return;
      }

      const policyLoad = await loadPtxPolicyConfig({ cwd: ctx.cwd });
      if (policyLoad.error) {
        ctx.ui.notify(
          `Invalid PTX config (${policyLoad.configPath}): ${asErrorMessage(policyLoad.error)}. Using defaults.`,
          "warning",
        );
      }

      const plan = await planPromptTemplateTransform({
        pi,
        ctx,
        rawText: rawInput,
        policyConfig: policyLoad.config,
      });

      switch (plan.status) {
        case "parse-error":
          ctx.ui.notify(`Could not parse command: ${plan.error.message}`, "warning");
          return;

        case "not-slash-command":
          ctx.ui.notify("Preview requires a slash command, e.g. /ptx-preview /refine \"text\"", "warning");
          return;

        case "non-template-command":
          ctx.ui.notify(`Not a prompt template command: /${plan.parsed.commandName}`, "warning");
          return;

        case "policy-blocked": {
          const fallbackMode = resolveFallbackMode(plan.policy);
          ctx.ui.notify(
            `PTX policy blocked /${plan.parsed.commandName} (${plan.policy.reason}, fallback=${fallbackMode})`,
            "warning",
          );
          return;
        }

        case "template-path-missing": {
          const fallbackMode = resolveFallbackMode(plan.policy);
          ctx.ui.notify(
            `Prompt template path unavailable: /${plan.parsed.commandName} (fallback=${fallbackMode})`,
            "warning",
          );
          return;
        }

        case "template-read-error": {
          const fallbackMode = resolveFallbackMode(plan.policy);
          ctx.ui.notify(
            `Failed to read template /${plan.parsed.commandName}: ${asErrorMessage(plan.error)} (fallback=${fallbackMode})`,
            "warning",
          );
          return;
        }

        case "ok": {
          const report = formatPreviewReport(rawInput, plan);
          await ctx.ui.editor("ptx preview", report);
          return;
        }

        default:
          ctx.ui.notify("Unable to preview mapping", "warning");
      }
    },
  });
}

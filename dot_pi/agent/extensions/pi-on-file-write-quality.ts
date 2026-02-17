import { existsSync } from "node:fs";
import path from "node:path";
import type { ExtensionAPI, ToolResultEventResult } from "@mariozechner/pi-coding-agent";
import { isEditToolResult, isWriteToolResult } from "@mariozechner/pi-coding-agent";

const SUPPORTED_FILE =
  /\.(js|jsx|ts|tsx|mjs|cjs|py|pyw|pyi|c|cc|cpp|cxx|h|hh|hpp|hxx|rs|go|java|rb)$/i;
const QUALITY_GATE_SCRIPT = path.join("scripts", "quality-gate.sh");
const HOOK_TIMEOUT_MS = 120_000;
const MAX_HOOK_OUTPUT_CHARS = 6_000;

function stripAtPrefix(filePath: string): string {
  return filePath.startsWith("@") ? filePath.slice(1) : filePath;
}

function truncate(text: string, maxChars = MAX_HOOK_OUTPUT_CHARS): string {
  if (text.length <= maxChars) return text;
  return `${text.slice(0, maxChars)}\n...[truncated]`;
}

function resolveQualityGateScript(cwd: string): string | undefined {
  const scriptPath = path.join(cwd, QUALITY_GATE_SCRIPT);
  return existsSync(scriptPath) ? scriptPath : undefined;
}

export default function piOnFileWriteQualityBridge(pi: ExtensionAPI) {
  let warnedMissingScript = false;

  pi.on("tool_result", async (event, ctx): Promise<ToolResultEventResult | void> => {
    if (event.isError) return;
    if (!isWriteToolResult(event) && !isEditToolResult(event)) return;

    const rawPath = (event.input as { path?: unknown }).path;
    if (typeof rawPath !== "string") return;

    const filePath = stripAtPrefix(rawPath);
    if (!SUPPORTED_FILE.test(filePath)) return;

    const scriptPath = resolveQualityGateScript(ctx.cwd);
    if (!scriptPath) {
      if (!warnedMissingScript && ctx.hasUI) {
        warnedMissingScript = true;
        ctx.ui.notify(
          "Pi write-time checks skipped: scripts/quality-gate.sh not found in project root.",
          "warning",
        );
      }
      return;
    }

    const result = await pi.exec("bash", [scriptPath, "write-file", filePath], {
      cwd: ctx.cwd,
      timeout: HOOK_TIMEOUT_MS,
    });

    if (result.code === 0) return;

    const combinedOutput = [result.stdout, result.stderr]
      .map((part) => part.trim())
      .filter(Boolean)
      .join("\n")
      .trim();

    const output = truncate(combinedOutput || `quality-gate exited with code ${result.code}.`);

    if (ctx.hasUI) {
      ctx.ui.notify(`Write-time checks failed: ${filePath}`, "warning");
    }

    return {
      content: [
        ...event.content,
        {
          type: "text",
          text:
            `\n\n🔬 Pi write-time checks reported issues for ${filePath}:\n` +
            `${output}\n\n` +
            "(Source of truth: scripts/quality-gate.sh and repo git hooks.)",
        },
      ],
    };
  });
}

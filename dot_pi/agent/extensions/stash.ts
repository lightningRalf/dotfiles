import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

/**
 * Stash extension
 *
 * - ctrl+x: push current editor content onto an in-memory stack, then clear editor
 * - ctrl+shift+x: pop from stack and append to current editor content
 *
 * Note: stack is in-memory only; it resets on pi restart or /reload.
 */
export default function stashExtension(pi: ExtensionAPI) {
  let stack: string[] = [];

  const updateStatus = (ctx: any) => {
    if (!ctx?.hasUI) return;
    // Footer status key must be stable per extension
    ctx.ui.setStatus("stash", stack.length > 0 ? `stash: ${stack.length}` : undefined);
  };

  pi.on("session_start", async (_event, ctx) => {
    // new session load; clear ephemeral state
    stack = [];
    updateStatus(ctx);
  });

  const popAndAppend = (ctx: any) => {
    const popped = stack.pop();
    if (popped === undefined) {
      ctx.ui.notify("stash: empty", "info");
      updateStatus(ctx);
      return;
    }

    const current = ctx.ui.getEditorText() ?? "";
    let next: string;
    if (current.length === 0) {
      next = popped;
    } else if (current.endsWith("\n") || popped.startsWith("\n")) {
      next = current + popped;
    } else {
      // Heuristic: keep text readable by inserting a newline between chunks.
      next = current + "\n" + popped;
    }

    ctx.ui.setEditorText(next);
    updateStatus(ctx);
  };

  pi.registerShortcut("ctrl+x", {
    description:
      "Stash editor content (push+clear). If editor is empty, unstash (pop+append).",
    handler: async (ctx) => {
      if (!ctx.hasUI) return;

      const text = ctx.ui.getEditorText() ?? "";

      // Important terminal limitation: Ctrl+Shift+<letter> usually produces the same
      // control code as Ctrl+<letter>, so we can't reliably distinguish ctrl+x from
      // ctrl+shift+x in most terminals. We therefore overload ctrl+x:
      // - non-empty editor => push+clear
      // - empty editor     => pop+append
      if (text.length === 0) {
        popAndAppend(ctx);
        return;
      }

      stack.push(text);
      ctx.ui.setEditorText("");
      updateStatus(ctx);
    },
  });

  // Alternative keys for explicit pop. Some terminals (Windows Terminal/cmd, zellij)
  // don't forward ctrl+alt combinations reliably.
  for (const key of ["alt+x", "ctrl+alt+x", "f9"] as const) {
    pi.registerShortcut(key, {
      description: "Unstash editor content (pop) and append to editor",
      handler: async (ctx) => {
        if (!ctx.hasUI) return;
        popAndAppend(ctx);
      },
    });
  }
}

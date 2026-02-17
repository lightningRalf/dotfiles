import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("_template-smoke-copier2", {
    description: "Run the _template-smoke-copier2 scaffold command",
    handler: async (_args, ctx) => {
      if (ctx.hasUI) {
        ctx.ui.notify("_template-smoke-copier2 scaffold ready", "info");
      }
    },
  });
}

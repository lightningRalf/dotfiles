import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import ext_ptx_ from "./extensions/ptx.ts";

export default function (pi: ExtensionAPI) {
  ext_ptx_(pi);
}

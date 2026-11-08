import type { ReactNode } from "react";
import { NODE_DOWNLOAD_PAGE, useNodeInstaller } from "./lib";

/** Downloads the current Node.js LTS installer for macOS – for everyone who doesn't have `npx` yet. */
export function GetNode({ children }: { children?: ReactNode }) {
  const installer = useNodeInstaller();
  return (
    <a
      href={installer?.url ?? NODE_DOWNLOAD_PAGE}
      title={installer ? `Node.js ${installer.version} LTS · macOS installer from nodejs.org` : "nodejs.org"}
      className="cursor-target text-white/70 underline decoration-white/25 underline-offset-[3px] transition-colors hover:text-white hover:decoration-white/70"
    >
      {children ?? `Download Node.js${installer ? ` ${installer.version}` : ""}`}
    </a>
  );
}

import { useEffect, useState } from "react";

export const REPO = "ddkbs/nosynotch";
export const REPO_URL = `https://github.com/${REPO}`;
export const RELEASES_URL = `${REPO_URL}/releases/latest`;
export const INSTALL_COMMAND = "npx nosynotch";

export type RepoInfo = {
  stars?: number;
  version?: string;
  /** The universal app archive attached to the latest release. */
  archive?: string;
};

/** One shared fetch per page load: star count and latest release from the public GitHub API. */
let repoInfo: Promise<RepoInfo> | null = null;
function loadRepoInfo(): Promise<RepoInfo> {
  const get = (path: string) =>
    fetch(`https://api.github.com/repos/${REPO}${path}`)
      .then((r) => (r.ok ? r.json() : null))
      .catch(() => null);
  repoInfo ??= Promise.all([get(""), get("/releases/latest")]).then(([repo, release]) => {
    const files: { name: string; browser_download_url: string }[] = release?.assets ?? [];
    return {
      stars: typeof repo?.stargazers_count === "number" ? repo.stargazers_count : undefined,
      version: release?.tag_name ? String(release.tag_name).replace(/^v/, "") : undefined,
      archive: files.find((f) => f.name.endsWith(".tar.gz"))?.browser_download_url,
    };
  });
  return repoInfo;
}

export function useRepoInfo(): RepoInfo {
  const [info, setInfo] = useState<RepoInfo>({});
  useEffect(() => {
    let live = true;
    void loadRepoInfo().then((i) => live && setInfo(i));
    return () => {
      live = false;
    };
  }, []);
  return info;
}

export function formatStars(n: number): string {
  return n >= 1000 ? `${(n / 1000).toFixed(n >= 10000 ? 0 : 1)}k` : String(n);
}

/** Pages ask the install notch to open through this event (hero button, nav notch). */
export const OPEN_INSTALL = "nosy:open-install";
export function openInstall() {
  window.dispatchEvent(new Event(OPEN_INSTALL));
}

export const ease = [0.22, 1, 0.36, 1] as const;
export const up = (delay: number) => ({
  initial: { opacity: 0, y: 16, filter: "blur(6px)" },
  animate: { opacity: 1, y: 0, filter: "blur(0px)" },
  transition: { duration: 0.9, delay, ease },
});

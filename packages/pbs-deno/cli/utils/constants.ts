export const HOME_DIR =
  Deno.env.get("HOME") ||
  Deno.env.get("HOMEPATH") ||
  Deno.env.get("USERPATH") ||
  Deno.cwd();

export const STORAGE_DIR = `${HOME_DIR}/.pbs`;

export const OBS_PATH = `${HOME_DIR}/.config/obs-studio`;

export const masterAbort = new AbortController();

export const envPrefix = "PBS_";

export const validVisibilities = ["public", "unlisted", "private"] as const;
export type Visibility = (typeof validVisibilities)[number];

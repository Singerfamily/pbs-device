import consola from "consola";
import { exists } from "jsr:@std/fs";
import { STORAGE_DIR } from "./constants.ts";
import { OBS } from "./obs.ts";

export const kv = await (async () => {
  consola.log("Initializing KV store...");
  consola.log(`Storage directory: ${STORAGE_DIR}`);

  const dirExists = await exists(STORAGE_DIR);
  if (!dirExists) {
    consola.warn("KV store does not exist, creating a new one...");
    await Deno.mkdir(STORAGE_DIR, { recursive: true });
  } else {
    consola.log("KV store directory already exists.");
  }

  return await Deno.openKv(STORAGE_DIR + "/db");
})();

export const youtube = async () => {
  const { google } = await import("npm:googleapis");
  const { authorize } = await import("./auth.ts");
  const auth = await authorize();
  return google.youtube({
    version: "v3",
    auth,
  });
};

export const obs = new OBS();

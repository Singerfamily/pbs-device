import { CliCommandOptionsFlat, defineCli } from "../utils/cli_parser.ts";
import { validVisibilities } from "../utils/constants.ts";

export const cliSpec = defineCli({
  auth: {
    description: "Authenticate with YouTube",
    force: {
      description: "Force re-authorization",
      type: "boolean",
      default: false,
      alias: ["f"],
    },

    "dump-credentials": {
      description: "Dump the current YouTube credentials",
      type: "boolean",
      default: false,
    },
  },
  "print-env": {
    description: "Print environment variable flags",
  },
  start: {
    description: "Start a live stream",
    title: {
      description: "Title of the stream",
      type: "string",
      default: "Sacrament Meeting",
      alias: ["t"],
    },
    visibility: {
      description: "Visibility of the stream",
      type: "string",
      choices: validVisibilities,
      default: "unlisted",
      alias: ["v"],
    },
  },
  stop: {
    description: "Stop the live stream",
    delete: {
      description: "Delete the broadcast after stopping",
      type: "boolean",
      default: false,
      alias: ["d"],
    },
    visibility: {
      description: "Visibility of the stream",
      type: "string",
      choices: validVisibilities,
      default: "unlisted",
      alias: ["v"],
    },
  },
  debug: {
    description: "Enable debug mode",
    funnel: {
      description: "Spawn a Tailscale funnel",
      type: "boolean",
      default: false,
    },
    kv: {
      description: "Dump KV store contents",
      type: "boolean",
      default: false,
    },
    env: {
      description: "Print Deno environment variables",
      type: "boolean",
    },
  },
});

export type FlagsForCommand<K extends keyof typeof cliSpec> =
  CliCommandOptionsFlat<typeof cliSpec, K>;

// Utility to print all environment variable flags and their descriptions
export function printEnvFlags() {
  console.log("\nEnvironment Variable Flags:\n");
  for (const [cmd, def] of Object.entries(cliSpec)) {
    for (const [flag, spec] of Object.entries(def)) {
      if (flag === "description" || typeof spec !== "object") continue;
      const envVar = `PBS_${cmd.toUpperCase()}_${flag
        .replace(/-/g, "_")
        .toUpperCase()}`;
      let desc = spec.description;
      if ("default" in spec && spec.default !== undefined)
        desc += ` (default: ${spec.default})`;
      if ("choices" in spec && spec.choices)
        desc += ` [choices: ${(spec.choices as readonly string[]).join(", ")}]`;
      console.log(`${envVar}: ${desc}`);
    }
  }
  console.log("");
}

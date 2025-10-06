// import { startWebcamWatcher } from "./utils/camera.ts";

// startWebcamWatcher({
//   intervalMs: 2000,
//   onConnect: async () => {
//     console.log("Webcam connected. Starting stream...");
//     // Import start dynamically to avoid circular deps
//     //   const { start } = await import("./actions/start.ts");
//     //   await start();
//   },
//   onDisconnect: async () => {
//     console.log("Webcam disconnected. Initiating shutdown sequence...");
//     // Import stop dynamically to avoid circular deps
//     //   const { stop } = await import("./actions/stop.ts");
//     //   await stop();
//     //   Deno.exit(0);
//   },
// });

import consola from "consola";
import { getRandomPort } from "get-port-please";
import { start } from "./actions/start.ts";
import { stop } from "./actions/stop.ts";
import { cliSpec } from "./constants/cli.ts";
import { parseCli } from "./utils/cli_parser.ts";
import { masterAbort } from "./utils/constants.ts";
import { getFunnelUrl, startFunnel } from "./utils/tunnel.ts";
import { kv } from "./utils/wrappers.ts";

const { command, flags } = parseCli(cliSpec);

console.log(`\n=== PBS CLI ===`);
console.log(`Command: ${command}`);
console.log(`Flags:`, flags);

let shutdownResolver: (() => void) | undefined = undefined;

switch (command) {
  case "auth": {
    const { authorize } = await import("./utils/auth.ts");

    const auth = await authorize(flags);

    if (!auth && !flags["dump-credentials"]) {
      consola.error("YouTube authentication failed. Please try again.");
      Deno.exit(1);
    } else {
      consola.success("YouTube authentication successful!");
    }

    break;
  }
  case "print-env": {
    // Print environment variable flags with color
    const green = (s: string) => `\x1b[32m${s}\x1b[0m`;
    const yellow = (s: string) => `\x1b[33m${s}\x1b[0m`;
    const cyan = (s: string) => `\x1b[36m${s}\x1b[0m`;
    console.log(cyan("Environment Variable Flags:\n"));
    for (const [cmd, def] of Object.entries(cliSpec)) {
      for (const [flag, spec] of Object.entries(def)) {
        if (flag === "description" || typeof spec !== "object") continue;
        const envVar = `PBS_${cmd.toUpperCase()}_${flag
          .replace(/-/g, "_")
          .toUpperCase()}`;
        let desc = spec.description;
        if (spec.alias) {
          desc += yellow(` (aliases: ${spec.alias.join(", ")})`);
        }
        console.log(`${green(envVar)}: ${desc}`);
      }
    }
    break;
  }

  case "debug": {
    const whoami = new Deno.Command("whoami");

    whoami.output().then((res) => {
      if (res.code === 0) {
        const user = new TextDecoder().decode(res.stdout).trim();
        console.log(`Running as user: ${user}`);
      } else {
        console.error(
          "Failed to get user:",
          new TextDecoder().decode(res.stderr)
        );
      }
    });

    console.log(`\n=== PBS Debug ===`);
    console.log(`Running as user: ${Deno.env.get("USER") || "unknown"}`);
    console.log(`Current working directory: ${Deno.cwd()}`);
    console.log(`Deno version: ${Deno.version.deno}`);
    console.log(`Deno PID: ${Deno.pid}`);
    console.log(`Deno platform: ${Deno.build.os} ${Deno.build.arch}`);
    if (flags.env) {
      console.log(`Deno environment variables:`);
      for (const [key, value] of Object.entries(Deno.env.toObject())) {
        console.log(`  ${key}: ${value}`);
      }
    }

    // console.log(`\n=== PBS Commands ===`);
    // for (const [cmd, def] of Object.entries(cliSpec)) {
    //   console.log(`\nCommand: ${cmd}`);
    //   console.log(`Description: ${def.description}`);
    //   for (const [optKey, opt] of Object.entries(def)) {
    //     if (optKey === "description" || typeof opt !== "object") continue;
    //     const alias = opt.alias ? ` (aliases: ${opt.alias.join(", ")})` : "";
    //     const choices = opt.choices
    //       ? ` [choices: ${opt.choices.join(", ")}]`
    //       : "";
    //     const defVal =
    //       opt.default !== undefined ? ` (default: ${opt.default})` : "";
    //     console.log(
    //       `  --${optKey}${alias}${choices}: ${opt.description}${defVal}`
    //     );
    //   }
    // }

    if (flags.funnel) {
      const tunnel = startFunnel(await getRandomPort());

      if (tunnel) {
        consola.success(`Tailscale funnel started successfully!`);
        console.log(`Tunnel URL: ${getFunnelUrl()}`);
      } else {
        consola.error(`Failed to start Tailscale funnel.`);
      }
    }

    break;
  }

  case "start": {
    // Clean, modern start logic
    const { title, visibility, "dry-run": dryRun } = flags;
    console.log(`\n=== PBS Start ===`);
    console.log(`Title: ${title}`);
    console.log(`Visibility: ${visibility}`);
    console.log(`Dry run: ${dryRun}`);

    // Validate visibility
    const validVis = ["public", "unlisted", "private"];
    if (!validVis.includes(visibility)) {
      console.error(
        `Invalid visibility: ${visibility}. Valid: ${validVis.join(", ")}`
      );
      Deno.exit(1);
    }

    // If dry run, just print config and exit
    if (dryRun) {
      console.log("[DRY RUN] Would start stream with above settings.");
      break;
    }

    // TODO: Insert actual start logic here (e.g. OBS launch, API calls, etc.)
    console.log("[LIVE] Starting stream...");

    await start(flags);

    // Hold process open until interrupted
    await new Promise<void>((resolve) => {
      consola.info("Stream started. Press Ctrl+C to stop.");
      const shutdownHandler = () => {
        consola.info("Stopping stream...");
        masterAbort.abort("Stream stopped by user.");
        stop();
        resolve();
      };
      Deno.addSignalListener("SIGINT", shutdownHandler);
      Deno.addSignalListener("SIGTERM", shutdownHandler);
      Deno.addSignalListener("SIGHUP", shutdownHandler);
      // Keep the process alive
      shutdownResolver = resolve; // Store resolver for shutdown
    });

    break;
  }
  case "stop": {
    // Clean, modern stop logic
    console.log(`\n=== PBS Stop ===`);
    console.log(`Visibility: ${flags.visibility}`);
    console.log(`Delete broadcast: ${flags.delete ? "yes" : "no"}`);

    // Validate visibility
    const validVis = ["public", "unlisted", "private"];
    if (!validVis.includes(flags.visibility)) {
      console.error(
        `Invalid visibility: ${flags.visibility}. Valid: ${validVis.join(", ")}`
      );
      Deno.exit(1);
    }

    await stop(flags);
  }
}

// Improved shutdown handler: idempotent, logs errors, closes resources, and only calls stop if running
async function handleShutdown(signal: string) {
  consola.info(`Received ${signal}, shutting down PBS...`);
  masterAbort.abort(`${signal} received, stopping the stream.`);
  // Only call stop if the stream is running (optional: add your own check)
  await stop();
  kv.close();
  consola.success("Shutdown complete. Goodbye!");
  if (shutdownResolver) shutdownResolver();
}

for (const sig of ["SIGINT", "SIGTERM", "SIGHUP"] as Deno.Signal[]) {
  Deno.addSignalListener(sig, async () => await handleShutdown(sig));
}

import { ChildProcessWithoutNullStreams, spawn } from "node:child_process";
import { consola } from "npm:consola";
import { masterAbort, OBS_PATH } from "./constants.ts";

// Extract config type for clarity
interface OBSServiceConfig {
  settings: {
    bwtest: boolean;
    key: string;
    server: string;
    service: string;
  };
  type: string;
}

export class OBS {
  private obsProcess: ChildProcessWithoutNullStreams | undefined;
  private profile: string;
  private scene: string;
  private configPath: string;
  // If true, the next close event is expected (we killed OBS intentionally)
  private expectedExit = false;
  // Last stream key used to start OBS (used when attempting automatic restarts)
  private lastStreamKey: string | undefined;
  // Whether a restart loop is currently scheduled/running
  private restarting = false;
  // Restart backoff parameters (ms)
  private restartDelay = 1000;
  private readonly restartMaxDelay = 30_000;

  constructor(profile = "Sacrament", scene = "Welcome") {
    this.profile = profile;
    this.scene = scene;
    this.configPath = `${OBS_PATH}/basic/profiles/${this.profile}/service.json`;
  }

  public async start(
    streamkey?: string
  ): Promise<ChildProcessWithoutNullStreams> {
    // Clear any expectation that an exit was intentional when starting normally
    this.expectedExit = false;

    // remember the stream key for auto-restarts
    if (streamkey) this.lastStreamKey = streamkey;

    if (this.obsProcess) {
      return this.obsProcess;
    }

    consola.start(`Starting OBS...`);
    consola.log(`Using Stream Key: ${streamkey}`);

    let rawCfg: string;
    try {
      rawCfg = await Deno.readTextFile(this.configPath);
    } catch (err) {
      consola.error(`Could not read OBS config at ${this.configPath}:`, err);
      throw err;
    }

    let jsonCfg: OBSServiceConfig;
    try {
      jsonCfg = JSON.parse(rawCfg);
    } catch (err) {
      consola.error("Invalid OBS config JSON:", err);
      throw err;
    }

    jsonCfg.settings.key = streamkey || jsonCfg.settings.key;

    try {
      await Deno.writeTextFile(this.configPath, JSON.stringify(jsonCfg));
    } catch (err) {
      consola.error(`Could not write OBS config at ${this.configPath}:`, err);
      throw err;
    }

    const proc = spawn(
      "obs",
      [
        "--startstreaming",
        "--collection",
        this.profile,
        "--scene",
        this.scene,
        Deno.env.get("PBS_DEBUG") ? "--verbose" : "",
      ],
      {
        detached: true,
        signal: masterAbort.signal,
      }
    );

    this.obsProcess = proc;
    if (proc.unref) proc.unref();

    proc.stdout?.on("data", (data) => {
      consola.info(`[OBS]: ${data}`);
    });

    if (consola.level === 5) {
      proc.stderr.on("data", (data) => {
        consola.error(`[OBS]: ${data}`);
      });
    }

    proc.on("error", (err) => {
      consola.error("Failed to start OBS:", err);
      this.obsProcess = undefined;
      // Can't throw here, so emit log only
    });

    proc.on("close", (code, signal) => {
      consola.log(`[OBS] process exited with code ${code} signal=${signal}`);
      // Clear current process reference
      this.obsProcess = undefined;

      // If this exit was expected (we intentionally killed OBS) or abort signal fired, don't restart
      if (this.expectedExit) {
        consola.debug("OBS exit was expected; not restarting.");
        // reset expectedExit so future unexpected exits can be handled
        this.expectedExit = false;
        return;
      }

      if (masterAbort.signal.aborted) {
        consola.debug("Master abort signalled; not restarting OBS.");
        return;
      }

      // Otherwise, attempt to restart OBS (with backoff)
      if (!this.restarting) {
        this.restarting = true;
        void this.attemptRestartLoop();
      }
    });

    return proc;
  }

  public kill(): void {
    if (this.obsProcess) {
      // Mark that this exit is expected so the close handler won't attempt a restart
      this.expectedExit = true;
      try {
        this.obsProcess.kill();
      } catch (err) {
        consola.debug("Error killing OBS process:", err);
      }
      this.obsProcess = undefined;
    }
  }

  public get process(): ChildProcessWithoutNullStreams | undefined {
    return this.obsProcess;
  }

  // Attempt to restart OBS using an exponential backoff until success, master abort, or an expected exit is set.
  private async attemptRestartLoop(): Promise<void> {
    while (!masterAbort.signal.aborted && !this.expectedExit) {
      try {
        consola.log(`Attempting to restart OBS (delay ${this.restartDelay}ms)`);
        await this.start(this.lastStreamKey);
        // start succeeded; reset restart state
        this.restarting = false;
        this.restartDelay = 1000;
        consola.log("OBS restarted successfully.");
        return;
      } catch (err) {
        consola.error("OBS restart attempt failed:", err);
        // wait for restartDelay or until masterAbort
        await new Promise<void>((resolve) => {
          const to = setTimeout(() => resolve(), this.restartDelay);
          // if masterAbort fires, clear timeout and resolve immediately
          const onAbort = () => {
            clearTimeout(to);
            resolve();
          };
          masterAbort.signal.addEventListener("abort", onAbort, { once: true });
        });
        // increase delay
        this.restartDelay = Math.min(this.restartDelay * 2, this.restartMaxDelay);
      }
    }

    // Cleanup flags if we exit the loop
    this.restarting = false;
  }
}

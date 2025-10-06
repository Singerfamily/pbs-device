import {
  ChildProcessWithoutNullStreams,
  execSync,
  spawnSync,
} from "node:child_process";
import { consola } from "npm:consola";

export interface FunnelProcess {
  url: string;
  kill: () => void;
  process: ChildProcessWithoutNullStreams;
}

export function getFunnelUrl(): string {
  try {
    // if (!silent) consola.start(`Getting Tailscale hostname...`);
    const output = execSync("tailscale status --json", { encoding: "utf-8" });
    const status = JSON.parse(output);

    const dnsname = status?.Self?.DNSName || "";

    // Trim the trailing dot if it exists
    return dnsname.endsWith(".") ? dnsname.slice(0, -1) : dnsname;
  } catch (err) {
    consola.error("Failed to get Tailscale hostname:", err);
    return "";
  }
}

export function startFunnel(port: number) {
  consola.start(`Starting Tailscale funnel on port ${port}...`);

  // Clear any existing funnel
  spawnSync("tailscale funnel reset");

  const args = ["tailscale", "funnel", `${port}`];
  consola.debug(`Tailscale funnel command: ${args.join(" ")}`);
  const cmd = new Deno.Command("sudo", {
    args,
    stdout: "piped",
    stderr: "piped",
  });

  const proc = cmd.spawn();

  consola.debug(`Tailscale funnel process started with PID: ${proc.pid}`);

  proc.stdout.pipeTo(
    new WritableStream({
      write(chunk) {
        consola.info(new TextDecoder().decode(chunk));
      },
    })
  );

  return proc;
}

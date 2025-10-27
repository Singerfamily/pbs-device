/**
 * Starts a background watcher that checks for /dev/video* devices every intervalMs milliseconds.
 * Calls onConnect when a webcam appears, and onDisconnect when all webcams are gone.
 */
export function startWebcamWatcher({
  intervalMs = 2000,
  onConnect,
  onDisconnect,
}: {
  intervalMs?: number;
  onConnect?: () => void;
  onDisconnect?: () => void;
}) {
  let running = true;
  let wasConnected: boolean | undefined = undefined;
  (async () => {
    while (running) {
      let connected = false;
      try {
        console.log("Checking for webcams...");
        const p = new Deno.Command("bash", {
          args: ["-c", "ls /dev/video* 2>/dev/null || true"],
          stdout: "piped",
        });
        const status = await p.output();

        if (status.code !== 0) {
          console.error(
            "Error checking for webcams:",
            new TextDecoder().decode(status.stderr)
          );
          connected = false;
          continue;
        }

        const videoDevices = new TextDecoder()
          .decode(status.stdout)
          .trim()
          .split("\n")
          .filter((line) => line.startsWith("/dev/video"));

        connected = videoDevices.length > 0;
        
        // If we have a webcam, log it
        if (connected) {
          const videoDevices = new TextDecoder()
            .decode(status.stdout)
            .trim()
            .split("\n")
            .filter((line) => line.startsWith("/dev/video"));
          console.log("Webcam devices found:", videoDevices);
        }
        // If we don't have a webcam, log it
        else {
          console.log("No webcams found.");
        }
      } catch (_) {
        connected = false;
      }
      if (wasConnected !== undefined && connected !== wasConnected) {
        if (connected && onConnect) onConnect();
        if (!connected && onDisconnect) onDisconnect();
        if (!connected) {
          running = false;
          break;
        }
      }
      wasConnected = connected;
      await new Promise((res) => setTimeout(res, intervalMs));
    }
  })();
  return () => {
    running = false;
  };
}

import consola from "consola";
import { toCamelCase } from "jsr:@std/text";
import { FlagsForCommand } from "../constants/cli.ts";
import { kv, obs, youtube } from "../utils/wrappers.ts";

export const stop = async (opts: FlagsForCommand<"stop"> = {
  delete: false,
  visibility: "unlisted",
}) => {

  consola.debug("Stopping live stream with options:", opts);

  if (obs) {
    consola.info("Stopping OBS...");
    obs.kill();

    consola.success("OBS stopped successfully.");
  }

  const broadcastId = await kv.get<string>(["stream", "broadcast", "id"]);

  if (!broadcastId.value) {
    consola.error("No broadcast ID found. Cannot stop stream.");
    return;
  } else {
    consola.info(`Stopping live broadcast with ID: ${broadcastId.value}`);
  }

  const yt = await youtube();

  if (opts.delete || false) {
    await yt.liveBroadcasts
      .delete({
        id: broadcastId.value,
      })
      .catch((err) => console.error("Failed to delete live broadcast:", err));
    consola.success(`Deleted live broadcast with ID: ${broadcastId.value}`);
  } else {
    consola.info("Transitioning live broadcast to complete...");

    consola.info("Updating live broadcast visibility...");

    await yt.liveBroadcasts
      .update({
        part: ["id", "status"],
        requestBody: {
          id: broadcastId.value,
          status: {
            privacyStatus: opts.visibility || "unlisted",
          },
        },
      })
      .catch((err) => console.error("Failed to delete live broadcast:", err));

    consola.success(
      `${toCamelCase(opts.visibility)} live broadcast with ID: ${
        broadcastId.value
      }`
    );
  }

  await kv.delete(["stream", "broadcast", "id"]);
};

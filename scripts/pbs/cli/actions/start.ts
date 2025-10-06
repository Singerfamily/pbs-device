import { consola } from "npm:consola";
import { renderUnicodeCompact } from "npm:uqr";
import { FlagsForCommand } from "../constants/cli.ts";
import { kv, obs, youtube } from "../utils/wrappers.ts";

export const start = async (opts?: FlagsForCommand<"start">) => {
  const yt = await youtube();

  consola.debug("Starting live stream setup with args", opts);

  if (opts?.dryRun) {
    consola.warn("Dry run mode enabled. No actions will be performed.");
    consola.info("YouTube API client initialized successfully.");
    return;
  }

  // Create Stream

  const stream = (
    await yt.liveStreams.insert({
      part: ["snippet", "cdn", "contentDetails"],
      requestBody: {
        snippet: {
          title: opts?.title || "PBS Live Stream",
          isDefaultStream: true,
        },
        cdn: {
          resolution: "variable",
          frameRate: "variable",
          ingestionType: "rtmp",
        },
        contentDetails: {
          isReusable: false,
        },
      },
    })
  ).data;

  const streamKey = stream.cdn?.ingestionInfo?.streamName;

  if (!streamKey) {
    throw new Error("Failed to create live stream or no stream key available.");
  }

  consola.start(`Starting live stream with key: ${streamKey}`);

  const cur = new Date();
  cur.setHours(cur.getHours() + 1, 0, 0, 0); // Set to top of the hour

  // Create Broadcast

  const broadcast = (
    await yt.liveBroadcasts.insert({
      part: ["snippet", "contentDetails", "status"],
      requestBody: {
        snippet: {
          scheduledStartTime: cur.toISOString(),
          scheduledEndTime: cur.toISOString(),
          title: `Auburn Bay Ward Live Stream`,
        },
        contentDetails: {
          closedCaptionsType: "closedCaptionsDisabled",
          enableContentEncryption: true,
          enableDvr: false,
          enableAutoStart: true,
          enableAutoStop: true,
        },
        kind: "youtube#liveBroadcast",
        status: {
          privacyStatus: opts?.visibility || "unlisted",
          selfDeclaredMadeForKids: true,
        },
      },
    })
  ).data;

  if (!broadcast.id) {
    throw new Error("Live broadcast creation failed.");
  }

  await kv.set(["stream", "broadcast", "id"], broadcast.id);

  consola.success(`Created live broadcast with ID: ${broadcast.id}`);

  consola.info(`Scheduled start time: ${cur.toISOString()}`);

  // Bind Stream to Broadcast

  await yt.liveBroadcasts
    .bind({
      part: ["id"],
      id: broadcast.id,
      streamId: stream.id!,
    })
    .catch((err) => console.error("Failed to bind live broadcast:", err));
  consola.success(`Bound live broadcast to stream key: ${streamKey}\n\n`);

  // Generate Dashboard URL

  const dashboardUrl = `https://studio.youtube.com/video/${broadcast.id}/livestreaming`;

  consola.log(renderUnicodeCompact(dashboardUrl));

  consola.box(dashboardUrl);

  await obs.start(streamKey);
};

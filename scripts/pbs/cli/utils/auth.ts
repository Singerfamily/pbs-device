import consola from "consola";
import { getRandomPort } from "get-port-please";
import { Credentials } from "google-auth-library";
import { google } from "googleapis";
import { FlagsForCommand } from "../constants/cli.ts";
import { getFunnelUrl, startFunnel } from "./tunnel.ts";
import { kv } from "./wrappers.ts";

const SCOPES = [
  "https://www.googleapis.com/auth/youtube",
  "https://www.googleapis.com/auth/youtube.force-ssl",
  "https://www.googleapis.com/auth/youtube.upload",
];

const auth = new google.auth.OAuth2(
  "845312267359-2i5o8uobmrd2spg1nhp63p7tvt2kj7la.apps.googleusercontent.com",
  "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",
  `https://${getFunnelUrl()}/auth/callback/`
);

export const authorize = async (opts?: FlagsForCommand<"auth">) => {
  if (opts?.["dump-credentials"]) {
    consola.warn("Dumping credentials to console...");
    const kvCredentials = await kv.get<Credentials>(["auth", "youtube"]);
    if (kvCredentials.value) {
      consola.log("Current credentials:", kvCredentials.value);
    } else {
      consola.warn("No credentials found in KV store.");
    }
    return auth;
  }

  if (opts?.force) {
    consola.warn("Forcing re-authorization...");
    await kv.set(["auth", "youtube"], null); // Clear any existing credentials

    auth.setCredentials({}); // Clear current credentials
    consola.log("Credentials cleared. Starting OAuth flow...");
  }

  // Do we have credentials already?
  if (auth.credentials.refresh_token) {
    if (
      auth.credentials.expiry_date &&
      Date.now() >= auth.credentials.expiry_date
    ) {
      consola.warn("Credentials are expired, refreshing...");
      const { credentials } = await auth.refreshAccessToken();
      auth.credentials = credentials;
      consola.success("Credentials refreshed successfully.");

      return auth;
    }

    consola.log("Credentials are already loaded and valid.");
    return auth;
  }

  consola.log("Loading credentials from KV store...");
  const kvCredentials = await kv.get<Credentials>(["auth", "youtube"]);

  if (!kvCredentials.value || !kvCredentials.value.refresh_token) {
    await kv.set(["auth", "youtube"], null); // Clear any existing credentials

    // If no credentials are found, we need to start the OAuth flow
    await oauthFlow();
  }

  const token = kvCredentials.value!;

  auth.setCredentials(token);
  // consola.debug("Loaded credentials from KV store:", token);

  consola.log("Checking token expiration...");
  if (token.expiry_date && Date.now() >= token.expiry_date) {
    consola.warn("Token is expired, refreshing...");

    const { credentials } = await auth.refreshAccessToken();

    auth.setCredentials(credentials);

    // Update the KV store with the new credentials
    await kv.set(["auth", "youtube"], credentials);

    consola.success("Token refreshed successfully.");

    return auth;
  }

  consola.success("Successfully loaded credentials.");
  return auth;
};

export const oauthFlow = async () => {
  const port = await getRandomPort();
  const tunnel = startFunnel(port);
  const server = Deno.serve({ port }, async (req) => {
    const qs = new URL(req.url).searchParams;
    consola.log("Received request:", new URL(req.url).toString());
    if (!qs.has("code")) {
      return new Response("Missing 'code' parameter in request.", {
        status: 400,
        headers: { "Content-Type": "text/plain" },
      });
    }
    // else {
    //   tunnel.kill();
    //   await server.shutdown();
    // }

    consola.debug("Received code:", qs.get("code"));
    consola.start("Exchanging code for tokens...");
    const { tokens } = await auth.getToken(qs.get("code")!);
    auth.credentials = tokens; // eslint-disable-line require-atomic-updates
    consola.debug("Received tokens:", tokens);
    await kv.set(["auth", "youtube"], tokens);
    return new Response(
      "Authentication successful! Please return to the console.",
      {
        status: 200,
        headers: { "Content-Type": "text/plain" },
      }
    );
  });
  console.log(server.addr);
  // Generate a new authentication URL
  const authUrl = auth.generateAuthUrl({
    access_type: "offline",
    scope: SCOPES,
    // redirect_uri: auth.,
  });
  consola.success(authUrl);
  while (!auth.credentials.refresh_token) {
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }

  tunnel.kill();
  await server.shutdown();
};

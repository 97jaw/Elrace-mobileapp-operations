/**
 * Isolated codebase: deploy only to asia-south1.
 * Avoids me-central-1 upload 403 when main functions use setGlobalOptions(me-central-1).
 *
 * Deploy:
 *   firebase deploy --only functions:liveness:createFaceLivenessSession,functions:liveness:getFaceLivenessSessionResults
 */
const { setGlobalOptions } = require("firebase-functions/v2");
const { defineSecret, defineString } = require("firebase-functions/params");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");

initializeApp();

setGlobalOptions({ region: "asia-south1" });

const awsAccessKeyId = defineSecret("AWS_ACCESS_KEY_ID");
const awsSecretAccessKey = defineSecret("AWS_SECRET_ACCESS_KEY");
const awsRegionParam = defineString("AWS_REGION", { default: "ap-south-1" });

const callOptions = {
  secrets: [awsAccessKeyId, awsSecretAccessKey],
};

function resolveAwsCredentials() {
  try {
    const accessKeyId = awsAccessKeyId.value();
    const secretAccessKey = awsSecretAccessKey.value();
    if (accessKeyId && secretAccessKey) {
      return {
        accessKeyId,
        secretAccessKey,
        region: awsRegionParam.value(),
      };
    }
  } catch (_) {}

  const envKey = process.env.AWS_ACCESS_KEY_ID;
  const envSecret = process.env.AWS_SECRET_ACCESS_KEY;
  if (envKey && envSecret) {
    return {
      accessKeyId: envKey,
      secretAccessKey: envSecret,
      region: process.env.AWS_REGION || "ap-south-1",
    };
  }
  return null;
}

function getRekognitionClient() {
  const creds = resolveAwsCredentials();
  if (!creds) return null;
  const { RekognitionClient } = require("@aws-sdk/client-rekognition");
  return new RekognitionClient({
    region: creds.region,
    credentials: {
      accessKeyId: creds.accessKeyId,
      secretAccessKey: creds.secretAccessKey,
    },
  });
}

function requireString(value, fieldName) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${fieldName} is required`);
  }
  return value.trim();
}

exports.createFaceLivenessSession = onCall(callOptions, async () => {
  const creds = resolveAwsCredentials();
  const rekognitionRegion = creds?.region || awsRegionParam.value();
  const client = getRekognitionClient();
  if (!client) {
    const sessionId = `mock_liveness_${Date.now()}`;
    console.log("[AntiSpoof] createFaceLivenessSession mock", { sessionId });
    return {
      session_id: sessionId,
      mock_mode: true,
      region: rekognitionRegion,
    };
  }

  const {
    CreateFaceLivenessSessionCommand,
  } = require("@aws-sdk/client-rekognition");
  const response = await client.send(new CreateFaceLivenessSessionCommand({}));
  const sessionId = response.SessionId;
  if (!sessionId) {
    throw new HttpsError("internal", "AWS returned empty SessionId");
  }
  console.log("[AntiSpoof] createFaceLivenessSession", { sessionId });
  return {
    session_id: sessionId,
    mock_mode: false,
    region: rekognitionRegion,
  };
});

exports.getFaceLivenessSessionResults = onCall(callOptions, async (request) => {
  const data = request.data || {};
  const sessionId = requireString(
    data.session_id || data.sessionId,
    "session_id",
  );

  if (sessionId.startsWith("mock_liveness_")) {
    return {
      session_id: sessionId,
      status: "SUCCEEDED",
      confidence: 92.5,
      live: true,
      mock_mode: true,
    };
  }

  const client = getRekognitionClient();
  if (!client) {
    throw new HttpsError(
      "failed-precondition",
      "AWS credentials not configured on server",
    );
  }

  const {
    GetFaceLivenessSessionResultsCommand,
  } = require("@aws-sdk/client-rekognition");
  const response = await client.send(
    new GetFaceLivenessSessionResultsCommand({ SessionId: sessionId }),
  );

  const status = response.Status || "UNKNOWN";
  const confidence = response.Confidence ?? 0;
  const live = status === "SUCCEEDED";

  console.log("[AntiSpoof] getFaceLivenessSessionResults", {
    sessionId,
    status,
    confidence,
  });

  return {
    session_id: sessionId,
    status,
    confidence,
    live,
    mock_mode: false,
  };
});

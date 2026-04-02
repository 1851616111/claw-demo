"use strict";

const http = require("http");
const https = require("https");
const path = require("path");
const crypto = require("crypto");
const { URL } = require("url");

const SERVICE_NAME = "jira-relay";
const SERVICE_VERSION = "0.1.0";

function loadDotEnv(rootDir) {
  const fs = require("fs");
  const envPath = path.join(rootDir, ".env");

  if (!fs.existsSync(envPath)) {
    return;
  }

  const lines = fs.readFileSync(envPath, "utf8").split(/\r?\n/);

  for (const line of lines) {
    const trimmed = line.trim();

    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }

    const separatorIndex = trimmed.indexOf("=");

    if (separatorIndex === -1) {
      continue;
    }

    const key = trimmed.slice(0, separatorIndex).trim();
    let value = trimmed.slice(separatorIndex + 1).trim();

    if (!key || Object.prototype.hasOwnProperty.call(process.env, key)) {
      continue;
    }

    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    process.env[key] = value;
  }
}

function parseInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function createConfig(options = {}) {
  const rootDir = options.rootDir || __dirname;
  loadDotEnv(rootDir);

  const relayPath = process.env.RELAY_PATH || "/jira/events";
  const healthPath = process.env.HEALTH_PATH || "/healthz";

  return {
    rootDir,
    host: process.env.HOST || "0.0.0.0",
    port: parseInteger(process.env.PORT, 8080),
    relayPath,
    healthPath,
    authToken: process.env.RELAY_AUTH_TOKEN || "",
    requestTimeoutMs: parseInteger(process.env.REQUEST_TIMEOUT_MS, 10000),
    bodyLimitBytes: parseInteger(process.env.BODY_LIMIT_BYTES, 1024 * 1024),
    lobsterTargetUrl: process.env.LOBSTER_TARGET_URL || "http://127.0.0.1:18789/jira/events",
    lobsterAuthToken: process.env.LOBSTER_AUTH_TOKEN || ""
  };
}

function parseBearerToken(headerValue) {
  if (!headerValue) {
    return "";
  }

  const match = /^Bearer\s+(.+)$/i.exec(headerValue.trim());
  return match ? match[1] : "";
}

function readRequestBody(req, limitBytes) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];

    req.on("data", (chunk) => {
      size += chunk.length;

      if (size > limitBytes) {
        reject(Object.assign(new Error("Request body too large."), { statusCode: 413 }));
        req.destroy();
        return;
      }

      chunks.push(chunk);
    });

    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

function normalizePayload(rawPayload) {
  const issue = rawPayload.issue || {};
  const fields = issue.fields || {};

  return {
    eventName:
      rawPayload.event ||
      rawPayload.eventName ||
      rawPayload.webhookEvent ||
      "jira_event",
    issueKey: rawPayload.issueKey || issue.key || null,
    issueId: rawPayload.issueId || issue.id || null,
    summary: rawPayload.summary || fields.summary || null,
    projectKey:
      rawPayload.projectKey ||
      issue.projectKey ||
      fields.project?.key ||
      null,
    status:
      rawPayload.status ||
      rawPayload.statusName ||
      fields.status?.name ||
      null,
    previousStatus:
      rawPayload.previousStatus ||
      rawPayload.fromStatus ||
      rawPayload.changelog?.fromString ||
      null,
    serviceDomain:
      rawPayload.serviceDomain ||
      rawPayload.domain ||
      rawPayload.context?.serviceDomain ||
      null,
    executionMode:
      rawPayload.executionMode ||
      rawPayload.mode ||
      null,
    issueUrl:
      rawPayload.issueUrl ||
      rawPayload.issueBrowseUrl ||
      rawPayload.url ||
      null,
    context:
      rawPayload.context ||
      rawPayload.taskContext ||
      rawPayload["任务上下文"] ||
      rawPayload.description ||
      fields.description ||
      null
  };
}

function buildForwardPayload(rawPayload, normalized, req, targetUrl) {
  const correlationId = crypto.randomUUID();

  return {
    relay: {
      service: SERVICE_NAME,
      version: SERVICE_VERSION,
      correlationId,
      targetUrl,
      receivedAt: new Date().toISOString(),
      source: {
        method: req.method,
        path: req.url,
        remoteAddress: req.socket.remoteAddress || null,
        userAgent: req.headers["user-agent"] || null
      }
    },
    event: {
      name: normalized.eventName,
      status: normalized.status,
      previousStatus: normalized.previousStatus,
      serviceDomain: normalized.serviceDomain,
      executionMode: normalized.executionMode
    },
    issue: {
      key: normalized.issueKey,
      id: normalized.issueId,
      summary: normalized.summary,
      projectKey: normalized.projectKey,
      status: normalized.status,
      issueUrl: normalized.issueUrl
    },
    context: normalized.context,
    raw: rawPayload
  };
}

function sendJson(res, statusCode, body) {
  const payload = JSON.stringify(body, null, 2);
  res.writeHead(statusCode, {
    "content-type": "application/json; charset=utf-8",
    "content-length": Buffer.byteLength(payload)
  });
  res.end(payload);
}

function forwardJson(urlString, payload, options = {}) {
  const url = new URL(urlString);
  const body = JSON.stringify(payload);
  const headers = {
    "content-type": "application/json",
    "content-length": Buffer.byteLength(body),
    ...options.headers
  };

  const requestOptions = {
    protocol: url.protocol,
    hostname: url.hostname,
    port: url.port || (url.protocol === "https:" ? 443 : 80),
    path: `${url.pathname}${url.search}`,
    method: "POST",
    headers,
    timeout: options.timeoutMs || 10000
  };

  const client = url.protocol === "https:" ? https : http;

  return new Promise((resolve, reject) => {
    const upstreamReq = client.request(requestOptions, (upstreamRes) => {
      const chunks = [];

      upstreamRes.on("data", (chunk) => chunks.push(chunk));
      upstreamRes.on("end", () => {
        resolve({
          statusCode: upstreamRes.statusCode || 502,
          headers: upstreamRes.headers,
          body: Buffer.concat(chunks).toString("utf8")
        });
      });
    });

    upstreamReq.on("timeout", () => {
      upstreamReq.destroy(new Error("Upstream request timed out."));
    });
    upstreamReq.on("error", reject);
    upstreamReq.write(body);
    upstreamReq.end();
  });
}

async function handleRelayRequest(req, res, config) {
  if (req.method === "GET" && req.url === config.healthPath) {
    sendJson(res, 200, {
      ok: true,
      service: SERVICE_NAME,
      version: SERVICE_VERSION
    });
    return;
  }

  if (req.method !== "POST" || req.url !== config.relayPath) {
    sendJson(res, 404, {
      ok: false,
      error: "Route not found."
    });
    return;
  }

  const inboundToken =
    parseBearerToken(req.headers.authorization) ||
    req.headers["x-relay-token"] ||
    "";

  if (!config.authToken) {
    sendJson(res, 500, {
      ok: false,
      error: "RELAY_AUTH_TOKEN is not configured."
    });
    return;
  }

  if (inboundToken !== config.authToken) {
    sendJson(res, 401, {
      ok: false,
      error: "Unauthorized."
    });
    return;
  }

  let rawBody;
  let rawPayload;

  try {
    rawBody = await readRequestBody(req, config.bodyLimitBytes);
    rawPayload = rawBody ? JSON.parse(rawBody) : {};
  } catch (error) {
    sendJson(res, error.statusCode || 400, {
      ok: false,
      error: error.message || "Invalid request body."
    });
    return;
  }

  const normalized = normalizePayload(rawPayload);
  if (!config.lobsterTargetUrl) {
    sendJson(res, 502, {
      ok: false,
      error: "LOBSTER_TARGET_URL is not configured."
    });
    return;
  }

  const forwardPayload = buildForwardPayload(rawPayload, normalized, req, config.lobsterTargetUrl);

  const outboundHeaders = {
    "x-relay-correlation-id": forwardPayload.relay.correlationId,
    "x-relay-event": forwardPayload.event.name
  };

  if (config.lobsterAuthToken) {
    outboundHeaders.authorization = `Bearer ${config.lobsterAuthToken}`;
  }

  try {
    const upstreamResponse = await forwardJson(config.lobsterTargetUrl, forwardPayload, {
      headers: outboundHeaders,
      timeoutMs: config.requestTimeoutMs
    });

    const isSuccess =
      upstreamResponse.statusCode >= 200 && upstreamResponse.statusCode < 300;

    sendJson(res, isSuccess ? 202 : upstreamResponse.statusCode, {
      ok: isSuccess,
      targetUrl: config.lobsterTargetUrl,
      correlationId: forwardPayload.relay.correlationId,
      upstreamStatusCode: upstreamResponse.statusCode,
      upstreamBody: upstreamResponse.body || null
    });
  } catch (error) {
    sendJson(res, 502, {
      ok: false,
      error: error.message || "Failed to forward request.",
      targetUrl: config.lobsterTargetUrl
    });
  }
}

function createRelayServer(config) {
  return http.createServer((req, res) => {
    handleRelayRequest(req, res, config).catch((error) => {
      sendJson(res, 500, {
        ok: false,
        error: error.message || "Unexpected relay error."
      });
    });
  });
}

function startServer() {
  const config = createConfig();
  const server = createRelayServer(config);

  server.listen(config.port, config.host, () => {
    console.log(
      `${SERVICE_NAME} listening on http://${config.host}:${config.port}${config.relayPath}`
    );
  });

  return server;
}

if (require.main === module) {
  startServer();
}

module.exports = {
  SERVICE_NAME,
  SERVICE_VERSION,
  buildForwardPayload,
  createConfig,
  createRelayServer,
  forwardJson,
  loadDotEnv,
  normalizePayload,
  parseBearerToken,
  startServer
};

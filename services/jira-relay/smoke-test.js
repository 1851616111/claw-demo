"use strict";

const http = require("http");
const assert = require("assert");
const { createRelayServer } = require("./server");

function listen(server, port) {
  return new Promise((resolve) => {
    server.listen(port, "127.0.0.1", () => resolve(server.address()));
  });
}

function close(server) {
  return new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
}

function postJson(url, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(body);
    const request = http.request(
      url,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "content-length": Buffer.byteLength(payload),
          ...headers
        }
      },
      (response) => {
        const chunks = [];
        response.on("data", (chunk) => chunks.push(chunk));
        response.on("end", () => {
          resolve({
            statusCode: response.statusCode || 0,
            body: Buffer.concat(chunks).toString("utf8")
          });
        });
      }
    );

    request.on("error", reject);
    request.write(payload);
    request.end();
  });
}

async function main() {
  let forwardedBody = null;

  const lobsterServer = http.createServer((req, res) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => {
      forwardedBody = JSON.parse(Buffer.concat(chunks).toString("utf8"));
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ ok: true }));
    });
  });

  const lobsterAddress = await listen(lobsterServer, 0);

  const relayServer = createRelayServer({
    host: "127.0.0.1",
    port: 0,
    relayPath: "/jira/events",
    healthPath: "/healthz",
    authToken: "smoke-token",
    requestTimeoutMs: 5000,
    bodyLimitBytes: 1024 * 1024,
    lobsterTargetUrl: `http://127.0.0.1:${lobsterAddress.port}/hooks/jira-relay`,
    lobsterAuthToken: ""
  });

  const relayAddress = await listen(relayServer, 0);

  const response = await postJson(
    `http://127.0.0.1:${relayAddress.port}/jira/events`,
    {
      event: "issue_created",
      issueKey: "KAN-1",
      summary: "Smoke test",
      serviceDomain: "aws",
      context: {
        taskGoal: "verify relay"
      }
    },
    {
      authorization: "Bearer smoke-token"
    }
  );

  assert.strictEqual(response.statusCode, 202);
  assert.ok(forwardedBody);
  assert.strictEqual(forwardedBody.issue.key, "KAN-1");
  assert.strictEqual(forwardedBody.event.name, "issue_created");
  assert.strictEqual(forwardedBody.context.taskGoal, "verify relay");

  await close(relayServer);
  await close(lobsterServer);

  console.log("relay smoke test passed");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

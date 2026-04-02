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
  let forwardedHeaders = null;

  const lobsterServer = http.createServer((req, res) => {
    const chunks = [];
    forwardedHeaders = req.headers;

    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => {
      forwardedBody = JSON.parse(Buffer.concat(chunks).toString("utf8"));
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ ok: true, received: true }));
    });
  });

  const lobsterAddress = await listen(lobsterServer, 0);

  const relayServer = createRelayServer({
    host: "127.0.0.1",
    port: 0,
    relayPath: "/jira/events",
    healthPath: "/healthz",
    authToken: "jira-demo-token",
    requestTimeoutMs: 5000,
    bodyLimitBytes: 1024 * 1024,
    lobsterTargetUrl: `http://127.0.0.1:${lobsterAddress.port}/jira/events`,
    lobsterAuthToken: "lobster-internal-token"
  });

  const relayAddress = await listen(relayServer, 0);

  const jiraAutomationPayload = {
    event: "issue_created",
    issueKey: "KAN-42",
    summary: "创建 demo 告警通知链路",
    projectKey: "KAN",
    status: "待办",
    serviceDomain: "aws",
    executionMode: "单Agent",
    issueUrl: "https://netstars-sre-demo.atlassian.net/browse/KAN-42",
    context: {
      taskGoal: "验证 Jira Automation 事件是否能转发给龙虾",
      plannerOutput: "等待 Planner 规划",
      taskContext: "system=aws, service=notifications"
    }
  };

  const response = await postJson(
    `http://127.0.0.1:${relayAddress.port}/jira/events`,
    jiraAutomationPayload,
    {
      authorization: "Bearer jira-demo-token",
      "user-agent": "Atlassian HttpClient"
    }
  );

  assert.strictEqual(response.statusCode, 202);
  assert.ok(forwardedBody);
  assert.strictEqual(forwardedBody.event.name, "issue_created");
  assert.strictEqual(forwardedBody.issue.key, "KAN-42");
  assert.strictEqual(forwardedBody.issue.summary, "创建 demo 告警通知链路");
  assert.strictEqual(forwardedBody.issue.projectKey, "KAN");
  assert.strictEqual(forwardedBody.context.taskGoal, "验证 Jira Automation 事件是否能转发给龙虾");
  assert.strictEqual(forwardedBody.relay.source.userAgent, "Atlassian HttpClient");
  assert.strictEqual(forwardedHeaders.authorization, "Bearer lobster-internal-token");

  console.log("jira automation simulation passed");
  console.log(JSON.stringify(forwardedBody, null, 2));

  await close(relayServer);
  await close(lobsterServer);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

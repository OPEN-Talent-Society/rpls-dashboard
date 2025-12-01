#!/usr/bin/env node
import fetch from "node-fetch";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const server = new McpServer({
  name: "cortex-siyuan-mcp",
  version: "0.1.0",
});

const BASE_URL =
  process.env.SIYUAN_BASE_URL ?? "https://cortex.aienablement.academy";
const API_TOKEN =
  process.env.SIYUAN_API_TOKEN ??
  process.env.SIYUAN_TOKEN ??
  process.env.SIYUAN_ACCESS_TOKEN ??
  "";
const ACCESS_CLIENT_ID = process.env.CF_ACCESS_CLIENT_ID;
const ACCESS_CLIENT_SECRET = process.env.CF_ACCESS_CLIENT_SECRET;
const ACCESS_JWT =
  process.env.CF_ACCESS_JWT ??
  process.env.SIYUAN_ACCESS_AUTH_CODE ??
  process.env.SIYUAN_ACCESS_AUTH_CODE_BYPASS ??
  "";

if (!API_TOKEN) {
  console.warn(
    "[cortex-mcp] Warning: SIYUAN_API_TOKEN not set. Requests will fall back to unauthenticated mode."
  );
}

async function callSiyuan(endpoint, payload = {}) {
  const url = endpoint.startsWith("http")
    ? endpoint
    : `${BASE_URL.replace(/\/$/, "")}${endpoint.startsWith("/") ? "" : "/"}${endpoint}`;

  const headers = {
    "Content-Type": "application/json",
  };

  if (API_TOKEN) headers["Authorization"] = `Token ${API_TOKEN}`;
  if (ACCESS_CLIENT_ID && ACCESS_CLIENT_SECRET) {
    headers["CF-Access-Client-Id"] = ACCESS_CLIENT_ID;
    headers["CF-Access-Client-Secret"] = ACCESS_CLIENT_SECRET;
  }
  if (ACCESS_JWT) {
    headers["CF-Access-Jwt-Assertion"] = ACCESS_JWT;
    headers["Cookie"] = `CF_Authorization=${ACCESS_JWT}`;
  }

  const resp = await fetch(url, {
    method: "POST",
    headers,
    body: JSON.stringify(payload ?? {}),
  });
  const data = await resp.json().catch(() => ({}));

  if (!resp.ok) {
    throw new Error(`SiYuan request failed: HTTP ${resp.status} ${resp.statusText}`);
  }
  if (data && typeof data === "object" && "code" in data && data.code !== 0) {
    const msg = data.msg || "unknown error";
    throw new Error(`SiYuan error: ${msg}`);
  }
  return data;
}

server.registerTool(
  "siyuan_request",
  {
    title: "SiYuan Raw Request",
    description:
      "POST to a SiYuan API endpoint (e.g. /api/notebook/lsNotebooks). Provide payload as an object.",
    inputSchema: {
      type: "object",
      properties: {
        endpoint: {
          type: "string",
          description:
            "Endpoint path or full URL (e.g. /api/notebook/lsNotebooks).",
        },
        payload: {
          type: "object",
          additionalProperties: true,
        },
      },
      required: ["endpoint"],
    },
    outputSchema: {
      type: "object",
      properties: {
        response: {},
      },
    },
  },
  async ({ endpoint, payload }) => {
    const result = await callSiyuan(endpoint, payload ?? {});
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(result, null, 2),
        },
      ],
      structuredContent: { response: result },
    };
  }
);

server.registerTool(
  "siyuan_search",
  {
    title: "Search Docs",
    description: "Search SiYuan documents by keyword.",
    inputSchema: {
      type: "object",
      properties: {
        keyword: { type: "string" },
        page: { type: "integer", default: 1 },
        pageSize: { type: "integer", default: 20 },
      },
      required: ["keyword"],
    },
    outputSchema: {
      type: "object",
      properties: {
        response: {},
      },
    },
  },
  async ({ keyword, page = 1, pageSize = 20 }) => {
    const result = await callSiyuan("/api/search/searchDoc", {
      k: keyword,
      page,
      pageSize,
    });
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(result, null, 2),
        },
      ],
      structuredContent: { response: result },
    };
  }
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("[cortex-mcp] ready");
}

main().catch((err) => {
  console.error("[cortex-mcp] fatal", err);
  process.exit(1);
});

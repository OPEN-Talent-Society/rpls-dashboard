#!/usr/bin/env node

/**
 * Synchronize MCP server configuration across Codex CLI and Claude clients.
 *
 * Reads canonical definitions from `mcp/servers.json`, resolves environment
 * values (preferring process.env, falling back to existing configs), and
 * rewrites:
 *   - ~/.codex/config.toml           (Codex CLI)
 *   - claude-code/.claude/.claude.json
 *   - claude-zai/.claude/.claude.json
 *
 * This allows a single registry to drive the toolboxes for every agent.
 */

const fs = require("fs");
const path = require("path");

const rootDir = path.resolve(__dirname, "..");
const workspaceRoot = path.resolve(rootDir, "..");
const registryPath = path.join(rootDir, "mcp", "servers.json");
const envFilePath = path.join(rootDir, ".env.mcp");
const codexConfigPath = path.join(process.env.HOME || "", ".codex", "config.toml");
const claudeCodeConfigPath = path.join(workspaceRoot, "claude-code", ".claude", ".claude.json");
const claudeZaiConfigPath = path.join(workspaceRoot, "claude-zai", ".claude", ".claude.json");
const DEFAULT_PROJECT_TEMPLATE = {
  allowedTools: [],
  history: [],
  mcpContextUris: [],
  mcpServers: {},
  enabledMcpjsonServers: [],
  disabledMcpjsonServers: [],
  hasTrustDialogAccepted: true,
  ignorePatterns: []
};

function preloadEnv() {
  if (!fs.existsSync(envFilePath)) {
    return;
  }
  const text = fs.readFileSync(envFilePath, "utf8");
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1);
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (!(key in process.env)) {
      process.env[key] = value;
    }
  }
}

function loadRegistry() {
  const raw = fs.readFileSync(registryPath, "utf8");
  return JSON.parse(raw);
}

function parseCodexEnv(configText) {
  const envByServer = {};
  const lines = configText.split(/\r?\n/);
  let currentEnv = null;
  for (const line of lines) {
    const envHeaderMatch = line.match(/^\[mcp_servers\.([^\]]+)\.env\]$/);
    if (envHeaderMatch) {
      currentEnv = envHeaderMatch[1];
      envByServer[currentEnv] ??= {};
      continue;
    }
    const sectionMatch = line.match(/^\[mcp_servers\.([^\]]+)\]$/);
    if (sectionMatch) {
      currentEnv = null;
      continue;
    }
    if (currentEnv) {
      const kvMatch = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.+)$/);
      if (kvMatch) {
        const key = kvMatch[1];
        const rawValue = kvMatch[2].trim();
        envByServer[currentEnv][key] = parseTomlValue(rawValue);
      }
    }
  }
  return envByServer;
}

function parseTomlValue(value) {
  if (!value.length) return "";
  if (value.startsWith('"') || value.startsWith("'")) {
    try {
      return JSON.parse(value.replace(/'/g, '"'));
    } catch (err) {
      return value.slice(1, -1);
    }
  }
  if (value === "true" || value === "false") return value === "true";
  const num = Number(value);
  return Number.isNaN(num) ? value : num;
}

function ensureProject(data, projectPath) {
  if (!data.projects) data.projects = {};
  if (!data.projects[projectPath]) {
    const templateSource = Object.values(data.projects)[0];
    data.projects[projectPath] = templateSource ? JSON.parse(JSON.stringify(templateSource)) : JSON.parse(JSON.stringify(DEFAULT_PROJECT_TEMPLATE));
    data.projects[projectPath].mcpServers = data.projects[projectPath].mcpServers || {};
  }
  return data.projects[projectPath];
}

function loadMcpJson(projectPath) {
  const mcpPath = path.join(projectPath, ".claude", "mcp.json");
  if (!fs.existsSync(mcpPath)) {
    return { mcpPath, data: { mcpServers: {} }, mcpEnv: {}, mcpHeaders: {} };
  }
  const data = JSON.parse(fs.readFileSync(mcpPath, "utf8"));
  const mcpEnv = {};
  const mcpHeaders = {};
  for (const [name, cfg] of Object.entries(data.mcpServers || {})) {
    if (cfg.env) mcpEnv[name] = { ...cfg.env };
    if (cfg.headers) mcpHeaders[name] = { ...cfg.headers };
  }
  return { mcpPath, data, mcpEnv, mcpHeaders };
}

function parseClaudeConfig(configPath, projectDescriptors) {
  const data = JSON.parse(fs.readFileSync(configPath, "utf8"));
  const projects = {};
  for (const descriptor of projectDescriptors) {
    const projectPath = descriptor.path;
    const project = ensureProject(data, projectPath);
    const serverEnv = {};
    const serverHeaders = {};
    for (const [name, cfg] of Object.entries(project.mcpServers || {})) {
      if (cfg.env) serverEnv[name] = { ...cfg.env };
      if (cfg.headers) serverHeaders[name] = { ...cfg.headers };
    }
    const { mcpPath, data: mcpData, mcpEnv, mcpHeaders } = loadMcpJson(projectPath);
    projects[projectPath] = { project, serverEnv, serverHeaders, mcpPath, mcpData, mcpEnv, mcpHeaders };
  }
  return { data, projects };
}

function resolvePlaceholder(spec, key, fallbackMaps, desc) {
  if (typeof spec === "string" && spec.startsWith("${") && spec.endsWith("}")) {
    const envName = spec.slice(2, -1);
    const envValue = process.env[envName];
    if (envValue) return envValue;
    for (const fallbacks of fallbackMaps) {
      const candidate = fallbacks?.[key];
      if (candidate !== undefined && !(typeof candidate === "string" && candidate.includes("${"))) {
        return candidate;
      }
    }
    throw new Error(
      `Missing environment value for ${desc}.${key}. Set ${envName} or provide it in an existing config before running the sync.`
    );
  }
  return spec;
}

function buildCodexBlock(servers, resolvedEnv, registry) {
  const lines = [];
  lines.push("## MCP servers (auto-generated by scripts/sync-mcp-config.js)");
  for (const server of servers) {
    const client = server.clients?.codex;
    if (!client || client.enabled === false) continue;
    const name = client.name || server.id;
    lines.push(`[mcp_servers.${name}]`);
    if (server.type === "http") {
      lines.push(`type = "http"`);
      lines.push(`url = ${JSON.stringify(server.url)}`);
    } else {
      lines.push(`command = ${JSON.stringify(server.command)}`);
      if (server.args && server.args.length) {
        lines.push(`args = ${JSON.stringify(server.args)}`);
      }
    }
    lines.push("");
    const envMap = resolvedEnv[server.id];
    if (envMap && Object.keys(envMap).length > 0) {
      const section = server.type === "http" ? "headers" : "env";
      lines.push(`[mcp_servers.${name}.${section}]`);
      for (const [key, value] of Object.entries(envMap)) {
        lines.push(`${key} = ${JSON.stringify(value)}`);
      }
      lines.push("");
    }
  }
  return lines.map((line, index) => (line.length === 0 && index === lines.length - 1 ? "" : line)).join("\n");
}

function updateCodexConfig(codexPath, block) {
  if (!fs.existsSync(codexPath)) {
    throw new Error(`Codex config not found at ${codexPath}`);
  }
  const original = fs.readFileSync(codexPath, "utf8");
  const markerIndex = original.indexOf("[mcp_servers.");
  const prefix = markerIndex === -1 ? original.trimEnd() : original.slice(0, markerIndex).trimEnd();
  const newContent = `${prefix}\n\n${block}\n`;
  fs.writeFileSync(codexPath, newContent, "utf8");
}

function buildClaudeEntry(server, envMap) {
  const entry = { type: server.type };
  if (server.type === "stdio") {
    entry.command = server.command;
    if (server.args && server.args.length) {
      entry.args = server.args;
    }
    if (envMap && Object.keys(envMap).length) {
      entry.env = envMap;
    }
  } else if (server.type === "http") {
    entry.url = server.url;
    if (envMap && Object.keys(envMap).length) {
      entry.headers = envMap;
    }
  }
  return entry;
}

function updateClaudeConfig(config, registry, resolvedEnv, clientKey) {
  for (const [projectPath, projectData] of Object.entries(config.projects)) {
    const newServers = {};
    for (const server of registry.servers) {
      const client = server.clients?.[clientKey];
      if (!client || client.enabled === false) continue;
      const name = client.name || server.id;
      const envMap = resolvedEnv[clientKey]?.[projectPath]?.[server.id] || {};
      newServers[name] = buildClaudeEntry(server, envMap);
    }
    projectData.project.mcpServers = newServers;
  }
}

function writeMcpJson(config, registry, resolvedEnv, clientKey) {
  for (const [projectPath, projectData] of Object.entries(config.projects)) {
    const mcpServers = {};
    for (const server of registry.servers) {
      const client = server.clients?.[clientKey];
      if (!client || client.enabled === false) continue;
      const name = client.name || server.id;
      const envMap = resolvedEnv[clientKey]?.[projectPath]?.[server.id] || {};
      mcpServers[name] = buildClaudeEntry(server, envMap);
    }
    const output = { mcpServers };
    fs.mkdirSync(path.join(projectPath, ".claude"), { recursive: true });
    fs.writeFileSync(projectData.mcpPath, JSON.stringify(output, null, 2) + "\n");
  }
}

function main() {
  preloadEnv();
  const registry = loadRegistry();
  const codexConfigText = fs.readFileSync(codexConfigPath, "utf8");
  const codexEnv = parseCodexEnv(codexConfigText);

  const basePath = registry.projectPath || path.join(workspaceRoot);
  const claudeCodeProjects = [
    { path: basePath },
    { path: path.join(basePath, "claude-code") }
  ];
  const claudeZaiProjects = [
    { path: path.join(basePath, "claude-zai") }
  ];

  const claudeCodeConfig = parseClaudeConfig(claudeCodeConfigPath, claudeCodeProjects);
  const claudeZaiConfig = parseClaudeConfig(claudeZaiConfigPath, claudeZaiProjects);

  const resolvedEnv = { codex: {}, "claude-code": {}, "claude-zai": {} };

  for (const server of registry.servers) {
    const env = server.env || {};
    const headers = server.headers || {};
    const combined = {};
    const sources = [];

    const codexName = server.clients?.codex?.name;
    const claudeCodeName = server.clients?.["claude-code"]?.name;
    const claudeZaiName = server.clients?.["claude-zai"]?.name;

    const codexFallback = codexName ? codexEnv[codexName] : undefined;

    const claudeCodeFallbacks = [];
    if (claudeCodeName) {
      for (const { serverEnv } of Object.values(claudeCodeConfig.projects)) {
        if (serverEnv[claudeCodeName]) claudeCodeFallbacks.push(serverEnv[claudeCodeName]);
      }
      for (const { mcpEnv } of Object.values(claudeCodeConfig.projects)) {
        if (mcpEnv[claudeCodeName]) claudeCodeFallbacks.push(mcpEnv[claudeCodeName]);
      }
    }
    const claudeZaiFallbacks = [];
    if (claudeZaiName) {
      for (const { serverEnv } of Object.values(claudeZaiConfig.projects)) {
        if (serverEnv[claudeZaiName]) claudeZaiFallbacks.push(serverEnv[claudeZaiName]);
      }
      for (const { mcpEnv } of Object.values(claudeZaiConfig.projects)) {
        if (mcpEnv[claudeZaiName]) claudeZaiFallbacks.push(mcpEnv[claudeZaiName]);
      }
    }

    for (const [key, spec] of Object.entries(env)) {
      combined[key] = resolvePlaceholder(spec, key, [codexFallback, ...claudeCodeFallbacks, ...claudeZaiFallbacks], `${server.id} env`);
    }

    for (const [key, spec] of Object.entries(headers)) {
      const claudeHeaders = [];
      if (claudeCodeName) {
        for (const { serverHeaders } of Object.values(claudeCodeConfig.projects)) {
          if (serverHeaders[claudeCodeName]) claudeHeaders.push(serverHeaders[claudeCodeName]);
        }
        for (const { mcpHeaders } of Object.values(claudeCodeConfig.projects)) {
          if (mcpHeaders[claudeCodeName]) claudeHeaders.push(mcpHeaders[claudeCodeName]);
        }
      }
      if (claudeZaiName) {
        for (const { serverHeaders } of Object.values(claudeZaiConfig.projects)) {
          if (serverHeaders[claudeZaiName]) claudeHeaders.push(serverHeaders[claudeZaiName]);
        }
        for (const { mcpHeaders } of Object.values(claudeZaiConfig.projects)) {
          if (mcpHeaders[claudeZaiName]) claudeHeaders.push(mcpHeaders[claudeZaiName]);
        }
      }
      combined[key] = resolvePlaceholder(spec, key, [...claudeHeaders, codexFallback], `${server.id} header`);
    }

    const envValue = Object.keys(combined).length > 0 ? combined : undefined;
    if (envValue) {
      resolvedEnv.codex[server.id] = envValue;
      if (claudeCodeName) {
        for (const projectPath of Object.keys(claudeCodeConfig.projects)) {
          resolvedEnv["claude-code"][projectPath] ??= {};
          resolvedEnv["claude-code"][projectPath][server.id] = envValue;
        }
      }
      if (claudeZaiName) {
        for (const projectPath of Object.keys(claudeZaiConfig.projects)) {
          resolvedEnv["claude-zai"][projectPath] ??= {};
          resolvedEnv["claude-zai"][projectPath][server.id] = envValue;
        }
      }
    } else {
      if (claudeCodeName) {
        for (const projectPath of Object.keys(claudeCodeConfig.projects)) {
          resolvedEnv["claude-code"][projectPath] ??= {};
        }
      }
      if (claudeZaiName) {
        for (const projectPath of Object.keys(claudeZaiConfig.projects)) {
          resolvedEnv["claude-zai"][projectPath] ??= {};
        }
      }
    }
  }

  const codexBlock = buildCodexBlock(registry.servers, resolvedEnv.codex, registry);
  updateCodexConfig(codexConfigPath, codexBlock);

  updateClaudeConfig(claudeCodeConfig, registry, resolvedEnv, "claude-code");
  fs.writeFileSync(claudeCodeConfigPath, JSON.stringify(claudeCodeConfig.data, null, 2) + "\n");
  writeMcpJson(claudeCodeConfig, registry, resolvedEnv, "claude-code");

  updateClaudeConfig(claudeZaiConfig, registry, resolvedEnv, "claude-zai");
  fs.writeFileSync(claudeZaiConfigPath, JSON.stringify(claudeZaiConfig.data, null, 2) + "\n");
  writeMcpJson(claudeZaiConfig, registry, resolvedEnv, "claude-zai");
}

try {
  main();
  console.log("MCP configurations synchronized.");
} catch (error) {
  console.error(error.message);
  process.exit(1);
}

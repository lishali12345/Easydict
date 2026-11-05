import {
  chmodSync, closeSync, existsSync, fsyncSync, linkSync,
  mkdirSync, openSync, readFileSync, renameSync, unlinkSync, writeFileSync,
} from "node:fs";
import { randomUUID } from "node:crypto";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { paths } from "./paths.mjs";
import { loadPolicy } from "./policy.mjs";
import { exportRecords, getRecord, getRecordStats, listRecords } from "./records.mjs";

const pluginDirectory = dirname(fileURLToPath(import.meta.url));

/** Local-only setup and explicit record access; never contact a model or upload. */
function main(args) {
  let directory;
  const optionIndex = args.indexOf("--directory");
  if (optionIndex >= 0) {
    directory = args[optionIndex + 1];
    if (!directory) throw new Error("--directory requires an absolute path");
    args.splice(optionIndex, 2);
  }
  const files = paths(directory ? { directory } : {});
  const [command = "help", argument] = args;
  switch (command) {
    case "init":
      initialize(files);
      return { ...files, policyId: loadPolicy(files.policy).id };
    case "paths":
      return files;
    case "validate": {
      const policy = loadPolicy(files.policy);
      return { policyId: policy.id, terms: policy.snapshot.terms };
    }
    case "install":
      initialize(files);
      loadPolicy(files.policy);
      return configurePlugin(files, false);
    case "disable":
      return configurePlugin(files, true);
    case "stats":
      return getRecordStats(files.database);
    case "list":
      return listRecords(files.database, argument === undefined ? 20 : Number(argument));
    case "show": {
      if (!argument) throw new Error("show requires a record ID");
      const record = getRecord(files.database, argument);
      if (!record) throw new Error("Record not found");
      return record;
    }
    case "export":
      if (!argument) throw new Error("export requires a new output file");
      return exportToFile(files.database, resolve(argument));
    case "help":
      return {
        usage: "bun cli.mjs <command> [argument] [--directory /absolute/path]",
        commands: ["init", "paths", "validate", "install", "disable", "stats", "list [limit]", "show <id>", "export <new-file.jsonl>"],
      };
    default:
      throw new Error("Unknown command; run help");
  }
}

function initialize(files) {
  mkdirSync(files.directory, { recursive: true, mode: 0o700 });
  chmodSync(files.directory, 0o700);
  if (!existsSync(files.policy)) {
    writeFileSync(files.policy, readFileSync(join(pluginDirectory, "policy.example.json")), { flag: "wx", mode: 0o600 });
  }
  chmodSync(files.policy, 0o600);
}

function configurePlugin(files, off) {
  const configPath = join(homedir(), ".config", "magpie", "plugins.json");
  const original = readFileSync(configPath, "utf8");
  const config = JSON.parse(original);
  if (!Array.isArray(config.plugins)) throw new Error("Unsupported Magpie plugin configuration");
  let entry = config.plugins.find((item) => item?.spec === pluginDirectory);
  if (!entry && off) throw new Error("This plugin is not installed");
  if (!entry) {
    entry = { spec: pluginDirectory };
    config.plugins.push(entry);
  }
  entry.off = off;
  if (!off) {
    entry.options = { ...entry.options, directory: files.directory, gatewayTimeoutMs: 1000 };
  }

  const backups = join(files.directory, "backups");
  mkdirSync(backups, { recursive: true, mode: 0o700 });
  chmodSync(backups, 0o700);
  const backup = join(backups, `plugins-${Date.now()}-${randomUUID()}.json`);
  writeFileSync(backup, original, { flag: "wx", mode: 0o600 });
  const temporary = `${configPath}.meetar-${randomUUID()}`;
  try {
    writeFileSync(temporary, JSON.stringify(config, null, 2) + "\n", { flag: "wx", mode: 0o600 });
    if (readFileSync(configPath, "utf8") !== original) {
      throw new Error("Magpie configuration changed during setup; retry");
    }
    // Magpie notices this file's mtime/size on its next request and drains the old host.
    renameSync(temporary, configPath);
    const installed = JSON.parse(readFileSync(configPath, "utf8")).plugins
      .find((item) => item?.spec === pluginDirectory);
    if (!installed || installed.off !== off) throw new Error("Plugin configuration readback failed");
  } finally {
    if (existsSync(temporary)) unlinkSync(temporary);
  }
  return { enabled: !off, pluginDirectory, ...files, backup };
}

function exportToFile(database, destination) {
  if (existsSync(destination)) throw new Error("Export destination already exists");
  const temporary = `${destination}.partial-${randomUUID()}`;
  const fd = openSync(temporary, "wx", 0o600);
  let count = 0;
  try {
    for (const record of exportRecords(database)) {
      writeFileSync(fd, JSON.stringify(record) + "\n");
      count++;
    }
    fsyncSync(fd);
    // link is exclusive: an existing destination can never be overwritten.
    linkSync(temporary, destination);
  } finally {
    closeSync(fd);
    unlinkSync(temporary);
  }
  return { destination, records: count };
}

try {
  console.log(JSON.stringify(main(process.argv.slice(2)), null, 2));
} catch (error) {
  console.error(JSON.stringify({ error: error.message }));
  process.exitCode = 1;
}

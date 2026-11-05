import { Database } from "bun:sqlite";
import { chmodSync, closeSync, mkdirSync, openSync } from "node:fs";
import { dirname, isAbsolute } from "node:path";

const schema = `
  CREATE TABLE IF NOT EXISTS translation_records (
    id TEXT PRIMARY KEY,
    created_at TEXT NOT NULL,
    completed_at TEXT,
    protocol TEXT NOT NULL,
    model TEXT NOT NULL,
    agent TEXT NOT NULL,
    session TEXT NOT NULL,
    origin TEXT NOT NULL,
    query TEXT NOT NULL,
    policy_id TEXT NOT NULL,
    policy_json TEXT NOT NULL,
    original_request_json TEXT NOT NULL,
    effective_request_json TEXT NOT NULL,
    reply_json TEXT,
    response_text TEXT,
    capture_status TEXT NOT NULL DEFAULT 'awaiting_response'
      CHECK (capture_status IN ('awaiting_response', 'complete', 'incomplete'))
  );
  CREATE INDEX IF NOT EXISTS translation_records_created_at
    ON translation_records (created_at, id);
`;

const summaryColumns = `
  id, created_at AS createdAt, completed_at AS completedAt,
  protocol, model, agent, origin, policy_id AS policyId,
  capture_status AS captureStatus
`;

function requireAbsolutePath(dbPath) {
  if (typeof dbPath !== "string" || !isAbsolute(dbPath)) {
    throw new TypeError("The translation database path must be absolute.");
  }
}

function secureSidecars(dbPath) {
  for (const suffix of ["-wal", "-shm"]) {
    try {
      chmodSync(dbPath + suffix, 0o600);
    } catch (error) {
      // SQLite may remove a sidecar after another connection closes.
      if (error.code !== "ENOENT") throw error;
    }
  }
}

function openWriter(dbPath, create) {
  requireAbsolutePath(dbPath);
  if (create) {
    mkdirSync(dirname(dbPath), { recursive: true, mode: 0o700 });
    chmodSync(dirname(dbPath), 0o700);
    // Create with private permissions before SQLite writes any request data.
    closeSync(openSync(dbPath, "a", 0o600));
  }
  chmodSync(dbPath, 0o600);
  const db = new Database(dbPath, { create: false, strict: true });
  try {
    db.exec("PRAGMA busy_timeout = 150; PRAGMA journal_mode = WAL; PRAGMA synchronous = FULL;");
    secureSidecars(dbPath);
    if (create) db.exec(schema);
    return db;
  } catch (error) {
    db.close();
    throw error;
  }
}

function openReader(dbPath) {
  requireAbsolutePath(dbPath);
  const db = new Database(dbPath, { readonly: true, create: false, strict: true });
  db.exec("PRAGMA busy_timeout = 150;");
  return db;
}

function closeWriter(db, dbPath) {
  try {
    secureSidecars(dbPath);
  } finally {
    db.close();
  }
}

function decodeRecord(row) {
  if (!row) return null;
  return {
    id: row.id,
    createdAt: row.created_at,
    completedAt: row.completed_at,
    protocol: row.protocol,
    model: row.model,
    agent: row.agent,
    session: row.session,
    origin: row.origin,
    query: row.query,
    policyId: row.policy_id,
    policy: JSON.parse(row.policy_json),
    originalRequest: JSON.parse(row.original_request_json),
    effectiveRequest: JSON.parse(row.effective_request_json),
    reply: row.reply_json === null ? null : JSON.parse(row.reply_json),
    responseText: row.response_text,
    captureStatus: row.capture_status,
  };
}

/** Persist the original and enriched JSON independently before forwarding. */
export function recordRequest(dbPath, record) {
  const db = openWriter(dbPath, true);
  try {
    return db.transaction(() => db.query(`
      INSERT INTO translation_records (
        id, created_at, protocol, model, agent, session, origin, query,
        policy_id, policy_json, original_request_json, effective_request_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO NOTHING
    `).run(
      record.id, record.createdAt, record.protocol, record.model,
      record.agent ?? "", record.session ?? "", record.origin ?? "", record.query ?? "",
      record.policyId, JSON.stringify(record.policy), JSON.stringify(record.originalRequest),
      JSON.stringify(record.effectiveRequest),
    ).changes > 0)();
  } finally {
    closeWriter(db, dbPath);
  }
}

/** Completion describes capture, not model success or whether a message was sent. */
export function recordResponse(dbPath, id, response) {
  const db = openWriter(dbPath, false);
  try {
    return db.transaction(() => db.query(`
      UPDATE translation_records
      SET completed_at = ?, reply_json = ?, response_text = ?, capture_status = ?
      WHERE id = ? AND capture_status <> 'complete'
    `).run(
      response.completedAt,
      response.reply == null ? null : JSON.stringify(response.reply),
      response.responseText ?? null,
      response.success === true ? "complete" : "incomplete",
      id,
    ).changes > 0)();
  } finally {
    closeWriter(db, dbPath);
  }
}

/** Return metadata only, so listing records does not print private message text. */
export function listRecords(dbPath, limit = 20) {
  if (!Number.isInteger(limit) || limit < 1 || limit > 1000) {
    throw new RangeError("The record limit must be an integer from 1 to 1000.");
  }
  const db = openReader(dbPath);
  try {
    return db.query(`
      SELECT ${summaryColumns} FROM translation_records
      ORDER BY created_at DESC, id DESC LIMIT ?
    `).all(limit);
  } finally {
    db.close();
  }
}

/** Explicitly read one complete stored envelope, or null for an unknown ID. */
export function getRecord(dbPath, id) {
  const db = openReader(dbPath);
  try {
    return decodeRecord(db.query("SELECT * FROM translation_records WHERE id = ?").get(id));
  } finally {
    db.close();
  }
}

/** Iterate all captures in chronological order without loading the whole archive. */
export function* exportRecords(dbPath) {
  const db = openReader(dbPath);
  try {
    for (const row of db.query("SELECT * FROM translation_records ORDER BY created_at, id").iterate()) {
      yield decodeRecord(row);
    }
  } finally {
    db.close();
  }
}

/** Missing callbacks remain awaiting_response; no elapsed time implies success. */
export function getRecordStats(dbPath) {
  const db = openReader(dbPath);
  try {
    const counts = { awaiting_response: 0, complete: 0, incomplete: 0, total: 0 };
    for (const row of db.query(`
      SELECT capture_status AS status, COUNT(*) AS count
      FROM translation_records GROUP BY capture_status
    `).all()) {
      counts[row.status] = row.count;
      counts.total += row.count;
    }
    return counts;
  } finally {
    db.close();
  }
}

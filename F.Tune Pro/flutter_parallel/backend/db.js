// ── db.js ── SQLite database for license keys ──────────────────────────────
'use strict';

const Database = require('better-sqlite3');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

const DB_PATH = path.join(__dirname, 'ftune_licenses.db');

let _db;

function getDb() {
  if (!_db) {
    _db = new Database(DB_PATH);
    _db.pragma('journal_mode = WAL');
    _db.exec(`
      CREATE TABLE IF NOT EXISTS licenses (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        license_key   TEXT    NOT NULL UNIQUE,
        email         TEXT,
        order_code    TEXT    UNIQUE,
        activated     INTEGER NOT NULL DEFAULT 0,
        created_at    TEXT    NOT NULL DEFAULT (datetime('now')),
        activated_at  TEXT
      );
    `);
    _db.exec(`
      CREATE TABLE IF NOT EXISTS pending_orders (
        order_code    TEXT    PRIMARY KEY,
        email         TEXT,
        created_at    TEXT    NOT NULL DEFAULT (datetime('now'))
      );
    `);
  }
  return _db;
}

/** Lưu order + email trước khi user thanh toán. */
function savePendingOrder({ orderCode, email }) {
  const db = getDb();
  db.prepare(
    `INSERT OR REPLACE INTO pending_orders (order_code, email) VALUES (?, ?)`
  ).run(orderCode, email || null);
}

/** Tạo license key mới cho một PayOS order. */
function createLicense({ orderCode, email }) {
  const db = getDb();
  const key = generateLicenseKey();

  // Kiểm tra order đã có license chưa (idempotent)
  const existing = db
    .prepare('SELECT license_key FROM licenses WHERE order_code = ?')
    .get(orderCode);
  if (existing) return existing.license_key;

  // Lấy email từ pending_orders nếu không được truyền vào
  let finalEmail = email;
  if (!finalEmail) {
    const pending = db
      .prepare('SELECT email FROM pending_orders WHERE order_code = ?')
      .get(orderCode);
    if (pending) finalEmail = pending.email;
  }

  db.prepare(
    `INSERT INTO licenses (license_key, email, order_code)
     VALUES (?, ?, ?)`
  ).run(key, finalEmail || null, orderCode);

  return key;
}

/** Validate license key — trả về { valid, message }. */
function validateLicense(licenseKey) {
  const db = getDb();
  const row = db
    .prepare('SELECT * FROM licenses WHERE license_key = ?')
    .get(licenseKey);

  if (!row) {
    return { valid: false, message: 'Mã kích hoạt không tồn tại.' };
  }

  // Đánh dấu đã activate (lần đầu)
  if (!row.activated) {
    db.prepare(
      `UPDATE licenses SET activated = 1, activated_at = datetime('now')
       WHERE license_key = ?`
    ).run(licenseKey);
  }

  return { valid: true, message: 'License hợp lệ.' };
}

/** Lấy license key theo PayOS orderCode. */
function getLicenseByOrderCode(orderCode) {
  const db = getDb();
  return db
    .prepare('SELECT license_key, email FROM licenses WHERE order_code = ?')
    .get(orderCode);
}

/** Tạo license key dạng XXXXX-XXXXX-XXXXX-XXXXX */
function generateLicenseKey() {
  const raw = uuidv4().replace(/-/g, '').toUpperCase();
  const chars = raw.slice(0, 20);
  return `${chars.slice(0, 5)}-${chars.slice(5, 10)}-${chars.slice(10, 15)}-${chars.slice(15, 20)}`;
}

module.exports = { savePendingOrder, createLicense, validateLicense, getLicenseByOrderCode };

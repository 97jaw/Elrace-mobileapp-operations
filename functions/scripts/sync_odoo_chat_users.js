#!/usr/bin/env node
/**
 * One-time Odoo → Firestore chat profile sync (Admin SDK).
 *
 * Writes/merges `users/odoo_{res.users.id}` with person name + public avatar.
 * Does NOT wipe `fcm_tokens`. Does NOT loosen Firestore client rules.
 *
 * Usage:
 *   # Dry-run audit only (default)
 *   node scripts/sync_odoo_chat_users.js
 *   node scripts/sync_odoo_chat_users.js --dry-run
 *
 *   # Apply profile sync
 *   node scripts/sync_odoo_chat_users.js --apply
 *
 *   # Also heal DM list titles (empty / "User" / role-like)
 *   node scripts/sync_odoo_chat_users.js --apply --heal-dm-titles
 *
 *   # Heal titles only (uses existing Firestore user docs)
 *   node scripts/sync_odoo_chat_users.js --heal-dm-titles --apply
 *
 * Env:
 *   GOOGLE_APPLICATION_CREDENTIALS  Path to Firebase service account JSON
 *   ODOO_URL                        Default https://erp.elrace.com
 *   ODOO_DB                         Odoo database name
 *   ODOO_USERNAME / ODOO_LOGIN      Odoo login
 *   ODOO_PASSWORD                   Odoo password
 *   ODOO_EMPLOYEES_JSON             Optional path to pre-exported employees JSON
 *                                   (skips Odoo RPC). Array of objects with at least
 *                                   user_id, name, employee_id (or id).
 *   ERP_PUBLIC_BASE                 Default https://erp.elrace.com
 */

"use strict";

const fs = require("fs");
const path = require("path");
const { initializeApp, applicationDefault, cert } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

const args = new Set(process.argv.slice(2));
const APPLY = args.has("--apply");
const DRY_RUN = !APPLY || args.has("--dry-run");
const HEAL_DM = args.has("--heal-dm-titles");
const VERBOSE = args.has("--verbose") || args.has("-v");

const ERP_BASE = (process.env.ERP_PUBLIC_BASE || "https://erp.elrace.com").replace(
  /\/$/,
  ""
);
const ODOO_URL = (process.env.ODOO_URL || ERP_BASE).replace(/\/$/, "");
const ODOO_DB = process.env.ODOO_DB || "";
const ODOO_LOGIN = process.env.ODOO_USERNAME || process.env.ODOO_LOGIN || "";
const ODOO_PASSWORD = process.env.ODOO_PASSWORD || "";
const EMPLOYEES_JSON = process.env.ODOO_EMPLOYEES_JSON || "";
const FIRESTORE_AUDIT_ONLY =
  args.has("--firestore-audit-only") || process.env.FIRESTORE_AUDIT_ONLY === "1";

function log(...parts) {
  console.log(...parts);
}

function vlog(...parts) {
  if (VERBOSE) console.log(...parts);
}

function many2oneId(value) {
  if (value == null || value === false) return null;
  if (typeof value === "number") return value;
  if (Array.isArray(value) && value.length > 0) return Number(value[0]) || null;
  if (typeof value === "object" && value.id != null) return Number(value.id) || null;
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? n : null;
}

function many2oneName(value) {
  if (value == null || value === false) return null;
  if (Array.isArray(value) && value.length > 1) return String(value[1] || "").trim() || null;
  if (typeof value === "object" && value.name) return String(value.name).trim() || null;
  return null;
}

function normalizeStr(value) {
  if (value == null || value === false) return null;
  const text = String(value).trim();
  if (!text) return null;
  const lower = text.toLowerCase();
  if (lower === "null" || lower === "false" || lower === "n/a" || lower === "-") {
    return null;
  }
  return text;
}

function buildSearchKeywords(name, email) {
  const keywords = new Set();
  const tokens = String(name || "")
    .toLowerCase()
    .split(/\s+/)
    .filter(Boolean);
  for (const token of tokens) {
    keywords.add(token);
    for (let i = 2; i < token.length; i++) {
      keywords.add(token.substring(0, i));
    }
  }
  const em = normalizeStr(email);
  if (em) {
    const local = em.toLowerCase().split("@")[0];
    if (local) {
      keywords.add(local);
      for (let i = 2; i < local.length; i++) {
        keywords.add(local.substring(0, i));
      }
    }
  }
  return Array.from(keywords);
}

function publicAvatarUrl(employeeId) {
  if (!employeeId || employeeId <= 0) return null;
  return `${ERP_BASE}/public/employee/image/${employeeId}`;
}

function firebaseUidFor(odooUserId) {
  return `odoo_${odooUserId}`;
}

function isPlaceholderName(name) {
  const n = normalizeStr(name);
  if (!n) return true;
  const lower = n.toLowerCase();
  return lower === "user" || lower === "unknown" || lower === "null";
}

function looksLikeRoleTitle(name, jobTitle, roleName) {
  const n = normalizeStr(name);
  if (!n) return true;
  const job = normalizeStr(jobTitle);
  const role = normalizeStr(roleName);
  if (job && n.toLowerCase() === job.toLowerCase()) return true;
  if (role && n.toLowerCase() === role.toLowerCase()) return true;
  return false;
}

function needsProfileFix(fsData, personName, avatarUrl) {
  const existingName = normalizeStr(fsData && fsData.name);
  const existingAvatar = normalizeStr(fsData && fsData.avatar_url);
  const nameBad =
    isPlaceholderName(existingName) ||
    looksLikeRoleTitle(
      existingName,
      fsData && (fsData.job_title || fsData.job_position),
      fsData && fsData.role_name
    ) ||
    (personName && existingName && existingName !== personName);
  const avatarBad = !existingAvatar && !!avatarUrl;
  return { nameBad: !!nameBad && !!personName, avatarBad, missingDoc: !fsData };
}

async function initFirebase() {
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (credPath && fs.existsSync(credPath)) {
    const sa = JSON.parse(fs.readFileSync(credPath, "utf8"));
    initializeApp({ credential: cert(sa), projectId: sa.project_id });
    log(`Firebase: using service account ${sa.client_email} (${sa.project_id})`);
  } else {
    initializeApp({ credential: applicationDefault() });
    log("Firebase: using application default credentials");
  }
  return getFirestore();
}

async function odooJsonRpc(service, method, rpcArgs) {
  const res = await fetch(`${ODOO_URL}/jsonrpc`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      jsonrpc: "2.0",
      method: "call",
      params: { service, method, args: rpcArgs },
      id: Date.now(),
    }),
  });
  if (!res.ok) {
    throw new Error(`Odoo HTTP ${res.status}: ${await res.text()}`);
  }
  const body = await res.json();
  if (body.error) {
    throw new Error(
      `Odoo RPC error: ${JSON.stringify(body.error.data || body.error)}`
    );
  }
  return body.result;
}

async function fetchEmployeesFromOdoo() {
  if (!ODOO_DB || !ODOO_LOGIN || !ODOO_PASSWORD) {
    throw new Error(
      "Set ODOO_DB, ODOO_USERNAME (or ODOO_LOGIN), and ODOO_PASSWORD — " +
        "or provide ODOO_EMPLOYEES_JSON"
    );
  }
  log(`Odoo: authenticating against ${ODOO_URL} db=${ODOO_DB} as ${ODOO_LOGIN}`);
  const uid = await odooJsonRpc("common", "authenticate", [
    ODOO_DB,
    ODOO_LOGIN,
    ODOO_PASSWORD,
    {},
  ]);
  if (!uid) {
    throw new Error("Odoo authentication failed (check credentials / db)");
  }
  log(`Odoo: authenticated uid=${uid}`);

  const domain = [
    ["active", "=", true],
    ["user_id", "!=", false],
  ];
  // Prefer excluding labor when the field exists; ignore if it fails.
  let records;
  try {
    records = await odooJsonRpc("object", "execute_kw", [
      ODOO_DB,
      uid,
      ODOO_PASSWORD,
      "hr.employee",
      "search_read",
      [domain.concat([["is_labor", "=", false]])],
      {
        fields: [
          "id",
          "name",
          "emp_id",
          "work_email",
          "mobile_phone",
          "work_phone",
          "job_id",
          "user_id",
          "company_id",
          "department_id",
        ],
        limit: 0,
      },
    ]);
  } catch (e) {
    log(`Odoo: is_labor filter failed (${e.message}); retrying without it`);
    records = await odooJsonRpc("object", "execute_kw", [
      ODOO_DB,
      uid,
      ODOO_PASSWORD,
      "hr.employee",
      "search_read",
      [domain],
      {
        fields: [
          "id",
          "name",
          "emp_id",
          "work_email",
          "mobile_phone",
          "work_phone",
          "job_id",
          "user_id",
          "company_id",
          "department_id",
        ],
        limit: 0,
      },
    ]);
  }
  return records.map(normalizeEmployeeRecord).filter((e) => e.odooUserId > 0);
}

function normalizeEmployeeRecord(raw) {
  const employeeId = Number(raw.employee_id || raw.id) || 0;
  const odooUserId = many2oneId(raw.user_id) || Number(raw.odoo_user_id) || 0;
  const name = normalizeStr(raw.name) || normalizeStr(raw.emp_name) || "";
  const email =
    normalizeStr(raw.work_email) ||
    normalizeStr(raw.email) ||
    null;
  const phone =
    normalizeStr(raw.mobile_phone) ||
    normalizeStr(raw.work_phone) ||
    normalizeStr(raw.phone) ||
    null;
  const jobTitle =
    many2oneName(raw.job_id) ||
    normalizeStr(raw.job_title) ||
    normalizeStr(raw.job_position) ||
    null;
  const empIdBadge = normalizeStr(raw.emp_id);
  const companyId = many2oneId(raw.company_id) || 1;
  return {
    employeeId,
    odooUserId,
    name,
    email,
    phone,
    jobTitle,
    empIdBadge,
    companyId,
    avatarUrl: publicAvatarUrl(employeeId),
    firebaseUid: firebaseUidFor(odooUserId),
  };
}

function loadEmployeesFromJson(filePath) {
  const abs = path.resolve(filePath);
  const raw = JSON.parse(fs.readFileSync(abs, "utf8"));
  const list = Array.isArray(raw)
    ? raw
    : raw.employees || raw.result || raw.data || [];
  if (!Array.isArray(list)) {
    throw new Error(`Employees JSON must be an array (got ${typeof list})`);
  }
  return list.map(normalizeEmployeeRecord).filter((e) => e.odooUserId > 0);
}

async function loadEmployees() {
  if (EMPLOYEES_JSON) {
    log(`Loading employees from ${EMPLOYEES_JSON}`);
    return loadEmployeesFromJson(EMPLOYEES_JSON);
  }
  return fetchEmployeesFromOdoo();
}

function profilePayload(emp) {
  const keywords = buildSearchKeywords(emp.name, emp.email);
  const data = {
    odoo_user_id: emp.odooUserId,
    employee_id: emp.employeeId,
    name: emp.name,
    company_id: emp.companyId,
    updated_at: FieldValue.serverTimestamp(),
    search_keywords: keywords,
  };
  if (emp.empIdBadge) data.emp_id = emp.empIdBadge;
  if (emp.avatarUrl) data.avatar_url = emp.avatarUrl;
  if (emp.email) {
    data.email = emp.email;
    data.work_email = emp.email;
  }
  if (emp.phone) {
    data.phone = emp.phone;
    data.mobile_phone = emp.phone;
  }
  if (emp.jobTitle) data.job_title = emp.jobTitle;
  return data;
}

async function auditAndSync(db, employees) {
  log(`\n=== Profile audit (${employees.length} Odoo employees with user_id) ===`);

  const usersSnap = await db.collection("users").get();
  const byUid = new Map();
  for (const doc of usersSnap.docs) {
    byUid.set(doc.id, doc.data() || {});
  }
  log(`Firestore users collection: ${byUid.size} docs`);

  let missingDoc = 0;
  let missingName = 0;
  let missingAvatar = 0;
  let roleLikeName = 0;
  let wouldWrite = 0;
  const samples = { missingDoc: [], missingName: [], missingAvatar: [], roleLike: [] };

  for (const emp of employees) {
    const existing = byUid.get(emp.firebaseUid);
    const nameEmpty = !existing || isPlaceholderName(existing.name);
    const avatarEmpty = !existing || !normalizeStr(existing.avatar_url);
    const roleLike =
      existing &&
      looksLikeRoleTitle(
        existing.name,
        existing.job_title || existing.job_position,
        existing.role_name
      );

    if (!existing) {
      missingDoc++;
      if (samples.missingDoc.length < 8) {
        samples.missingDoc.push(`${emp.firebaseUid} (${emp.name})`);
      }
    }
    if (nameEmpty) {
      missingName++;
      if (samples.missingName.length < 8) {
        samples.missingName.push(`${emp.firebaseUid}`);
      }
    } else if (roleLike) {
      roleLikeName++;
      if (samples.roleLike.length < 8) {
        samples.roleLike.push(
          `${emp.firebaseUid}: "${existing.name}" → "${emp.name}"`
        );
      }
    }
    if (avatarEmpty) {
      missingAvatar++;
      if (samples.missingAvatar.length < 8) {
        samples.missingAvatar.push(`${emp.firebaseUid}`);
      }
    }

    const fix = needsProfileFix(existing, emp.name, emp.avatarUrl);
    if (fix.missingDoc || fix.nameBad || fix.avatarBad || roleLike) {
      wouldWrite++;
      if (APPLY && !DRY_RUN) {
        const ref = db.collection("users").doc(emp.firebaseUid);
        const payload = profilePayload(emp);
        if (!existing) {
          payload.created_at = FieldValue.serverTimestamp();
          await ref.set(payload, { merge: true });
        } else {
          // Merge — never delete fcm_tokens / unrelated fields.
          await ref.set(payload, { merge: true });
        }
        vlog(`wrote ${emp.firebaseUid}`);
      }
    }
  }

  // Orphan Firestore chat users not in Odoo export
  let orphanFs = 0;
  const empUids = new Set(employees.map((e) => e.firebaseUid));
  for (const uid of byUid.keys()) {
    if (!uid.startsWith("odoo_")) continue;
    if (!empUids.has(uid)) orphanFs++;
  }

  log(`
Report:
  Odoo employees with login:     ${employees.length}
  Firestore users docs:          ${byUid.size}
  Missing Firestore doc:         ${missingDoc}
  Missing/empty name:            ${missingName}
  Role/job-like name:            ${roleLikeName}
  Missing avatar_url:            ${missingAvatar}
  Profiles to create/update:     ${wouldWrite}
  Firestore odoo_* not in Odoo:  ${orphanFs}
  Mode:                          ${APPLY && !DRY_RUN ? "APPLY" : "DRY-RUN"}
`);

  if (samples.missingDoc.length) {
    log("  Sample missing docs:", samples.missingDoc.join(", "));
  }
  if (samples.roleLike.length) {
    log("  Sample role-like names:", samples.roleLike.join("; "));
  }
  if (samples.missingAvatar.length) {
    log("  Sample missing avatars:", samples.missingAvatar.join(", "));
  }

  if (APPLY && !DRY_RUN) {
    log(`Applied merge writes for up to ${wouldWrite} profiles.`);
  } else {
    log("Dry-run only — re-run with --apply to write.");
  }

  return { byUid, wouldWrite };
}

async function healDmTitles(db, byUid) {
  log("\n=== Heal DM userChats titles ===");
  let scanned = 0;
  let healed = 0;
  let skipped = 0;

  const userIds = Array.from(byUid.keys());
  for (const uid of userIds) {
    const chatsSnap = await db
      .collection("userChats")
      .doc(uid)
      .collection("chats")
      .where("type", "==", "dm")
      .get();

    for (const doc of chatsSnap.docs) {
      scanned++;
      const data = doc.data() || {};
      const peerUid = normalizeStr(data.peer_uid);
      if (!peerUid) {
        skipped++;
        continue;
      }

      let peer = byUid.get(peerUid);
      if (!peer) {
        const peerDoc = await db.collection("users").doc(peerUid).get();
        peer = peerDoc.exists ? peerDoc.data() : null;
        if (peer) byUid.set(peerUid, peer);
      }

      const peerName = normalizeStr(peer && peer.name);
      if (!peerName || isPlaceholderName(peerName)) {
        skipped++;
        continue;
      }

      const title = normalizeStr(data.title);
      if (title === peerName) {
        skipped++;
        continue;
      }

      // Plan: rewrite when empty / "User" / role-or-job-like.
      const clearlyBad =
        !title ||
        title.toLowerCase() === "user" ||
        looksLikeRoleTitle(
          title,
          peer.job_title || peer.job_position,
          peer.role_name
        );
      if (!clearlyBad) {
        skipped++;
        continue;
      }

      if (APPLY && !DRY_RUN) {
        await doc.ref.set(
          { title: peerName, peer_uid: peerUid, type: "dm" },
          { merge: true }
        );
      }
      healed++;
      vlog(`heal ${uid}/${doc.id}: "${title || ""}" → "${peerName}"`);
    }
  }

  log(`
DM title heal:
  Scanned DM rows:  ${scanned}
  Would heal:       ${healed}
  Skipped:          ${skipped}
  Mode:             ${APPLY && !DRY_RUN ? "APPLY" : "DRY-RUN"}
`);
}

async function auditFirestoreOnly(db) {
  log("\n=== Firestore-only audit (no Odoo source) ===");
  const usersSnap = await db.collection("users").get();
  let missingName = 0;
  let missingAvatar = 0;
  let roleLikeName = 0;
  let ok = 0;
  const samples = { missingName: [], missingAvatar: [], roleLike: [] };

  const byUid = new Map();
  for (const doc of usersSnap.docs) {
    const data = doc.data() || {};
    byUid.set(doc.id, data);
    const nameEmpty = isPlaceholderName(data.name);
    const avatarEmpty = !normalizeStr(data.avatar_url);
    const roleLike = looksLikeRoleTitle(
      data.name,
      data.job_title || data.job_position,
      data.role_name
    );
    if (nameEmpty) {
      missingName++;
      if (samples.missingName.length < 10) samples.missingName.push(doc.id);
    } else if (roleLike) {
      roleLikeName++;
      if (samples.roleLike.length < 10) {
        samples.roleLike.push(`${doc.id}:"${data.name}"`);
      }
    }
    if (avatarEmpty) {
      missingAvatar++;
      if (samples.missingAvatar.length < 10) samples.missingAvatar.push(doc.id);
    }
    if (!nameEmpty && !avatarEmpty && !roleLike) ok++;
  }

  log(`
Report:
  Firestore users docs:   ${usersSnap.size}
  OK (name+avatar):       ${ok}
  Missing/empty name:     ${missingName}
  Role/job-like name:     ${roleLikeName}
  Missing avatar_url:     ${missingAvatar}
`);
  if (samples.missingName.length) {
    log("  Sample missing names:", samples.missingName.join(", "));
  }
  if (samples.roleLike.length) {
    log("  Sample role-like:", samples.roleLike.join("; "));
  }
  if (samples.missingAvatar.length) {
    log("  Sample missing avatars:", samples.missingAvatar.join(", "));
  }
  log(
    "Tip: re-run with ODOO_* credentials (or ODOO_EMPLOYEES_JSON) for full Odoo↔Firestore compare."
  );
  return { byUid };
}

async function main() {
  const writeMode = APPLY && !args.has("--dry-run");
  log(
    `sync_odoo_chat_users: write=${writeMode} healDm=${HEAL_DM} ` +
      `firestoreAuditOnly=${FIRESTORE_AUDIT_ONLY} ` +
      `(pass --apply to write; default is dry-run)`
  );

  const db = await initFirebase();
  let byUid = new Map();
  const healOnly = HEAL_DM && args.has("--heal-only");

  if (healOnly) {
    const usersSnap = await db.collection("users").get();
    for (const doc of usersSnap.docs) {
      byUid.set(doc.id, doc.data() || {});
    }
    log(`Heal-only: loaded ${byUid.size} Firestore user docs`);
  } else if (FIRESTORE_AUDIT_ONLY) {
    const result = await auditFirestoreOnly(db);
    byUid = result.byUid;
  } else {
    try {
      const employees = await loadEmployees();
      log(`Loaded ${employees.length} employees`);
      const result = await auditAndSync(db, employees);
      byUid = result.byUid;
    } catch (e) {
      if (writeMode) {
        throw e;
      }
      log(
        `Odoo/employees source unavailable (${e.message}); falling back to Firestore-only audit`
      );
      const result = await auditFirestoreOnly(db);
      byUid = result.byUid;
    }
  }

  if (HEAL_DM) {
    await healDmTitles(db, byUid);
  }

  log("Done.");
}

main().catch((err) => {
  console.error("FATAL:", err);
  process.exit(1);
});

/**
 * Timesheet approval Firestore + Storage rules (Task 2).
 *
 * Run from repo root:
 *   firebase emulators:exec --project elrace-new --only firestore,database,storage \
 *     "npm --prefix firebase/rules-tests test"
 */
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';
import { dirname, resolve } from 'path';
import { fileURLToPath } from 'url';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  updateDoc,
  where,
  Timestamp,
} from 'firebase/firestore';
import {
  ref as storageRef,
  uploadBytes,
  getBytes,
  deleteObject,
} from 'firebase/storage';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, '../../..');

const PROJECT_ID = 'elrace-new';
const ALICE = 'odoo_100';
const BOB = 'odoo_200';
const CAROL = 'odoo_300';
const EVE = 'odoo_999';

const ALICE_CLAIMS = { role_id: 5, branch_id: 1, company_id: 1 };
const BOB_CLAIMS = { role_id: 5, branch_id: 1, company_id: 1 };
const CAROL_CLAIMS = { role_id: 5, branch_id: 1, company_id: 1 };
const EVE_CLAIMS = { role_id: 99, branch_id: 9, company_id: 1 };

const DOC_ID = 'ta_contract_1';
const PDF_PATH = `timesheet_approvals/${ALICE}/${DOC_ID}/original.pdf`;

let testEnv;

function aliceFs() {
  return testEnv.authenticatedContext(ALICE, ALICE_CLAIMS).firestore();
}
function bobFs() {
  return testEnv.authenticatedContext(BOB, BOB_CLAIMS).firestore();
}
function carolFs() {
  return testEnv.authenticatedContext(CAROL, CAROL_CLAIMS).firestore();
}
function eveFs() {
  return testEnv.authenticatedContext(EVE, EVE_CLAIMS).firestore();
}

function aliceStorage() {
  return testEnv.authenticatedContext(ALICE, ALICE_CLAIMS).storage();
}
function bobStorage() {
  return testEnv.authenticatedContext(BOB, BOB_CLAIMS).storage();
}
function eveStorage() {
  return testEnv.authenticatedContext(EVE, EVE_CLAIMS).storage();
}

function cell(role) {
  return {
    page: 0,
    role,
    x: 0.1,
    y: 0.7,
    width: 0.3,
    height: 0.08,
  };
}

function pendingEntry(role, name) {
  return { role, name, status: 'pending' };
}

function validCreate({
  ownerUid = ALICE,
  approvers = {
    [BOB]: pendingEntry('site_engineer', 'Bob'),
    [CAROL]: pendingEntry('projects_manager', 'Carol'),
  },
  status = 'pending',
  extra = {},
} = {}) {
  const uids = Object.keys(approvers);
  return {
    owner_uid: ownerUid,
    owner_name: 'Alice',
    file_name: 'timesheet.pdf',
    project_id: '42',
    project_name: 'Site A',
    page_count: 3,
    pdf_path: PDF_PATH,
    approvers,
    approver_uids: uids,
    pending_uids: uids,
    status,
    cells: uids.map((uid) => cell(approvers[uid].role)),
    created_at: Timestamp.now(),
    updated_at: Timestamp.now(),
    ...extra,
  };
}

async function seedPendingDoc(data = validCreate()) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'timesheet_approvals', DOC_ID), data);
  });
}

describe('timesheet approvals rules', () => {
  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: readFileSync(resolve(root, 'firestore.rules'), 'utf8'),
        host: '127.0.0.1',
        port: Number(process.env.FIRESTORE_EMULATOR_PORT || 8080),
      },
      database: {
        rules: readFileSync(resolve(root, 'database.rules.json'), 'utf8'),
        host: '127.0.0.1',
        port: Number(process.env.DATABASE_EMULATOR_PORT || 9000),
      },
      storage: {
        rules: readFileSync(resolve(root, 'storage.rules'), 'utf8'),
        host: '127.0.0.1',
        port: Number(process.env.STORAGE_EMULATOR_PORT || 9199),
      },
    });
  });

  after(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.clearDatabase();
    await testEnv.clearStorage();
  });

  describe('timesheet_approvals queries', () => {
  beforeEach(async () => {
    await seedPendingDoc();
  });

  it('allows watchMine (owner_uid + created_at)', async () => {
    const q = query(
      collection(aliceFs(), 'timesheet_approvals'),
      where('owner_uid', '==', ALICE),
      orderBy('created_at', 'desc'),
    );
    await assertSucceeds(getDocs(q));
  });

  it('allows watchPendingFor (pending_uids array-contains + created_at)', async () => {
    const q = query(
      collection(bobFs(), 'timesheet_approvals'),
      where('pending_uids', 'array-contains', BOB),
      orderBy('created_at', 'desc'),
    );
    await assertSucceeds(getDocs(q));
  });
});

describe('timesheet_approvals create', () => {
  it('allows the owner to create a valid pending doc', async () => {
    await assertSucceeds(
      setDoc(doc(aliceFs(), 'timesheet_approvals', DOC_ID), validCreate()),
    );
  });

  it('denies a non-owner create', async () => {
    await assertFails(
      setDoc(doc(bobFs(), 'timesheet_approvals', DOC_ID), validCreate()),
    );
  });

  it('denies create with an extra key', async () => {
    await assertFails(
      setDoc(
        doc(aliceFs(), 'timesheet_approvals', DOC_ID),
        validCreate({ extra: { evil: true } }),
      ),
    );
  });

  it('denies create when the owner is also an approver', async () => {
    await assertFails(
      setDoc(
        doc(aliceFs(), 'timesheet_approvals', DOC_ID),
        validCreate({
          approvers: {
            [ALICE]: pendingEntry('site_engineer', 'Alice'),
            [BOB]: pendingEntry('projects_manager', 'Bob'),
          },
        }),
      ),
    );
  });

  it('denies create when status is not pending', async () => {
    await assertFails(
      setDoc(
        doc(aliceFs(), 'timesheet_approvals', DOC_ID),
        validCreate({ status: 'approved' }),
      ),
    );
  });
});

describe('timesheet_approvals read / delete', () => {
  beforeEach(async () => {
    await seedPendingDoc();
  });

  it('allows owner and approver reads, denies strangers', async () => {
    await assertSucceeds(getDoc(doc(aliceFs(), 'timesheet_approvals', DOC_ID)));
    await assertSucceeds(getDoc(doc(bobFs(), 'timesheet_approvals', DOC_ID)));
    await assertFails(getDoc(doc(eveFs(), 'timesheet_approvals', DOC_ID)));
  });

  it('denies delete for everyone', async () => {
    await assertFails(deleteDoc(doc(aliceFs(), 'timesheet_approvals', DOC_ID)));
    await assertFails(deleteDoc(doc(bobFs(), 'timesheet_approvals', DOC_ID)));
  });
});

describe('timesheet_approvals approve / reject', () => {
  beforeEach(async () => {
    await seedPendingDoc();
  });

  function approveUpdate(uid, remainingPending, nextStatus, otherApprovers) {
    return {
      approvers: {
        ...otherApprovers,
        [uid]: {
          role: uid === BOB ? 'site_engineer' : 'projects_manager',
          name: uid === BOB ? 'Bob' : 'Carol',
          status: 'approved',
          acted_at: Timestamp.now(),
        },
      },
      pending_uids: remainingPending,
      status: nextStatus,
      updated_at: Timestamp.now(),
    };
  }

  it('SE approve leaves status pending; PM approve finishes as approved', async () => {
    const afterSe = approveUpdate(BOB, [CAROL], 'pending', {
      [CAROL]: pendingEntry('projects_manager', 'Carol'),
    });
    await assertSucceeds(
      updateDoc(doc(bobFs(), 'timesheet_approvals', DOC_ID), afterSe),
    );

    const snap = await getDoc(doc(carolFs(), 'timesheet_approvals', DOC_ID));
    const current = snap.data();
    await assertSucceeds(
      updateDoc(doc(carolFs(), 'timesheet_approvals', DOC_ID), {
        approvers: {
          ...current.approvers,
          [CAROL]: {
            role: 'projects_manager',
            name: 'Carol',
            status: 'approved',
            acted_at: Timestamp.now(),
          },
        },
        pending_uids: [],
        status: 'approved',
        updated_at: Timestamp.now(),
      }),
    );
  });

  it('denies SE changing PM entry', async () => {
    await assertFails(
      updateDoc(doc(bobFs(), 'timesheet_approvals', DOC_ID), {
        approvers: {
          [BOB]: {
            role: 'site_engineer',
            name: 'Bob',
            status: 'approved',
            acted_at: Timestamp.now(),
          },
          [CAROL]: {
            role: 'projects_manager',
            name: 'Carol',
            status: 'approved',
            acted_at: Timestamp.now(),
          },
        },
        pending_uids: [],
        status: 'approved',
        updated_at: Timestamp.now(),
      }),
    );
  });

  it('denies the owner approving', async () => {
    await assertFails(
      updateDoc(doc(aliceFs(), 'timesheet_approvals', DOC_ID), {
        approvers: {
          [BOB]: {
            role: 'site_engineer',
            name: 'Bob',
            status: 'approved',
            acted_at: Timestamp.now(),
          },
          [CAROL]: pendingEntry('projects_manager', 'Carol'),
        },
        pending_uids: [CAROL],
        status: 'pending',
        updated_at: Timestamp.now(),
      }),
    );
  });

  it('reject sets rejected and blocks the other approver', async () => {
    await assertSucceeds(
      updateDoc(doc(bobFs(), 'timesheet_approvals', DOC_ID), {
        approvers: {
          [BOB]: {
            role: 'site_engineer',
            name: 'Bob',
            status: 'rejected',
            acted_at: Timestamp.now(),
          },
          [CAROL]: pendingEntry('projects_manager', 'Carol'),
        },
        pending_uids: [],
        status: 'rejected',
        updated_at: Timestamp.now(),
      }),
    );

    await assertFails(
      updateDoc(doc(carolFs(), 'timesheet_approvals', DOC_ID), {
        approvers: {
          [BOB]: {
            role: 'site_engineer',
            name: 'Bob',
            status: 'rejected',
            acted_at: Timestamp.now(),
          },
          [CAROL]: {
            role: 'projects_manager',
            name: 'Carol',
            status: 'approved',
            acted_at: Timestamp.now(),
          },
        },
        pending_uids: [],
        status: 'approved',
        updated_at: Timestamp.now(),
      }),
    );
  });
});

describe('timesheet_approvals storage', () => {
  const pdfBytes = Buffer.from('%PDF-1.4 timesheet');

  it('allows owner upload before create; denies overwrite/delete after; approver read ok', async () => {
    await assertSucceeds(
      uploadBytes(storageRef(aliceStorage(), PDF_PATH), pdfBytes, {
        contentType: 'application/pdf',
      }),
    );

    await assertFails(
      uploadBytes(
        storageRef(aliceStorage(), `timesheet_approvals/${ALICE}/${DOC_ID}/evil.png`),
        Buffer.from('png'),
        { contentType: 'image/png' },
      ),
    );

    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'timesheet_approvals', DOC_ID), validCreate());
    });

    await assertSucceeds(getBytes(storageRef(bobStorage(), PDF_PATH)));
    await assertFails(getBytes(storageRef(eveStorage(), PDF_PATH)));

    await assertFails(
      uploadBytes(storageRef(aliceStorage(), PDF_PATH), Buffer.from('%PDF-1.4 swapped'), {
        contentType: 'application/pdf',
      }),
    );
    await assertFails(deleteObject(storageRef(aliceStorage(), PDF_PATH)));
  });
});

describe('app_notifications and config/features', () => {
  const notifPath = ['users', ALICE, 'app_notifications', 'n1'];

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), ...notifPath), {
        title: 'Timesheet pending',
        read: false,
        created_at: Timestamp.now(),
      });
      await setDoc(doc(ctx.firestore(), 'config', 'features'), {
        timesheet_approval: true,
      });
    });
  });

  it('allows owner read / mark read / delete; denies create and other users', async () => {
    await assertFails(getDoc(doc(bobFs(), ...notifPath)));
    await assertSucceeds(getDoc(doc(aliceFs(), ...notifPath)));
    await assertSucceeds(
      updateDoc(doc(aliceFs(), ...notifPath), { read: true }),
    );
    await assertSucceeds(deleteDoc(doc(aliceFs(), ...notifPath)));

    await assertFails(
      setDoc(doc(aliceFs(), 'users', ALICE, 'app_notifications', 'n2'), {
        title: 'nope',
        read: false,
      }),
    );
  });

  it('allows signed-in read of config/features and denies write', async () => {
    await assertSucceeds(getDoc(doc(aliceFs(), 'config', 'features')));
    await assertFails(
      setDoc(doc(aliceFs(), 'config', 'features'), { timesheet_approval: false }),
    );
  });
});
}); // timesheet approvals rules

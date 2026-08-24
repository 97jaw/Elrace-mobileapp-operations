/**
 * Phase 2 Firebase security acceptance tests (Hub-aligned denials).
 *
 * Run from repo root:
 *   firebase emulators:exec --only firestore,database,storage \
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
  doc,
  getDoc,
  setDoc,
  updateDoc,
  collection,
  getDocs,
} from 'firebase/firestore';
import {
  ref as dbRef,
  set as dbSet,
  get as dbGet,
} from 'firebase/database';
import {
  ref as storageRef,
  uploadBytes,
  getBytes,
} from 'firebase/storage';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, '../../..');

const PROJECT_ID = 'elrace-new';
const ALICE = 'odoo_100';
const BOB = 'odoo_200';
const EVE = 'odoo_999';
const DM_AB = 'dm_odoo_100_odoo_200';
const ROLE_CHAT = 'role_5_branch_1';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(resolve(root, 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
    database: {
      rules: readFileSync(resolve(root, 'database.rules.json'), 'utf8'),
      host: '127.0.0.1',
      port: 9000,
    },
    storage: {
      rules: readFileSync(resolve(root, 'storage.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
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

  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'chats', DM_AB), {
      type: 'dm',
      member_ids: [ALICE, BOB],
      dm_pair: [ALICE, BOB],
    });
    await setDoc(doc(db, 'chats', DM_AB, 'messages', 'm1'), {
      sender_id: ALICE,
      type: 'text',
      text: 'hello',
      created_at: new Date(),
    });
    await setDoc(doc(db, 'chats', ROLE_CHAT), {
      type: 'role',
      role_id: 5,
      member_ids: [ALICE],
    });
    await setDoc(doc(db, 'chats', ROLE_CHAT, 'messages', 'rm1'), {
      sender_id: ALICE,
      type: 'text',
      text: 'role hello',
      created_at: new Date(),
    });
    await setDoc(doc(db, 'chats', DM_AB, 'messages', 'sign1'), {
      sender_id: ALICE,
      type: 'signable_doc',
      sign_status: 'pending',
      current_signer_uid: BOB,
      signer_uids: [BOB],
      created_at: new Date(),
    });
  });
});

function aliceFs() {
  return testEnv.authenticatedContext(ALICE).firestore();
}
function bobFs() {
  return testEnv.authenticatedContext(BOB).firestore();
}
function eveFs() {
  return testEnv.authenticatedContext(EVE).firestore();
}

describe('Firestore chat security', () => {
  it('denies non-member message read', async () => {
    await assertFails(getDoc(doc(eveFs(), 'chats', DM_AB, 'messages', 'm1')));
  });

  it('denies non-member message write', async () => {
    await assertFails(
      setDoc(doc(eveFs(), 'chats', DM_AB, 'messages', 'evil'), {
        sender_id: EVE,
        type: 'text',
        text: 'nope',
        created_at: new Date(),
      }),
    );
  });

  it('allows member message read/write with matching sender_id', async () => {
    await assertSucceeds(getDoc(doc(aliceFs(), 'chats', DM_AB, 'messages', 'm1')));
    await assertSucceeds(
      setDoc(doc(bobFs(), 'chats', DM_AB, 'messages', 'm2'), {
        sender_id: BOB,
        type: 'text',
        text: 'hi',
        created_at: new Date(),
      }),
    );
  });

  it('denies unrelated role-chat read for non-member', async () => {
    await assertFails(getDoc(doc(eveFs(), 'chats', ROLE_CHAT)));
    await assertFails(getDoc(doc(eveFs(), 'chats', ROLE_CHAT, 'messages', 'rm1')));
  });

  it('denies sender spoofing on message create', async () => {
    await assertFails(
      setDoc(doc(bobFs(), 'chats', DM_AB, 'messages', 'spoof'), {
        sender_id: ALICE,
        type: 'text',
        text: 'spoof',
        created_at: new Date(),
      }),
    );
  });

  it('denies arbitrary member/admin insertion by non-member', async () => {
    await assertFails(
      setDoc(doc(eveFs(), 'chats', DM_AB, 'members', EVE), {
        joined_at: new Date(),
        is_admin: true,
      }),
    );
    await assertFails(
      setDoc(doc(eveFs(), 'chats', DM_AB, 'members', ALICE), {
        is_admin: true,
      }),
    );
  });

  it('denies unrelated cross-user userChats write', async () => {
    await assertFails(
      setDoc(doc(eveFs(), 'userChats', ALICE, 'chats', DM_AB), {
        type: 'dm',
        updated_at: new Date(),
      }),
    );
  });

  it('allows peer userChats write when writer is a chat member', async () => {
    await assertSucceeds(
      setDoc(doc(aliceFs(), 'userChats', BOB, 'chats', DM_AB), {
        type: 'dm',
        peer_uid: ALICE,
        updated_at: new Date(),
        has_messages: true,
      }),
    );
  });

  it('denies invalid chat ID/type creation', async () => {
    await assertFails(
      setDoc(doc(aliceFs(), 'chats', 'random_chat_xyz'), {
        type: 'dm',
        member_ids: [ALICE],
        dm_pair: [ALICE, ALICE],
      }),
    );
    await assertFails(
      setDoc(doc(aliceFs(), 'chats', 'dm_odoo_100_odoo_100'), {
        type: 'hacker',
        member_ids: [ALICE],
      }),
    );
  });

  it('denies immutable sender mutation', async () => {
    await assertFails(
      updateDoc(doc(aliceFs(), 'chats', DM_AB, 'messages', 'm1'), {
        sender_id: BOB,
      }),
    );
  });

  it('denies unauthorized signing transition', async () => {
    await assertFails(
      updateDoc(doc(eveFs(), 'chats', DM_AB, 'messages', 'sign1'), {
        sign_status: 'signed',
        signed_by: EVE,
      }),
    );
    await assertFails(
      updateDoc(doc(aliceFs(), 'chats', DM_AB, 'messages', 'sign1'), {
        sign_status: 'signed',
        signed_by: ALICE,
      }),
    );
  });

  it('allows authorized signer to update sign fields', async () => {
    await assertSucceeds(
      updateDoc(doc(bobFs(), 'chats', DM_AB, 'messages', 'sign1'), {
        sign_status: 'signed',
        signed_by: BOB,
        signed_at: new Date(),
      }),
    );
  });
});

describe('RTDB presence/typing security', () => {
  it('denies invalid presence payload', async () => {
    const eveDb = testEnv.authenticatedContext(EVE).database();
    await assertFails(dbSet(dbRef(eveDb, `presence/${EVE}`), { online: 'yes' }));
    await assertFails(
      dbSet(dbRef(eveDb, `presence/${EVE}`), {
        online: true,
        lastChanged: Date.now(),
        role: 'admin',
      }),
    );
  });

  it('allows valid own presence write', async () => {
    const aliceDb = testEnv.authenticatedContext(ALICE).database();
    await assertSucceeds(
      dbSet(dbRef(aliceDb, `presence/${ALICE}`), {
        online: true,
        lastChanged: Date.now(),
      }),
    );
  });

  it('denies typing write for another uid', async () => {
    const eveDb = testEnv.authenticatedContext(EVE).database();
    await assertFails(dbSet(dbRef(eveDb, `typing/${DM_AB}/${ALICE}`), true));
  });

  it('denies invalid typing payload', async () => {
    const aliceDb = testEnv.authenticatedContext(ALICE).database();
    await assertFails(
      dbSet(dbRef(aliceDb, `typing/${DM_AB}/${ALICE}`), { typing: true }),
    );
  });

  it('allows typing true for self', async () => {
    const aliceDb = testEnv.authenticatedContext(ALICE).database();
    await assertSucceeds(dbSet(dbRef(aliceDb, `typing/${DM_AB}/${ALICE}`), true));
  });
});

describe('Storage chat_media security', () => {
  const bytes = Buffer.from('%PDF-1.4 fake');

  it('denies non-member media upload/read', async () => {
    const eve = testEnv.authenticatedContext(EVE).storage();
    const path = storageRef(eve, `chat_media/${DM_AB}/m1/file.pdf`);
    await assertFails(uploadBytes(path, bytes, { contentType: 'application/pdf' }));
    await assertFails(getBytes(path));
  });

  it('denies malformed chat-media paths', async () => {
    const alice = testEnv.authenticatedContext(ALICE).storage();
    await assertFails(
      uploadBytes(storageRef(alice, `chat_media/file.pdf`), bytes, {
        contentType: 'application/pdf',
      }),
    );
    await assertFails(
      uploadBytes(storageRef(alice, `chat_media/${DM_AB}/file.pdf`), bytes, {
        contentType: 'application/pdf',
      }),
    );
    await assertFails(
      uploadBytes(storageRef(alice, `uploads/${DM_AB}/m1/file.pdf`), bytes, {
        contentType: 'application/pdf',
      }),
    );
  });

  it('allows member media upload on canonical path', async () => {
    const alice = testEnv.authenticatedContext(ALICE).storage();
    await assertSucceeds(
      uploadBytes(
        storageRef(alice, `chat_media/${DM_AB}/m1/ok.pdf`),
        bytes,
        { contentType: 'application/pdf' },
      ),
    );
  });
});

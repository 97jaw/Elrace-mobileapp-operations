/**
 * Phase 2 + G2 Firebase security acceptance tests (Hub-aligned denials).
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
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  Timestamp,
} from 'firebase/firestore';
import {
  ref as dbRef,
  set as dbSet,
  remove as dbRemove,
} from 'firebase/database';
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
const EVE = 'odoo_999';
const DM_AB = 'dm_odoo_100_odoo_200';
const ROLE_CHAT = 'role_5_branch_1';
const GROUP_CHAT = 'project_42';

const ALICE_CLAIMS = { role_id: 5, branch_id: 1, company_id: 1 };
const BOB_CLAIMS = { role_id: 5, branch_id: 1, company_id: 1 };
const EVE_CLAIMS = { role_id: 99, branch_id: 9, company_id: 1 };

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
    await setDoc(doc(db, 'chats', DM_AB, 'members', ALICE), {
      joined_at: new Date(),
      muted: false,
      is_admin: false,
    });
    await setDoc(doc(db, 'chats', DM_AB, 'members', BOB), {
      joined_at: new Date(),
      muted: false,
      is_admin: false,
    });
    await setDoc(doc(db, 'chats', DM_AB, 'messages', 'm1'), {
      sender_id: ALICE,
      type: 'text',
      text: 'hello',
      created_at: Timestamp.now(),
      client_msg_id: 'c1',
    });
    await setDoc(doc(db, 'chats', ROLE_CHAT), {
      type: 'role',
      role_id: 5,
      branch_id: 1,
      member_ids: [ALICE],
    });
    await setDoc(doc(db, 'chats', ROLE_CHAT, 'members', ALICE), {
      joined_at: new Date(),
      muted: false,
    });
    await setDoc(doc(db, 'chats', ROLE_CHAT, 'messages', 'rm1'), {
      sender_id: ALICE,
      type: 'text',
      text: 'role hello',
      created_at: Timestamp.now(),
    });
    await setDoc(doc(db, 'chats', DM_AB, 'messages', 'sign1'), {
      sender_id: ALICE,
      type: 'signable_doc',
      sign_status: 'pending',
      current_signer_uid: BOB,
      signer_uids: [BOB],
      created_at: Timestamp.now(),
    });
    await setDoc(doc(db, 'chats', GROUP_CHAT), {
      type: 'group',
      title: 'Site',
      member_ids: [ALICE, BOB],
    });
    await setDoc(doc(db, 'chats', GROUP_CHAT, 'members', ALICE), {
      joined_at: new Date(),
      is_admin: true,
      muted: false,
    });
    await setDoc(doc(db, 'chats', GROUP_CHAT, 'members', BOB), {
      joined_at: new Date(),
      is_admin: false,
      muted: false,
    });
    await setDoc(doc(db, 'userChats', BOB, 'chats', DM_AB), {
      type: 'dm',
      peer_uid: ALICE,
      updated_at: Timestamp.now(),
      has_messages: true,
      last_read_at: Timestamp.now(),
    });
  });
});

function aliceFs() {
  return testEnv.authenticatedContext(ALICE, ALICE_CLAIMS).firestore();
}
function bobFs() {
  return testEnv.authenticatedContext(BOB, BOB_CLAIMS).firestore();
}
function eveFs() {
  return testEnv.authenticatedContext(EVE, EVE_CLAIMS).firestore();
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
        created_at: Timestamp.now(),
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
        created_at: Timestamp.now(),
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
        created_at: Timestamp.now(),
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

  it('denies ordinary member adding a foreign member', async () => {
    await assertFails(
      setDoc(doc(aliceFs(), 'chats', DM_AB, 'members', EVE), {
        joined_at: new Date(),
        muted: false,
        is_admin: false,
      }),
    );
  });

  it('denies ordinary member deleting another member', async () => {
    await assertFails(
      deleteDoc(doc(aliceFs(), 'chats', DM_AB, 'members', BOB)),
    );
  });

  it('denies unproven user self-joining a role chat', async () => {
    await assertFails(
      updateDoc(doc(eveFs(), 'chats', ROLE_CHAT), {
        member_ids: [ALICE, EVE],
      }),
    );
    await assertFails(
      setDoc(doc(eveFs(), 'chats', ROLE_CHAT, 'members', EVE), {
        joined_at: new Date(),
        muted: false,
      }),
    );
  });

  it('allows proven role self-join when token role matches', async () => {
    await assertSucceeds(
      updateDoc(doc(bobFs(), 'chats', ROLE_CHAT), {
        member_ids: [ALICE, BOB],
      }),
    );
    await assertSucceeds(
      setDoc(doc(bobFs(), 'chats', ROLE_CHAT, 'members', BOB), {
        joined_at: new Date(),
        muted: false,
        is_admin: false,
      }),
    );
  });

  it('denies unrelated cross-user userChats write', async () => {
    await assertFails(
      setDoc(doc(eveFs(), 'userChats', ALICE, 'chats', DM_AB), {
        type: 'dm',
        updated_at: Timestamp.now(),
      }),
    );
  });

  it('denies unexpected fields in peer userChats write', async () => {
    await assertFails(
      setDoc(doc(aliceFs(), 'userChats', BOB, 'chats', DM_AB), {
        type: 'dm',
        peer_uid: ALICE,
        updated_at: Timestamp.now(),
        has_messages: true,
        evil_flag: true,
      }),
    );
    await assertFails(
      updateDoc(doc(aliceFs(), 'userChats', BOB, 'chats', DM_AB), {
        last_read_at: Timestamp.now(),
      }),
    );
  });

  it('allows peer userChats write when writer is a chat member', async () => {
    await assertSucceeds(
      updateDoc(doc(aliceFs(), 'userChats', BOB, 'chats', DM_AB), {
        updated_at: Timestamp.now(),
        has_messages: true,
      }),
    );
  });

  it('denies loosely shaped / non-deterministic DM IDs', async () => {
    await assertFails(
      setDoc(doc(aliceFs(), 'chats', 'dm_odoo_200_odoo_100'), {
        type: 'dm',
        member_ids: [ALICE, BOB],
        dm_pair: [BOB, ALICE],
      }),
    );
    await assertFails(
      setDoc(doc(aliceFs(), 'chats', 'dm_odoo_100_odoo_200_extra'), {
        type: 'dm',
        member_ids: [ALICE, BOB],
        dm_pair: [ALICE, BOB],
      }),
    );
    await assertFails(
      setDoc(doc(aliceFs(), 'chats', 'random_chat_xyz'), {
        type: 'dm',
        member_ids: [ALICE],
        dm_pair: [ALICE, ALICE],
      }),
    );
  });

  it('denies mutation of chat type / member_ids / dm_pair', async () => {
    await assertFails(
      updateDoc(doc(aliceFs(), 'chats', DM_AB), {
        type: 'group',
      }),
    );
    await assertFails(
      updateDoc(doc(aliceFs(), 'chats', DM_AB), {
        dm_pair: [ALICE, EVE],
      }),
    );
    await assertFails(
      updateDoc(doc(aliceFs(), 'chats', DM_AB), {
        member_ids: [ALICE, BOB, EVE],
      }),
    );
  });

  it('denies invalid chat ID/type creation', async () => {
    await assertFails(
      setDoc(doc(aliceFs(), 'chats', 'dm_odoo_100_odoo_100'), {
        type: 'hacker',
        member_ids: [ALICE],
      }),
    );
  });

  it('denies unsupported message type and unexpected fields', async () => {
    await assertFails(
      setDoc(doc(aliceFs(), 'chats', DM_AB, 'messages', 'badtype'), {
        sender_id: ALICE,
        type: 'sticker',
        text: 'nope',
        created_at: Timestamp.now(),
      }),
    );
    await assertFails(
      setDoc(doc(aliceFs(), 'chats', DM_AB, 'messages', 'badfields'), {
        sender_id: ALICE,
        type: 'text',
        text: 'hi',
        created_at: Timestamp.now(),
        hacker_field: true,
      }),
    );
  });

  it('denies client-controlled historical message timestamps', async () => {
    const old = Timestamp.fromDate(new Date('2020-01-01T00:00:00Z'));
    await assertFails(
      setDoc(doc(aliceFs(), 'chats', DM_AB, 'messages', 'oldts'), {
        sender_id: ALICE,
        type: 'text',
        text: 'ancient',
        created_at: old,
      }),
    );
  });

  it('denies mutation of message type / created_at / client_msg_id', async () => {
    await assertFails(
      updateDoc(doc(aliceFs(), 'chats', DM_AB, 'messages', 'm1'), {
        type: 'image',
      }),
    );
    await assertFails(
      updateDoc(doc(aliceFs(), 'chats', DM_AB, 'messages', 'm1'), {
        created_at: Timestamp.now(),
      }),
    );
    await assertFails(
      updateDoc(doc(aliceFs(), 'chats', DM_AB, 'messages', 'm1'), {
        client_msg_id: 'mutated',
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

  it('denies invalid signing transitions by the current signer', async () => {
    await assertFails(
      updateDoc(doc(bobFs(), 'chats', DM_AB, 'messages', 'sign1'), {
        sign_status: 'expired',
        signed_by: BOB,
      }),
    );
    await assertFails(
      updateDoc(doc(bobFs(), 'chats', DM_AB, 'messages', 'sign1'), {
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
        signed_at: Timestamp.now(),
      }),
    );
  });

  it('allows sender soft-delete within 10 minutes', async () => {
    await assertSucceeds(
      updateDoc(doc(aliceFs(), 'chats', DM_AB, 'messages', 'm1'), {
        status: 'deleted',
        text: '',
        media_url: null,
        media_path: null,
        thumb_url: null,
        deleted_at: Timestamp.now(),
      }),
    );
  });

  it('denies peer soft-delete of another user message', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'chats', DM_AB, 'messages', 'm_peer'), {
        sender_id: ALICE,
        type: 'text',
        text: 'mine',
        created_at: Timestamp.now(),
        status: 'sent',
      });
    });
    await assertFails(
      updateDoc(doc(bobFs(), 'chats', DM_AB, 'messages', 'm_peer'), {
        status: 'deleted',
        text: '',
      }),
    );
  });

  it('allows self member receipt timestamps and denies forged peer receipts', async () => {
    await assertSucceeds(
      updateDoc(doc(aliceFs(), 'chats', DM_AB, 'members', ALICE), {
        last_read_at: Timestamp.now(),
        last_delivered_at: Timestamp.now(),
      }),
    );
    await assertFails(
      updateDoc(doc(aliceFs(), 'chats', DM_AB, 'members', BOB), {
        last_read_at: Timestamp.now(),
        last_delivered_at: Timestamp.now(),
      }),
    );
  });
});

describe('RTDB presence/typing security', () => {
  it('denies presence without required lastChanged', async () => {
    const aliceDb = testEnv.authenticatedContext(ALICE, ALICE_CLAIMS).database();
    await assertFails(dbSet(dbRef(aliceDb, `presence/${ALICE}`), { online: true }));
  });

  it('denies invalid presence payload', async () => {
    const eveDb = testEnv.authenticatedContext(EVE, EVE_CLAIMS).database();
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
    const aliceDb = testEnv.authenticatedContext(ALICE, ALICE_CLAIMS).database();
    await assertSucceeds(
      dbSet(dbRef(aliceDb, `presence/${ALICE}`), {
        online: true,
        lastChanged: Date.now(),
      }),
    );
  });

  it('denies typing write for another uid', async () => {
    const eveDb = testEnv.authenticatedContext(EVE, EVE_CLAIMS).database();
    await assertFails(dbSet(dbRef(eveDb, `typing/${DM_AB}/${ALICE}`), true));
  });

  it('denies typing false (must be true or delete)', async () => {
    const aliceDb = testEnv.authenticatedContext(ALICE, ALICE_CLAIMS).database();
    await assertFails(dbSet(dbRef(aliceDb, `typing/${DM_AB}/${ALICE}`), false));
  });

  it('denies invalid typing payload', async () => {
    const aliceDb = testEnv.authenticatedContext(ALICE, ALICE_CLAIMS).database();
    await assertFails(
      dbSet(dbRef(aliceDb, `typing/${DM_AB}/${ALICE}`), { typing: true }),
    );
  });

  it('allows typing true for self and delete', async () => {
    const aliceDb = testEnv.authenticatedContext(ALICE, ALICE_CLAIMS).database();
    await assertSucceeds(dbSet(dbRef(aliceDb, `typing/${DM_AB}/${ALICE}`), true));
    await assertSucceeds(dbRemove(dbRef(aliceDb, `typing/${DM_AB}/${ALICE}`)));
  });
});

describe('Storage chat_media security', () => {
  const bytes = Buffer.from('%PDF-1.4 fake');

  it('denies non-member media upload/read', async () => {
    const eve = testEnv.authenticatedContext(EVE, EVE_CLAIMS).storage();
    const path = storageRef(eve, `chat_media/${DM_AB}/m1/file.pdf`);
    await assertFails(uploadBytes(path, bytes, { contentType: 'application/pdf' }));
    await assertFails(getBytes(path));
  });

  it('denies malformed chat-media paths', async () => {
    const alice = testEnv.authenticatedContext(ALICE, ALICE_CLAIMS).storage();
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
    const alice = testEnv.authenticatedContext(ALICE, ALICE_CLAIMS).storage();
    await assertSucceeds(
      uploadBytes(
        storageRef(alice, `chat_media/${DM_AB}/m1/ok.pdf`),
        bytes,
        { contentType: 'application/pdf' },
      ),
    );
  });

  it('allows member media read via members/{uid} when member_ids lags', async () => {
    const lagChat = 'dm_odoo_100_odoo_300';
    const charlie = 'odoo_300';
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'chats', lagChat), {
        type: 'dm',
        dm_pair: [ALICE, charlie],
        // member_ids intentionally missing / empty — Hub race case
      });
      await setDoc(doc(db, 'chats', lagChat, 'members', ALICE), {
        joined_at: new Date(),
        muted: false,
      });
      await setDoc(doc(db, 'chats', lagChat, 'members', charlie), {
        joined_at: new Date(),
        muted: false,
      });
    });

    const alice = testEnv.authenticatedContext(ALICE, ALICE_CLAIMS).storage();
    const path = `chat_media/${lagChat}/hub_voice_1/voice.webm`;
    await assertSucceeds(
      uploadBytes(storageRef(alice, path), bytes, {
        contentType: 'audio/webm',
      }),
    );
    await assertSucceeds(getBytes(storageRef(alice, path)));
  });

  it('allows DM peer media via dm_pair without members doc', async () => {
    const pairChat = 'dm_odoo_100_odoo_400';
    const dana = 'odoo_400';
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'chats', pairChat), {
        type: 'dm',
        dm_pair: [ALICE, dana],
      });
    });

    const alice = testEnv.authenticatedContext(ALICE, ALICE_CLAIMS).storage();
    const path = `chat_media/${pairChat}/hub_msg/voice.webm`;
    await assertSucceeds(
      uploadBytes(storageRef(alice, path), bytes, {
        contentType: 'audio/webm',
      }),
    );
  });

  it('allows sender to delete own message media object', async () => {
    const alice = testEnv.authenticatedContext(ALICE, ALICE_CLAIMS).storage();
    const path = `chat_media/${DM_AB}/m1/voice-delete.webm`;
    await assertSucceeds(
      uploadBytes(storageRef(alice, path), bytes, {
        contentType: 'audio/webm',
      }),
    );
    await assertSucceeds(deleteObject(storageRef(alice, path)));
  });

  it('denies non-sender media delete', async () => {
    const alice = testEnv.authenticatedContext(ALICE, ALICE_CLAIMS).storage();
    const bob = testEnv.authenticatedContext(BOB, BOB_CLAIMS).storage();
    const path = `chat_media/${DM_AB}/m1/alice-only.pdf`;
    await assertSucceeds(
      uploadBytes(storageRef(alice, path), bytes, {
        contentType: 'application/pdf',
      }),
    );
    await assertFails(deleteObject(storageRef(bob, path)));
  });
});

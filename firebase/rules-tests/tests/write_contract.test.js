/**
 * Creates one document for every key the mobile writers and the Hub web
 * writer persist. App and Hub keys must be a subset of the rules allow-list
 * where one exists. Notes, signature documents, userChats, and members have
 * no key allow-list, so those creates must simply succeed.
 *
 * Hub keys: docs/hub_chat_contract.md (Hub frontend is not in this workspace).
 */
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';
import { dirname, resolve } from 'path';
import { fileURLToPath } from 'url';
import { doc, setDoc, serverTimestamp, Timestamp } from 'firebase/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, '../../..');
const fixture = JSON.parse(
  readFileSync(resolve(root, 'firebase/rules-tests/fixtures/write_keys.json'), 'utf8'),
);
const rulesSource = readFileSync(resolve(root, 'firestore.rules'), 'utf8');
const mobile = fixture.mobile;
const hub = fixture.hub;

function allowedMessageKeys() {
  const names = [
    'messageCreateKeysAllowed',
    'signingKeysOnly',
    'isSoftDeleteUpdate',
    'isOwnMessageNonSenderEdit',
  ];
  const keys = new Set();
  for (const name of names) {
    const start = rulesSource.indexOf(`function ${name}`);
    if (start < 0) throw new Error(`missing ${name}`);
    const next = rulesSource.indexOf('\n    function ', start + 1);
    const body = rulesSource.slice(start, next === -1 ? undefined : next);
    for (const match of body.matchAll(/'([A-Za-z0-9_]+)'/g)) keys.add(match[1]);
  }
  return keys;
}

function createMessageKeys() {
  const start = rulesSource.indexOf('function messageCreateKeysAllowed');
  const next = rulesSource.indexOf('\n    function ', start + 1);
  const body = rulesSource.slice(start, next);
  return new Set([...body.matchAll(/'([A-Za-z0-9_]+)'/g)].map((match) => match[1]));
}

const PROJECT_ID = 'elrace-new';
const ALICE = 'odoo_100';
const BOB = 'odoo_200';
const DM_AB = 'dm_odoo_100_odoo_200';
const ALICE_CLAIMS = { role_id: 5, branch_id: 1, company_id: 1 };

let testEnv;

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

function aliceDb() {
  return testEnv.authenticatedContext(ALICE, ALICE_CLAIMS).firestore();
}

function sample(key, messageType) {
  switch (key) {
    case 'sender_id':
    case 'owner_uid':
    case 'signed_by':
    case 'current_signer_uid':
    case 'ownerId':
      return ALICE;
    case 'peer_uid':
    case 'recipient_uid':
    case 'support_user_uid':
      return BOB;
    case 'type':
      return messageType || 'dm';
    case 'noteType':
      return 'audio';
    case 'status':
      return messageType ? 'sent' : 'pending_other';
    case 'sign_status':
      return 'pending';
    case 'aiMode':
      return 'summarize';
    case 'aiStatus':
      return 'done';
    case 'created_at':
    case 'updated_at':
    case 'signed_at':
    case 'expires_at':
    case 'joined_at':
    case 'createdAt':
    case 'updatedAt':
      return Timestamp.now();
    case 'text':
    case 'title':
    case 'content':
    case 'file_name':
    case 'recipient_name':
    case 'support_group_title':
    case 'aiContext':
    case 'aiSummary':
    case 'aiBulletPoints':
    case 'translatedText':
    case 'translatedLanguage':
    case 'client_msg_id':
    case 'chat_id':
    case 'message_id':
    case 'signature_document_id':
    case 'mime_type':
      return key === 'mime_type' ? 'application/pdf' : `${key}-value`;
    case 'media_url':
    case 'thumb_url':
    case 'signed_pdf_url':
    case 'file_url':
    case 'thumbnail_url':
    case 'media_path':
      return `https://example.com/${key}`;
    case 'file_size':
    case 'duration_ms':
    case 'page_count':
    case 'sign_expires_in_days':
    case 'current_signer_index':
    case 'role_id':
    case 'branch_id':
    case 'company_id':
    case 'role_id_snapshot':
    case 'branch_id_snapshot':
    case 'company_id_snapshot':
      return 1;
    case 'pinned':
    case 'muted':
    case 'archived':
    case 'is_admin':
    case 'isImportant':
    case 'isTodo':
      return false;
    case 'has_messages':
    case 'stamp_needed':
    case 'timesheet_mode':
      return true;
    case 'signer_uids':
    case 'sharedWithUids':
    case 'tags':
      return [BOB];
    case 'signer_names':
      return ['Bob'];
    case 'reply_to':
      return {
        message_id: 'm1',
        sender_id: ALICE,
        text: 'earlier',
        type: 'text',
      };
    case 'sign_zones':
      return [{
        page: 0,
        x: 0.1,
        y: 0.1,
        width: 0.2,
        height: 0.08,
        type: 'signature',
        signer_slot: 0,
        cell_role: 'employee',
      }];
    case 'actionItems':
      return [{ id: 'a1', description: 'Follow up', isDone: false }];
    case 'recording':
      return {
        audioUrl: 'https://example.com/audio.m4a',
        durationSeconds: 3,
        language: 'en',
        transcript: 'hello',
        status: 'done',
      };
    case 'images':
      return [{ id: 'img-1', imageUrl: 'https://example.com/image.jpg' }];
    case 'sharedWith':
      return [{ uid: BOB, name: 'Bob' }];
    default:
      return `contract-${key}`;
  }
}

function payloadFrom(keys, messageType) {
  const data = {};
  for (const key of keys) data[key] = sample(key, messageType);
  return data;
}

describe('write contract', () => {
  const allowedMessages = allowedMessageKeys();
  const creatableMessages = createMessageKeys();

  it('keeps mobile and Hub message keys inside the rules allow-lists', () => {
    for (const [messageType, keys] of Object.entries(mobile.messages)) {
      const missing = keys.filter((key) => !allowedMessages.has(key));
      if (missing.length) {
        throw new Error(`${messageType} writes keys the rules do not allow: ${missing}`);
      }
    }
    const hubMissing = hub.messages.filter((key) => !allowedMessages.has(key));
    if (hubMissing.length) {
      throw new Error(`Hub message keys are not allowed: ${hubMissing}`);
    }
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'chats', DM_AB), {
        type: 'dm',
        member_ids: [ALICE, BOB],
        dm_pair: [ALICE, BOB],
      });
      await setDoc(doc(db, 'chats', DM_AB, 'members', BOB), {
        joined_at: Timestamp.now(),
        muted: false,
        is_admin: false,
      });
    });
  });

  for (const [messageType, keys] of Object.entries(mobile.messages)) {
    it(`allows a ${messageType} message with every mobile key`, async () => {
      const db = aliceDb();
      await assertSucceeds(
        setDoc(
          doc(db, 'chats', DM_AB, 'messages', `contract_${messageType}`),
          payloadFrom(keys, messageType),
        ),
      );
    });
  }

  it('allows a Hub message with every Hub key the create rule accepts', async () => {
    const db = aliceDb();
    const keys = hub.messages.filter((key) => creatableMessages.has(key));
    await assertSucceeds(
      setDoc(
        doc(db, 'chats', DM_AB, 'messages', 'contract_hub'),
        payloadFrom(keys, 'text'),
      ),
    );
  });

  it('denies a message key that is not in the rules allow-list', async () => {
    const db = aliceDb();
    const data = payloadFrom(mobile.messages.text, 'text');
    data.contract_extra_field = true;
    await assertFails(
      setDoc(doc(db, 'chats', DM_AB, 'messages', 'contract_extra'), data),
    );
  });

  it('allows a signature document with every contracted key', async () => {
    const db = aliceDb();
    await assertSucceeds(
      setDoc(
        doc(db, 'users', ALICE, 'signature_documents', 'contract'),
        payloadFrom(mobile.signature_documents),
      ),
    );
  });

  it('allows a note with every mobile key', async () => {
    const db = aliceDb();
    await assertSucceeds(
      setDoc(
        doc(db, 'users', ALICE, 'notes', 'contract'),
        payloadFrom(mobile.notes),
      ),
    );
  });

  it('allows a userChats doc with every mobile key', async () => {
    const db = aliceDb();
    await assertSucceeds(
      setDoc(
        doc(db, 'userChats', ALICE, 'chats', 'contract_inbox'),
        payloadFrom(mobile.userChats),
      ),
    );
  });

  it('allows a member doc with every mobile key', async () => {
    const db = aliceDb();
    await assertSucceeds(
      setDoc(
        doc(db, 'chats', DM_AB, 'members', ALICE),
        payloadFrom(mobile.members),
      ),
    );
  });

  it('allows a Hub chat, member, and userChats doc', async () => {
    const db = aliceDb();
    const chatId = 'dm_odoo_100_odoo_300';
    const chat = payloadFrom(hub.chats);
    chat.type = 'dm';
    chat.dm_pair = [ALICE, 'odoo_300'];
    chat.member_ids = [ALICE, 'odoo_300'];
    chat.last_message = {
      text: 'hello',
      type: 'text',
      sender_id: ALICE,
      created_at: Timestamp.now(),
    };
    await assertSucceeds(setDoc(doc(db, 'chats', chatId), chat));

    const member = payloadFrom(hub.members);
    member.last_read_at = serverTimestamp();
    member.last_delivered_at = serverTimestamp();
    member.joined_at = serverTimestamp();
    await assertSucceeds(
      setDoc(doc(db, 'chats', chatId, 'members', ALICE), member),
    );

    await assertSucceeds(
      setDoc(
        doc(db, 'userChats', ALICE, 'chats', chatId),
        payloadFrom(hub.userChats),
      ),
    );
  });
});

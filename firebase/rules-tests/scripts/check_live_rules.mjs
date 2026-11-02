/**
 * Fail when live elrace-new rules differ from this checkout.
 *
 * Reads an access token from stdin. Does not print the token.
 *
 *   gcloud auth print-access-token | node firebase/rules-tests/scripts/check_live_rules.mjs
 */
import { readFileSync } from 'fs';
import { dirname, resolve } from 'path';
import { fileURLToPath } from 'url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const project = 'elrace-new';
const databaseInstance = 'elrace-new-default-rtdb';

const token = (await readStdin()).trim();
if (!token || token.split('.').length < 2) {
  console.error('No access token on stdin. Pipe `gcloud auth print-access-token`.');
  process.exit(1);
}

const headers = {
  Authorization: `Bearer ${token}`,
  'x-goog-user-project': project,
};

const failures = [];

try {
  const releases = await getJson(
    `https://firebaserules.googleapis.com/v1/projects/${project}/releases`,
  );
  await compareRuleset(releases, 'cloud.firestore', 'firestore.rules');
  await compareRuleset(releases, 'firebase.storage', 'storage.rules');
} catch (error) {
  failures.push(`rules API: ${error.message}`);
}

try {
  const live = await getJson(
    `https://${databaseInstance}.firebaseio.com/.settings/rules.json`,
  );
  const local = JSON.parse(readFileSync(resolve(root, 'database.rules.json'), 'utf8'));
  if (stable(live) !== stable(local)) {
    failures.push('database.rules.json differs from the live Realtime Database rules');
  }
} catch (error) {
  failures.push(`realtime database: ${error.message}`);
}

if (failures.length) {
  console.error('Live Firebase rules differ from this checkout:');
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log('Live Firestore, Storage, and Realtime Database rules match this checkout.');

async function compareRuleset(releases, releaseId, fileName) {
  const release = (releases.releases || []).find((item) =>
    item.name?.endsWith(`/releases/${releaseId}`),
  );
  if (!release?.rulesetName) {
    failures.push(`no live release for ${releaseId}`);
    return;
  }
  const ruleset = await getJson(
    `https://firebaserules.googleapis.com/v1/${release.rulesetName}`,
  );
  const live = ruleset.source?.files?.[0]?.content ?? '';
  const local = readFileSync(resolve(root, fileName), 'utf8');
  if (normalize(live) !== normalize(local)) {
    failures.push(`${fileName} differs from live release ${release.rulesetName}`);
  }
}

async function getJson(url) {
  const response = await fetch(url, { headers });
  const body = await response.text();
  if (!response.ok) {
    throw new Error(`${response.status} ${url} ${body.slice(0, 180)}`);
  }
  return JSON.parse(body);
}

function normalize(value) {
  return value.replace(/\r\n/g, '\n').trim();
}

function stable(value) {
  if (Array.isArray(value)) return `[${value.map(stable).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stable(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

function readStdin() {
  return new Promise((resolvePromise, reject) => {
    const chunks = [];
    process.stdin.on('data', (chunk) => chunks.push(chunk));
    process.stdin.on('end', () => resolvePromise(Buffer.concat(chunks).toString('utf8')));
    process.stdin.on('error', reject);
  });
}

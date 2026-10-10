import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  arrayUnion,
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} from 'firebase/firestore';
import { readFile } from 'node:fs/promises';

const projectId = 'demo-wirdi-rules';
let env;

const group = (ownerUid = 'owner', overrides = {}) => ({
  name: 'Family Khatma',
  ownerUid,
  memberUids: [ownerUid],
  members: { [ownerUid]: 'Owner' },
  claims: {},
  rounds: 1,
  ...overrides,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: { rules: await readFile('firestore.rules', 'utf8') },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env.cleanup();
});

async function seedGroup(code, data) {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'family_khatmas', code), data);
  });
}

test('unauthenticated users cannot read group khatmas', async () => {
  await seedGroup('ABC234', group());
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'family_khatmas', 'ABC234')));
});

test('a signed-in owner can create a group containing only themselves', async () => {
  const db = env.authenticatedContext('owner').firestore();
  await assertSucceeds(setDoc(doc(db, 'family_khatmas', 'ABC234'), group()));
});

test('a creator cannot add another member during group creation', async () => {
  const db = env.authenticatedContext('owner').firestore();
  await assertFails(setDoc(doc(db, 'family_khatmas', 'ABC234'), group('owner', {
    memberUids: ['owner', 'intruder'],
    members: { owner: 'Owner', intruder: 'Intruder' },
  })));
});

test('a non-member can join without changing protected group data', async () => {
  await seedGroup('ABC234', group());
  const db = env.authenticatedContext('member').firestore();
  await assertSucceeds(updateDoc(doc(db, 'family_khatmas', 'ABC234'), {
    memberUids: arrayUnion('member'),
    'members.member': 'Member',
  }));
});

test('joining cannot change the owner or group name', async () => {
  await seedGroup('ABC234', group());
  const db = env.authenticatedContext('member').firestore();
  await assertFails(updateDoc(doc(db, 'family_khatmas', 'ABC234'), {
    memberUids: arrayUnion('member'),
    'members.member': 'Member',
    name: 'Hijacked',
  }));
});

test('a member can update only their own claim entry', async () => {
  await seedGroup('ABC234', group('owner', {
    memberUids: ['owner', 'member'],
    members: { owner: 'Owner', member: 'Member' },
    claims: { owner: { name: 'Owner', juzs: { '1': false } } },
  }));
  const db = env.authenticatedContext('member').firestore();
  await assertSucceeds(updateDoc(doc(db, 'family_khatmas', 'ABC234'), {
    'claims.member': { name: 'Member', juzs: { '2': false } },
  }));
});

test('a member cannot rewrite another member claim', async () => {
  await seedGroup('ABC234', group('owner', {
    memberUids: ['owner', 'member'],
    members: { owner: 'Owner', member: 'Member' },
    claims: { owner: { name: 'Owner', juzs: { '1': false } } },
  }));
  const db = env.authenticatedContext('member').firestore();
  await assertFails(updateDoc(doc(db, 'family_khatmas', 'ABC234'), {
    claims: {
      owner: { name: 'Owner', juzs: { '1': true } },
      member: { name: 'Member', juzs: { '2': false } },
    },
  }));
});

test('a member can leave by removing only their own membership', async () => {
  await seedGroup('ABC234', group('owner', {
    memberUids: ['owner', 'member'],
    members: { owner: 'Owner', member: 'Member' },
  }));
  const db = env.authenticatedContext('member').firestore();
  await assertSucceeds(updateDoc(doc(db, 'family_khatmas', 'ABC234'), {
    memberUids: ['owner'],
    members: { owner: 'Owner' },
  }));
});

test('the owner can start a new round by clearing claims and incrementing rounds', async () => {
  await seedGroup('ABC234', group('owner', {
    claims: { owner: { name: 'Owner', juzs: { '1': true } } },
  }));
  const db = env.authenticatedContext('owner').firestore();
  await assertSucceeds(updateDoc(doc(db, 'family_khatmas', 'ABC234'), {
    claims: {},
    rounds: 2,
  }));
});

test('the owner cannot delete a group while other members remain', async () => {
  await seedGroup('ABC234', group('owner', {
    memberUids: ['owner', 'member'],
    members: { owner: 'Owner', member: 'Member' },
  }));
  const db = env.authenticatedContext('owner').firestore();
  await assertFails(deleteDoc(doc(db, 'family_khatmas', 'ABC234')));
});

test('the owner can delete an empty group', async () => {
  await seedGroup('ABC234', group());
  const db = env.authenticatedContext('owner').firestore();
  await assertSucceeds(deleteDoc(doc(db, 'family_khatmas', 'ABC234')));
});

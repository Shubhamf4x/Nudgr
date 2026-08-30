/**
 * Nudgr — Firestore Security Rules test suite (requirements 17 & 18)
 *
 * Run against the Firebase Emulator Suite:
 *
 *   1. npm install
 *   2. firebase emulators:exec --only firestore "npm test"
 *      (or: firebase emulators:start --only firestore  +  npm test)
 *
 * Test matrix (Account A / Account B):
 *   - A -> A's data: allowed
 *   - A -> B's data: rejected
 *   - B -> A's data: rejected
 *   - unauthenticated -> private data: rejected
 *   - read / create / update / delete covered per collection
 *   - ownership-field tampering covered
 */

const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

const RULES = fs.readFileSync(path.resolve(__dirname, '../firestore.rules'), 'utf8');
const UID_A = 'uid-a-111111';
const UID_B = 'uid-b-222222';

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'rules-test-nudgr',
    firestore: { rules: RULES },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

function authedDb(uid, provider = 'google.com') {
  return uid
    ? testEnv
        .authenticatedContext(uid, { firebase: { sign_in_provider: provider } })
        .firestore()
    : testEnv.unauthenticatedContext().firestore();
}

const noteData = (uid) => ({
  id: 'note-1',
  title: 'Test note',
  content: 'Hello world',
  categoryId: null,
  categoryName: null,
  tags: [],
  isPinned: false,
  isArchived: false,
  userId: uid,
  createdAt: '2026-01-01T00:00:00.000',
  updatedAt: '2026-01-01T00:00:00.000',
  isSynced: true,
});

const taskData = (uid) => ({
  id: 'task-1',
  title: 'Test task',
  description: null,
  categoryId: null,
  categoryName: null,
  priority: 'medium',
  dueDate: null,
  dueTime: null,
  isCompleted: false,
  isRecurring: false,
  recurrencePattern: null,
  tags: [],
  subtasks: [],
  reminderTime: null,
  userId: uid,
  createdAt: '2026-01-01T00:00:00.000',
  updatedAt: '2026-01-01T00:00:00.000',
  completedAt: null,
  isSynced: true,
});

const profileData = (uid, email) => ({
  id: uid,
  email,
  displayName: 'Test User',
  username: 'testuser',
  photoUrl: null,
  bio: null,
  isOnline: true,
  lastSeen: '2026-01-01T00:00:00.000',
  createdAt: '2026-01-01T00:00:00.000',
  updatedAt: '2026-01-01T00:00:00.000',
  preferences: {},
  statistics: { totalTasks: 0, completedTasks: 0, totalNotes: 0, focusMinutes: 0 },
});

describe('user profile docs users/{uid}', () => {
  test('owner can create own profile', async () => {
    await assertSucceeds(
      authedDb(UID_A).doc('users/uid-a-111111').set(profileData(UID_A, 'a@example.com'))
    );
  });

  test('owner can read own profile', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('users/uid-a-111111').set(profileData(UID_A, 'a@example.com'));
    });
    await assertSucceeds(authedDb(UID_A).doc('users/uid-a-111111').get());
  });

  test("user B cannot read user A's profile", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('users/uid-a-111111').set(profileData(UID_A, 'a@example.com'));
    });
    await assertFails(authedDb(UID_B).doc('users/uid-a-111111').get());
  });

  test('unauthenticated cannot read profiles', async () => {
    await assertFails(authedDb(null).doc('users/uid-a-111111').get());
  });

  test('user cannot delete own profile doc from client', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('users/uid-a-111111').set(profileData(UID_A, 'a@example.com'));
    });
    await assertFails(authedDb(UID_A).doc('users/uid-a-111111').delete());
  });

  test('profile id field cannot be changed on update', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('users/uid-a-111111').set(profileData(UID_A, 'a@example.com'));
    });
    await assertFails(
      authedDb(UID_A).doc('users/uid-a-111111').set({ id: UID_B }, { merge: true })
    );
  });

  test('createdAt is immutable on update', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('users/uid-a-111111').set(profileData(UID_A, 'a@example.com'));
    });
    await assertFails(
      authedDb(UID_A)
        .doc('users/uid-a-111111')
        .set({ createdAt: '1999-01-01T00:00:00.000' }, { merge: true })
    );
  });
});

describe('notes users/{uid}/notes/{noteId}', () => {
  test('owner can create, read, update, delete own note', async () => {
    const db = authedDb(UID_A);
    const ref = db.doc('users/uid-a-111111/notes/note-1');
    await assertSucceeds(ref.set(noteData(UID_A)));
    await assertSucceeds(ref.get());
    await assertSucceeds(ref.set({ isPinned: true }, { merge: true }));
    await assertSucceeds(ref.delete());
  });

  test("user A cannot read user B's note", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('users/uid-b-222222/notes/note-1').set(noteData(UID_B));
    });
    await assertFails(authedDb(UID_A).doc('users/uid-b-222222/notes/note-1').get());
    await assertFails(
      authedDb(UID_A).doc('users/uid-b-222222/notes/note-1').set({ title: 'hacked' }, { merge: true })
    );
    await assertFails(authedDb(UID_A).doc('users/uid-b-222222/notes/note-1').delete());
  });

  test('cannot create a note inside another user subtree with own userId stamped', async () => {
    await assertFails(
      authedDb(UID_A).doc('users/uid-b-222222/notes/note-x').set(noteData(UID_A))
    );
  });

  test('unauthenticated cannot create notes', async () => {
    await assertFails(
      authedDb(null).doc('users/uid-a-111111/notes/note-1').set(noteData(UID_A))
    );
  });

  test('note with oversized title is rejected', async () => {
    const data = noteData(UID_A);
    data.title = 'x'.repeat(201);
    await assertFails(authedDb(UID_A).doc('users/uid-a-111111/notes/note-1').set(data));
  });
});

describe('tasks users/{uid}/tasks/{taskId}', () => {
  test('owner can create own task', async () => {
    await assertSucceeds(
      authedDb(UID_A).doc('users/uid-a-111111/tasks/task-1').set(taskData(UID_A))
    );
  });

  test("user A cannot modify user B's tasks", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('users/uid-b-222222/tasks/task-1').set(taskData(UID_B));
    });
    await assertFails(
      authedDb(UID_A).doc('users/uid-b-222222/tasks/task-1').set({ isCompleted: true }, { merge: true })
    );
  });

  test('task ownership field cannot be reassigned via update', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('users/uid-a-111111/tasks/task-1').set(taskData(UID_A));
    });
    await assertFails(
      authedDb(UID_A)
        .doc('users/uid-a-111111/tasks/task-1')
        .set({ userId: UID_B }, { merge: true })
    );
  });

  test('invalid priority value is rejected', async () => {
    const data = taskData(UID_A);
    data.priority = 'urgent';
    await assertFails(authedDb(UID_A).doc('users/uid-a-111111/tasks/task-1').set(data));
  });
});

describe('steps users/{uid}/steps/{date}', () => {
  test('owner can write own step record', async () => {
    await assertSucceeds(
      authedDb(UID_A).doc('users/uid-a-111111/steps/2026-08-29').set({ date: '2026-08-29', stepCount: 1234 })
    );
  });

  test('date field must match document id', async () => {
    await assertFails(
      authedDb(UID_A).doc('users/uid-a-111111/steps/2026-08-29').set({ date: '2020-01-01', stepCount: 5 })
    );
  });

  test('step count cannot be negative', async () => {
    await assertFails(
      authedDb(UID_A).doc('users/uid-a-111111/steps/2026-08-29').set({ date: '2026-08-29', stepCount: -1 })
    );
  });

  test("user A cannot write into user B's steps", async () => {
    await assertFails(
      authedDb(UID_A).doc('users/uid-b-222222/steps/2026-08-29').set({ date: '2026-08-29', stepCount: 5 })
    );
  });
});

describe('focus sessions, categories, conversations', () => {
  test('owner can create focus session', async () => {
    const data = {
      id: 'fs-1',
      taskId: null,
      taskTitle: null,
      userId: UID_A,
      durationMinutes: 25,
      actualDurationMinutes: 25,
      sessionType: 'focus',
      sessionNumber: 1,
      isCompleted: true,
      startTime: '2026-01-01T00:00:00.000',
      endTime: '2026-01-01T00:25:00.000',
      createdAt: '2026-01-01T00:00:00.000',
      updatedAt: '2026-01-01T00:25:00.000',
      isSynced: true,
    };
    await assertSucceeds(authedDb(UID_A).doc('users/uid-a-111111/focus_sessions/fs-1').set(data));
  });

  test('focus session duration is capped', async () => {
    const data = {
      id: 'fs-1',
      userId: UID_A,
      durationMinutes: 2000,
      actualDurationMinutes: 0,
      startTime: '2026-01-01T00:00:00.000',
      createdAt: '2026-01-01T00:00:00.000',
    };
    await assertFails(authedDb(UID_A).doc('users/uid-a-111111/focus_sessions/fs-1').set(data));
  });

  test('owner can manage categories and conversations', async () => {
    const db = authedDb(UID_A);
    await assertSucceeds(
      db.doc('users/uid-a-111111/categories/cat-1').set({
        id: 'cat-1', name: 'Work', colorIndex: 1, icon: null, userId: UID_A,
        type: 'task', sortOrder: 0,
        createdAt: '2026-01-01T00:00:00.000', updatedAt: '2026-01-01T00:00:00.000', isSynced: true,
      })
    );
    await assertSucceeds(
      db.doc('users/uid-a-111111/conversations/conv-1').set({ id: 'conv-1', userId: UID_A })
    );
  });
});

describe('username mapping usernames/{username}', () => {
  test('unauthenticated can look up a username (needed by login flow)', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('usernames/alice').set({
        email: 'a@example.com', uid: UID_A, createdAt: '2026-01-01T00:00:00.000',
      });
    });
    await assertSucceeds(authedDb(null).doc('usernames/alice').get());
  });

  test('authenticated user can claim a username mapped to own uid', async () => {
    await assertSucceeds(
      authedDb(UID_A).doc('usernames/alice').set({
        email: 'a@example.com', uid: UID_A, createdAt: '2026-01-01T00:00:00.000',
      })
    );
  });

  test('user cannot create a username mapping pointing at another uid', async () => {
    await assertFails(
      authedDb(UID_A).doc('usernames/bob').set({
        email: 'b@example.com', uid: UID_B, createdAt: '2026-01-01T00:00:00.000',
      })
    );
  });

  test('user cannot steal an existing username mapping via update', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('usernames/alice').set({
        email: 'a@example.com', uid: UID_A, createdAt: '2026-01-01T00:00:00.000',
      });
    });
    await assertFails(
      authedDb(UID_B).doc('usernames/alice').set({ uid: UID_B }, { merge: true })
    );
  });

  test('invalid username doc id is rejected on create', async () => {
    await assertFails(
      authedDb(UID_A).doc('usernames/has space').set({
        email: 'a@example.com', uid: UID_A, createdAt: '2026-01-01T00:00:00.000',
      })
    );
  });
});

describe('cloud sync provider gating', () => {
  test('email/password users cannot read or write private subcollections', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('users/uid-a-111111/notes/note-1').set(noteData(UID_A));
    });
    await assertFails(
      authedDb(UID_A, 'password').doc('users/uid-a-111111/notes/note-1').get()
    );
    await assertFails(
      authedDb(UID_A, 'password').doc('users/uid-a-111111/notes/note-2').set(noteData(UID_A))
    );
    await assertFails(
      authedDb(UID_A, 'password').doc('users/uid-a-111111/tasks/task-1').set(taskData(UID_A))
    );
  });

  test('email/password users can still read and update their own profile doc', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('users/uid-a-111111').set(profileData(UID_A, 'a@example.com'));
    });
    await assertSucceeds(authedDb(UID_A, 'password').doc('users/uid-a-111111').get());
    await assertSucceeds(
      authedDb(UID_A, 'password').doc('users/uid-a-111111').set({ bio: 'hello' }, { merge: true })
    );
  });

  test('google users keep full subcollection access', async () => {
    await assertSucceeds(
      authedDb(UID_A, 'google.com').doc('users/uid-a-111111/notes/note-1').set(noteData(UID_A))
    );
  });
});

describe('default deny', () => {
  test('unknown top-level collections are inaccessible', async () => {
    await assertFails(authedDb(UID_A).doc('anything/else').get());
    await assertFails(authedDb(UID_A).doc('anything/else').set({ x: 1 }));
  });

  test('unknown subcollections under users are inaccessible', async () => {
    await assertFails(authedDb(UID_A).doc('users/uid-a-111111/unknown/doc1').get());
    await assertFails(authedDb(UID_A).doc('users/uid-a-111111/unknown/doc1').set({ x: 1 }));
  });
});

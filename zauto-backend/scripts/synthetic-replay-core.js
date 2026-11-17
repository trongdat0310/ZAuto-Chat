import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { performance } from "node:perf_hooks";
import { fileURLToPath, pathToFileURL } from "node:url";

import {
  compileUserFilterDocument,
  getCompiledGroupPlan,
} from "../src/filters/user-filter-runtime.js";
import { evaluateCompiledGroupPlan } from "../src/filters/user-filter-evaluator.js";
import {
  shouldSkipDuplicateUserMessage,
  clearUserMessageDedupeCache,
} from "../src/messages/user-message-dedupe.js";

const fixtureModules = [
  "conversations/conversation-store.js",
  "conversations/conversation-json-codec.js",
  "diagnostics/conversation-io-metrics.js",
  "diagnostics/runtime-performance.js",
];

const percentile = (sorted, quantile) => {
  if (!sorted.length) return null;
  return Number(sorted[Math.ceil(sorted.length * quantile) - 1].toFixed(3));
};

export function validateReplayOptions({
  users = 3,
  messagesPerUser = 60,
  duplicatesEvery = 5,
  rejectedEvery = 7,
} = {}) {
  const values = { users, messagesPerUser, duplicatesEvery, rejectedEvery };
  for (const [key, value] of Object.entries(values)) {
    if (!Number.isSafeInteger(value) || value <= 0) {
      throw new Error(`INVALID_REPLAY_OPTION:${key}`);
    }
  }
  if (users > 12 || messagesPerUser > 300) {
    throw new Error("REPLAY_LIMIT_EXCEEDED: maximum 12 users x 300 messages");
  }
  return values;
}

async function makeIsolatedConversationStore(root) {
  const sourceRoot = fileURLToPath(new URL("../src/", import.meta.url));
  fs.writeFileSync(path.join(root, "package.json"), '{"type":"module"}');
  for (const file of fixtureModules) {
    const target = path.join(root, "src", file);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.copyFileSync(path.join(sourceRoot, file), target);
  }
  // The store derives data/user-data from its own module's location,
  // so copying it into a fresh OS temp tree isolates all test writes.
  const moduleUrl = pathToFileURL(
    path.join(root, "src", "conversations", "conversation-store.js")
  ).href;
  return import(moduleUrl);
}

function planForGroup(groupId) {
  const document = {
    filters: [{
      id: "load-matching-filter",
      name: "Synthetic test only",
      mode: "advanced",
      enabled: true,
      groupIds: [groupId],
      basic: {},
      advanced: {
        showKeywords: ["tripload"],
        hideKeywords: ["rejectload"],
      },
    }],
  };
  return getCompiledGroupPlan(compileUserFilterDocument(document), groupId);
}

function messageFor(groupId, sequence, userIndex) {
  return {
    threadId: groupId,
    isSelf: false,
    data: {
      msgType: "chat.text",
      msgId: `synthetic-${userIndex}-${sequence}`,
      cliMsgId: `synthetic-client-${userIndex}-${sequence}`,
      uidFrom: "synthetic-sender",
      content: `tripload test ride #${userIndex}-${sequence}`,
      ts: 1790000000000 + sequence * 1000,
    },
  };
}

/**
 * Replay: compiled filter -> per-user dedupe -> real conversation-store
 * atomic persistence -> read back and validate. No Zalo, network, server,
 * sockets, customer data, payment, quota or accepting rides is touched.
 */
export async function replaySyntheticLoad(options = {}) {
  const config = validateReplayOptions(options);
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "zchatauto-synthetic-"));
  const userIds = [];
  const samples = [];
  const metrics = {
    inputEvents: 0,
    matched: 0,
    duplicatesSkipped: 0,
    rejected: 0,
    saved: 0,
    persisted: 0,
    dataBytes: 0,
  };
  const started = performance.now();
  try {
    const store = await makeIsolatedConversationStore(root);
    for (let userIndex = 0; userIndex < config.users; userIndex++) {
      const userId = `synthetic-${randomUUID()}`;
      const groupId = `synthetic-group-${userIndex}`;
      userIds.push(userId);
      const plan = planForGroup(groupId);
      store.syncConversationGroups(userId, [{
        groupId, name: "Synthetic load group",
      }]);

      function dispatch(message) {
        const began = performance.now();
        metrics.inputEvents++;
        const result = evaluateCompiledGroupPlan(plan, message.data.content);
        if (!result.matched) {
          metrics.rejected++;
        } else {
          metrics.matched++;
          if (shouldSkipDuplicateUserMessage(userId, {
            senderId: message.data.uidFrom,
            content: message.data.content,
          })) {
            metrics.duplicatesSkipped++;
          } else {
            const saved = store.saveConversationMessage(userId, {
              message, groupName: "Synthetic load group",
            });
            assert.ok(saved && saved.id, "store did not persist a matched trip");
            metrics.saved++;
          }
        }
        samples.push(performance.now() - began);
      }

      let first = null;
      for (let sequence = 0; sequence < config.messagesPerUser; sequence++) {
        const message = messageFor(groupId, sequence, userIndex);
        if (!first) first = message;
        dispatch(message);
        if (sequence % config.duplicatesEvery === 0) {
          // Same sender and content inside dedupe window.
          dispatch(message);
        }
        if (sequence % config.rejectedEvery === 0) {
          dispatch({
            ...message,
            data: {
              ...message.data,
              msgId: `unmatched-${userIndex}-${sequence}`,
              content: `unmatched unrelated status #${userIndex}-${sequence}`,
            },
          });
        }
        if (sequence % 30 === 0) {
          await new Promise(resolve => setImmediate(resolve));
        }
      }

      // Verify idempotency in the persistent store independently of the
      // short-window in-memory duplicate detector.
      const before = store.getUserConversationMessages(
        userId, groupId, { limit: 500 },
      );
      assert.equal(before.length, config.messagesPerUser);
      const original = before.find(item => item.msgId === first.data.msgId);
      const repeated = store.saveConversationMessage(userId, {
        message: first, groupName: "Synthetic load group",
      });
      assert.equal(repeated.id, original.id);
      const after = store.getUserConversationMessages(
        userId, groupId, { limit: 500 },
      );
      assert.equal(after.length, before.length);

      const dataRoot = path.join(root, "data", "user-data", userId, "conversations");
      const file = path.join(dataRoot, "messages", `${groupId}.json`);
      const stored = JSON.parse(fs.readFileSync(file, "utf8"));
      assert.equal(stored.length, config.messagesPerUser);
      assert.equal(new Set(stored.map(item => item.msgId)).size, stored.length);
      assert.equal(fs.readdirSync(path.dirname(file)).some(name =>
        name.endsWith(".tmp")), false);
      metrics.persisted += stored.length;
      metrics.dataBytes += fs.statSync(file).size;
    }
    assert.equal(metrics.persisted, config.users * config.messagesPerUser);
    assert.equal(metrics.saved, metrics.persisted);
    assert.equal(metrics.matched, metrics.saved + metrics.duplicatesSkipped);
    assert.equal(metrics.inputEvents,
      metrics.matched + metrics.rejected);

    samples.sort((a, b) => a - b);
    const wallMs = performance.now() - started;
    return {
      kind: "synthetic-filter-dedupe-conversation-store",
      ...config,
      ...metrics,
      wallMs: Number(wallMs.toFixed(2)),
      eventsPerSecond: Number((metrics.inputEvents * 1000 / wallMs).toFixed(1)),
      processingMs: {
        p50: percentile(samples, 0.5),
        p95: percentile(samples, 0.95),
        p99: percentile(samples, 0.99),
        max: percentile(samples, 1),
      },
      rssMiB: Number((process.memoryUsage().rss / 1048576).toFixed(1)),
      isolatedTemporaryData: true,
      networkOrRealZaloTraffic: false,
    };
  } finally {
    for (const userId of userIds) {
      clearUserMessageDedupeCache(userId);
    }
    fs.rmSync(root, { recursive: true, force: true });
  }
}

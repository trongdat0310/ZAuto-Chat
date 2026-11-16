import path from "node:path";
import { performance } from "node:perf_hooks";
import { serializeConversationJson } from "../src/conversations/conversation-json-codec.js";

// Synthetic, non-customer data. Compare only JSON serialization and byte size;
// results do not represent end-to-end latency or filesystem durability.
const parseOption = (name, fallback, max) => {
  const flag = process.argv.find(arg => arg.startsWith(name + "="));
  const parsed = Number(flag?.split("=")[1]);
  return Number.isInteger(parsed) && parsed > 0 && parsed <= max
    ? parsed
    : fallback;
};
const size = parseOption("--messages", 1000, 20000);
const runs = parseOption("--runs", 15, 1000);
const file = path.join("data", "user-data", "benchmark", "conversations", "messages", "benchmark.json");

const sample = Array.from({ length: size }, (_, i) => ({
  id: "synthetic-" + i,
  groupId: "group-1",
  msgId: "zalo-" + i,
  cliMsgId: "client-" + i,
  content: "Cuốc thử nghiệm " + i + ": A → B, 150k",
  senderName: "Test sender",
  preview: "Cuốc thử nghiệm: A → B, 150k",
  rawData: {
    msgId: "zalo-" + i,
    ts: 1790000000000 + i * 1000,
    content: "Cuốc thử nghiệm " + i + ": A → B, 150k",
  },
}));

function benchmark(serialize) {
  for (let i = 0; i < 3; i++) serialize();
  const samples = [];
  for (let i = 0; i < runs; i++) {
    const started = performance.now();
    const value = serialize();
    samples.push(performance.now() - started);
    if (i === 0) {
      // Guard against accidentally comparing different documents.
      if (JSON.parse(value).length !== size) {
        throw new Error("SERIALIZATION_CONTENT_MISMATCH");
      }
    }
  }
  samples.sort((a, b) => a - b);
  return {
    medianMs: Number(samples[Math.floor(samples.length / 2)].toFixed(3)),
    p95Ms: Number(samples[Math.ceil(samples.length * 0.95) - 1].toFixed(3)),
  };
}

const compact = serializeConversationJson(file, sample);
const pretty = JSON.stringify(sample, null, 2);
const result = {
  kind: "synthetic-json-only",
  messages: size,
  iterations: runs,
  bytesPretty: Buffer.byteLength(pretty),
  bytesCompact: Buffer.byteLength(compact),
  byteReductionPercent: Number((
    100 * (1 - Buffer.byteLength(compact) / Buffer.byteLength(pretty))
  ).toFixed(2)),
  pretty: benchmark(() => JSON.stringify(sample, null, 2)),
  compact: benchmark(() => serializeConversationJson(file, sample)),
};
if (JSON.stringify(JSON.parse(compact)) !== JSON.stringify(JSON.parse(pretty))) {
  throw new Error("SERIALIZATION_ROUNDTRIP_MISMATCH");
}
console.log(JSON.stringify(result, null, 2));

import fs from "node:fs";
import { fileURLToPath } from "node:url";

// Reads existing Flutter [LATENCY] lines (no message content).
// Backend durations are converted from microseconds to milliseconds.
const fields = {
  "backend.filter": "us",
  "backend.dedupe": "us",
  "backend.store": "us",
  "backend.ws": "us",
  "network~": "ms",
  "flutter.socketToBus": "ms",
  "flutter.busToHome": "ms",
  "flutter.homeToRender": "ms",
  "flutter.internal": "ms",
  "total~": "ms",
};

export function parseLatencyLine(line) {
  const at = line.indexOf("[LATENCY]");
  if (at < 0) return null;
  const tail = line.slice(at + "[LATENCY]".length);
  const values = {};
  let clockSkew = false;

  for (const token of tail.trim().split(/\s+/)) {
    const equals = token.indexOf("=");
    if (equals <= 0) continue;
    const key = token.slice(0, equals);
    const value = token.slice(equals + 1);
    if ((key === "network~" || key === "total~") &&
        value === "clock-skew") {
      clockSkew = true;
    }
    if (!Object.hasOwn(fields, key)) continue;
    const match = /^(\d+(?:\.\d+)?)(us|ms)$/.exec(value);
    if (!match || match[2] !== fields[key]) continue;
    const number = Number(match[1]);
    if (!Number.isFinite(number)) continue;
    values[key] = match[2] === "us" ? number / 1000 : number;
  }
  return { values, clockSkew };
}

export function percentile(values, q) {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const index = Math.max(0, Math.ceil(q * sorted.length) - 1);
  return sorted[index];
}

export function summarizeLatencyLog(text) {
  const samples = Object.fromEntries(
    Object.keys(fields).map(key => [key, []])
  );
  let traces = 0;
  let clockSkewReports = 0;
  for (const line of text.split(/\r?\n/)) {
    const parsed = parseLatencyLine(line);
    if (!parsed) continue;
    traces += 1;
    if (parsed.clockSkew) clockSkewReports += 1;
    for (const [key, value] of Object.entries(parsed.values)) {
      samples[key].push(value);
    }
  }
  return {
    traces,
    clockSkewReports,
    unit: "milliseconds",
    metrics: Object.fromEntries(
      Object.entries(samples).map(([key, values]) => [
        key,
        {
          n: values.length,
          p50: percentile(values, 0.50),
          p95: percentile(values, 0.95),
          p99: percentile(values, 0.99),
          max: percentile(values, 1),
        },
      ])
    ),
  };
}

const formatNumber = number =>
  number == null ? "-" : number.toFixed(2);

export function formatLatencyReport(report) {
  const lines = [
    "ZCHATAUTO latency samples: " + report.traces +
      "; clock-skew records: " + report.clockSkewReports,
    "All values in ms; network~ and total~ are approximate.",
    "Metric                    n      p50      p95      p99      max",
  ];
  for (const [name, stats] of Object.entries(report.metrics)) {
    lines.push(
      name.padEnd(26) + " " + String(stats.n).padStart(4) + " " +
      formatNumber(stats.p50).padStart(8) + " " +
      formatNumber(stats.p95).padStart(8) + " " +
      formatNumber(stats.p99).padStart(8) + " " +
      formatNumber(stats.max).padStart(8)
    );
  }
  return lines.join("\n");
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const args = process.argv.slice(2);
  const json = args.includes("--json");
  const file = args.find(arg => !arg.startsWith("--"));
  const input = file
    ? fs.readFileSync(file, "utf8")
    : fs.readFileSync(0, "utf8");
  const report = summarizeLatencyLog(input);
  console.log(json ? JSON.stringify(report, null, 2) :
    formatLatencyReport(report));
  if (report.traces === 0) process.exitCode = 2;
}

import { replaySyntheticLoad } from "./synthetic-replay-core.js";

const names = {
  "--users": "users",
  "--messages": "messagesPerUser",
  "--duplicates-every": "duplicatesEvery",
  "--reject-every": "rejectedEvery",
};

async function main() {
  const options = {};
  for (const arg of process.argv.slice(2)) {
    const [flag, value, extra] = arg.split("=");
    if (!(flag in names) || value == null || extra != null) {
      throw new Error("INVALID_FLAG: " + arg);
    }
    options[names[flag]] = Number(value);
  }
  const report = await replaySyntheticLoad(options);
  console.log(JSON.stringify(report, null, 2));
}

main().catch(error => {
  console.error("[LOAD SMOKE] " + error.message);
  process.exitCode = 1;
});

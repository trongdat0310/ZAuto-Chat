import path from "node:path";

/**
 * Keep message history JSON compact: every newly stored message previously
 * reserialized the complete history with 2-space indentation.
 * Index JSON remains human-readable. Both encodings are valid JSON with the
 * exact same data schema, and the store still uses synchronous atomic rename.
 */
export function isConversationMessageFile(file) {
  return path.basename(path.dirname(file)) === "messages" &&
    path.extname(file) === ".json";
}

export function serializeConversationJson(file, value) {
  return isConversationMessageFile(file)
    ? JSON.stringify(value)
    : JSON.stringify(value, null, 2);
}

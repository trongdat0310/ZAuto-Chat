// The private chat title belongs to the peer (threadId), not the last sender.
// In outgoing messages, data.dName can be the current Zalo account's name.
function nonEmpty(value) {
  return typeof value === "string" ? value.trim() : "";
}

export function resolvePrivatePeerName({
  peerId,
  peerName,
  senderId,
  senderName,
  isSelf = false,
  storedName,
} = {}) {
  const resolved = nonEmpty(peerName);
  if (resolved) return resolved;

  // Only an incoming message FROM the peer can safely provide a peer name.
  if (!isSelf && nonEmpty(peerId) &&
      String(senderId ?? "").trim() === nonEmpty(peerId)) {
    const incomingName = nonEmpty(senderName);
    if (incomingName) return incomingName;
  }

  return nonEmpty(storedName) || "Người dùng Zalo";
}

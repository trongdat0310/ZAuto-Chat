import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename =
  fileURLToPath(import.meta.url);

const __dirname =
  path.dirname(__filename);

const filePath =
  path.resolve(
    __dirname,
    "../../data/revoked-tokens.json"
  );


function readTokens() {
  if (!fs.existsSync(filePath)) {
    return [];
  }

  try {
    const data =
      JSON.parse(
        fs.readFileSync(
          filePath,
          "utf-8"
        )
      );

    return Array.isArray(data)
      ? data
      : [];

  } catch {
    return [];
  }
}


function writeTokens(tokens) {
  fs.writeFileSync(
    filePath,
    JSON.stringify(
      tokens,
      null,
      2
    ),
    "utf-8"
  );
}


export function revokeToken({
  jti,
  exp,
}) {
  const now =
    Math.floor(
      Date.now() / 1000
    );

  // Xoa cac token da het han
  const tokens =
    readTokens().filter(
      item =>
        item.exp > now
    );


  if (
    !tokens.some(
      item =>
        item.jti === jti
    )
  ) {
    tokens.push({
      jti,
      exp,
      revokedAt:
        new Date().toISOString(),
    });
  }


  writeTokens(tokens);
}


export function isTokenRevoked(
  jti
) {
  if (!jti) {
    return false;
  }

  return readTokens().some(
    item =>
      item.jti === jti
  );
}
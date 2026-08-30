import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const settingsPath = path.resolve(
  __dirname,
  "../../data/filter-settings.json"
);


// ========================================
// NORMALIZE TEXT
// ========================================

function normalizeText(value = "") {
  return String(value)
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .toLowerCase()
    .trim();
}


// ========================================
// DEFAULT SETTINGS
// ========================================

function defaultSettings() {
  return {
    includeKeywords: [],
    excludeKeywords: [],
    enabled: true,
  };
}


// ========================================
// READ SETTINGS
// ========================================

export function getFilterSettings() {
  if (!fs.existsSync(settingsPath)) {
    return defaultSettings();
  }

  try {
    const saved = JSON.parse(
      fs.readFileSync(settingsPath, "utf-8")
    );

    return {
      ...defaultSettings(),
      ...saved,
    };
  } catch (error) {
    console.error(
      "[FILTER] Khong doc duoc filter-settings.json"
    );

    return defaultSettings();
  }
}


// ========================================
// SAVE SETTINGS
// ========================================

export function saveFilterSettings(settings) {
  const current = getFilterSettings();

  const next = {
    ...current,
    ...settings,
    updatedAt: new Date().toISOString(),
  };

  fs.writeFileSync(
    settingsPath,
    JSON.stringify(next, null, 2),
    "utf-8"
  );

  return next;
}


// ========================================
// FILTER ENGINE
// ========================================

export function evaluateMessage(messageText) {
  const settings = getFilterSettings();

  if (!settings.enabled) {
    return {
      matched: true,
      reason: "filter_disabled",
    };
  }

  const text = normalizeText(messageText);

  const includeKeywords =
    (settings.includeKeywords ?? [])
      .map(normalizeText)
      .filter(Boolean);

  const excludeKeywords =
    (settings.excludeKeywords ?? [])
      .map(normalizeText)
      .filter(Boolean);


  // Exclude luon uu tien cao nhat
  const matchedExclude =
    excludeKeywords.find(
      keyword => text.includes(keyword)
    );

  if (matchedExclude) {
    return {
      matched: false,
      reason: "excluded_keyword",
      keyword: matchedExclude,
    };
  }


  // Khong co include keyword -> chap nhan
  if (includeKeywords.length === 0) {
    return {
      matched: true,
      reason: "no_include_keywords",
    };
  }


  // Include hien tai dung OR:
  // chi can trung 1 keyword
  const matchedInclude =
    includeKeywords.find(
      keyword => text.includes(keyword)
    );

  if (matchedInclude) {
    return {
      matched: true,
      reason: "included_keyword",
      keyword: matchedInclude,
    };
  }


  return {
    matched: false,
    reason: "no_include_match",
  };
}
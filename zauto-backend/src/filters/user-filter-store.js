import fs from "node:fs";
import path from "node:path";
import {
randomUUID,
} from "node:crypto";
import {
fileURLToPath,
} from "node:url";


const __filename =
fileURLToPath(
    import.meta.url
);

const __dirname =
path.dirname(
    __filename
);


const rootPath =
path.resolve(
    __dirname,
    "../../data/user-data"
);


export const USER_FILTER_SCHEMA_VERSION =
2;

export const MAX_USER_FILTERS =
50;

export const LEGACY_FILTER_ID =
    "legacy-default";


// ========================================
// RAM CACHE
//
// userId -> filter document
//
// Message realtime KHONG doc disk.
// ========================================

const documentCache =
new Map();


// ========================================
// PATH
// ========================================

function getUserDir(
    userId
    ) {
  return path.join(
      rootPath,
      String(userId)
  );
}


function getFilterPath(
    userId
    ) {
  return path.join(
      getUserDir(
          userId
      ),
      "filter-settings.json"
  );
}


// ========================================
// HELPERS
// ========================================

function nowIso() {
  return new Date()
      .toISOString();
}


function sanitizeText(
value,
maxLength = 2000
) {
return String(
value ?? ""
)
    .trim()
    .slice(
0,
maxLength
);
}


function sanitizeStringList(
values, {
maxItems = 100,
maxLength = 255,
} = {}
) {
if (
!Array.isArray(
values
)
) {
return [];
}


const result = [];

const seen =
new Set();


for (
const raw of values
) {
const value =
sanitizeText(
raw,
maxLength
);


if (
!value ||
seen.has(
value
)
) {
continue;
}


seen.add(
value
);

result.push(
value
);


if (
result.length >=
maxItems
) {
break;
}
}


return result;
}


// ========================================
// DEFAULT BASIC
// ========================================

export function createDefaultBasicFilter() {
return {
pickup:
"",

dropoff:
"",

acceptBothDirections:
false,

includeKeywords:
"",

excludeKeywords:
"",

minimumPrice:
null,

timeRules:
"",
};
}


// ========================================
// DEFAULT ADVANCED
// ========================================

export function createDefaultAdvancedFilter() {
return {
showKeywords:
[],

hideKeywords:
[],
};
}


// ========================================
// BASIC SANITIZE
// ========================================

function sanitizeBasic(
value
) {
const source =
value &&
typeof value ===
"object"
? value
    : {};


const rawPrice =
source.minimumPrice;


let minimumPrice =
null;


if (
rawPrice !==
null &&
rawPrice !==
undefined &&
rawPrice !==
""
) {
const parsed =
Number(
rawPrice
);


if (
Number.isFinite(
parsed
) &&
parsed >= 0
) {
minimumPrice =
parsed;
}
}


return {
pickup:
sanitizeText(
source.pickup
),

dropoff:
sanitizeText(
source.dropoff
),

acceptBothDirections:
source
    .acceptBothDirections ===
true,

includeKeywords:
sanitizeText(
source
    .includeKeywords
),

excludeKeywords:
sanitizeText(
source
    .excludeKeywords
),

minimumPrice,

timeRules:
sanitizeText(
source.timeRules
),
};
}


// ========================================
// ADVANCED SANITIZE
// ========================================

function sanitizeAdvanced(
value
) {
const source =
value &&
typeof value ===
"object"
? value
    : {};


return {
showKeywords:
sanitizeStringList(
source
    .showKeywords
),

hideKeywords:
sanitizeStringList(
source
    .hideKeywords
),
};
}


// ========================================
// FILTER SANITIZE
// ========================================

export function sanitizeUserFilter(
input, {
fallbackId = null,
} = {}
) {
const source =
input &&
typeof input ===
"object"
? input
    : {};


const mode =
source.mode ===
"advanced"
? "advanced"
    : "basic";


const createdAt =
sanitizeText(
source.createdAt,
64
) ||
nowIso();


const updatedAt =
sanitizeText(
source.updatedAt,
64
) ||
createdAt;


return {
id:
sanitizeText(
source.id ??
fallbackId,
128
) ||
randomUUID(),

name:
sanitizeText(
source.name,
255
) ||
"Bộ lọc",

mode,

enabled:
source.enabled !==
false,

// [] = tat ca group
groupIds:
sanitizeStringList(
source.groupIds,
{
maxItems: 500,
maxLength: 128,
}
),

basic:
sanitizeBasic(
source.basic
),

advanced:
sanitizeAdvanced(
source.advanced
),

createdAt,

updatedAt,
};
}


// ========================================
// EMPTY DOCUMENT
// ========================================

function createEmptyDocument() {
return {
version:
USER_FILTER_SCHEMA_VERSION,

filters:
[],

updatedAt:
null,
};
}


// ========================================
// LEGACY MIGRATION
//
// OLD:
// {
//   enabled,
//   includeKeywords,
//   excludeKeywords
// }
//
// NEW:
// 1 advanced filter.
//
// Khong ghi disk luc read.
// Chi migrate trong RAM.
// Khi user save lan sau se ghi schema V2.
// ========================================

function migrateLegacyDocument(
saved
) {
const includeKeywords =
sanitizeStringList(
saved
    ?.includeKeywords
);

const excludeKeywords =
sanitizeStringList(
saved
    ?.excludeKeywords
);


// Filter cu rong
// = khong can tao filter V2.
if (
includeKeywords.length ===
0 &&
excludeKeywords.length ===
0
) {
return createEmptyDocument();
}


const timestamp =
sanitizeText(
saved?.updatedAt,
64
) ||
nowIso();


const legacyFilter =
sanitizeUserFilter(
{
id:
LEGACY_FILTER_ID,

name:
"Bộ lọc cũ",

mode:
"advanced",

enabled:
saved?.enabled !==
false,

groupIds:
[],

advanced: {
showKeywords:
includeKeywords,

hideKeywords:
excludeKeywords,
},

createdAt:
timestamp,

updatedAt:
timestamp,
},
{
fallbackId:
LEGACY_FILTER_ID,
}
);


return {
version:
USER_FILTER_SCHEMA_VERSION,

filters: [
legacyFilter,
],

updatedAt:
timestamp,
};
}


// ========================================
// DOCUMENT SANITIZE
// ========================================

function sanitizeDocument(
saved
) {
if (
saved &&
saved.version ===
USER_FILTER_SCHEMA_VERSION &&
Array.isArray(
saved.filters
)
) {
const filters =
saved.filters
    .slice(
0,
MAX_USER_FILTERS
)
    .map(
filter =>
sanitizeUserFilter(
filter
)
);


return {
version:
USER_FILTER_SCHEMA_VERSION,

filters,

updatedAt:
sanitizeText(
saved.updatedAt,
64
) ||
null,
};
}


return migrateLegacyDocument(
saved
);
}


// ========================================
// DISK READ
//
// CHI CHAY KHI CACHE MISS.
// ========================================

function readDocumentFromDisk(
userId
) {
const filePath =
getFilterPath(
userId
);


if (
!fs.existsSync(
filePath
)
) {
return createEmptyDocument();
}


try {
const saved =
JSON.parse(
fs.readFileSync(
filePath,
"utf-8"
)
);


return sanitizeDocument(
saved
);

} catch (error) {

console.error(
"[USER FILTER STORE] READ ERROR:",
userId,
error
);


return createEmptyDocument();
}
}


// ========================================
// PUBLIC READ
//
// QUAN TRONG:
// message realtime vao day se lay RAM.
// ========================================

export function getUserFilterDocument(
userId
) {
const key =
String(userId);


const cached =
documentCache.get(
key
);


if (cached) {
return cached;
}


const document =
readDocumentFromDisk(
key
);


documentCache.set(
key,
document
);


return document;
}


// ========================================
// ATOMIC WRITE
//
// Ghi temp file -> rename.
// Tranh JSON hong neu process bi dung
// dung luc dang write.
// ========================================

function persistDocument(
userId,
document
) {
const key =
String(userId);


const userDir =
getUserDir(
key
);


fs.mkdirSync(
userDir,
{
recursive: true,
}
);


const next =
sanitizeDocument({
...document,

version:
USER_FILTER_SCHEMA_VERSION,

updatedAt:
nowIso(),
});


next.updatedAt =
nowIso();


const filePath =
getFilterPath(
key
);


const tempPath =
`${filePath}.tmp-${process.pid}-${Date.now()}`;


fs.writeFileSync(
tempPath,

JSON.stringify(
next,
null,
2
),

"utf-8"
);


fs.renameSync(
tempPath,
filePath
);


// ========================================
// DOI OBJECT CACHE
//
// Runtime compiler sau nay chi can
// so sanh reference document cu/moi.
// ========================================

documentCache.set(
key,
next
);


return next;
}


// ========================================
// REPLACE DOCUMENT
// ========================================

export function saveUserFilterDocument(
userId,
document
) {
return persistDocument(
userId,
document
);
}


// ========================================
// UPSERT ONE FILTER
//
// San sang cho UI moi.
// ========================================

export function upsertUserFilter(
userId,
input
) {
const current =
getUserFilterDocument(
userId
);


const filters =
[
...current.filters,
];


const requestedId =
sanitizeText(
input?.id,
128
);


const existingIndex =
requestedId
? filters.findIndex(
item =>
item.id ===
requestedId
)
    : -1;


const now =
nowIso();


if (
existingIndex >= 0
) {
const existing =
filters[
existingIndex
];


filters[
existingIndex
] =
sanitizeUserFilter({
...existing,
...input,

id:
existing.id,

createdAt:
existing.createdAt,

updatedAt:
now,
});

} else {

if (
filters.length >=
MAX_USER_FILTERS
) {
throw new Error(
`Moi tai khoan chi duoc toi da ${MAX_USER_FILTERS} bo loc.`
);
}


filters.push(
sanitizeUserFilter({
...input,

createdAt:
now,

updatedAt:
now,
})
);
}


const saved =
persistDocument(
userId,
{
...current,
filters,
}
);


return requestedId
? saved.filters.find(
item =>
item.id ===
requestedId
) ??
saved.filters[
saved.filters.length -
1
]
    : saved.filters[
saved.filters.length -
1
];
}


// ========================================
// DELETE ONE FILTER
// ========================================

export function deleteUserFilter(
userId,
filterId
) {
const current =
getUserFilterDocument(
userId
);


const id =
sanitizeText(
filterId,
128
);


const filters =
current.filters.filter(
item =>
item.id !== id
);


if (
filters.length ===
current.filters.length
) {
return false;
}


persistDocument(
userId,
{
...current,
filters,
}
);


return true;
}


// ========================================
// LEGACY API VIEW
//
// Giup server/API cu tiep tuc chay
// trong luc chung ta migrate UI moi.
// ========================================

function defaultLegacySettings() {
return {
enabled:
true,

includeKeywords:
[],

excludeKeywords:
[],
};
}


export function getLegacyUserFilterSettings(
userId
) {
const document =
getUserFilterDocument(
userId
);


const legacy =
document.filters.find(
item =>
item.id ===
LEGACY_FILTER_ID
);


if (!legacy) {
return defaultLegacySettings();
}


return {
enabled:
legacy.enabled !==
false,

includeKeywords: [
...legacy
    .advanced
    .showKeywords,
],

excludeKeywords: [
...legacy
    .advanced
    .hideKeywords,
],

updatedAt:
legacy.updatedAt,
};
}


// ========================================
// LEGACY SAVE
//
// Chi cap nhat filter legacy.
// KHONG pha cac filter V2 moi.
// ========================================

export function saveLegacyUserFilterSettings(
userId,
updates
) {
const currentLegacy =
getLegacyUserFilterSettings(
userId
);


const nextLegacy = {
enabled:
updates.enabled !==
undefined
? updates.enabled ===
true
    : currentLegacy
    .enabled,

includeKeywords:
updates
    .includeKeywords !==
undefined
? sanitizeStringList(
updates
    .includeKeywords
)
    : currentLegacy
    .includeKeywords,

excludeKeywords:
updates
    .excludeKeywords !==
undefined
? sanitizeStringList(
updates
    .excludeKeywords
)
    : currentLegacy
    .excludeKeywords,
};


const document =
getUserFilterDocument(
userId
);


const filters =
document.filters.filter(
item =>
item.id !==
LEGACY_FILTER_ID
);


// Khong co rule cu nao
// thi khong can giu legacy filter.
if (
nextLegacy
    .includeKeywords
    .length >
0 ||
nextLegacy
    .excludeKeywords
    .length >
0
) {
const existing =
document.filters.find(
item =>
item.id ===
LEGACY_FILTER_ID
);


const timestamp =
nowIso();


filters.push(
sanitizeUserFilter({
id:
LEGACY_FILTER_ID,

name:
"Bộ lọc cũ",

mode:
"advanced",

enabled:
nextLegacy.enabled,

groupIds:
[],

advanced: {
showKeywords:
nextLegacy
    .includeKeywords,

hideKeywords:
nextLegacy
    .excludeKeywords,
},

createdAt:
existing
    ?.createdAt ??
timestamp,

updatedAt:
timestamp,
})
);
}


persistDocument(
userId,
{
...document,
filters,
}
);


return {
...nextLegacy,

updatedAt:
nowIso(),
};
}


// ========================================
// CACHE INVALIDATION
//
// Dung khi can reload thu cong.
// ========================================

export function invalidateUserFilterCache(
userId
) {
documentCache.delete(
String(userId)
);
}
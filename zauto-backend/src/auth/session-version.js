// A missing version is supported for accounts and tokens issued before migration.
export function isSessionCurrent(user, payload) {
  return Boolean(user && payload) &&
    (user.sessionVersion ?? null) === (payload.sv ?? null);
}

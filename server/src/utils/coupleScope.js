// Shared helpers for couple-scoped resource access and cursor pagination.
//
// These centralize two patterns that recur across the routes:
//   1. "load a row by id, but only if it belongs to the requesting couple"
//   2. cursor-based pagination using the take+1 / skip:1 idiom (see feed.js)

/**
 * Loads a single row by id via `model.findUnique`, returning it only when it
 * exists AND belongs to the given couple. Otherwise returns null.
 *
 * The caller is responsible for producing the 404 (and its message) when null
 * is returned, so per-route error copy is preserved.
 *
 * @param {object} model    Prisma delegate, e.g. prisma.feed
 * @param {string} id       Row id to look up
 * @param {string} coupleId Couple the row must belong to
 * @param {object} [opts]   Extra findUnique args (e.g. { include } or { select }).
 *                          If `select` is used it MUST include coupleId.
 * @returns {Promise<object|null>}
 */
export async function loadCoupleOwned(model, id, coupleId, opts = {}) {
  const row = await model.findUnique({ where: { id }, ...opts });
  if (!row || row.coupleId !== coupleId) return null;
  return row;
}

/**
 * Parses cursor pagination params from a request query, mirroring the idiom in
 * feed.js: fetch `take + 1` rows, and when a cursor is present use
 * `{ cursor: { id }, skip: 1 }` to exclude the cursor row itself.
 *
 * @param {object} query           req.query
 * @param {object} [options]
 * @param {number} [options.defaultLimit=20]
 * @param {number} [options.maxLimit=50]
 * @returns {{ take: number, cursorArgs: object }}
 */
export function paginateArgs(query, { defaultLimit = 20, maxLimit = 50 } = {}) {
  const take = Math.min(Number.parseInt(query.limit, 10) || defaultLimit, maxLimit);
  const cursor = query.cursor;
  const cursorArgs = {
    take: take + 1,
    ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
  };
  return { take, cursorArgs };
}

/**
 * Splits an over-fetched result set (fetched with take + 1) into a page,
 * matching feed.js semantics exactly: the page is the first `take` rows, and
 * nextCursor is the id of the last returned row (rows[take - 1]) when there are
 * more rows, otherwise null.
 *
 * @param {Array<{ id: string }>} rows Rows fetched with `take: take + 1`
 * @param {number} take                Requested page size
 * @returns {{ items: Array, nextCursor: string|null, hasMore: boolean }}
 */
export function buildPage(rows, take) {
  const hasMore = rows.length > take;
  return {
    items: rows.slice(0, take),
    nextCursor: hasMore ? rows[take - 1].id : null,
    hasMore,
  };
}

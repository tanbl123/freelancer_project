import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/job_post.dart';

/// Data-Access Object for the offline job-feed SQLite cache.
///
/// ## Schema (columnar, not blob)
/// Unlike the legacy `cached_job_posts` table that stored a JSON blob per row,
/// this table mirrors every [JobPost] field as a proper column. Benefits:
/// - SQL-level filtering (`WHERE category = ?`, `WHERE budget_min >= ?`)
/// - Schema-drift is explicit — adding a column is a migration, not a silent loss
/// - Row-level updates are possible without re-serialising the whole list
///
/// ## Tables
/// ```
/// job_posts_cache   — one row per cached post (max 20 rows enforced by replaceAll)
/// job_cache_meta    — single key/value store; holds `last_synced_at`
/// ```
///
/// ## Usage
/// ```dart
/// final dao = JobCacheDao(db);
/// await dao.replaceAll(freshPosts);      // write after a successful Supabase fetch
/// final posts = await dao.getAll();      // read when offline
/// final age   = await dao.lastSyncedAt(); // null → never synced
/// final stale = await dao.isStale();     // true → older than [kStaleDuration]
/// ```
class JobCacheDao {
  const JobCacheDao(this._db);

  final Database _db;

  // ── Constants ───────────────────────────────────────────────────────────────

  static const kTable      = 'job_posts_cache';
  static const kMetaTable  = 'job_cache_meta';
  static const kCacheLimit = 20;

  /// Cache is considered stale after this duration.
  /// Re-fetching Supabase more often than this is worthless on a bad connection.
  static const kStaleDuration = Duration(hours: 1);

  // ── DDL ─────────────────────────────────────────────────────────────────────

  /// Idempotent table creation — safe to call on every app start.
  /// Call this from your database `onCreate` and `onUpgrade` callbacks.
  static Future<void> ensureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $kTable (
        id                        TEXT    PRIMARY KEY,
        client_id                 TEXT    NOT NULL,
        client_name               TEXT    NOT NULL,
        title                     TEXT    NOT NULL,
        description               TEXT    NOT NULL,
        category                  TEXT    NOT NULL,
        status                    TEXT    NOT NULL DEFAULT 'open',
        required_skills           TEXT    NOT NULL,
        budget_min                REAL,
        budget_max                REAL,
        deadline                  INTEGER,
        cover_image_url           TEXT,
        allow_pre_engagement_chat INTEGER NOT NULL DEFAULT 1,
        view_count                INTEGER NOT NULL DEFAULT 0,
        application_count         INTEGER NOT NULL DEFAULT 0,
        project_duration          TEXT,
        created_at                INTEGER NOT NULL,
        updated_at                INTEGER NOT NULL,
        cached_at                 INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $kMetaTable (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ── Write ────────────────────────────────────────────────────────────────────

  /// Atomically replaces the entire cache with the [posts] list.
  ///
  /// Only the [kCacheLimit] most-recent posts (by their own `created_at`) are
  /// kept. The `last_synced_at` meta key is updated in the same batch.
  Future<void> replaceAll(List<JobPost> posts) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final toCache = posts.take(kCacheLimit).toList();

    final batch = _db.batch();

    // Clear old rows first — ensures limit is respected even if caller sends
    // more than kCacheLimit items.
    batch.delete(kTable);

    for (final post in toCache) {
      // toSqliteMap() already uses epoch-ms dates and JSON-encodes arrays,
      // matching the columnar schema exactly. We only add cached_at on top.
      batch.insert(
        kTable,
        {...post.toSqliteMap(), 'cached_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    batch.insert(
      kMetaTable,
      {'key': 'last_synced_at', 'value': now.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await batch.commit(noResult: true);
  }

  // ── Read ─────────────────────────────────────────────────────────────────────

  /// All cached posts, ordered newest-cached first.
  ///
  /// Uses [JobPost.fromMap] which handles epoch-ms integers natively —
  /// no extra parsing needed.
  Future<List<JobPost>> getAll() async {
    final rows = await _db.query(kTable, orderBy: 'cached_at DESC');
    return rows.map(JobPost.fromMap).toList();
  }

  /// Open posts in [category], read directly from the columnar index.
  ///
  /// Useful for offline category filtering without re-fetching Supabase.
  Future<List<JobPost>> getByCategory(String category) async {
    final rows = await _db.query(
      kTable,
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'cached_at DESC',
    );
    return rows.map(JobPost.fromMap).toList();
  }

  /// Cached posts whose title or required_skills text contains [query].
  ///
  /// SQLite LIKE is case-insensitive for ASCII. For full Unicode, prefer
  /// client-side filtering on the [getAll] result set.
  Future<List<JobPost>> search(String query) async {
    final like = '%$query%';
    final rows = await _db.query(
      kTable,
      where: 'title LIKE ? OR required_skills LIKE ?',
      whereArgs: [like, like],
      orderBy: 'cached_at DESC',
    );
    return rows.map(JobPost.fromMap).toList();
  }

  // ── Meta ──────────────────────────────────────────────────────────────────────

  /// Timestamp of the last successful Supabase sync, or `null` if the cache
  /// has never been populated.
  Future<DateTime?> lastSyncedAt() async {
    final rows = await _db.query(
      kMetaTable,
      where: 'key = ?',
      whereArgs: ['last_synced_at'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final ms = int.tryParse(rows.first['value'] as String);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// `true` when [lastSyncedAt] is older than [kStaleDuration] (or null).
  ///
  /// The caller can use this to decide whether a background re-fetch is
  /// worthwhile even when the device appears online.
  Future<bool> isStale() async {
    final last = await lastSyncedAt();
    if (last == null) return true;
    return DateTime.now().difference(last) > kStaleDuration;
  }

  // ── Patch operations ─────────────────────────────────────────────────────────

  /// Updates `client_name` for every cached post owned by [clientId].
  ///
  /// Call this immediately after a client changes their display name so the
  /// offline cache stays in sync and does not serve the stale old name.
  Future<void> updateClientName(String clientId, String newName) async {
    await _db.update(
      kTable,
      {'client_name': newName},
      where: 'client_id = ?',
      whereArgs: [clientId],
    );
  }

  // ── Maintenance ───────────────────────────────────────────────────────────────

  /// Wipe the cache — call on logout so the next user starts fresh.
  Future<void> clear() async {
    await _db.delete(kTable);
    await _db.delete(kMetaTable);
  }
}

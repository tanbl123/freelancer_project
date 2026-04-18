import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../services/supabase_service.dart';
import '../models/application_item.dart';

/// Data-access layer for [ApplicationItem].
///
/// ## One-shot fetches vs. Realtime streams
///
/// | Method | Use case |
/// |---|---|
/// | `getByClient` / `getByFreelancer` | Initial page load, pull-to-refresh |
/// | `streamForClient` / `streamForFreelancer` | `StreamBuilder` — live updates |
///
/// ## Supabase `.stream()` constraints
/// The `.stream()` API supports only a **single `.eq()` filter** per
/// subscription. We exploit this cleanly because the two roles require
/// different filter columns:
/// - Client → `client_id = uid` (all applications to their posted jobs)
/// - Freelancer → `freelancer_id = uid` (all proposals they submitted)
///
/// Both subscriptions respect Row-Level Security — users never see each
/// other's data even if the client-side filter were somehow bypassed.
class ApplicationRepository {
  const ApplicationRepository(this._db);

  final SupabaseService _db;

  // ── One-shot fetches ──────────────────────────────────────────────────────

  /// All applications addressed to jobs owned by [clientId].
  Future<List<ApplicationItem>> getByClient(String clientId) =>
      _db.getApplicationsByClient(clientId);

  /// All applications submitted by [freelancerId].
  Future<List<ApplicationItem>> getByFreelancer(String freelancerId) =>
      _db.getApplicationsByFreelancer(freelancerId);

  Future<bool> hasApplied(String jobId, String freelancerId) =>
      _db.hasApplied(jobId, freelancerId);

  Future<void> insert(ApplicationItem app) =>
      _db.insertApplication(app);

  Future<void> updateStatus(String id, ApplicationStatus status) =>
      _db.updateApplicationStatus(id, status);

  Future<void> update(ApplicationItem app) =>
      _db.updateApplication(app);

  // ── Realtime streams ───────────────────────────────────────────────────────

  /// **Client stream** — emits the full updated list whenever an application
  /// is INSERTED, UPDATED, or DELETED on any job this client posted.
  ///
  /// Use inside a `StreamBuilder<List<ApplicationItem>>`. Each emission
  /// replaces the previous list — there are no partial diffs to merge.
  ///
  /// ```dart
  /// StreamBuilder<List<ApplicationItem>>(
  ///   stream: _appRepo.streamForClient(uid),
  ///   builder: (context, snapshot) {
  ///     final apps = snapshot.data ?? const [];
  ///     ...
  ///   },
  /// )
  /// ```
  Stream<List<ApplicationItem>> streamForClient(String clientId) =>
      Supabase.instance.client
          .from('applications')
          .stream(primaryKey: ['id'])
          .eq('client_id', clientId)
          .order('created_at', ascending: false)
          .map((rows) => rows.map(ApplicationItem.fromMap).toList());

  /// **Freelancer stream** — emits whenever one of the freelancer's own
  /// proposals changes status (pending → accepted / rejected / withdrawn).
  ///
  /// Particularly useful for the "my applications" tab: the freelancer sees
  /// instant status updates the moment a client accepts or rejects.
  Stream<List<ApplicationItem>> streamForFreelancer(String freelancerId) =>
      Supabase.instance.client
          .from('applications')
          .stream(primaryKey: ['id'])
          .eq('freelancer_id', freelancerId)
          .order('created_at', ascending: false)
          .map((rows) => rows.map(ApplicationItem.fromMap).toList());
}

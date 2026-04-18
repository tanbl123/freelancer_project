import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../services/supabase_service.dart';
import '../models/service_order.dart';

/// Data-access layer for [ServiceOrder].
///
/// ## One-shot vs. Realtime
/// - `getByClient` / `getByFreelancer` — initial load and pull-to-refresh.
/// - `streamForFreelancer` / `streamForClient` — Supabase Realtime via
///   `.stream()`, suitable for direct use in `StreamBuilder`.
///
/// ## One-filter constraint
/// Supabase `.stream()` supports only **one `.eq()` filter**. Freelancers
/// and clients filter on different columns, so each role has its own factory.
class ServiceOrderRepository {
  const ServiceOrderRepository(this._db);
  final SupabaseService _db;

  // ── One-shot fetches ──────────────────────────────────────────────────────

  Future<List<ServiceOrder>> getByClient(String clientId) =>
      _db.getServiceOrdersByClient(clientId);

  Future<List<ServiceOrder>> getByFreelancer(String freelancerId) =>
      _db.getServiceOrdersByFreelancer(freelancerId);

  Future<ServiceOrder?> getById(String id) =>
      _db.getServiceOrderById(id);

  Future<void> create(ServiceOrder order) =>
      _db.insertServiceOrder(order);

  Future<void> updateStatus(
    String id,
    ServiceOrderStatus status, {
    String? freelancerNote,
  }) =>
      _db.updateServiceOrderStatus(id, status, freelancerNote: freelancerNote);

  // ── Realtime streams ───────────────────────────────────────────────────────

  /// Live stream of orders received by [freelancerId].
  ///
  /// Emits a fresh full list on every INSERT / UPDATE / DELETE that affects
  /// a row where `freelancer_id = freelancerId`. Use in `StreamBuilder`:
  ///
  /// ```dart
  /// StreamBuilder<List<ServiceOrder>>(
  ///   stream: _orderRepo.streamForFreelancer(uid),
  ///   builder: (context, snapshot) { ... },
  /// )
  /// ```
  Stream<List<ServiceOrder>> streamForFreelancer(String freelancerId) =>
      Supabase.instance.client
          .from('service_orders')
          .stream(primaryKey: ['id'])
          .eq('freelancer_id', freelancerId)
          .order('created_at', ascending: false)
          .map((rows) => rows.map(ServiceOrder.fromMap).toList());

  /// Live stream of orders placed by [clientId].
  ///
  /// The client sees instant status changes (pending → accepted / rejected)
  /// without needing to refresh.
  Stream<List<ServiceOrder>> streamForClient(String clientId) =>
      Supabase.instance.client
          .from('service_orders')
          .stream(primaryKey: ['id'])
          .eq('client_id', clientId)
          .order('created_at', ascending: false)
          .map((rows) => rows.map(ServiceOrder.fromMap).toList());
}

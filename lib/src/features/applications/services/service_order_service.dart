import '../../../backend/shared/domain_types.dart';
import '../../../features/profile/models/profile_user.dart';
import '../../../shared/guards/access_guard.dart';
import '../models/service_order.dart';
import '../repositories/service_order_repository.dart';

/// Business-logic layer for [ServiceOrder].
///
/// Rules:
///  - Only [UserRole.client] users may submit orders.
///  - Clients cannot order their own service (checked by caller via
///    `service.freelancerId != actor.uid`).
///  - Only the order's [ServiceOrder.clientId] may cancel (while pending).
///  - Only the order's [ServiceOrder.freelancerId] may accept or reject.
///  - Edits (message / budget / timeline) only allowed while status = pending,
///    and only by the original client.
///  - Once convertedToProject / rejected / cancelled, no further transitions.
class ServiceOrderService {
  const ServiceOrderService(this._repo);
  final ServiceOrderRepository _repo;

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<String?> submitOrder(ProfileUser actor, ServiceOrder order) async {
    if (!AccessGuard.canOrderService(actor)) {
      return 'Only active clients can place service orders.';
    }
    if (actor.uid == order.freelancerId) {
      return 'You cannot order your own service.';
    }
    final msgErr = _validateMessage(order.message);
    if (msgErr != null) return msgErr;

    if (order.proposedBudget != null && order.proposedBudget! <= 0) {
      return 'Proposed budget must be greater than zero.';
    }
    if (order.timelineDays != null &&
        (order.timelineDays! < 1 || order.timelineDays! > 365)) {
      return 'Timeline must be between 1 and 365 days.';
    }

    try {
      await _repo.create(order);
      return null;
    } catch (e) {
      return 'Failed to submit order: $e';
    }
  }

  // ── Edit (client, while pending) ───────────────────────────────────────────

  Future<String?> editOrder(ProfileUser actor, ServiceOrder updated) async {
    if (actor.uid != updated.clientId) return 'Access denied.';
    if (!updated.isPending) {
      return 'Only pending orders can be edited.';
    }
    final msgErr = _validateMessage(updated.message);
    if (msgErr != null) return msgErr;

    try {
      // Re-insert full order with updated fields via upsert (handled by DB).
      await _repo.create(updated); // SupabaseService.insertServiceOrder uses upsert
      return null;
    } catch (e) {
      return 'Failed to update order: $e';
    }
  }

  // ── Cancel (client, while pending) ────────────────────────────────────────

  Future<String?> cancelOrder(ProfileUser actor, ServiceOrder order) async {
    if (actor.uid != order.clientId) return 'Access denied.';
    if (!order.isPending) return 'Only pending orders can be cancelled.';

    try {
      await _repo.updateStatus(order.id, ServiceOrderStatus.cancelled);
      return null;
    } catch (e) {
      return 'Failed to cancel order: $e';
    }
  }

  // ── Accept (freelancer) ────────────────────────────────────────────────────

  Future<String?> acceptOrder(
      ProfileUser actor, ServiceOrder order, String note) async {
    if (actor.uid != order.freelancerId) return 'Access denied.';
    if (!order.isPending) return 'Only pending orders can be accepted.';

    try {
      await _repo.updateStatus(
        order.id,
        ServiceOrderStatus.accepted,
        freelancerNote: note.trim().isEmpty ? null : note.trim(),
      );
      return null;
    } catch (e) {
      return 'Failed to accept order: $e';
    }
  }

  // ── Reject (freelancer) ────────────────────────────────────────────────────

  Future<String?> rejectOrder(
      ProfileUser actor, ServiceOrder order, String reason) async {
    if (actor.uid != order.freelancerId) return 'Access denied.';
    if (!order.isPending) return 'Only pending orders can be rejected.';

    try {
      await _repo.updateStatus(
        order.id,
        ServiceOrderStatus.rejected,
        freelancerNote: reason.trim().isEmpty ? null : reason.trim(),
      );
      return null;
    } catch (e) {
      return 'Failed to reject order: $e';
    }
  }

  // ── Convert to project (called after project creation) ───────────────────

  Future<String?> markConverted(String orderId) async {
    try {
      await _repo.updateStatus(orderId, ServiceOrderStatus.convertedToProject);
      return null;
    } catch (e) {
      return 'Failed to update order status: $e';
    }
  }

  // ── Validators ─────────────────────────────────────────────────────────────

  static String? _validateMessage(String v) {
    final t = v.trim();
    if (t.isEmpty) return 'Message is required.';
    if (t.length < 20) return 'Please provide at least 20 characters.';
    if (t.length > 2000) return 'Message must be under 2000 characters.';
    return null;
  }

  static String? validateMessage(String? v) =>
      v == null ? 'Message is required.' : _validateMessage(v);

  static String? validateBudget(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    final d = double.tryParse(v.trim());
    if (d == null) return 'Enter a valid amount.';
    if (d <= 0) return 'Budget must be greater than zero.';
    return null;
  }

  static String? validateTimeline(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    final i = int.tryParse(v.trim());
    if (i == null) return 'Enter a whole number.';
    if (i < 1 || i > 365) return 'Timeline must be 1 – 365 days.';
    return null;
  }
}

import '../../../services/supabase_service.dart';
import '../models/payment_record.dart';
import '../models/payout_record.dart';

/// Thin data-access wrapper for payment and payout records.
/// All business rules live in [PaymentService].
class PaymentRepository {
  const PaymentRepository(this._db);
  final SupabaseService _db;

  // ── Payment Records ────────────────────────────────────────────────────────

  Future<PaymentRecord?> getForProject(String projectId) =>
      _db.getPaymentRecordForProject(projectId);

  Future<void> insert(PaymentRecord record) =>
      _db.insertPaymentRecord(record);

  Future<void> update(PaymentRecord record) =>
      _db.updatePaymentRecord(record);

  // ── Payout Records ─────────────────────────────────────────────────────────

  Future<void> insertPayout(PayoutRecord payout) =>
      _db.insertPayoutRecord(payout);

  Future<List<PayoutRecord>> getPayoutsForProject(String projectId) =>
      _db.getPayoutsForProject(projectId);

  Future<List<PayoutRecord>> getPayoutsForPayment(String paymentId) =>
      _db.getPayoutsForPayment(paymentId);
}

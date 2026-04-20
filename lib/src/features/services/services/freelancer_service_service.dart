import '../../../features/profile/models/profile_user.dart';
import '../../../shared/enums/service_status.dart';
import '../../../shared/enums/user_role.dart';
import '../../../shared/guards/access_guard.dart';
import '../models/freelancer_service.dart';
import '../repositories/freelancer_service_repository.dart';

/// Business-logic layer for the Provide Service Module.
///
/// Enforces role-based access control and validates all inputs before
/// delegating persistence to [FreelancerServiceRepository].
class FreelancerServiceService {
  const FreelancerServiceService(this._repo);
  final FreelancerServiceRepository _repo;

  // ── CRUD operations ───────────────────────────────────────────────────────

  Future<String?> createService(
      ProfileUser actor, FreelancerService service) async {
    if (!AccessGuard.canCreateService(actor)) {
      return actor.role == UserRole.client
          ? 'Only freelancers can list services. '
              'Submit a freelancer upgrade request first.'
          : 'Your account must be active to create services.';
    }
    final err = validateService(service);
    if (err != null) return err;
    try {
      await _repo.create(service);
      return null;
    } catch (e) {
      return 'Failed to create service: $e';
    }
  }

  Future<String?> updateService(
      ProfileUser actor, FreelancerService service) async {
    if (actor.uid != service.freelancerId && !AccessGuard.isAdmin(actor)) {
      return 'You can only edit your own services.';
    }
    if (service.status == ServiceStatus.deleted) {
      return 'Cannot edit a deleted service.';
    }
    final err = validateService(service);
    if (err != null) return err;
    try {
      await _repo.update(service);
      return null;
    } catch (e) {
      return 'Failed to update service: $e';
    }
  }

  Future<String?> deactivateService(
      ProfileUser actor, String serviceId, String ownerId) async {
    if (actor.uid != ownerId && !AccessGuard.isAdmin(actor)) {
      return 'You can only deactivate your own services.';
    }
    try {
      await _repo.updateStatus(serviceId, ServiceStatus.inactive);
      return null;
    } catch (e) {
      return 'Failed to deactivate service: $e';
    }
  }

  Future<String?> activateService(
      ProfileUser actor, String serviceId, String ownerId) async {
    if (actor.uid != ownerId && !AccessGuard.isAdmin(actor)) {
      return 'You can only activate your own services.';
    }
    if (!AccessGuard.canCreateService(actor)) {
      return 'Your account does not have permission to list services.';
    }
    try {
      await _repo.updateStatus(serviceId, ServiceStatus.active);
      return null;
    } catch (e) {
      return 'Failed to activate service: $e';
    }
  }

  /// Soft-deletes a service by setting its status to [ServiceStatus.deleted].
  Future<String?> deleteService(
      ProfileUser actor, String serviceId, String ownerId) async {
    if (actor.uid != ownerId && !AccessGuard.isAdmin(actor)) {
      return 'You can only delete your own services.';
    }
    try {
      await _repo.updateStatus(serviceId, ServiceStatus.deleted);
      return null;
    } catch (e) {
      return 'Failed to delete service: $e';
    }
  }

  /// Fire-and-forget view tracking — no UI feedback needed.
  void recordView(String serviceId) {
    _repo.incrementViewCount(serviceId).catchError((_) {});
  }

  // ── Static validators ─────────────────────────────────────────────────────

  /// Runs all field validators in sequence; returns the first error found.
  static String? validateService(FreelancerService s) {
    return validateTitle(s.title) ??
        validateDescription(s.description) ??
        validateTags(s.tags) ??
        validatePrice(s.priceMin, s.priceMax) ??
        validateDeliveryDays(s.deliveryDays) ??
        (s.portfolioImageUrls.isEmpty
            ? 'At least one portfolio image is required.'
            : null);
  }

  static String? validateTitle(String? v) {
    if (v == null || v.trim().isEmpty) return 'Title is required.';
    if (v.trim().length < 5) return 'Title must be at least 5 characters.';
    if (v.trim().length > 100) return 'Title must be under 100 characters.';
    return null;
  }

  static String? validateDescription(String? v) {
    if (v == null || v.trim().isEmpty) return 'Description is required.';
    if (v.trim().length < 30) {
      return 'Description must be at least 30 characters.';
    }
    if (v.trim().length > 5000) {
      return 'Description must be under 5 000 characters.';
    }
    return null;
  }

  static String? validateTags(List<String> tags) {
    if (tags.isEmpty) return 'Add at least one skill/tag.';
    if (tags.length > 20) return 'Maximum 20 tags allowed.';
    for (final t in tags) {
      if (t.trim().length > 50) {
        return 'Each tag must be under 50 characters.';
      }
    }
    return null;
  }

  /// Maximum allowed service price in RM.
  /// Keeps listings realistic and prevents test/junk data like RM 9,999,999.
  static const double maxPrice = 10000;

  static String? validatePrice(double? min, double? max) {
    if (min != null && min < 0) return 'Price cannot be negative.';
    if (max != null && max <= 0) return 'Price must be greater than RM 0.';
    if (max != null && max > maxPrice) {
      return 'Price cannot exceed RM ${maxPrice.toStringAsFixed(0)}.';
    }
    if (min != null && max != null && min > max) {
      return 'Minimum price cannot exceed the maximum price.';
    }
    return null;
  }

  /// Validates a single price form-field string (used by TextFormField).
  static String? validatePriceField(String? v, {required bool isMin}) {
    if (v == null || v.trim().isEmpty) return null; // price is optional
    final parsed = double.tryParse(v.trim());
    if (parsed == null) return 'Enter a valid number.';
    if (parsed < 0) return 'Price cannot be negative.';
    if (!isMin && parsed <= 0) return 'Price must be greater than RM 0.';
    if (!isMin && parsed > maxPrice) {
      return 'Price cannot exceed RM ${maxPrice.toStringAsFixed(0)}.';
    }
    return null;
  }

  static String? validateDeliveryDays(int? days) {
    if (days == null) return null; // optional
    if (days < 1) return 'Delivery days must be at least 1.';
    if (days > 365) return 'Delivery days cannot exceed 365.';
    return null;
  }

  static String? validateDeliveryDaysField(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    final parsed = int.tryParse(v.trim());
    if (parsed == null) return 'Enter a whole number.';
    return validateDeliveryDays(parsed);
  }
}

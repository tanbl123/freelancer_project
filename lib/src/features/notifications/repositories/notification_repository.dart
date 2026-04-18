import '../../../services/supabase_service.dart';
import '../models/in_app_notification.dart';

/// Thin data-access wrapper for [InAppNotification].
/// All factory/business logic lives in [NotificationService].
class NotificationRepository {
  const NotificationRepository(this._db);
  final SupabaseService _db;

  Future<void> insert(InAppNotification notification) =>
      _db.insertNotification(notification);

  Future<List<InAppNotification>> getForUser(
    String userId, {
    int limit = 30,
    int offset = 0,
  }) =>
      _db.getNotificationsForUser(userId, limit: limit, offset: offset);

  Future<int> unreadCount(String userId) =>
      _db.unreadNotificationCount(userId);

  Future<void> markRead(String notificationId) =>
      _db.markNotificationRead(notificationId);

  Future<void> markAllRead(String userId) =>
      _db.markAllNotificationsRead(userId);
}

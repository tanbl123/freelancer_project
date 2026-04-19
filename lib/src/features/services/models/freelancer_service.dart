import 'dart:convert';

import '../../../shared/enums/service_status.dart';

/// A service listing created by a freelancer.
///
/// Dual-serialisation: [toSupabaseWriteMap] for the cloud,
/// [toSqliteMap] for the offline SQLite cache. [fromMap] accepts both.
class FreelancerService {
  const FreelancerService({
    required this.id,
    required this.freelancerId,
    required this.freelancerName,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.tags,
    this.priceMin,
    this.priceMax,
    this.deliveryDays,
    this.portfolioImageUrls = const [],
    this.thumbnailUrl,
    this.viewCount = 0,
    this.orderCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String freelancerId;
  final String freelancerName;
  final String title;
  final String description;

  /// Service category slug (e.g. 'design'), matched against the categories table.
  final String category;
  final ServiceStatus status;

  /// Searchable skill/keyword tags (max 20).
  final List<String> tags;

  /// Optional price range (RM).
  final double? priceMin;
  final double? priceMax;

  /// Estimated delivery time in calendar days.
  final int? deliveryDays;

  /// Portfolio images uploaded by the freelancer (up to 5).
  /// Items may be local file paths (before upload) or remote HTTPS URLs.
  final List<String> portfolioImageUrls;

  /// Primary display image — defaults to the first portfolio image.
  final String? thumbnailUrl;

  /// Denormalized counters updated server-side.
  final int viewCount;
  final int orderCount;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── Computed helpers ──────────────────────────────────────────────────────

  /// True when the service is publicly visible and can be ordered.
  bool get isLive => status == ServiceStatus.active;

  /// Human-readable price, or null when no pricing is set.
  String? get priceDisplay {
    if (priceMin == null && priceMax == null) return null;
    String fmt(double v) => 'RM ${v.toStringAsFixed(0)}';
    // Both set → show range (legacy posts)
    if (priceMin != null && priceMax != null && priceMin != priceMax) {
      return '${fmt(priceMin!)} – ${fmt(priceMax!)}';
    }
    // Single value — just show the amount
    return fmt(priceMax ?? priceMin!);
  }

  /// Human-readable delivery time, or null when not specified.
  String? get deliveryDisplay {
    if (deliveryDays == null) return null;
    final d = deliveryDays!;
    if (d % 30 == 0 && d ~/ 30 <= 7) {
      final m = d ~/ 30;
      return m == 1 ? '1 month' : '$m months';
    }
    if (d % 7 == 0 && d ~/ 7 <= 7) {
      final w = d ~/ 7;
      return w == 1 ? '1 week' : '$w weeks';
    }
    return d == 1 ? '1 day' : '$d days';
  }

  /// The URL to show as the service thumbnail.
  /// Falls back to the first portfolio image if no explicit thumbnail is set.
  String get effectiveThumbnail =>
      (thumbnailUrl?.isNotEmpty == true)
          ? thumbnailUrl!
          : (portfolioImageUrls.isNotEmpty ? portfolioImageUrls.first : '');

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory FreelancerService.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic v) {
      if (v is List) return v.cast<String>();
      if (v is String && v.isNotEmpty) {
        try {
          final decoded = jsonDecode(v);
          if (decoded is List) return decoded.cast<String>();
        } catch (_) {}
      }
      return [];
    }

    DateTime? parseDate(dynamic v) {
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return FreelancerService(
      id: map['id'] as String,
      freelancerId: map['freelancer_id'] as String,
      freelancerName: map['freelancer_name'] as String? ?? '',
      title: map['title'] as String,
      description: map['description'] as String,
      category: map['category'] as String? ?? 'other',
      status:
          ServiceStatus.fromString(map['status'] as String? ?? 'inactive'),
      tags: parseList(map['tags']),
      priceMin: (map['price_min'] as num?)?.toDouble(),
      priceMax: (map['price_max'] as num?)?.toDouble(),
      deliveryDays: (map['delivery_days'] as num?)?.toInt(),
      portfolioImageUrls: parseList(map['portfolio_image_urls']),
      thumbnailUrl: map['thumbnail_url'] as String?,
      viewCount: (map['view_count'] as num?)?.toInt() ?? 0,
      orderCount: (map['order_count'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  /// Full map for reading — includes auto-managed counters.
  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'freelancer_id': freelancerId,
        'freelancer_name': freelancerName,
        'title': title,
        'description': description,
        'category': category,
        'status': status.name,
        'tags': tags,
        'price_min': priceMin,
        'price_max': priceMax,
        'delivery_days': deliveryDays,
        'portfolio_image_urls': portfolioImageUrls,
        'thumbnail_url': thumbnailUrl,
        'view_count': viewCount,
        'order_count': orderCount,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  /// Write map for INSERT / UPDATE — omits server-managed counter columns.
  Map<String, dynamic> toSupabaseWriteMap() {
    final m = Map<String, dynamic>.from(toSupabaseMap());
    m.remove('view_count');
    m.remove('order_count');
    return m;
  }

  /// SQLite-compatible map: epoch ms for dates, JSON strings for arrays.
  Map<String, dynamic> toSqliteMap() => {
        'id': id,
        'freelancer_id': freelancerId,
        'freelancer_name': freelancerName,
        'title': title,
        'description': description,
        'category': category,
        'status': status.name,
        'tags': jsonEncode(tags),
        'price_min': priceMin,
        'price_max': priceMax,
        'delivery_days': deliveryDays,
        'portfolio_image_urls': jsonEncode(portfolioImageUrls),
        'thumbnail_url': thumbnailUrl,
        'view_count': viewCount,
        'order_count': orderCount,
        'created_at': createdAt?.millisecondsSinceEpoch,
        'updated_at': updatedAt?.millisecondsSinceEpoch,
      };

  FreelancerService copyWith({
    String? id,
    String? freelancerId,
    String? freelancerName,
    String? title,
    String? description,
    String? category,
    ServiceStatus? status,
    List<String>? tags,
    double? priceMin,
    double? priceMax,
    int? deliveryDays,
    List<String>? portfolioImageUrls,
    String? thumbnailUrl,
    int? viewCount,
    int? orderCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      FreelancerService(
        id: id ?? this.id,
        freelancerId: freelancerId ?? this.freelancerId,
        freelancerName: freelancerName ?? this.freelancerName,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        status: status ?? this.status,
        tags: tags ?? this.tags,
        priceMin: priceMin ?? this.priceMin,
        priceMax: priceMax ?? this.priceMax,
        deliveryDays: deliveryDays ?? this.deliveryDays,
        portfolioImageUrls: portfolioImageUrls ?? this.portfolioImageUrls,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        viewCount: viewCount ?? this.viewCount,
        orderCount: orderCount ?? this.orderCount,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

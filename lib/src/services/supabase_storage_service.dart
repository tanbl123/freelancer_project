import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Handles uploading images to Supabase Storage and returning public URLs.
///
/// ## Bucket layout
/// ```
/// job-covers/
///   {userId}/{uuid}.jpg
///
/// service-portfolio/
///   {userId}/{uuid}.jpg
/// ```
///
/// Both buckets must be created in the Supabase dashboard as **public** buckets
/// so that `getPublicUrl()` works without authentication.
///
/// ## Error handling
/// All methods return `null` on failure (network error, permission denied, etc.)
/// so callers can fall back to a locally saved path without crashing.
class SupabaseStorageService {
  SupabaseStorageService._();
  static final SupabaseStorageService instance = SupabaseStorageService._();

  static const _uuid = Uuid();

  static const bucketJobCovers            = 'job-covers';
  static const bucketServicePortfolio     = 'service-portfolio';
  static const bucketProjectSignatures    = 'project-signatures';
  static const bucketMilestoneDeliverables = 'milestone-deliverables';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Uploads [localPath] to [bucket] under `{userId}/{uuid}.ext` and returns
  /// the public HTTPS URL, or `null` if the upload failed.
  ///
  /// [bucket] — one of [bucketJobCovers] or [bucketServicePortfolio].
  /// [userId] — used as the folder name so each user's files stay separate.
  Future<String?> uploadImage({
    required String localPath,
    required String bucket,
    required String userId,
  }) async {
    try {
      final file = File(localPath);
      if (!file.existsSync()) return null;

      final bytes = await file.readAsBytes();
      final ext   = p.extension(localPath).toLowerCase().replaceFirst('.', '');
      final mime  = _mimeForExt(ext);
      final remoteName = '${_uuid.v4()}.$ext';
      final remotePath = '$userId/$remoteName';

      await Supabase.instance.client.storage
          .from(bucket)
          .uploadBinary(
            remotePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mime,
              upsert: true,
            ),
          );

      return Supabase.instance.client.storage
          .from(bucket)
          .getPublicUrl(remotePath);
    } catch (_) {
      return null;
    }
  }

  /// Uploads a signature PNG (raw bytes) to the `project-signatures` bucket.
  ///
  /// ## Path layout
  /// ```
  /// project-signatures/{projectId}/{userId}.png
  /// ```
  /// One canonical file per project per user — re-signing overwrites the old
  /// file (`upsert: true`).
  ///
  /// Returns the public HTTPS URL on success, or `null` if the upload fails
  /// (e.g. device offline, permission denied).  The caller should fall back to
  /// the locally-saved file path when `null` is returned.
  Future<String?> uploadSignaturePng({
    required Uint8List bytes,
    required String projectId,
    required String userId,
  }) async {
    try {
      final remotePath = '$projectId/$userId.png';
      await Supabase.instance.client.storage
          .from(bucketProjectSignatures)
          .uploadBinary(
            remotePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );
      return Supabase.instance.client.storage
          .from(bucketProjectSignatures)
          .getPublicUrl(remotePath);
    } catch (_) {
      return null;
    }
  }

  /// Uploads any file (PDF, docx, zip, image, etc.) as a milestone deliverable.
  ///
  /// Stored under `milestone-deliverables/{userId}/{milestoneId}/{uuid}.ext`.
  /// Returns the public HTTPS URL, or `null` if the upload failed.
  Future<String?> uploadDeliverableFile({
    required String localPath,
    required String userId,
    required String milestoneId,
  }) async {
    try {
      final file = File(localPath);
      if (!file.existsSync()) return null;

      final bytes = await file.readAsBytes();
      final ext = p.extension(localPath).toLowerCase().replaceFirst('.', '');
      final mime = _mimeForFile(ext);
      final remoteName = '${_uuid.v4()}${ext.isNotEmpty ? '.$ext' : ''}';
      final remotePath = '$userId/$milestoneId/$remoteName';

      await Supabase.instance.client.storage
          .from(bucketMilestoneDeliverables)
          .uploadBinary(
            remotePath,
            bytes,
            fileOptions: FileOptions(contentType: mime, upsert: true),
          );

      return Supabase.instance.client.storage
          .from(bucketMilestoneDeliverables)
          .getPublicUrl(remotePath);
    } catch (_) {
      return null;
    }
  }

  /// Deletes a previously-uploaded file given its full public [url].
  ///
  /// Silently swallows errors — deletion is best-effort.
  Future<void> deleteByUrl({
    required String url,
    required String bucket,
  }) async {
    try {
      // Extract the storage path from the public URL.
      // URL format: https://{project}.supabase.co/storage/v1/object/public/{bucket}/{path}
      final marker = '/object/public/$bucket/';
      final idx = url.indexOf(marker);
      if (idx < 0) return;
      final remotePath = Uri.decodeComponent(url.substring(idx + marker.length));
      await Supabase.instance.client.storage
          .from(bucket)
          .remove([remotePath]);
    } catch (_) {
      // Ignore — non-critical cleanup.
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _mimeForExt(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  static String _mimeForFile(String ext) {
    switch (ext) {
      case 'pdf':  return 'application/pdf';
      case 'doc':  return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':  return 'application/vnd.ms-excel';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':  return 'application/vnd.ms-powerpoint';
      case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'zip':  return 'application/zip';
      case 'rar':  return 'application/x-rar-compressed';
      case 'txt':  return 'text/plain';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'gif':  return 'image/gif';
      case 'webp': return 'image/webp';
      case 'mp4':  return 'video/mp4';
      case 'mov':  return 'video/quicktime';
      default:     return 'application/octet-stream';
    }
  }
}

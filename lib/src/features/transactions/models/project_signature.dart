/// Carries the result of a client's digital sign-off on a completed project.
///
/// Created inside [SignaturePadPage] after the user confirms their signature.
/// Not persisted as a separate DB row — its data is stored in two places:
///
/// - [storageUrl] → written to `projects.client_signature_url` by [AppState.completeProject].
/// - [localPath]  → kept on-device so the signature image can be displayed
///   offline on the signer's handset without hitting the network.
///
/// ## URL priority
/// If the upload to Supabase Storage succeeded, [remoteUrl] is non-null and
/// [storageUrl] returns the public HTTPS link (the canonical reference).
/// If the device was offline at sign-time, [remoteUrl] is null and [storageUrl]
/// falls back to [localPath].  Either value can be stored safely — the remote
/// URL is stable; the local path only works on the signer's device but still
/// satisfies the "signature captured" constraint for the completion flow.
class ProjectSignature {
  const ProjectSignature({
    required this.projectId,
    required this.signedBy,
    required this.signedByName,
    required this.localPath,
    required this.signedAt,
    this.remoteUrl,
  });

  /// The project this signature is attached to.
  final String projectId;

  /// UID of the client who signed (must match `projects.client_id`).
  final String signedBy;

  /// Display name of the signer — included in the on-screen legal panel and
  /// useful for audit log purposes.
  final String signedByName;

  /// Absolute path to the locally-saved PNG file on this device.
  /// Always present; never null.
  final String localPath;

  /// Supabase Storage public URL (`project-signatures/{projectId}/{userId}.png`).
  /// Null when the upload failed or the device was offline.
  final String? remoteUrl;

  /// Timestamp of when the user tapped "Confirm Signature".
  final DateTime signedAt;

  // ── Derived ─────────────────────────────────────────────────────────────────

  /// The URL to store in `projects.client_signature_url`.
  ///
  /// Prefers the remote public URL so that any party to the project can load
  /// the image via HTTPS.  Falls back to [localPath] only when the upload
  /// failed — in that case the DB value is still non-empty, which satisfies the
  /// "signature required" guard, but the image will only render on the signer's
  /// device.
  String get storageUrl => remoteUrl ?? localPath;

  /// Whether a permanent cloud copy of the signature was successfully made.
  bool get hasRemoteBackup => remoteUrl != null;

  @override
  String toString() => 'ProjectSignature('
      'project=$projectId, '
      'signedBy=$signedByName, '
      'at=$signedAt, '
      'remote=$hasRemoteBackup)';
}

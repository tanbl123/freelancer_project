import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';

import '../../../services/file_storage_service.dart';
import '../../../services/supabase_storage_service.dart';
import '../../../state/app_state.dart';

// ── Upload config ─────────────────────────────────────────────────────────────

/// Instructs [SignaturePadPage] to upload the captured PNG to Supabase Storage
/// after the user confirms their signature.
///
/// When an [SignatureUploadConfig] is provided:
/// - The page calls [SupabaseStorageService.uploadSignaturePng] on confirm.
/// - On success, [Navigator.pop] is called with the **remote public URL**.
/// - On failure (offline, permission error), it falls back gracefully and
///   pops with the **local file path** instead — completion can still proceed.
///
/// When no config is provided (milestone approvals, previews):
/// - The page behaves as before: saves locally and pops with the local path.
class SignatureUploadConfig {
  const SignatureUploadConfig({
    required this.projectId,
    required this.userId,
  });

  /// Used as the first path segment: `project-signatures/{projectId}/...`
  final String projectId;

  /// Used as the file name: `.../{userId}.png`
  final String userId;
}

// ── Widget ────────────────────────────────────────────────────────────────────

/// Collects a freehand digital signature through a **two-phase flow**:
///
/// ## Phase 1 — Draw
/// A blank white canvas. The user signs with their finger or stylus.
/// An AppBar action lets them clear and start over.
/// Tapping **"Preview →"** renders the stroke to a PNG and advances to
/// phase 2.
///
/// ## Phase 2 — Review & Confirm
/// Displays the captured signature image in a bordered panel.
/// Below it a **legal declaration** names the signer and timestamps the act.
/// The user can tap **"Sign Again"** (back-arrow) to return to the canvas, or
/// **"Confirm Signature"** to finalise.
///
/// ## Return value
/// [Navigator.pop] is called with a `String`:
/// - **Remote public URL** — when [uploadConfig] is provided and the upload
///   succeeds.
/// - **Local file path** — when [uploadConfig] is not provided, or the upload
///   fails (offline fallback).
///
/// Returns `null` if the user cancels.
class SignaturePadPage extends StatefulWidget {
  const SignaturePadPage({
    super.key,
    required this.contextId,
    this.promptText,
    this.legalText,
    this.confirmLabel,
    this.uploadConfig,
  });

  /// Filename stem for the locally-saved PNG (e.g. `'project_<id>'`).
  final String contextId;

  /// Short instructional line shown above the canvas in phase 1.
  /// Defaults to a generic milestone-approval message.
  final String? promptText;

  /// Legal declaration shown in the phase-2 review panel.
  /// Defaults to a generic acceptance statement.
  final String? legalText;

  /// Label on the final confirm button.  Defaults to `'Confirm Signature'`.
  final String? confirmLabel;

  /// When non-null, the PNG is uploaded to Supabase Storage on confirm and
  /// the remote URL is returned instead of the local path.
  final SignatureUploadConfig? uploadConfig;

  @override
  State<SignaturePadPage> createState() => _SignaturePadPageState();
}

// ── Phase enum ────────────────────────────────────────────────────────────────

enum _Phase { draw, preview }

// ── State ─────────────────────────────────────────────────────────────────────

class _SignaturePadPageState extends State<SignaturePadPage> {
  final SignatureController _ctrl = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  _Phase _phase = _Phase.draw;

  /// PNG bytes captured at the end of phase 1.  Non-null during phase 2.
  Uint8List? _capturedBytes;

  /// True while saving/uploading after the user taps Confirm.
  bool _isSaving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Phase transitions ─────────────────────────────────────────────────────

  Future<void> _advanceToPreview() async {
    if (_ctrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw your signature first.')),
      );
      return;
    }
    final bytes = await _ctrl.toPngBytes();
    if (bytes == null || !mounted) return;
    setState(() {
      _capturedBytes = bytes;
      _phase = _Phase.preview;
    });
  }

  void _backToDraw() {
    setState(() {
      _capturedBytes = null;
      _phase = _Phase.draw;
      _ctrl.clear();
    });
  }

  // ── Confirm ───────────────────────────────────────────────────────────────

  Future<void> _confirmSignature() async {
    final bytes = _capturedBytes;
    if (bytes == null) return;

    setState(() => _isSaving = true);

    // 1. Always save a local copy first — offline fallback + fast display.
    final localPath = await FileStorageService.instance
        .saveSignaturePng(bytes, widget.contextId);

    // 2. Optionally upload to Supabase Storage.
    String resultUrl = localPath;
    final cfg = widget.uploadConfig;
    if (cfg != null) {
      final remote = await SupabaseStorageService.instance.uploadSignaturePng(
        bytes: bytes,
        projectId: cfg.projectId,
        userId: cfg.userId,
      );
      // remote is null on failure — silently fall back to local path.
      if (remote != null) resultUrl = remote;
    }

    if (mounted) Navigator.pop(context, resultUrl);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Signature'),
        leading: _phase == _Phase.preview
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Sign again',
                onPressed: _isSaving ? null : _backToDraw,
              )
            : null, // default back button for draw phase
        actions: [
          if (_phase == _Phase.draw)
            TextButton(
              onPressed: _ctrl.clear,
              child: const Text('Clear'),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _phase == _Phase.draw
            ? _DrawPhase(
                key: const ValueKey('draw'),
                controller: _ctrl,
                promptText: widget.promptText,
                onNext: _advanceToPreview,
              )
            : _PreviewPhase(
                key: const ValueKey('preview'),
                bytes: _capturedBytes!,
                legalText: widget.legalText,
                confirmLabel: widget.confirmLabel ?? 'Confirm Signature',
                isSaving: _isSaving,
                onConfirm: _confirmSignature,
              ),
      ),
    );
  }
}

// ── Phase 1: Draw ─────────────────────────────────────────────────────────────

class _DrawPhase extends StatelessWidget {
  const _DrawPhase({
    super.key,
    required this.controller,
    required this.promptText,
    required this.onNext,
  });

  final SignatureController controller;
  final String? promptText;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Instruction ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(
            promptText ??
                'Sign below to approve this milestone and release payment.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
        ),

        // ── Canvas ───────────────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: Colors.grey.shade300, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Signature(
                        controller: controller,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Sign-here guide
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(Icons.edit, size: 13, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        'Draw your signature above',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Next button ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Preview Signature',
                  style: TextStyle(fontSize: 16)),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: onNext,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Phase 2: Preview + Legal confirmation ─────────────────────────────────────

class _PreviewPhase extends StatelessWidget {
  const _PreviewPhase({
    super.key,
    required this.bytes,
    required this.legalText,
    required this.confirmLabel,
    required this.isSaving,
    required this.onConfirm,
  });

  final Uint8List bytes;
  final String? legalText;
  final String confirmLabel;
  final bool isSaving;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final signerName =
        AppState.instance.currentUser?.displayName ?? 'Unknown';
    final now = DateTime.now();
    final dateStr = DateFormat('d MMMM yyyy, HH:mm').format(now);

    final effectiveLegal = legalText ??
        'I confirm that I have reviewed and accepted the terms of this '
            'agreement and authorise completion of the above milestone.';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Heading ────────────────────────────────────────────────────────
          Text(
            'Review Your Signature',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Confirm below to permanently record your digital signature.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          // ── Captured signature image ───────────────────────────────────────
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(12),
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 20),

          // ── Legal declaration ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.gavel_rounded,
                        size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      'Legal Declaration',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  effectiveLegal,
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      height: 1.5),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                // Signer info row
                _InfoRow(label: 'Signed by', value: signerName),
                const SizedBox(height: 4),
                _InfoRow(label: 'Date & Time', value: dateStr),
                const SizedBox(height: 4),
                _InfoRow(
                    label: 'Method', value: 'Electronic — freehand on device'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Confirm button ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: isSaving ? null : onConfirm,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                isSaving ? 'Saving…' : confirmLabel,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),

          // ── Sign again hint ───────────────────────────────────────────────
          if (!isSaving)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Text(
                  'Tap ← in the top-left to sign again.',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style:
                TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

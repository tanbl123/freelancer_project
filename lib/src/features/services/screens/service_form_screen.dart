import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../services/file_storage_service.dart';
import '../../../services/supabase_storage_service.dart';
import '../../../shared/enums/service_status.dart';
import '../../../shared/widgets/camera_picker_screen.dart';
import '../../../state/app_state.dart';
import '../models/freelancer_service.dart';
import '../services/freelancer_service_service.dart';

/// Create-or-edit form for a [FreelancerService].
///
/// Pass [existing] to enter edit mode; leave null to create a new listing.
/// Freelancers only — enforced by [AccessGuard.canCreateService] inside
/// [FreelancerServiceService].
class ServiceFormScreen extends StatefulWidget {
  const ServiceFormScreen({super.key, this.existing});
  final FreelancerService? existing;

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  static const _uuid = Uuid();
  static const _maxPortfolioImages = 5; // "portfolio" kept as internal name; UI shows "Service Images"

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _tagInput = TextEditingController();

  String? _category;          // null = not yet selected
  final _deliveryAmountController = TextEditingController(text: '1');
  String _deliveryUnit = 'Days';
  bool _isLoading = false;
  String? _tagsError;         // inline error for the tags section
  String? _imagesError;       // inline error for the images section

  static const _deliveryUnits = ['Days', 'Weeks', 'Months'];

  /// Max amount per unit: Days→365, Weeks→52, Months→12.
  static int _maxForUnit(String unit) => switch (unit) {
    'Weeks'  => 52,
    'Months' => 12,
    _        => 365,
  };

  /// Max digits per unit: Days→3, Weeks/Months→2.
  static int _maxDigitsForUnit(String unit) => unit == 'Days' ? 3 : 2;

  /// Mix of local file paths (new picks) and remote HTTPS URLs (existing).
  final List<String> _portfolioImages = [];
  final List<String> _tags = [];

  // ── Unsaved-changes detection ─────────────────────────────────────────────
  late String _origTitle;
  late String _origDesc;
  late String _origPrice;
  late String? _origCategory;
  late List<String> _origTags;
  late List<String> _origImages;
  late String _origDeliveryValue;
  late String _origDeliveryUnit;

  bool get _hasChanges =>
      _titleController.text.trim() != _origTitle ||
      _descController.text.trim() != _origDesc ||
      _priceController.text.trim() != _origPrice ||
      _category != _origCategory ||
      !_listEq(_tags, _origTags) ||
      !_listEq(_portfolioImages, _origImages) ||
      _deliveryAmountController.text.trim() != _origDeliveryValue ||
      _deliveryUnit != _origDeliveryUnit;

  static bool _listEq(List<String> a, List<String> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((v) => v);

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    if (s != null) {
      _titleController.text = s.title;
      _descController.text = s.description;
      _category = s.category; // pre-fill from existing
      _tags.addAll(s.tags);
      _portfolioImages.addAll(s.portfolioImageUrls);
      // Load single price — prefer priceMax, fall back to priceMin
      final price = s.priceMax ?? s.priceMin;
      if (price != null) {
        _priceController.text = price.toStringAsFixed(0);
      }
      // Restore delivery: convert days back to amount+unit
      if (s.deliveryDays != null) {
        final days = s.deliveryDays!;
        if (days % 30 == 0) {
          _deliveryAmountController.text = (days ~/ 30).toString();
          _deliveryUnit = 'Months';
        } else if (days % 7 == 0) {
          _deliveryAmountController.text = (days ~/ 7).toString();
          _deliveryUnit = 'Weeks';
        } else {
          _deliveryAmountController.text = days.toString();
          _deliveryUnit = 'Days';
        }
      }
    }
    // Capture initial state after loading existing data.
    _origTitle         = _titleController.text.trim();
    _origDesc          = _descController.text.trim();
    _origPrice         = _priceController.text.trim();
    _origCategory      = _category;
    _origTags          = List.from(_tags);
    _origImages        = List.from(_portfolioImages);
    _origDeliveryValue = _deliveryAmountController.text.trim();
    _origDeliveryUnit  = _deliveryUnit;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _tagInput.dispose();
    _deliveryAmountController.dispose();
    super.dispose();
  }

  // ── Portfolio image handling ───────────────────────────────────────────────

  Future<void> _addPortfolioImage(ImageSource source) async {
    if (_portfolioImages.length >= _maxPortfolioImages) return;

    String? localPath;

    if (source == ImageSource.camera) {
      // Full in-app camera with live preview + retake.
      localPath = await CameraPickerScreen.open(context);
    } else {
      final xfile = await ImagePicker()
          .pickImage(source: source, maxWidth: 1200, imageQuality: 85);
      if (xfile == null) return;
      localPath = await FileStorageService.instance
          .saveImage(xfile, 'service_portfolio');
    }

    if (localPath == null || !mounted) return;

    // Upload to Supabase Storage; fall back to local path if upload fails.
    final userId = AppState.instance.currentUser?.uid;
    final remoteUrl = userId != null
        ? await SupabaseStorageService.instance.uploadImage(
            localPath: localPath,
            bucket: SupabaseStorageService.bucketServicePortfolio,
            userId: userId,
          )
        : null;

    setState(() {
      _portfolioImages.add(remoteUrl ?? localPath!);
      _imagesError = null; // clear error once first image is added
    });
  }

  void _removePortfolioImage(int index) {
    setState(() => _portfolioImages.removeAt(index));
  }

  // ── Tags ──────────────────────────────────────────────────────────────────

  void _addTag() {
    final tag = _tagInput.text.trim();
    if (tag.isEmpty) return;
    if (_tags.contains(tag)) {
      _tagInput.clear();
      return;
    }
    if (_tags.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 20 tags allowed.')));
      return;
    }
    setState(() {
      _tags.add(tag);
      _tagInput.clear();
      _tagsError = null; // clear error once user adds a tag
    });
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    // Validate non-form fields inline before running the form validator
    setState(() {
      _tagsError = _tags.isEmpty ? 'Add at least one skill or tag.' : null;
      _imagesError = _portfolioImages.isEmpty
          ? 'At least one service image is required.'
          : null;
    });

    if (!_formKey.currentState!.validate() ||
        _tags.isEmpty ||
        _portfolioImages.isEmpty) return;

    final price = double.tryParse(_priceController.text.trim());
    final budgetErr = FreelancerServiceService.validatePrice(null, price);
    if (budgetErr != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(budgetErr)));
      return;
    }

    // Convert amount+unit to total days
    final deliveryAmount =
        int.tryParse(_deliveryAmountController.text.trim()) ?? 1;
    final deliveryDays = switch (_deliveryUnit) {
      'Weeks'  => deliveryAmount * 7,
      'Months' => deliveryAmount * 30,
      _        => deliveryAmount,
    };

    final user = AppState.instance.currentUser!;
    final now = DateTime.now();
    final service = FreelancerService(
      id: _isEdit ? widget.existing!.id : _uuid.v4(),
      freelancerId: user.uid,
      freelancerName: user.displayName,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _category!,
      status: _isEdit
          ? widget.existing!.status
          : ServiceStatus.active,
      tags: List.from(_tags),
      priceMin: null,
      priceMax: price,
      deliveryDays: deliveryDays,
      portfolioImageUrls: List.from(_portfolioImages),
      // First portfolio image is the thumbnail.
      thumbnailUrl:
          _portfolioImages.isNotEmpty ? _portfolioImages.first : null,
      viewCount: _isEdit ? widget.existing!.viewCount : 0,
      orderCount: _isEdit ? widget.existing!.orderCount : 0,
      createdAt: _isEdit ? widget.existing!.createdAt : now,
      updatedAt: now,
    );

    setState(() => _isLoading = true);
    final error = _isEdit
        ? await AppState.instance.editService(service)
        : await AppState.instance.createService(service);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit
              ? 'Service updated!'
              : 'Service listed successfully!')));
      Navigator.pop(context);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!_hasChanges) { Navigator.pop(context); return; }
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text(
                'You have unsaved changes. If you leave now, they will be lost.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep Editing')),
              FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Discard')),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Service' : 'New Service'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Portfolio images ─────────────────────────────────────
              _PortfolioSection(
                images: _portfolioImages,
                maxImages: _maxPortfolioImages,
                onAdd: _addPortfolioImage,
                onRemove: _removePortfolioImage,
                errorText: _imagesError,
              ),
              const SizedBox(height: 20),

              // ── Title ────────────────────────────────────────────────
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Service Title *',
                  hintText: 'e.g. Professional Logo Design',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                maxLength: 100,
                textInputAction: TextInputAction.next,
                validator: FreelancerServiceService.validateTitle,
              ),
              const SizedBox(height: 16),

              // ── Description ──────────────────────────────────────────
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText:
                      'Describe what you offer, your process, and '
                      'what the client will receive. At least 30 characters.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                maxLength: 5000,
                textInputAction: TextInputAction.newline,
                validator: FreelancerServiceService.validateDescription,
              ),
              const SizedBox(height: 16),

              // ── Category ─────────────────────────────────────────────
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                hint: const Text('Select a category'),
                items: AppState.instance.categories
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.displayName),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
                validator: (v) =>
                    v == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 16),

              // ── Tags ─────────────────────────────────────────────────
              _TagsInput(
                tags: _tags,
                controller: _tagInput,
                onAdd: _addTag,
                onRemove: (t) => setState(() => _tags.remove(t)),
                errorText: _tagsError,
              ),
              const SizedBox(height: 16),

              // ── Price (single field) ─────────────────────────────────
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (RM) *',
                  border: OutlineInputBorder(),
                  prefixText: 'RM ',
                  helperText: 'Min RM 1 · Max RM 10,000',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Price is required.';
                  }
                  return FreelancerServiceService.validatePriceField(
                      v, isMin: false);
                },
              ),
              const SizedBox(height: 16),

              // ── Delivery time (amount + unit dropdowns) ──────────────
              const Text('Delivery Time *',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount — free-text, digit-limited per unit
                  Expanded(
                    child: TextFormField(
                      controller: _deliveryAmountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(
                            _maxDigitsForUnit(_deliveryUnit)),
                      ],
                      validator: (v) {
                        final n = int.tryParse(v?.trim() ?? '');
                        if (n == null || n <= 0) return 'Enter a number';
                        final max = _maxForUnit(_deliveryUnit);
                        if (n > max) return 'Max $max ${_deliveryUnit.toLowerCase()}';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Unit dropdown (Days / Weeks / Months)
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _deliveryUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: _deliveryUnits
                          .map((u) => DropdownMenuItem(
                              value: u, child: Text(u)))
                          .toList(),
                      onChanged: (u) {
                        if (u != null) setState(() => _deliveryUnit = u);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Submit ───────────────────────────────────────────────
              FilledButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: Text(
                  _isLoading
                      ? (_isEdit ? 'Saving…' : 'Publishing…')
                      : (_isEdit ? 'Save Changes' : 'Publish Service'),
                ),
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ],
          ),
        ),
      ),
      ), // Scaffold
    ); // PopScope
  }
}

// ── Portfolio section ──────────────────────────────────────────────────────

class _PortfolioSection extends StatelessWidget {
  const _PortfolioSection({
    required this.images,
    required this.maxImages,
    required this.onAdd,
    required this.onRemove,
    this.errorText,
  });

  final List<String> images;
  final int maxImages;
  final void Function(ImageSource) onAdd;
  final void Function(int) onRemove;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Service Images *',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Text(
              '(${images.length}/$maxImages)',
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Add up to $maxImages images showing what you deliver '
          '(samples, mockups, examples). First image becomes the thumbnail.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount:
              images.length + (images.length < maxImages ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i == images.length) {
              return _AddImageCell(onAdd: onAdd);
            }
            return _ImageCell(
              path: images[i],
              isThumbnail: i == 0,
              onRemove: () => onRemove(i),
            );
          },
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _ImageCell extends StatelessWidget {
  const _ImageCell({
    required this.path,
    required this.isThumbnail,
    required this.onRemove,
  });
  final String path;
  final bool isThumbnail;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isRemote = path.startsWith('http');
    final isLocal =
        path.isNotEmpty && !isRemote && File(path).existsSync();

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: isRemote
              ? Image.network(path,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const _ImageErrorPlaceholder())
              : isLocal
                  ? Image.file(File(path), fit: BoxFit.cover)
                  : const _ImageErrorPlaceholder(),
        ),
        // Thumbnail star badge
        if (isThumbnail)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.white, size: 10),
                  SizedBox(width: 2),
                  Text('Cover',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        // Remove button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.close,
                  color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _ImageErrorPlaceholder extends StatelessWidget {
  const _ImageErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.broken_image_outlined,
          color: Colors.grey, size: 32),
    );
  }
}

/// The "Add Photo" cell at the end of the grid.
class _AddImageCell extends StatelessWidget {
  const _AddImageCell({required this.onAdd});
  final void Function(ImageSource) onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSourceSheet(context),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
              color: Colors.grey.shade300,
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade50,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: Colors.grey.shade500, size: 28),
            const SizedBox(height: 4),
            Text(
              'Add Photo',
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  void _showSourceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Camera ───────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              subtitle: const Text('Capture a new photo'),
              onTap: () {
                Navigator.pop(ctx);
                onAdd(ImageSource.camera);
              },
            ),
            // ── Gallery ──────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              subtitle: const Text('Choose from your photos'),
              onTap: () {
                Navigator.pop(ctx);
                onAdd(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Tags input widget ──────────────────────────────────────────────────────

class _TagsInput extends StatelessWidget {
  const _TagsInput({
    required this.tags,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
    this.errorText,
  });
  final List<String> tags;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final void Function(String) onRemove;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.label_outline, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Skills & Tags *  (${tags.length}/20)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags
                    .map((t) => Chip(
                          label: Text(t),
                          onDeleted: () => onRemove(t),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Figma, UI Design…',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onAdd(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  onPressed: onAdd,
                  tooltip: 'Add tag',
                ),
              ],
            ),
            if (errorText != null) ...[
              const SizedBox(height: 6),
              Text(
                errorText!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

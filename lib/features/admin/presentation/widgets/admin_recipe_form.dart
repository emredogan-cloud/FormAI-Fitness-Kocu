import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/app_logger.dart';

/// Phase 50B · admin form for authoring a `recipes` row.
///
/// Mandatory fields lifted from `docs/CONTENT_OPS.md`:
///   `title`, `meal_type`, `calories`, `protein`, `carbs`, `fat`,
///   `image_url`, `tags`. Plus two optional fields the existing seed
///   scripts already populate (`prep_time_minutes`, `instructions`).
///
/// On submit:
///   1. Validates with the standard [Form] / [TextFormField] machinery.
///   2. Uploads the picked image bytes to the Supabase Storage bucket
///      `recipes_images` and resolves the public URL.
///   3. Inserts a row into `public.recipes` with that URL + parsed tags.
///   4. Fires a success haptic + SnackBar and clears the form.
///
/// Failure paths (validation, missing image, upload error, insert error)
/// surface red SnackBars instead of throwing so the admin doesn't lose
/// their work-in-progress.
class AdminRecipeForm extends ConsumerStatefulWidget {
  const AdminRecipeForm({super.key});

  @override
  ConsumerState<AdminRecipeForm> createState() => _AdminRecipeFormState();
}

/// Maps the human-readable Turkish label shown in the dropdown to the
/// `meal_type` enum value the rest of the app + Supabase RLS expects.
const Map<String, String> _mealTypeOptions = {
  'breakfast': 'Kahvaltı',
  'lunch': 'Öğle',
  'dinner': 'Akşam',
  'snack': 'Atıştırmalık',
  'main': 'Ana Yemek',
};

/// Bucket the picked image is uploaded to. Must exist in the Supabase
/// project — if it doesn't, the upload will 404 with a "Bucket not found"
/// error and the SnackBar surfaces the message verbatim. The PM is
/// responsible for creating it from Supabase Studio:
///   Storage → New bucket → name=`recipes_images`, public=true.
const String _recipesImagesBucket = 'recipes_images';

class _AdminRecipeFormState extends ConsumerState<AdminRecipeForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _tagsController = TextEditingController();
  final _instructionsController = TextEditingController();

  String _mealType = 'main';
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _prepTimeController.dispose();
    _tagsController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Phase 50D · responsive padding. The desktop layout (40 px all
    // round) bleeds half a phone screen of whitespace at 360 px wide;
    // tightening to 20 × 24 keeps the form usable on the same hamburger-
    // drawered admin shell that the dashboard switches to under 600 px.
    final isMobile = MediaQuery.of(context).size.width < 600;
    final padding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 20, vertical: 24)
        : const EdgeInsets.all(40);

    return SingleChildScrollView(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tarif Yönetimi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 22 : 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Yeni bir tarif ekle. Zorunlu alanlar yıldız (*) ile '
                  'işaretlenmiştir. Görseller `recipes_images` Storage '
                  'bucket\'ına yüklenir.',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 28),
                _Section(
                  title: 'Temel Bilgiler',
                  children: [
                    _AdminTextField(
                      label: 'Başlık *',
                      hint: 'Örn. Izgara Tavuk ve Kinoa Kasesi',
                      controller: _titleController,
                      validator: _requiredText,
                    ),
                    const SizedBox(height: 14),
                    _MealTypeDropdown(
                      value: _mealType,
                      onChanged: (v) {
                        if (v != null) setState(() => _mealType = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _Section(
                  title: 'Makro Değerler (porsiyon başı)',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _AdminTextField(
                            label: 'Kalori (kcal) *',
                            hint: '520',
                            controller: _caloriesController,
                            keyboardType: TextInputType.number,
                            validator: _requiredInt,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _AdminTextField(
                            label: 'Protein (g) *',
                            hint: '52',
                            controller: _proteinController,
                            keyboardType: TextInputType.number,
                            validator: _requiredInt,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _AdminTextField(
                            label: 'Karbonhidrat (g) *',
                            hint: '35',
                            controller: _carbsController,
                            keyboardType: TextInputType.number,
                            validator: _requiredInt,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _AdminTextField(
                            label: 'Yağ (g) *',
                            hint: '18',
                            controller: _fatController,
                            keyboardType: TextInputType.number,
                            validator: _requiredInt,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _AdminTextField(
                      label: 'Hazırlık Süresi (dk)',
                      hint: '25',
                      controller: _prepTimeController,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _Section(
                  title: 'Etiketler & Talimatlar',
                  children: [
                    _AdminTextField(
                      label: 'Etiketler (virgülle ayır) *',
                      hint: 'Yüksek Protein, Hacim',
                      controller: _tagsController,
                      validator: (value) {
                        final tags = _parseTags(value);
                        if (tags.isEmpty) {
                          return 'En az bir etiket girilmelidir.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _AdminTextField(
                      label: 'Talimatlar',
                      hint: 'MALZEMELER:\n- 180g tavuk göğsü\n...',
                      controller: _instructionsController,
                      maxLines: 6,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _Section(
                  title: 'Görsel *',
                  children: [
                    _ImagePickerTile(
                      bytes: _pickedImageBytes,
                      fileName: _pickedImageName,
                      onPick: _pickImage,
                      onClear: _pickedImageBytes == null
                          ? null
                          : () => setState(() {
                                _pickedImageBytes = null;
                                _pickedImageName = null;
                              }),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : _resetForm,
                      child: const Text(
                        'Temizle',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload, size: 18),
                      label: Text(_isSubmitting ? 'Yükleniyor…' : 'Kaydet'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.neon,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
      );
      if (picked == null) return;
      // `XFile.readAsBytes` works on every platform image_picker
      // supports, including web — it reads the underlying blob into
      // a `Uint8List` that we hand to Supabase.uploadBinary later.
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageName = picked.name;
      });
    } catch (e, st) {
      AppLogger.error(
        'admin recipe form: image pick failed',
        e,
        stackTrace: st,
        category: 'admin',
      );
      _showError('Görsel seçilirken bir hata oluştu: $e');
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showError('Lütfen zorunlu alanları doldur.');
      return;
    }
    if (_pickedImageBytes == null) {
      _showError('Görsel seçilmesi zorunludur.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final supabase = Supabase.instance.client;
      final imageUrl =
          await _uploadImage(supabase, _pickedImageBytes!, _pickedImageName);
      await supabase.from('recipes').insert({
        'title': _titleController.text.trim(),
        'meal_type': _mealType,
        'calories': int.parse(_caloriesController.text.trim()),
        'protein': int.parse(_proteinController.text.trim()),
        'carbs': int.parse(_carbsController.text.trim()),
        'fat': int.parse(_fatController.text.trim()),
        'prep_time_minutes': _parseOptionalInt(_prepTimeController.text),
        'image_url': imageUrl,
        'instructions': _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
        'tags': _parseTags(_tagsController.text),
      });

      if (!mounted) return;
      AppHaptics.selectionClick();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tarif başarıyla kaydedildi.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      _resetForm();
    } on StorageException catch (e, st) {
      AppLogger.error(
        'admin recipe form: storage upload failed',
        e,
        stackTrace: st,
        category: 'admin',
      );
      _showError(
        'Görsel yüklenemedi: ${e.message}. '
        '`$_recipesImagesBucket` bucket\'ının var olduğundan emin ol.',
      );
    } on PostgrestException catch (e, st) {
      AppLogger.error(
        'admin recipe form: db insert failed',
        e,
        stackTrace: st,
        category: 'admin',
      );
      _showError('Tarif kaydedilemedi: ${e.message}');
    } catch (e, st) {
      AppLogger.error(
        'admin recipe form: unexpected error',
        e,
        stackTrace: st,
        category: 'admin',
      );
      _showError('Beklenmeyen bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Uploads the picked bytes to the [_recipesImagesBucket] bucket and
  /// returns the canonical public URL. The filename is keyed on
  /// `<timestamp>_<slug>` so two admins authoring at the same time can't
  /// collide; Supabase Storage names are globally unique within a bucket.
  Future<String> _uploadImage(
    SupabaseClient supabase,
    Uint8List bytes,
    String? originalName,
  ) async {
    final extension = _extractExtension(originalName) ?? 'webp';
    final slug = _slugify(_titleController.text);
    final filename =
        '${DateTime.now().millisecondsSinceEpoch}_$slug.$extension';
    await supabase.storage.from(_recipesImagesBucket).uploadBinary(
          filename,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFor(extension),
            upsert: false,
          ),
        );
    return supabase.storage.from(_recipesImagesBucket).getPublicUrl(filename);
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _caloriesController.clear();
    _proteinController.clear();
    _carbsController.clear();
    _fatController.clear();
    _prepTimeController.clear();
    _tagsController.clear();
    _instructionsController.clear();
    setState(() {
      _mealType = 'main';
      _pickedImageBytes = null;
      _pickedImageName = null;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.danger, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  static String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bu alan zorunludur.';
    }
    return null;
  }

  static String? _requiredInt(String? value) {
    final empty = _requiredText(value);
    if (empty != null) return empty;
    final parsed = int.tryParse(value!.trim());
    if (parsed == null || parsed < 0) {
      return 'Pozitif bir tam sayı gir.';
    }
    return null;
  }

  static int? _parseOptionalInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  static List<String> _parseTags(String? value) {
    if (value == null) return const [];
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  static String _slugify(String input) {
    final base = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9ğüşıöç]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (base.isEmpty) return 'recipe';
    return base.length > 40 ? base.substring(0, 40) : base;
  }

  static String? _extractExtension(String? name) {
    if (name == null) return null;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase();
  }

  static String _contentTypeFor(String extension) {
    switch (extension) {
      case 'webp':
        return 'image/webp';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _AdminTextField extends StatelessWidget {
  const _AdminTextField({
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String label;
  final String? hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            filled: true,
            fillColor: AppColors.darkBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.surfaceBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.surfaceBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.neon, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _MealTypeDropdown extends StatelessWidget {
  const _MealTypeDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Öğün Tipi *',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: AppColors.surface,
          iconEnabledColor: Colors.white70,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: _mealTypeOptions.entries
              .map(
                (entry) => DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.darkBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.surfaceBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.surfaceBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.neon, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _ImagePickerTile extends StatelessWidget {
  const _ImagePickerTile({
    required this.bytes,
    required this.fileName,
    required this.onPick,
    required this.onClear,
  });

  final Uint8List? bytes;
  final String? fileName;
  final Future<void> Function() onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasImage = bytes != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 160,
            height: 120,
            color: AppColors.darkBg,
            alignment: Alignment.center,
            child: hasImage
                ? Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: true)
                : const Icon(Icons.image, color: Colors.white24, size: 36),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilledButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text(hasImage ? 'Görseli Değiştir' : 'Görsel Seç'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.neon.withValues(alpha: 0.85),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasImage
                    ? (fileName ?? 'Seçilen görsel hazır.')
                    : 'WebP / PNG / JPG. Tarif görseli için 800×600 öneriliyor '
                        '(detay: docs/CONTENT_OPS.md).',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if (hasImage && onClear != null) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white54,
                  ),
                  label: const Text(
                    'Görseli kaldır',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
              if (!hasImage && kIsWeb)
                const SizedBox.shrink(), // placeholder for layout symmetry
            ],
          ),
        ),
      ],
    );
  }
}

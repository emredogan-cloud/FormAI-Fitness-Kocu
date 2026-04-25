import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/app_logger.dart';

/// Phase 50C · admin form for authoring a `public.exercises` row.
///
/// Mirrors every column the Phase 50A migration ships, with sensible
/// defaults for the housekeeping ones (sets, rest_duration, is_cardio).
/// The slug is derived from the name so the admin doesn't have to think
/// about URL-safe identifiers; the migration's `slug UNIQUE` constraint
/// catches accidental collisions at insert time.
///
/// On submit (in order so the SnackBar status text reads naturally):
///   1. Validates the form (required fields + at least one target muscle).
///   2. Optionally uploads the thumbnail bytes to
///      `exercises_media/thumbnails/<filename>` and resolves a public URL.
///   3. Uploads the video bytes to `exercises_media/videos/<filename>`
///      and resolves a public URL. Videos run last because they're the
///      slowest — if anything is going to fail it tends to be this step,
///      and we don't want a successful thumbnail upload to leak when the
///      whole form ultimately bails.
///   4. Inserts the exercises row carrying both URLs.
///
/// Failure paths surface red SnackBars with the underlying message; the
/// form keeps its state so the admin can retry without re-typing.
class AdminExerciseForm extends ConsumerStatefulWidget {
  const AdminExerciseForm({super.key});

  @override
  ConsumerState<AdminExerciseForm> createState() => _AdminExerciseFormState();
}

/// Bucket for both exercise media. Must exist + be public for the
/// resolved URLs to play in the mobile client. Created from
/// Supabase Studio: Storage → New bucket → name=`exercises_media`,
/// public=true.
const String _exercisesMediaBucket = 'exercises_media';

/// Maps Dart-side enum values to the Turkish labels rendered in
/// dropdowns. Keys are what we store in Postgres; values are display.
const Map<String, String> _categoryOptions = {
  'core': 'Core (Karın)',
  'chest': 'Göğüs',
  'back': 'Sırt',
  'legs': 'Bacak',
  'arms': 'Kol',
  'shoulders': 'Omuz',
  'fullBody': 'Kardiyo & Tüm Vücut',
};

const Map<String, String> _difficultyOptions = {
  'beginner': 'Başlangıç',
  'intermediate': 'Orta',
  'advanced': 'İleri',
};

const Map<String, String> _typeOptions = {
  'repBased': 'Tekrar Bazlı',
  'timeBased': 'Süre Bazlı',
};

class _AdminExerciseFormState extends ConsumerState<AdminExerciseForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetMusclesController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _shortTipController = TextEditingController();
  final _targetRepsController = TextEditingController(text: '12');
  final _targetDurationController = TextEditingController(text: '30');
  final _setsController = TextEditingController(text: '3');
  final _restController = TextEditingController(text: '30');

  String _category = 'core';
  String _difficulty = 'beginner';
  String _type = 'repBased';
  bool _isCardio = false;

  Uint8List? _thumbnailBytes;
  String? _thumbnailName;
  Uint8List? _videoBytes;
  String? _videoName;

  bool _isSubmitting = false;
  // Single source of truth for the inline status line. Empty when idle;
  // otherwise carries the current upload stage so the admin sees what
  // the (potentially slow) submit is actually doing instead of a bare
  // spinner.
  String _progressMessage = '';

  @override
  void dispose() {
    _nameController.dispose();
    _targetMusclesController.dispose();
    _instructionsController.dispose();
    _shortTipController.dispose();
    _targetRepsController.dispose();
    _targetDurationController.dispose();
    _setsController.dispose();
    _restController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Phase 50D · responsive padding so the form stays legible on the
    // mobile admin drawer (kicks in at < 600 px in admin_dashboard_screen).
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
                  'Egzersiz Yönetimi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 22 : 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Yeni bir egzersiz ekle. Slug, başlıktan otomatik üretilir. '
                  'Görsel ve video `exercises_media` Storage bucket\'ına '
                  'yüklenir (`/thumbnails`, `/videos` alt yolları).',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 28),
                _Section(
                  title: 'Temel Bilgiler',
                  children: [
                    _TextField(
                      label: 'Egzersiz Adı *',
                      hint: 'Örn. Mekik / Push-up',
                      controller: _nameController,
                      validator: _requiredText,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_nameController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'slug = ${_slugify(_nameController.text)}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _EnumDropdown(
                            label: 'Kategori *',
                            value: _category,
                            options: _categoryOptions,
                            onChanged: (v) {
                              if (v != null) setState(() => _category = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _EnumDropdown(
                            label: 'Zorluk *',
                            value: _difficulty,
                            options: _difficultyOptions,
                            onChanged: (v) {
                              if (v != null) setState(() => _difficulty = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _EnumDropdown(
                      label: 'Tip *',
                      value: _type,
                      options: _typeOptions,
                      onChanged: (v) {
                        if (v != null) setState(() => _type = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _Section(
                  title: 'Kas Grupları & Açıklama',
                  children: [
                    _TextField(
                      label: 'Hedef Kas Grupları (virgülle ayır) *',
                      hint: 'core, cardio',
                      controller: _targetMusclesController,
                      validator: (value) {
                        final muscles = _parseCsv(value);
                        if (muscles.isEmpty) {
                          return 'En az bir hedef kas grubu girilmelidir.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Önerilen değerler: core, upper_body, lower_body, '
                      'full_body, cardio. Generator bu alanı kullanarak '
                      'günlük rotasyonu kurar.',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _TextField(
                      label: 'Talimatlar *',
                      hint: 'Eller omuz hizasında, gövdeni düz tutarak yere '
                          'kadar in ve geri it.',
                      controller: _instructionsController,
                      validator: _requiredText,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 14),
                    _TextField(
                      label: 'Kısa İpucu (4-6 kelime)',
                      hint: 'Dirseğini gövdene yakın tut.',
                      controller: _shortTipController,
                      maxLines: 1,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _Section(
                  title: 'Tekrar / Set / Süre',
                  children: [
                    Row(
                      children: [
                        if (_type == 'repBased')
                          Expanded(
                            child: _TextField(
                              label: 'Hedef Tekrar *',
                              hint: '12',
                              controller: _targetRepsController,
                              keyboardType: TextInputType.number,
                              validator: _requiredPositiveInt,
                            ),
                          )
                        else
                          Expanded(
                            child: _TextField(
                              label: 'Hedef Süre (sn) *',
                              hint: '30',
                              controller: _targetDurationController,
                              keyboardType: TextInputType.number,
                              validator: _requiredPositiveInt,
                            ),
                          ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _TextField(
                            label: 'Set Sayısı',
                            hint: '3',
                            controller: _setsController,
                            keyboardType: TextInputType.number,
                            validator: _optionalPositiveInt,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _TextField(
                            label: 'Set Arası (sn)',
                            hint: '30',
                            controller: _restController,
                            keyboardType: TextInputType.number,
                            validator: _optionalPositiveInt,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.neon,
                      title: const Text(
                        'Kardiyo Hareketi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        '`is_cardio` flag — generator bu işareti HIIT '
                        'blokları kurarken kullanır.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      value: _isCardio,
                      onChanged: (v) => setState(() => _isCardio = v),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _Section(
                  title: 'Görsel & Video',
                  children: [
                    _MediaPickerTile(
                      label: 'Thumbnail',
                      hint: 'WebP / PNG / JPG · 400×400 öneriliyor '
                          '(detay: docs/CONTENT_OPS.md)',
                      isVideo: false,
                      bytes: _thumbnailBytes,
                      fileName: _thumbnailName,
                      onPick: _pickThumbnail,
                      onClear: _thumbnailBytes == null
                          ? null
                          : () => setState(() {
                                _thumbnailBytes = null;
                                _thumbnailName = null;
                              }),
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: AppColors.surfaceBorder, height: 1),
                    const SizedBox(height: 14),
                    _MediaPickerTile(
                      label: 'Video *',
                      hint:
                          'MP4 önerilir. Yükleme görsele göre uzun sürebilir.',
                      isVideo: true,
                      bytes: _videoBytes,
                      fileName: _videoName,
                      onPick: _pickVideo,
                      onClear: _videoBytes == null
                          ? null
                          : () => setState(() {
                                _videoBytes = null;
                                _videoName = null;
                              }),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_progressMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.neon,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _progressMessage,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                      label: Text(
                        _isSubmitting ? 'Yükleniyor…' : 'Kaydet',
                      ),
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

  Future<void> _pickThumbnail() async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _thumbnailBytes = bytes;
        _thumbnailName = picked.name;
      });
    } catch (e, st) {
      AppLogger.error(
        'admin exercise form: thumbnail pick failed',
        e,
        stackTrace: st,
        category: 'admin',
      );
      _showError('Görsel seçilemedi: $e');
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickVideo(
        source: ImageSource.gallery,
      );
      if (picked == null) return;
      // pickVideo returns an XFile pointing at the picked asset; on web
      // readAsBytes() pulls the underlying blob into memory. Files
      // larger than ~50 MB will block the page render briefly — we
      // don't try to stream because Supabase Storage's uploadBinary
      // wants the full bytes anyway.
      final bytes = await picked.readAsBytes();
      setState(() {
        _videoBytes = bytes;
        _videoName = picked.name;
      });
    } catch (e, st) {
      AppLogger.error(
        'admin exercise form: video pick failed',
        e,
        stackTrace: st,
        category: 'admin',
      );
      _showError('Video seçilemedi: $e');
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showError('Lütfen zorunlu alanları doldur.');
      return;
    }
    if (_videoBytes == null) {
      _showError('Video dosyası seçilmesi zorunludur.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _progressMessage = 'Hazırlanıyor…';
    });

    try {
      final supabase = Supabase.instance.client;
      final slug = _slugify(_nameController.text);

      String? thumbnailUrl;
      if (_thumbnailBytes != null) {
        setState(() => _progressMessage = 'Görsel yükleniyor…');
        thumbnailUrl = await _uploadMedia(
          supabase,
          bytes: _thumbnailBytes!,
          originalName: _thumbnailName,
          slug: slug,
          subPath: 'thumbnails',
          fallbackExtension: 'jpg',
        );
      }

      setState(() => _progressMessage = 'Video yükleniyor…');
      final videoUrl = await _uploadMedia(
        supabase,
        bytes: _videoBytes!,
        originalName: _videoName,
        slug: slug,
        subPath: 'videos',
        fallbackExtension: 'mp4',
      );

      setState(() => _progressMessage = 'Kayıt ekleniyor…');
      await supabase.from('exercises').insert({
        'slug': slug,
        'name': _nameController.text.trim(),
        'type': _type,
        'category': _category,
        'difficulty': _difficulty,
        'target_muscles': _parseCsv(_targetMusclesController.text),
        'target_reps': _type == 'repBased'
            ? int.parse(_targetRepsController.text.trim())
            : null,
        'target_duration_in_seconds': _type == 'timeBased'
            ? int.parse(_targetDurationController.text.trim())
            : null,
        'sets': _parseOptionalInt(_setsController.text) ?? 3,
        'rest_duration_in_seconds':
            _parseOptionalInt(_restController.text) ?? 30,
        'is_cardio': _isCardio,
        'instructions': _instructionsController.text.trim(),
        'short_tip': _shortTipController.text.trim(),
        'video_url': videoUrl,
        'thumbnail_url': thumbnailUrl,
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
                    'Egzersiz başarıyla kaydedildi.',
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
        'admin exercise form: storage upload failed',
        e,
        stackTrace: st,
        category: 'admin',
      );
      _showError(
        'Storage hatası: ${e.message}. '
        '`$_exercisesMediaBucket` bucket\'ı (public) Supabase\'de '
        'tanımlı mı kontrol et.',
      );
    } on PostgrestException catch (e, st) {
      AppLogger.error(
        'admin exercise form: db insert failed',
        e,
        stackTrace: st,
        category: 'admin',
      );
      _showError('Veritabanı hatası: ${e.message}');
    } catch (e, st) {
      AppLogger.error(
        'admin exercise form: unexpected error',
        e,
        stackTrace: st,
        category: 'admin',
      );
      _showError('Beklenmeyen bir hata oluştu: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _progressMessage = '';
        });
      }
    }
  }

  /// Uploads [bytes] to `<bucket>/<subPath>/<timestamp>_<slug>.<ext>` and
  /// returns the resolved public URL. The timestamp prefix avoids
  /// concurrent-admin collisions; Storage rejects upserts when the path
  /// already exists, which would otherwise drop the second submitter's
  /// file silently.
  Future<String> _uploadMedia(
    SupabaseClient supabase, {
    required Uint8List bytes,
    required String? originalName,
    required String slug,
    required String subPath,
    required String fallbackExtension,
  }) async {
    final extension =
        _extractExtension(originalName) ?? fallbackExtension.toLowerCase();
    final filename =
        '$subPath/${DateTime.now().millisecondsSinceEpoch}_$slug.$extension';
    await supabase.storage.from(_exercisesMediaBucket).uploadBinary(
          filename,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFor(extension),
            upsert: false,
          ),
        );
    return supabase.storage.from(_exercisesMediaBucket).getPublicUrl(filename);
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _targetMusclesController.clear();
    _instructionsController.clear();
    _shortTipController.clear();
    _targetRepsController.text = '12';
    _targetDurationController.text = '30';
    _setsController.text = '3';
    _restController.text = '30';
    setState(() {
      _category = 'core';
      _difficulty = 'beginner';
      _type = 'repBased';
      _isCardio = false;
      _thumbnailBytes = null;
      _thumbnailName = null;
      _videoBytes = null;
      _videoName = null;
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
              const Icon(
                Icons.error_outline,
                color: AppColors.danger,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );
  }

  // ==========================================================================
  // Validators / parsers
  // ==========================================================================

  static String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bu alan zorunludur.';
    }
    return null;
  }

  static String? _requiredPositiveInt(String? value) {
    final missing = _requiredText(value);
    if (missing != null) return missing;
    final parsed = int.tryParse(value!.trim());
    if (parsed == null || parsed <= 0) {
      return 'Pozitif bir tam sayı gir.';
    }
    return null;
  }

  static String? _optionalPositiveInt(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = int.tryParse(value.trim());
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

  static List<String> _parseCsv(String? value) {
    if (value == null) return const [];
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  /// ASCII-only slug — strips Turkish diacritics so the resulting URL
  /// path is portable. Existing migration uses ASCII slugs ('crunch',
  /// 'push_up') so admin entries should follow suit.
  static String _slugify(String input) {
    final transliterated = input
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
    final base = transliterated
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (base.isEmpty) return 'exercise';
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
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      default:
        return 'application/octet-stream';
    }
  }
}

// ============================================================================
// Internal styling helpers — kept private to this file rather than shared
// with admin_recipe_form.dart so the recipe form keeps shipping unchanged.
// If a third form lands the obvious next step is to lift these into a
// `lib/features/admin/presentation/widgets/admin_form_kit.dart`.
// ============================================================================

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

class _TextField extends StatelessWidget {
  const _TextField({
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final String? hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;

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
          onChanged: onChanged,
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

class _EnumDropdown extends StatelessWidget {
  const _EnumDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

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
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: AppColors.surface,
          iconEnabledColor: Colors.white70,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: options.entries
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

class _MediaPickerTile extends StatelessWidget {
  const _MediaPickerTile({
    required this.label,
    required this.hint,
    required this.isVideo,
    required this.bytes,
    required this.fileName,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final String hint;
  final bool isVideo;
  final Uint8List? bytes;
  final String? fileName;
  final Future<void> Function() onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasMedia = bytes != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 140,
            height: 100,
            color: AppColors.darkBg,
            alignment: Alignment.center,
            child: hasMedia
                ? (isVideo
                    ? const _VideoSelectedBadge()
                    : Image.memory(
                        bytes!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ))
                : Icon(
                    isVideo ? Icons.videocam : Icons.image,
                    color: Colors.white24,
                    size: 32,
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: onPick,
                icon: Icon(
                  isVideo ? Icons.movie : Icons.upload_file,
                  size: 18,
                ),
                label: Text(
                  hasMedia
                      ? (isVideo ? 'Videoyu Değiştir' : 'Görseli Değiştir')
                      : (isVideo ? 'Video Seç' : 'Thumbnail Seç'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.neon.withValues(alpha: 0.85),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasMedia ? (fileName ?? 'Seçili dosya hazır.') : hint,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if (hasMedia && onClear != null) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white54,
                  ),
                  label: const Text(
                    'Kaldır',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoSelectedBadge extends StatelessWidget {
  const _VideoSelectedBadge();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.play_circle, color: AppColors.neon, size: 28),
        SizedBox(height: 4),
        Text(
          'Video seçildi',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

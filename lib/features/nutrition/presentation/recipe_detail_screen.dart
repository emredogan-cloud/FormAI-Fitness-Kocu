import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_extension.dart';
import '../../../core/widgets/cached_image.dart';
import '../domain/models/daily_meal_slot.dart';
import '../domain/models/recipe.dart';
import '../providers/daily_menu_provider.dart';
import 'widgets/recipe_tags.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonGreen = Color(0xFF39FF14);
const Color _proteinColor = Color(0xFF4DA6FF);
const Color _carbsColor = Color(0xFFFF4DDB);
const Color _fatColor = Color(0xFFEAFF00);

/// Full recipe view opened from the discovery gallery (pushed via
/// `/recipe` with `state.extra == recipe`) or any other place that has
/// a [Recipe] in hand.
///
/// Layout follows the phase 22.3 spec:
///   • SliverAppBar with full-bleed image behind a vertical gradient
///     so the back button stays readable.
///   • Body: title + prep-time row, 4-tile macro breakdown, and the
///     instructions paragraph (line-height 1.5).
///   • Sticky "Plana Ekle" CTA at the bottom that toasts + pops for MVP.
class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    // Phase 53C · drop the hardcoded `0xFF0B0B12` scaffold + sliver bg
    // so the active theme's `scaffoldBackgroundColor` (lightBg in
    // light, darkBg in dark) drives both surfaces. Title + meta copy
    // pull through onSurface so the dark text stays legible on the
    // off-white scaffold.
    final scheme = context.colors;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: scheme.surface,
            elevation: 0,
            leading: const _BackButton(),
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroImage(imageUrl: recipe.imageUrl),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MealTypePill(mealType: recipe.mealType),
                  const SizedBox(height: 12),
                  Text(
                    recipe.title,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Category badges (🔥 Yüksek Protein, 🥗 Düşük Kalori,
                  // 💪 Hacim, ⚡ Hızlı) — up to three at full size so the
                  // user can scan the recipe's macro profile at a glance.
                  RecipeTagsStrip(recipe: recipe, maxTags: 3),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: scheme.onSurface.withValues(alpha: 0.7),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${recipe.prepTimeMinutes} dk',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _MacroTilesRow(recipe: recipe),
                  const SizedBox(height: 28),
                  if ((recipe.instructions ?? '').trim().isNotEmpty)
                    _InstructionsSection(text: recipe.instructions!),
                  // Leave headroom for the sticky CTA so long instruction
                  // blocks don't get visually eaten by the button.
                  const SizedBox(height: 96),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _AddToPlanButton(recipe: recipe),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final image = (url != null && url.isNotEmpty)
        ? CachedImage(
            url: url,
            fit: BoxFit.cover,
            memCacheHeight: 800,
            errorBuilder: (_, __, ___) => _fallback(),
          )
        : _fallback();
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        // Top gradient: keeps the back button + status bar readable even
        // on bright photography.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 120,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Bottom fade so the body's first line of text doesn't fight
        // the photo's details.
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 120,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF0B0B12).withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A3DFF), Color(0xFF4DA6FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.restaurant, color: Colors.white70, size: 56),
      );
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _MealTypePill extends StatelessWidget {
  const _MealTypePill({required this.mealType});
  final String mealType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: _neon.withValues(alpha: 0.18),
        border: Border.all(color: _neon.withValues(alpha: 0.55)),
      ),
      child: Text(
        mealType.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

/// Four vertical tiles for Calories / Protein / Carbs / Fat. Equal-width
/// via `Expanded` so the row stays balanced regardless of text length.
class _MacroTilesRow extends StatelessWidget {
  const _MacroTilesRow({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MacroTile(
            label: 'KALORİ',
            value: '${recipe.calories}',
            unit: 'kcal',
            color: Colors.white,
            accent: _neon,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MacroTile(
            label: 'PROTEİN',
            value: '${recipe.protein}',
            unit: 'g',
            color: _proteinColor,
            accent: _proteinColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MacroTile(
            label: 'KARB',
            value: '${recipe.carbs}',
            unit: 'g',
            color: _carbsColor,
            accent: _carbsColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MacroTile(
            label: 'YAĞ',
            value: '${recipe.fat}',
            unit: 'g',
            color: _fatColor,
            accent: _fatColor,
          ),
        ),
      ],
    );
  }
}

class _MacroTile extends StatelessWidget {
  const _MacroTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.accent,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(color: accent.withValues(alpha: 0.55), blurRadius: 12),
                ],
              ),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Parses the seed recipes' "MALZEMELER: …\n\nHAZIRLANIŞI: …" shape
/// into two visually distinct blocks. Legacy recipes (plain prose,
/// no section headers) fall through to a single block with the
/// original 14 px / 1.5 line height so they still read cleanly.
class _InstructionsSection extends StatelessWidget {
  const _InstructionsSection({required this.text});
  final String text;

  static const List<String> _sectionHeaders = ['MALZEMELER:', 'HAZIRLANIŞI:'];

  @override
  Widget build(BuildContext context) {
    final sections = _split(text);
    if (sections.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(label: 'Hazırlanışı'),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          _SectionHeading(label: sections[i].heading),
          const SizedBox(height: 10),
          Text(
            sections[i].body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (i != sections.length - 1) const SizedBox(height: 20),
        ],
      ],
    );
  }

  /// Splits the instruction blob on each recognised section header.
  /// Header tokens ("MALZEMELER:", "HAZIRLANIŞI:") are stripped from
  /// the body, and lowercase title-cased versions are used for the
  /// rendered heading. Returns an empty list when no recognised header
  /// is present — the caller then falls back to a plain single-block
  /// render so unstructured legacy instructions still work.
  List<_InstructionBlock> _split(String source) {
    final matches = <({int index, String header})>[];
    for (final header in _sectionHeaders) {
      final idx = source.indexOf(header);
      if (idx != -1) matches.add((index: idx, header: header));
    }
    if (matches.isEmpty) return const [];
    matches.sort((a, b) => a.index.compareTo(b.index));

    final blocks = <_InstructionBlock>[];
    for (var i = 0; i < matches.length; i++) {
      final start = matches[i].index + matches[i].header.length;
      final end = i + 1 < matches.length ? matches[i + 1].index : source.length;
      final body = source.substring(start, end).trim();
      blocks.add(_InstructionBlock(
        heading: _headingFor(matches[i].header),
        body: body,
      ));
    }
    return blocks;
  }

  String _headingFor(String raw) {
    switch (raw) {
      case 'MALZEMELER:':
        return 'Malzemeler';
      case 'HAZIRLANIŞI:':
        return 'Hazırlanışı';
      default:
        return raw;
    }
  }
}

class _InstructionBlock {
  const _InstructionBlock({required this.heading, required this.body});
  final String heading;
  final String body;
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.3,
      ),
    );
  }
}

/// Sticky bottom CTA. Wired in phase 23.1 to actually append the recipe
/// to the daily plan via [DailyMenuNotifier.addRecipeToPlan]; the slot
/// is inferred from `recipe.mealType` so a breakfast recipe lands in
/// the breakfast row, a main lands in dinner, etc.
class _AddToPlanButton extends ConsumerWidget {
  const _AddToPlanButton({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B12),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _handleAddToPlan(context, ref, recipe),
            icon: const Icon(Icons.add_circle_outline, size: 20),
            label: const Text('Plana Ekle'),
            style: FilledButton.styleFrom(
              backgroundColor: _neon,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the slot picker, waits for a selection, then dispatches the
/// add-to-plan and toasts + pops on success. Separated out so the
/// button's `onPressed` stays readable.
Future<void> _handleAddToPlan(
  BuildContext context,
  WidgetRef ref,
  Recipe recipe,
) async {
  final slot = await _showSlotPicker(context);
  if (slot == null) return;
  HapticFeedback.mediumImpact();
  ref.read(dailyMenuProvider.notifier).addRecipeToPlan(recipe, slot.name);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('${recipe.title} "${_slotLabel(slot)}" öğününe eklendi.'),
        backgroundColor: _neonGreen.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
      ),
    );
  if (context.canPop()) context.pop();
}

Future<DailyMealSlot?> _showSlotPicker(BuildContext context) {
  return showModalBottomSheet<DailyMealSlot>(
    context: context,
    // Phase 53C · pull the sheet bg from the active theme so the
    // bottom-sheet picker doesn't punch a dark hole through a
    // light-mode scaffold.
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _SlotPickerSheet(),
  );
}

class _SlotPickerSheet extends StatelessWidget {
  const _SlotPickerSheet();

  static const List<DailyMealSlot> _slots = [
    DailyMealSlot.breakfast,
    DailyMealSlot.lunch,
    DailyMealSlot.dinner,
    DailyMealSlot.snack,
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Hangi öğüne eklemek istersin?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 14),
            for (final slot in _slots) ...[
              _SlotOption(
                slot: slot,
                onTap: () => Navigator.of(context).pop(slot),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _SlotOption extends StatelessWidget {
  const _SlotOption({required this.slot, required this.onTap});
  final DailyMealSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconFor(slot);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.22),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _slotLabel(slot),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _iconFor(DailyMealSlot slot) {
    switch (slot) {
      case DailyMealSlot.breakfast:
        return (Icons.free_breakfast, _neon);
      case DailyMealSlot.lunch:
        return (Icons.lunch_dining, _proteinColor);
      case DailyMealSlot.dinner:
        return (Icons.dinner_dining, _carbsColor);
      case DailyMealSlot.snack:
        return (Icons.cookie, _fatColor);
    }
  }
}

String _slotLabel(DailyMealSlot slot) {
  switch (slot) {
    case DailyMealSlot.breakfast:
      return 'Kahvaltı';
    case DailyMealSlot.lunch:
      return 'Öğle Yemeği';
    case DailyMealSlot.dinner:
      return 'Akşam Yemeği';
    case DailyMealSlot.snack:
      return 'Atıştırmalık';
  }
}

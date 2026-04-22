import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/error_card.dart';
import '../../domain/models/recipe.dart';
import '../../providers/daily_menu_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonGreen = Color(0xFF39FF14);
const Color _proteinColor = Color(0xFF4DA6FF);
const Color _carbsColor = Color(0xFFFF4DDB);
const Color _fatColor = Color(0xFFEAFF00);

/// Vertical meal-plan timeline rendered directly under the AI insight
/// banner in the nutrition tab. Reads [dailyMenuProvider] and paints one
/// [_MealCard] per slot, stitched together by a continuous neon gutter
/// on the left (dot + line) so the day reads as a chronological arc.
///
/// Uses a plain [Column] instead of [ListView.builder] because the tab
/// already scrolls via [SingleChildScrollView]; a nested scroll view
/// would either fight the outer scroll or require shrinkWrap which
/// defeats the laziness ListView.builder gives you. With 2–4 cards per
/// day the cost of building them all eagerly is negligible.
class MealPlanTimeline extends ConsumerWidget {
  const MealPlanTimeline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(dailyMenuProvider);
    return menuAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: _neon)),
      ),
      error: (err, st) {
        debugPrint('MealPlanTimeline menu error: $err\n$st');
        return ErrorCard(
          message: 'Günün menüsü yüklenemedi.',
          onRetry: () => ref.invalidate(dailyMenuProvider),
        );
      },
      data: (slots) {
        if (slots.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _EmptyPlaceholder(
              message: 'Günün menüsü için tercih bulunamadı.',
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: IntrinsicHeight(
            child: Column(
              children: [
                for (var i = 0; i < slots.length; i++)
                  _TimelineRow(
                    slot: slots[i],
                    isFirst: i == 0,
                    isLast: i == slots.length - 1,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.slot,
    required this.isFirst,
    required this.isLast,
  });

  final DailyMenuSlot slot;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: CustomPaint(
              painter: _TimelineGutterPainter(
                isFirst: isFirst,
                isLast: isLast,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: _MealCard(slot: slot),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the vertical connecting line plus a neon dot at the top of
/// each row. First row has no line above, last row has no line below,
/// so the connective tissue flows continuously through the list.
class _TimelineGutterPainter extends CustomPainter {
  const _TimelineGutterPainter({required this.isFirst, required this.isLast});

  final bool isFirst;
  final bool isLast;

  static const double _dotY = 24;
  static const double _dotRadius = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final linePaint = Paint()
      ..color = _neon.withValues(alpha: 0.45)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Line running above the dot — suppressed on the first row so the
    // timeline visually "starts" at the first dot.
    if (!isFirst) {
      canvas.drawLine(
        Offset(centerX, 0),
        Offset(centerX, _dotY - _dotRadius - 1),
        linePaint,
      );
    }
    // Line running below the dot — suppressed on the last row so it
    // doesn't dangle into the next section.
    if (!isLast) {
      canvas.drawLine(
        Offset(centerX, _dotY + _dotRadius + 1),
        Offset(centerX, size.height),
        linePaint,
      );
    }
    // Glow behind the dot.
    final glow = Paint()
      ..color = _neon.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(centerX, _dotY), _dotRadius, glow);
    // Solid dot.
    final dot = Paint()..color = _neon;
    canvas.drawCircle(Offset(centerX, _dotY), _dotRadius, dot);
  }

  @override
  bool shouldRepaint(covariant _TimelineGutterPainter old) =>
      old.isFirst != isFirst || old.isLast != isLast;
}

/// One meal entry. Holds local state for:
///   • [_index] — the currently shown recipe inside `slot.candidates`.
///     "Değiştir" advances this by one, wrapping around.
///   • [_eaten] — toggled by "Yedim". Dims the card and swaps the log
///     button to "Geri Al" so the action is reversible.
///
/// The card tap also routes into `/recipe/:id` so users can drill down.
class _MealCard extends StatefulWidget {
  const _MealCard({required this.slot});
  final DailyMenuSlot slot;

  @override
  State<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<_MealCard> {
  late int _index;
  bool _eaten = false;

  @override
  void initState() {
    super.initState();
    _index = widget.slot.candidates.isEmpty
        ? 0
        : widget.slot.initialIndex.clamp(0, widget.slot.candidates.length - 1);
  }

  Recipe? get _recipe {
    if (widget.slot.candidates.isEmpty) return null;
    return widget.slot.candidates[_index];
  }

  bool get _canSwap => widget.slot.candidates.length > 1;

  void _swap() {
    if (!_canSwap) return;
    setState(() {
      _index = (_index + 1) % widget.slot.candidates.length;
      // Swapping the recipe resets the "eaten" flag — the user is now
      // looking at a different dish, so the old confirmation shouldn't
      // stick.
      _eaten = false;
    });
  }

  void _toggleEaten() => setState(() => _eaten = !_eaten);

  @override
  Widget build(BuildContext context) {
    final recipe = _recipe;
    if (recipe == null) {
      return _EmptySlotCard(slot: widget.slot.slot);
    }
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _eaten ? 0.55 : 1.0,
      child: _CardShell(
        onTap: () => context.push('/recipe/${recipe.id}'),
        borderColor: _eaten ? _neonGreen.withValues(alpha: 0.45) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 68,
                      height: 68,
                      child: _RecipeThumb(url: recipe.imageUrl),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _slotLabel(widget.slot.slot),
                          style: const TextStyle(
                            color: _neon,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recipe.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _MacroStrip(recipe: recipe),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _canSwap ? _swap : null,
                      icon: const Icon(Icons.sync, size: 16),
                      label: const Text('Değiştir'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        disabledForegroundColor: Colors.white38,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _toggleEaten,
                      icon: Icon(_eaten ? Icons.undo : Icons.check, size: 16),
                      label: Text(_eaten ? 'Geri Al' : 'Yedim'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _eaten
                            ? Colors.white.withValues(alpha: 0.12)
                            : _neonGreen,
                        foregroundColor: _eaten ? Colors.white : Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySlotCard extends StatelessWidget {
  const _EmptySlotCard({required this.slot});
  final DailyMealSlot slot;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      onTap: null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.hourglass_empty, color: Colors.white38, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _slotLabel(slot),
                    style: const TextStyle(
                      color: _neon,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Bu öğün için uygun tarif bulunamadı.',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.child,
    required this.onTap,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: borderColor ?? Colors.white12),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _MacroStrip extends StatelessWidget {
  const _MacroStrip({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _Chip(
          icon: Icons.local_fire_department,
          label: '${recipe.calories} kcal',
          iconColor: Colors.white70,
        ),
        _Chip(
          label: '${recipe.protein}g P',
          labelColor: _proteinColor,
        ),
        _Chip(
          label: '${recipe.carbs}g K',
          labelColor: _carbsColor,
        ),
        _Chip(
          label: '${recipe.fat}g Y',
          labelColor: _fatColor,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    this.icon,
    this.iconColor,
    this.labelColor,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor ?? Colors.white70, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: labelColor ?? Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Uses [Image.network] with fallback + loading builders instead of
/// `CachedNetworkImage`. The phase 22.2 spec named the latter, but the
/// project's pubspec doesn't include that package, so we reuse the same
/// cache-miss-friendly pattern already used by the Keşfet strip and
/// recipe detail screen — a Supabase image URL is the same cost to
/// re-fetch as most cached miss paths and this keeps deps minimal.
class _RecipeThumb extends StatelessWidget {
  const _RecipeThumb({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Colors.white10,
      alignment: Alignment.center,
      child: const Icon(Icons.restaurant, color: Colors.white54, size: 28),
    );
    final src = url;
    if (src == null || src.isEmpty) return fallback;
    return Image.network(
      src,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : Container(color: Colors.white10),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white54, fontSize: 13),
      ),
    );
  }
}

String _slotLabel(DailyMealSlot slot) {
  switch (slot) {
    case DailyMealSlot.breakfast:
      return 'KAHVALTI';
    case DailyMealSlot.lunch:
      return 'ÖĞLE YEMEĞİ';
    case DailyMealSlot.dinner:
      return 'AKŞAM YEMEĞİ';
    case DailyMealSlot.snack:
      return 'ARA ÖĞÜN';
  }
}

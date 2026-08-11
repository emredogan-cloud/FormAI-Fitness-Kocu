import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/food_database.dart';
import '../domain/models/meal_entry.dart';
import '../providers/calorie_providers.dart';
import 'barcode_scan_screen.dart';
import 'calorie_dashboard.dart' show slotLabel;

/// Scan a barcode, say how much you ate, log it.
///
/// Costs no scan quota and no model call — see [BarcodeScanScreen] for
/// why packaged food takes this route instead of the vision one.
Future<void> startBarcodeScan(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);

  final outcome = await Navigator.of(context).push<BarcodeScanOutcome>(
    MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
  );
  if (outcome == null || !context.mounted) return;

  if (!outcome.isFound) {
    // Open Food Facts is community-contributed and its coverage is
    // uneven by market, so a miss is expected rather than exceptional.
    // Say which barcode failed — it is the one useful thing we know, and
    // it lets a user contribute it upstream if they want to.
    _snack(context, l10n.calorieBarcodeNotFound(outcome.barcode ?? ''));
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PortionSheet(product: outcome.product!),
  );
}

/// How much of the scanned product was actually eaten.
///
/// The barcode identifies the product exactly; it says nothing about the
/// amount. Open Food Facts sometimes knows a serving size and often does
/// not, so the serving button is offered only when there is one — a
/// "1 serving" button that silently means 100 g would be inventing the
/// number the whole barcode path exists to avoid.
class _PortionSheet extends ConsumerStatefulWidget {
  const _PortionSheet({required this.product});

  final FoodProduct product;

  @override
  ConsumerState<_PortionSheet> createState() => _PortionSheetState();
}

class _PortionSheetState extends ConsumerState<_PortionSheet> {
  late final _grams = TextEditingController(
    text: (widget.product.servingGrams ?? 100).round().toString(),
  );
  MealSlot _slot = _slotForNow();
  bool _saving = false;

  static MealSlot _slotForNow() {
    final h = DateTime.now().hour;
    if (h < 11) return MealSlot.breakfast;
    if (h < 16) return MealSlot.lunch;
    if (h < 22) return MealSlot.dinner;
    return MealSlot.snack;
  }

  double get _amount => double.tryParse(_grams.text.trim()) ?? 0;

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = widget.product;
    final preview = p.toMealItem(grams: _amount, portionLabel: '');

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.displayName,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              l10n.calorieBarcodePer100(p.kcalPer100.round()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _grams,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.calorieBarcodeAmount,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final g in const [50, 100, 200])
                  ActionChip(
                    label: Text('$g g'),
                    onPressed: () => setState(() => _grams.text = '$g'),
                  ),
                if (p.servingGrams != null)
                  ActionChip(
                    label: Text(
                        l10n.calorieBarcodeOneServing(p.servingGrams!.round())),
                    onPressed: () => setState(
                        () => _grams.text = p.servingGrams!.round().toString()),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.neon.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    l10n.calorieKcalValue(preview.kcal),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.neon,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'P ${preview.proteinG} · '
                    'K ${preview.carbsG} · '
                    'Y ${preview.fatG}', // i18n-ignore — macro initials
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final slot in MealSlot.values)
                  ChoiceChip(
                    label: Text(slotLabel(l10n, slot)),
                    selected: _slot == slot,
                    onSelected: (_) => setState(() => _slot = slot),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.neon,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _saving || _amount <= 0 ? null : _save,
                child: Text(l10n.calorieManualSave),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(calorieRepositoryProvider).logMeal(
        day: ref.read(selectedCalorieDayProvider),
        slot: _slot,
        source: MealSource.barcode,
        items: [
          widget.product.toMealItem(
            grams: _amount,
            portionLabel: '${_amount.round()} g', // i18n-ignore — unit
          ),
        ],
      );
      refreshCalorieSurfaces(ref);
      if (!mounted) return;
      Navigator.of(context).pop();
      _snack(context, l10n.calorieMealLogged);
    } catch (e, st) {
      AppLogger.error('Barcode meal log failed', e,
          stackTrace: st, category: 'calories');
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(context, l10n.calorieLogFailed);
    }
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

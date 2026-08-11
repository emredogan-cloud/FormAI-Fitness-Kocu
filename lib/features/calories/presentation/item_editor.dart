import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/models/meal_entry.dart';
import '../providers/calorie_providers.dart';

/// Correct or remove an item that is already logged.
///
/// The scan sheet lets a user fix an estimate *before* saving. This is
/// the other half, and it matters more than it looks: the research doc
/// (§1.2) finds that the correction workflow is what reviewers actually
/// praise about this category, and a correction you can only make in the
/// three seconds before you tap Save is not really a correction — you
/// notice the chicken was 200 g, not 150, when you next open the day.
///
/// Every save sets `was_edited`, which `CalorieRepository.updateItem`
/// handles. That flag is the feature's most useful diagnostic: a food
/// with a high edit rate is one the prompt or the nutrition source is
/// wrong about, and without it that is invisible.
Future<void> showItemEditor(
  BuildContext context,
  WidgetRef ref,
  MealItem item,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ItemEditorSheet(item: item),
  );
}

class _ItemEditorSheet extends ConsumerStatefulWidget {
  const _ItemEditorSheet({required this.item});

  final MealItem item;

  @override
  ConsumerState<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends ConsumerState<_ItemEditorSheet> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _portion = TextEditingController(text: widget.item.portionLabel);
  late final _kcal = TextEditingController(text: '${widget.item.kcal}');
  late final _protein = TextEditingController(text: '${widget.item.proteinG}');
  late final _carbs = TextEditingController(text: '${widget.item.carbsG}');
  late final _fat = TextEditingController(text: '${widget.item.fatG}');
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _portion, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

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
            Text(l10n.calorieEditItemTitle,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: l10n.calorieManualName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _portion,
              decoration: InputDecoration(
                labelText: l10n.calorieManualPortion,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(flex: 2, child: _num(_kcal, l10n.calorieKcal)),
                const SizedBox(width: 8),
                Expanded(child: _num(_protein, l10n.calorieProteinShort)),
                const SizedBox(width: 8),
                Expanded(child: _num(_carbs, l10n.calorieCarbsShort)),
                const SizedBox(width: 8),
                Expanded(child: _num(_fat, l10n.calorieFatShort)),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.calorieRemoveItem),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.neon,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _busy ? null : _save,
                    child: Text(l10n.calorieEditItemSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _num(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      );

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final id = widget.item.id;
    if (id == null) return;

    final name = _name.text.trim();
    final kcal = int.tryParse(_kcal.text.trim()) ?? 0;
    if (name.isEmpty || kcal < 0) {
      _snack(context, l10n.calorieManualIncomplete);
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(calorieRepositoryProvider).updateItem(
            id,
            widget.item.copyWith(
              name: name,
              portionLabel: _portion.text.trim(),
              kcal: kcal,
              proteinG: int.tryParse(_protein.text.trim()) ?? 0,
              carbsG: int.tryParse(_carbs.text.trim()) ?? 0,
              fatG: int.tryParse(_fat.text.trim()) ?? 0,
              // A number the user typed is no longer an estimate, so the
              // confidence dot must stop saying it is one.
              confidence: ItemConfidence.high,
              wasEdited: true,
            ),
          );
      refreshCalorieSurfaces(ref);
      if (!mounted) return;
      Navigator.of(context).pop();
      _snack(context, l10n.calorieItemUpdated);
    } catch (e, st) {
      AppLogger.error('Item update failed', e,
          stackTrace: st, category: 'calories');
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(context, l10n.calorieLogFailed);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final id = widget.item.id;
    if (id == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(calorieRepositoryProvider).deleteItem(id);
      // The meal's totals are maintained by a trigger in migration 028,
      // so removing the last item leaves a zeroed meal rather than a
      // stale one. The user deletes the meal itself from the list.
      refreshCalorieSurfaces(ref);
      if (!mounted) return;
      Navigator.of(context).pop();
      _snack(context, l10n.calorieItemRemoved);
    } catch (e, st) {
      AppLogger.error('Item delete failed', e,
          stackTrace: st, category: 'calories');
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(context, l10n.calorieLogFailed);
    }
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/jpeg_privacy.dart';
import '../domain/models/meal_entry.dart';
import '../domain/models/scan_result.dart';
import '../providers/calorie_providers.dart';
import 'barcode_flow.dart';
import 'calorie_dashboard.dart' show ConfidenceDot, slotLabel;

/// Capture → analyse → correct → log.
///
/// ------------------------------------------------------------
/// WHY image_picker AND NOT THE camera PACKAGE
/// ------------------------------------------------------------
///
/// The app already depends on `camera` for the live pose overlay, so the
/// obvious move is to reuse it. It is the wrong tool here.
///
/// `maxWidth` / `maxHeight` / `imageQuality` make the platform downscale
/// and RE-ENCODE the photo before Dart ever sees it, which is three
/// requirements in one step:
///
///   * cost — the model's vision tier discards detail above ~1024 px, so
///     sending more is paying for tokens nobody reads (research doc §5.2)
///   * latency — a 4 MB upload over a phone connection is most of the
///     wait
///   * privacy — the full-resolution original never leaves the handset
///
/// `camera` would hand back a full-resolution file and leave all three to
/// us. Reaching for the heavier dependency would mean re-implementing
/// what the lighter one does natively.
///
/// The re-encode also drops EXIF, but that is treated as a bonus rather
/// than as the mechanism: `stripJpegMetadata` removes it explicitly
/// below, because a privacy claim resting on another package's resize
/// path stops being true the moment that path changes. See
/// `jpeg_privacy.dart`.
const _maxEdge = 1024.0;
const _quality = 80;

Future<void> startFoodScan(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);

  final choice = await _pickSource(context);
  if (choice == null || !context.mounted) return;

  // Barcode first, and deliberately BEFORE the quota check.
  //
  // Reading a barcode costs no model call, so it must stay available to
  // a user who has spent all their AI scans. Gating it behind the quota
  // would make the free tier merely limited instead of usable — and
  // would push packaged food back through the vision model, which the
  // research doc (§1.2) is explicit it should never take.
  if (choice == _ScanChoice.barcode) {
    await startBarcodeScan(context, ref);
    return;
  }

  // Everything below spends a scan. Check the quota BEFORE opening the
  // camera: letting a user frame a photo, wait, and only then be told
  // they are out wastes their time and reads as a bait-and-switch.
  final quota = ref.read(scanQuotaProvider).value;
  if (quota != null && quota.isExhausted) {
    if (!context.mounted) return;
    await _showQuotaSheet(context, ref, quota.limit);
    return;
  }

  final source =
      choice == _ScanChoice.camera ? ImageSource.camera : ImageSource.gallery;
  if (!context.mounted) return;

  final XFile? shot;
  try {
    shot = await ImagePicker().pickImage(
      source: source,
      maxWidth: _maxEdge,
      maxHeight: _maxEdge,
      imageQuality: _quality,
    );
  } catch (e, st) {
    // A denied camera permission arrives here as a PlatformException.
    // It is a normal user choice, not a crash — say so and offer the
    // gallery instead of dead-ending.
    AppLogger.warning('Food scan capture failed: $e',
        category: 'calories', data: {'stack': st.toString()});
    if (!context.mounted) return;
    _snack(context, l10n.calorieCameraDenied);
    return;
  }

  if (shot == null || !context.mounted) return;

  // Strip metadata before the bytes go anywhere. `image_picker`'s resize
  // almost certainly dropped EXIF already; this makes it certain, and
  // `jpeg_privacy.dart` explains why "almost certainly" was not good
  // enough for a claim we make in the privacy policy.
  final bytes = stripJpegMetadata(await shot.readAsBytes());
  if (!context.mounted) return;

  final outcome = await _runScanWithProgress(context, ref, bytes);
  if (outcome == null || !context.mounted) return;

  if (!outcome.isSuccess) {
    await _handleFailure(context, ref, outcome.failure!);
    return;
  }

  final result = outcome.result!;
  refreshCalorieSurfaces(ref);

  if (!result.recognized || result.items.isEmpty) {
    if (!context.mounted) return;
    _snack(context, l10n.calorieNoFoodFound);
    return;
  }

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ScanResultSheet(result: result),
  );
}

/// Runs the scan behind a blocking, honest progress dialog.
///
/// Measured end-to-end latency on a composite plate was ~9.9 s (Phase 6
/// device test), so this is NOT a spinner that implies "nearly done". It
/// names what is happening and warns that it takes a moment — a bare
/// spinner for ten seconds is how a working feature gets reported as
/// frozen.
Future<ScanOutcome?> _runScanWithProgress(
  BuildContext context,
  WidgetRef ref,
  List<int> bytes,
) async {
  final l10n = AppLocalizations.of(context);
  final future = ref.read(calorieRepositoryProvider).scan(bytes);

  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Text(l10n.calorieAnalysing, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              l10n.calorieAnalysingHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  ));

  final outcome = await future;
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  return outcome;
}

/// Every failure kind ends somewhere the user can act.
///
/// The roadmap's quality gate names "AI timeout creates an infinite
/// spinner" and "user can become stuck" as failures. This function is
/// where that is won: each branch has a message and, where retrying can
/// actually help, a retry.
Future<void> _handleFailure(
  BuildContext context,
  WidgetRef ref,
  ScanFailure failure,
) async {
  final l10n = AppLocalizations.of(context);
  refreshCalorieSurfaces(ref);

  switch (failure.kind) {
    case ScanFailureKind.quotaExhausted:
      await _showQuotaSheet(context, ref, failure.scanLimit ?? 0);
    case ScanFailureKind.unauthenticated:
      _snack(context, l10n.calorieSignInRequired);
    case ScanFailureKind.imageTooLarge:
      _snack(context, l10n.calorieImageTooLarge);
    case ScanFailureKind.refused:
      _snack(context, l10n.calorieScanRefused);
    case ScanFailureKind.unconfigured:
      _snack(context, l10n.calorieScannerUnavailable);
    case ScanFailureKind.upstream:
    case ScanFailureKind.network:
      _snack(context, l10n.calorieScanFailedRetry);
  }
}

/// Out of scans. Free users get the upgrade path; Pro users get told the
/// limit and nothing else, because there is nothing to sell them.
Future<void> _showQuotaSheet(
  BuildContext context,
  WidgetRef ref,
  int limit,
) async {
  final l10n = AppLocalizations.of(context);
  final quota = ref.read(scanQuotaProvider).value;
  final offerUpgrade = quota?.looksFree ?? (limit > 0 && limit <= 2);

  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 34, color: AppColors.neon),
          const SizedBox(height: 12),
          Text(
            l10n.calorieQuotaTitle(limit),
            textAlign: TextAlign.center,
            style: Theme.of(sheetContext)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            offerUpgrade
                ? l10n.calorieQuotaUpgradeBody
                : l10n.calorieQuotaProBody,
            textAlign: TextAlign.center,
            style: Theme.of(sheetContext).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          if (offerUpgrade)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.neon,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  context.push(AppRoutes.paywall);
                },
                child: Text(l10n.calorieQuotaUpgradeCta),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: Text(l10n.calorieQuotaDismiss),
            ),
          ),
        ],
      ),
    ),
  );
}

enum _ScanChoice { camera, gallery, barcode }

Future<_ScanChoice?> _pickSource(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<_ScanChoice>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.calorieSourceCamera),
            onTap: () => Navigator.pop(sheetContext, _ScanChoice.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.calorieSourceGallery),
            onTap: () => Navigator.pop(sheetContext, _ScanChoice.gallery),
          ),
          // Labelled as free, because that is the useful fact: it is the
          // one capture path that does not spend a daily scan.
          ListTile(
            leading: const Icon(Icons.qr_code_scanner),
            title: Text(l10n.calorieSourceBarcode),
            subtitle: Text(l10n.calorieSourceBarcodeHint),
            onTap: () => Navigator.pop(sheetContext, _ScanChoice.barcode),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// ────────────────────────────────────────────────────────────────────
// The result sheet — where a user corrects the estimate before it counts
// ────────────────────────────────────────────────────────────────────

/// Nothing is logged until Confirm.
///
/// This is the correction workflow the research doc (§1.2) identifies as
/// the actual product: every review of the category praises editing, and
/// with a documented 15–25% error rate an un-editable result would be
/// presenting a guess as a record.
class _ScanResultSheet extends ConsumerStatefulWidget {
  const _ScanResultSheet({required this.result});

  final FoodScanResult result;

  @override
  ConsumerState<_ScanResultSheet> createState() => _ScanResultSheetState();
}

class _ScanResultSheetState extends ConsumerState<_ScanResultSheet> {
  late final List<MealItem> _items = [...widget.result.items];
  MealSlot _slot = _slotForNow();
  bool _saving = false;

  /// Pre-selects the slot the clock suggests. A guess the user can change
  /// beats a required choice: most scans happen at mealtime.
  static MealSlot _slotForNow() {
    final h = DateTime.now().hour;
    if (h < 11) return MealSlot.breakfast;
    if (h < 16) return MealSlot.lunch;
    if (h < 22) return MealSlot.dinner;
    return MealSlot.snack;
  }

  int get _totalKcal => _items.fold(0, (s, i) => s + i.kcal);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              children: [
                Text(
                  l10n.calorieResultTitle,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.calorieResultSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                // A clarification is the model saying it could not tell.
                // It is shown as a prompt to edit, not as an error — the
                // research doc treats "ask a question" as the correct
                // low-confidence outcome.
                if (widget.result.clarification != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.help_outline,
                            size: 18, color: AppColors.orange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(widget.result.clarification!,
                              style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Text(l10n.calorieResultSlot, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
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
                for (var i = 0; i < _items.length; i++)
                  _EditableItemRow(
                    item: _items[i],
                    onChanged: (updated) => setState(() => _items[i] = updated),
                    onRemove: () => setState(() => _items.removeAt(i)),
                  ),

                if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(l10n.calorieResultAllRemoved,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.calorieResultTotal,
                          style: theme.textTheme.bodySmall),
                      Text(
                        l10n.calorieKcalValue(_totalKcal),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.neon,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.neon,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 14),
                  ),
                  onPressed: _items.isEmpty || _saving ? null : _confirm,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.calorieResultConfirm),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(calorieRepositoryProvider).logMeal(
            day: ref.read(selectedCalorieDayProvider),
            slot: _slot,
            source: MealSource.aiScan,
            items: _items,
          );
      refreshCalorieSurfaces(ref);
      if (!mounted) return;
      Navigator.of(context).pop();
      _snack(context, l10n.calorieMealLogged);
    } catch (e, st) {
      AppLogger.error('Logging scanned meal failed', e,
          stackTrace: st, category: 'calories');
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(context, l10n.calorieLogFailed);
    }
  }
}

/// One row the user can correct in place.
class _EditableItemRow extends StatelessWidget {
  const _EditableItemRow({
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final MealItem item;
  final ValueChanged<MealItem> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ConfidenceDot(confidence: item.confidence),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    if (item.portionLabel.isNotEmpty)
                      Text(item.portionLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.calorieRemoveItem,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _NumberField(
                  label: l10n.calorieKcal,
                  value: item.kcal,
                  onChanged: (v) =>
                      onChanged(item.copyWith(kcal: v, wasEdited: true)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NumberField(
                  label: l10n.calorieProteinShort,
                  value: item.proteinG,
                  onChanged: (v) =>
                      onChanged(item.copyWith(proteinG: v, wasEdited: true)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NumberField(
                  label: l10n.calorieCarbsShort,
                  value: item.carbsG,
                  onChanged: (v) =>
                      onChanged(item.copyWith(carbsG: v, wasEdited: true)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NumberField(
                  label: l10n.calorieFatShort,
                  value: item.fatG,
                  onChanged: (v) =>
                      onChanged(item.copyWith(fatG: v, wasEdited: true)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final _controller = TextEditingController(text: '${widget.value}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          labelText: widget.label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: const OutlineInputBorder(),
        ),
        onChanged: (raw) {
          // A half-typed field is not an error — an empty box while the
          // user clears it reads as 0 rather than as a validation failure.
          final parsed = int.tryParse(raw.trim());
          if (parsed != null && parsed >= 0) widget.onChanged(parsed);
          if (raw.trim().isEmpty) widget.onChanged(0);
        },
      );
}

// ────────────────────────────────────────────────────────────────────
// Manual entry
// ────────────────────────────────────────────────────────────────────

/// Adds a meal by hand — the escape hatch every failure path points at.
///
/// Costs no scan quota and needs no network beyond the write, which is
/// what makes it a real fallback rather than a second way to fail.
Future<void> startManualEntry(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ManualEntrySheet(),
    );

class _ManualEntrySheet extends ConsumerStatefulWidget {
  const _ManualEntrySheet();

  @override
  ConsumerState<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends ConsumerState<_ManualEntrySheet> {
  final _name = TextEditingController();
  final _portion = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  MealSlot _slot = MealSlot.snack;
  bool _saving = false;

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
            Text(l10n.calorieManualTitle,
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
                Expanded(
                  flex: 2,
                  child: _plainNumber(_kcal, l10n.calorieKcal),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: _plainNumber(_protein, l10n.calorieProteinShort)),
                const SizedBox(width: 8),
                Expanded(child: _plainNumber(_carbs, l10n.calorieCarbsShort)),
                const SizedBox(width: 8),
                Expanded(child: _plainNumber(_fat, l10n.calorieFatShort)),
              ],
            ),
            const SizedBox(height: 14),
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
                onPressed: _saving ? null : _save,
                child: Text(l10n.calorieManualSave),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _plainNumber(TextEditingController c, String label) => TextField(
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
    final name = _name.text.trim();
    final kcal = int.tryParse(_kcal.text.trim()) ?? 0;
    if (name.isEmpty || kcal <= 0) {
      _snack(context, l10n.calorieManualIncomplete);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(calorieRepositoryProvider).logMeal(
        day: ref.read(selectedCalorieDayProvider),
        slot: _slot,
        source: MealSource.manual,
        items: [
          MealItem(
            name: name,
            portionLabel: _portion.text.trim(),
            kcal: kcal,
            proteinG: int.tryParse(_protein.text.trim()) ?? 0,
            carbsG: int.tryParse(_carbs.text.trim()) ?? 0,
            fatG: int.tryParse(_fat.text.trim()) ?? 0,
            // A number the user typed themselves is not an estimate.
            confidence: ItemConfidence.high,
          ),
        ],
      );
      refreshCalorieSurfaces(ref);
      if (!mounted) return;
      Navigator.of(context).pop();
      _snack(context, l10n.calorieMealLogged);
    } catch (e, st) {
      AppLogger.error('Manual meal log failed', e,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/widgets/cached_image.dart';
import '../../../../core/widgets/error_card.dart';
import '../../../workout/models/workout_plan_model.dart';
import '../../../workout/providers/workout_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);

/// Tints assigned to each equipment card by ordinal. Kept aligned with
/// the order returned by `WorkoutRepository.getEquipmentPlans()`:
///   [chest, back, shoulders, biceps, triceps, legs, core]
const List<Color> _equipmentTints = [
  _neon,
  Color(0xFF1FBF8F),
  _neonAccent,
  Color(0xFFFF6FB5),
  Color(0xFFFFB84D),
  Color(0xFF39FF14),
  Color(0xFFFF4DDB),
];

Widget _resolveImage(String image) {
  final fallback = Container(
    color: Colors.white10,
    alignment: Alignment.center,
    child: const Icon(Icons.fitness_center, color: Colors.white54),
  );
  if (image.startsWith('http')) {
    return CachedImage(
      url: image,
      fit: BoxFit.cover,
      memCacheHeight: 500,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
  return Image.asset(
    image,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => fallback,
  );
}

class EquipmentStrip extends ConsumerWidget {
  const EquipmentStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(equipmentPlansProvider);
    return SizedBox(
      height: 200,
      child: plansAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _neon),
        ),
        // Offline pass · was SizedBox.shrink(): the strip spun through
        // the HTTP timeout then vanished with no way to retry short of
        // leaving the tab. A compact retry card keeps the dashboard
        // honest about what failed.
        error: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ErrorCard(
            compact: true,
            message: 'Ekipman planları yüklenemedi.',
            onRetry: () => ref.invalidate(equipmentPlansProvider),
          ),
        ),
        data: (plans) {
          if (plans.isEmpty) return const SizedBox.shrink();
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: plans.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final plan = plans[index];
              final tint = _equipmentTints[index % _equipmentTints.length];
              return _EquipmentCard(plan: plan, tint: tint);
            },
          );
        },
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({required this.plan, required this.tint});

  final WorkoutPlan plan;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                tint.withValues(alpha: 0.85),
                tint.withValues(alpha: 0.45),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: 0.35),
                blurRadius: 16,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openPlan(context),
            child: Stack(
              children: [
                if (plan.image != null)
                  Positioned.fill(
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.2),
                        BlendMode.darken,
                      ),
                      child: _resolveImage(plan.image!),
                    ),
                  ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.45),
                          Colors.black.withValues(alpha: 0.88),
                        ],
                        stops: const [0.35, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        plan.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                          shadows: [
                            Shadow(blurRadius: 10, color: Colors.black87),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Material(
                          color: Colors.white,
                          shape: const StadiumBorder(),
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: () => _openPlan(context),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 9,
                              ),
                              child: Text(
                                'BAŞLA',
                                style: TextStyle(
                                  color: tint,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPlan(BuildContext context) {
    context.push(AppRoutes.planDetail, extra: plan);
  }
}

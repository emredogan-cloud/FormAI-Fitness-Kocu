import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/widgets/cached_image.dart';
import '../../../workout/models/workout_plan_model.dart';
import '../../../workout/providers/workout_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);

/// Tints assigned to each push-limits card by ordinal. Kept aligned with
/// the order returned by `WorkoutRepository.getPushLimitsPlans()`:
///   [abs_hiit, stronger_core, iron_pack, athletic_core]
const List<Color> _pushLimitsTints = [
  _neon,
  Color(0xFF1FBF8F),
  _neonAccent,
  Color(0xFFFF6FB5),
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

class PushLimitsStrip extends ConsumerWidget {
  const PushLimitsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(pushLimitsPlansProvider);
    return SizedBox(
      height: 200,
      child: plansAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _neon),
        ),
        // Empty state mirrors the loading shell — the dashboard already
        // has plenty of other content, so a silent fallback is preferable
        // to a red error banner here. The next FutureProvider rebuild
        // (e.g. on pull-to-refresh) will retry automatically.
        error: (_, __) => const SizedBox.shrink(),
        data: (plans) {
          if (plans.isEmpty) return const SizedBox.shrink();
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: plans.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final plan = plans[index];
              final tint = _pushLimitsTints[index % _pushLimitsTints.length];
              return _PushLimitsCard(plan: plan, tint: tint);
            },
          );
        },
      ),
    );
  }
}

class _PushLimitsCard extends StatelessWidget {
  const _PushLimitsCard({required this.plan, required this.tint});

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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/theme/theme_extension.dart';
import '../data/faq_content.dart';
import '../services/feedback_service.dart';
import 'feedback_sheet.dart';

const Color _neon = Color(0xFF8E5BFF);

/// Roadmap Phase 1 (C30) · searchable in-app help centre.
///
/// Sits above the feedback row in Settings so a user with a question
/// finds the answer before writing a ticket. Every category ends at the
/// same place: a "still stuck?" CTA into the feedback sheet, because a
/// help centre that dead-ends is worse than no help centre.
///
/// Scaffold + AppBar follow the Phase 53D convention — theme-driven
/// colours, dark-mode-only gradient halo.
class HelpCenterScreen extends ConsumerStatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  ConsumerState<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends ConsumerState<HelpCenterScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.helpCenterOpened();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openFeedback() async {
    final result = await showFeedbackSheet(
      context,
      initialSubject: FeedbackSubject.question,
    );
    if (result == null || !mounted) return;
    final base = result.transport == FeedbackTransport.supabase
        ? 'Mesajın iletildi. Teşekkürler!'
        : 'Mail uygulaman açıldı — gönderince ulaşır.';
    final reward = result.reward;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          reward == null ? base : '$base +${reward.xp} XP kazandın.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    final categories = searchFaq(_query);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        title: Text(
          'Yardım Merkezi',
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ),
      body: Container(
        decoration: isDark
            ? const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.85),
                  radius: 1.1,
                  colors: [Color(0xFF1E0A40), Color(0xFF0A0612), Colors.black],
                  stops: [0.0, 0.55, 1.0],
                ),
              )
            : BoxDecoration(color: scheme.surface),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _SearchField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 20),
              if (categories.isEmpty)
                _NoResults(query: _query, onAsk: _openFeedback)
              else
                for (final category in categories) ...[
                  _CategoryHeader(title: category.title),
                  const SizedBox(height: 8),
                  for (final entry in category.entries)
                    _FaqTile(
                        entry: entry, expandedByDefault: _query.isNotEmpty),
                  const SizedBox(height: 20),
                ],
              if (categories.isNotEmpty) _StillStuckCard(onTap: _openFeedback),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(color: scheme.onSurface, fontSize: 14.5),
      decoration: InputDecoration(
        hintText: 'Soru ara…',
        prefixIcon: Icon(
          Icons.search_rounded,
          color: scheme.onSurface.withValues(alpha: 0.45),
          size: 20,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : Semantics(
                button: true,
                label: 'Aramayı temizle',
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: scheme.onSurface.withValues(alpha: 0.45),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
              ),
        filled: true,
        fillColor: scheme.onSurface.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.onSurface.withValues(alpha: 0.10),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.onSurface.withValues(alpha: 0.10),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _neon, width: 1.4),
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: context.colors.onSurface.withValues(alpha: 0.5),
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.4,
      ),
    );
  }
}

/// Expandable Q&A row. `expandedByDefault` opens every tile while a
/// search is active — a user who searched already told us what they
/// want to read, so making them tap again is friction for nothing.
class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.entry, required this.expandedByDefault});

  final FaqEntry entry;
  final bool expandedByDefault;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Theme(
          // Strip the default divider so the card reads as one surface.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            // A ValueKey on the question keeps expansion state stable
            // across search-filter rebuilds.
            key: ValueKey('faq_${entry.question}'),
            initiallyExpanded: expandedByDefault,
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            expandedAlignment: Alignment.centerLeft,
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            iconColor: _neon,
            collapsedIconColor: scheme.onSurface.withValues(alpha: 0.4),
            title: Text(
              entry.question,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            children: [
              Text(
                entry.answer,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query, required this.onAsk});

  final String query;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 40,
            color: scheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 14),
          Text(
            '"$query" için sonuç yok',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sorunu bize doğrudan yazabilirsin — her mesaj okunur.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAsk,
            icon: const Icon(Icons.support_agent, size: 18),
            label: const Text('Soru Gönder'),
            style: FilledButton.styleFrom(
              backgroundColor: _neon,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StillStuckCard extends StatelessWidget {
  const _StillStuckCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Material(
      color: _neon.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _neon.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.support_agent, color: _neon, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cevabını bulamadın mı?',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Bize yaz — her mesaj okunur ve yanıtlanır.',
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.65),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

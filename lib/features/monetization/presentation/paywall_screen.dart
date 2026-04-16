import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

enum _Plan { weekly, yearly, monthly }

class _PaywallScreenState extends State<PaywallScreen> {
  static const Color _neon = Color(0xFF8E5BFF);
  static const Color _neonAccent = Color(0xFF4DA6FF);

  _Plan _selected = _Plan.yearly;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.4,
                  colors: [Color(0xFF1A0B3D), Colors.black],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHero(),
                    const SizedBox(height: 24),
                    _buildFeatures(),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 230,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        children: [
                          _PlanCard(
                            plan: _Plan.weekly,
                            isSelected: _selected == _Plan.weekly,
                            onTap: () =>
                                setState(() => _selected = _Plan.weekly),
                          ),
                          const SizedBox(width: 12),
                          _PlanCard(
                            plan: _Plan.yearly,
                            isSelected: _selected == _Plan.yearly,
                            onTap: () =>
                                setState(() => _selected = _Plan.yearly),
                          ),
                          const SizedBox(width: 12),
                          _PlanCard(
                            plan: _Plan.monthly,
                            isSelected: _selected == _Plan.monthly,
                            onTap: () =>
                                setState(() => _selected = _Plan.monthly),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '7 gün boyunca hiçbir ücret alınmayacaktır. '
                        'İstediğin zaman iptal edebilirsin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildCta(),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _close(context),
                      child: const Text(
                        'Şimdilik geç',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _CloseButton(onTap: () => _close(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_neon, _neonAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _neon.withValues(alpha: 0.5),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.workspace_premium,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'FormAI Premium',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tam yapay zeka koçluğunun kilidini aç. '
          'Her tekrar, her gün — hep yanında.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildFeatures() {
    const items = [
      ('Sınırsız AI Form Kontrolü', Icons.auto_awesome),
      ('Tüm Vücut Programları', Icons.fitness_center),
      ('Reklamsız, kesintisiz deneyim', Icons.block),
    ];
    return Column(
      children: [
        for (final item in items) ...[
          _FeatureRow(text: item.$1, icon: item.$2),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildCta() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.55),
            blurRadius: 26,
            spreadRadius: 1,
          ),
        ],
      ),
      child: FilledButton(
        onPressed: _simulatePurchase,
        style: FilledButton.styleFrom(
          backgroundColor: _neon,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
            fontSize: 15,
          ),
        ),
        child: const Text('7 GÜN ÜCRETSİZ BAŞLA'),
      ),
    );
  }

  void _simulatePurchase() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Deneme süresi başlatıldı'),
          backgroundColor: Color(0xFF2A1B5C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _close(context);
    });
  }

  void _close(BuildContext context) {
    context.go('/');
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.text, required this.icon});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _PaywallScreenState._neon.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _PaywallScreenState._neon.withValues(alpha: 0.6),
              width: 0.8,
            ),
          ),
          child: Icon(
            icon,
            color: _PaywallScreenState._neon,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  final _Plan plan;
  final bool isSelected;
  final VoidCallback onTap;

  String get _title => switch (plan) {
        _Plan.weekly => 'Haftalık',
        _Plan.yearly => 'Yıllık',
        _Plan.monthly => 'Aylık',
      };

  String get _price => switch (plan) {
        _Plan.weekly => '99 TL',
        _Plan.yearly => '999 TL',
        _Plan.monthly => '249 TL',
      };

  String get _perUnit => switch (plan) {
        _Plan.weekly => 'haftalık',
        _Plan.yearly => 'yıllık',
        _Plan.monthly => 'aylık',
      };

  String? get _accent => plan == _Plan.yearly ? '7 GÜN ÜCRETSİZ DENE' : null;

  String? get _hint => switch (plan) {
        _Plan.weekly => 'Kısa süreli deneme',
        _Plan.yearly => 'Ayda yalnızca ~83 TL',
        _Plan.monthly => 'Esnek aylık plan',
      };

  @override
  Widget build(BuildContext context) {
    final isYearly = plan == _Plan.yearly;
    final scale = isYearly ? 1.0 : 0.92;
    final width = isYearly ? 180.0 : 150.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 220),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: width,
              padding: const EdgeInsets.fromLTRB(14, 22, 14, 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? _PaywallScreenState._neon.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color:
                      isSelected ? _PaywallScreenState._neon : Colors.white24,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isYearly || isSelected
                    ? [
                        BoxShadow(
                          color: _PaywallScreenState._neon
                              .withValues(alpha: isYearly ? 0.55 : 0.3),
                          blurRadius: isYearly ? 22 : 14,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _title,
                    style: TextStyle(
                      color:
                          isSelected ? _PaywallScreenState._neon : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _price,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _perUnit,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_accent != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            _PaywallScreenState._neon,
                            _PaywallScreenState._neonAccent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _accent!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    )
                  else if (_hint != null)
                    Text(
                      _hint!,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                ],
              ),
            ),
            if (isYearly)
              Positioned(
                top: -10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          _PaywallScreenState._neon,
                          _PaywallScreenState._neonAccent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color:
                              _PaywallScreenState._neon.withValues(alpha: 0.6),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Text(
                      'TAVSİYE EDİLEN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      shape: const CircleBorder(
        side: BorderSide(color: Colors.white24, width: 1),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.close, color: Colors.white70, size: 18),
        ),
      ),
    );
  }
}

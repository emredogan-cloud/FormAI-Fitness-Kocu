import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

enum _Plan { monthly, yearly }

class _PaywallScreenState extends State<PaywallScreen> {
  static const Color _neon = Color(0xFF00F0FF);
  static const Color _gold = Color(0xFFFFD166);

  _Plan _selected = _Plan.yearly;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHero(),
                  const SizedBox(height: 24),
                  _buildFeatures(),
                  const SizedBox(height: 28),
                  _PlanCard(
                    plan: _Plan.monthly,
                    isSelected: _selected == _Plan.monthly,
                    onTap: () => setState(() => _selected = _Plan.monthly),
                  ),
                  const SizedBox(height: 12),
                  _PlanCard(
                    plan: _Plan.yearly,
                    isSelected: _selected == _Plan.yearly,
                    onTap: () => setState(() => _selected = _Plan.yearly),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _simulatePurchase,
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 15,
                      ),
                    ),
                    child: Text(
                      _selected == _Plan.yearly
                          ? "YILLIK PLAN'A BAŞLA"
                          : "AYLIK PLAN'A BAŞLA",
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'İstediğin zaman iptal edebilirsin. Otomatik yenilenir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
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
      children: const [
        Icon(Icons.workspace_premium, color: _gold, size: 56),
        SizedBox(height: 10),
        Text(
          'SixPack AI Pro',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Daha hızlı sonuç için AI seni yanlış formdan korusun.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildFeatures() {
    const items = [
      ('Tam Yapay Zeka Form Kontrolü', Icons.auto_awesome),
      ('Sınırsız Program', Icons.all_inclusive),
      ('Reklamsız Deneyim', Icons.block),
    ];
    return Column(
      children: [
        for (final item in items) ...[
          _FeatureRow(text: item.$1, icon: item.$2),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  void _simulatePurchase() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Satın alma simüle edildi'),
          backgroundColor: Color(0xFF0A3A50),
          behavior: SnackBarBehavior.floating,
        ),
      );
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _close(context);
    });
  }

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _PaywallScreenState._neon.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _PaywallScreenState._neon.withValues(alpha: 0.6),
              width: 0.8,
            ),
          ),
          child: Icon(icon, color: _PaywallScreenState._neon, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
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

  @override
  Widget build(BuildContext context) {
    final isYearly = plan == _Plan.yearly;
    final accent =
        isYearly ? _PaywallScreenState._gold : _PaywallScreenState._neon;
    final borderColor = isSelected ? accent : Colors.white24;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? accent : Colors.white30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isYearly ? 'Yıllık' : 'Aylık',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (isYearly) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _PaywallScreenState._gold,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '%60 İNDİRİM',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isYearly
                          ? 'Yılda yalnızca 349 TL · ayda ~29 TL'
                          : 'Aylık yenilenir, istediğin zaman iptal et',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isYearly ? '349 TL' : '79 TL',
                style: TextStyle(
                  color: isSelected ? accent : Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

enum _Plan { monthly, yearly, quarterly }

class _PaywallScreenState extends State<PaywallScreen> {
  static const Color _neon = Color(0xFF8E5BFF);
  static const Color _neonAccent = Color(0xFF4DA6FF);

  _Plan _selected = _Plan.yearly;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A0B3D), Colors.black],
                stops: [0.0, 0.55],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _HeroSection(),
                    const SizedBox(height: 24),
                    _buildPlansRow(),
                    const SizedBox(height: 18),
                    const _NoPaymentBadge(),
                    const SizedBox(height: 16),
                    _buildCta(),
                    const SizedBox(height: 12),
                    const _LegalFooter(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: _CloseButton(onTap: () => _close(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansRow() {
    return SizedBox(
      height: 230,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _PlanCard(
              plan: _Plan.monthly,
              isSelected: _selected == _Plan.monthly,
              onTap: () => setState(() => _selected = _Plan.monthly),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PlanCard(
              plan: _Plan.yearly,
              isSelected: _selected == _Plan.yearly,
              onTap: () => setState(() => _selected = _Plan.yearly),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PlanCard(
              plan: _Plan.quarterly,
              isSelected: _selected == _Plan.quarterly,
              onTap: () => setState(() => _selected = _Plan.quarterly),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCta() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.6),
            blurRadius: 32,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [_neon, _neonAccent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _simulatePurchase,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ücretsiz Denemeyi Başlatın',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    fontSize: 16,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
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

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF2A1B5C), Color(0xFF0E0729)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: _PaywallScreenState._neon.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _PaywallScreenState._neon.withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: const _TransformationPlaceholder(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [
              _PaywallScreenState._neon,
              _PaywallScreenState._neonAccent,
            ],
          ).createShader(rect),
          child: const Text(
            'Kişiselleştirilmiş planınızı alın!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Yapay zeka her tekrarını izlesin, formunu düzeltsin '
          've seni 30 günde hedefe taşısın.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.45),
        ),
      ],
    );
  }
}

class _TransformationPlaceholder extends StatelessWidget {
  const _TransformationPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.8,
              colors: [Color(0x668E5BFF), Colors.transparent],
            ),
          ),
        ),
        Positioned.fill(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Silhouette(
                opacity: 0.45,
                size: 100,
                label: 'BUGÜN',
                color: Colors.white60,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: _PaywallScreenState._neon,
                  size: 30,
                ),
              ),
              _Silhouette(
                opacity: 1,
                size: 120,
                label: '30 GÜN',
                color: _PaywallScreenState._neonAccent,
                glow: true,
              ),
            ],
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _PaywallScreenState._neon.withValues(alpha: 0.6),
                width: 0.6,
              ),
            ),
            child: const Text(
              'AI DESTEKLİ',
              style: TextStyle(
                color: _PaywallScreenState._neon,
                fontSize: 10,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Silhouette extends StatelessWidget {
  const _Silhouette({
    required this.opacity,
    required this.size,
    required this.label,
    required this.color,
    this.glow = false,
  });

  final double opacity;
  final double size;
  final String label;
  final Color color;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.accessibility_new,
          color: color.withValues(alpha: opacity),
          size: size,
          shadows: glow
              ? [
                  Shadow(
                    color: color.withValues(alpha: 0.7),
                    blurRadius: 20,
                  ),
                ]
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
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

  bool get _isHighlighted => plan == _Plan.yearly;

  String get _title => switch (plan) {
        _Plan.monthly => '1 Ay',
        _Plan.yearly => '12 Ay',
        _Plan.quarterly => '3 Ay',
      };

  String get _price => switch (plan) {
        _Plan.monthly => '₺249,99',
        _Plan.yearly => '₺999,99',
        _Plan.quarterly => '₺499,99',
      };

  String get _per => switch (plan) {
        _Plan.monthly => '/ ay',
        _Plan.yearly => '/ yıl',
        _Plan.quarterly => '/ 3 ay',
      };

  String? get _decoy => plan == _Plan.yearly ? '₺2.999,99 idi' : null;

  @override
  Widget build(BuildContext context) {
    final cardHeight = _isHighlighted ? 220.0 : 180.0;
    final borderColor = isSelected
        ? _PaywallScreenState._neon
        : (_isHighlighted ? _PaywallScreenState._neon : Colors.white24);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 230,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: cardHeight,
              padding: const EdgeInsets.fromLTRB(10, 18, 10, 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? _PaywallScreenState._neon.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: borderColor,
                  width: isSelected || _isHighlighted ? 2 : 1,
                ),
                boxShadow: _isHighlighted || isSelected
                    ? [
                        BoxShadow(
                          color: _PaywallScreenState._neon.withValues(
                            alpha: _isHighlighted ? 0.55 : 0.3,
                          ),
                          blurRadius: _isHighlighted ? 22 : 14,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _title,
                    style: TextStyle(
                      color: isSelected
                          ? _PaywallScreenState._neon
                          : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _price,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: _isHighlighted ? 22 : 18,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _per,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                      if (_decoy != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _decoy!,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.white60,
                            decorationThickness: 2,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? _PaywallScreenState._neon
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? _PaywallScreenState._neon
                            : Colors.white38,
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          )
                        : null,
                  ),
                ],
              ),
            ),
            if (_isHighlighted)
              Positioned(
                top: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        _PaywallScreenState._neon,
                        _PaywallScreenState._neonAccent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _PaywallScreenState._neon.withValues(alpha: 0.7),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Text(
                    'POPÜLER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
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

class _NoPaymentBadge extends StatelessWidget {
  const _NoPaymentBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _PaywallScreenState._neon.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _PaywallScreenState._neon,
                    _PaywallScreenState._neonAccent,
                  ],
                ),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Şimdi ödeme yok!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '7 günlük ücretsiz deneme süresinin sonunda seçtiğin abonelik '
        'otomatik başlar. Deneme süresi içinde ayarlardan istediğin zaman '
        'iptal edebilirsin.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white38, fontSize: 10.5, height: 1.4),
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

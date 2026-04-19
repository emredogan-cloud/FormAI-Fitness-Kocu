import 'package:flutter/material.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);

class PhotoOptionCard extends StatelessWidget {
  const PhotoOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.fallbackIcon,
    this.image,
  });

  final String? image;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? _neon : Colors.white24;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(20),
            color: selected
                ? _neon.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.03),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _neon.withValues(alpha: 0.35),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        fallbackIcon,
                        color: selected ? _neon : Colors.white70,
                        size: 26,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Icon(
                        selected ? Icons.check_circle : Icons.chevron_right,
                        color: selected ? _neon : Colors.white24,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: image != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildPhoto(image!, fallbackIcon),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.black.withValues(alpha: 0.35),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _neon.withValues(
                                alpha: selected ? 0.45 : 0.22,
                              ),
                              _neonAccent.withValues(
                                alpha: selected ? 0.25 : 0.08,
                              ),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            fallbackIcon,
                            color: Colors.white.withValues(alpha: 0.85),
                            size: 56,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoto(String src, IconData fallbackIcon) {
    final fb = Container(
      color: Colors.white10,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: Colors.white54, size: 36),
    );
    if (src.startsWith('http')) {
      return Image.network(
        src,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : Container(color: Colors.white10),
        errorBuilder: (_, __, ___) => fb,
      );
    }
    return Image.asset(
      src,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fb,
    );
  }
}

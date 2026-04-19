import 'package:flutter/material.dart';

const Color _neon = Color(0xFF8E5BFF);

class WheelColumn extends StatelessWidget {
  const WheelColumn({
    super.key,
    required this.label,
    required this.controller,
    required this.min,
    required this.max,
    required this.current,
    required this.onChanged,
  });

  final String label;
  final FixedExtentScrollController controller;
  final int min;
  final int max;
  final int current;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            letterSpacing: 3,
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: _neon.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    bottom: BorderSide(
                      color: _neon.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: controller,
                itemExtent: 56,
                perspective: 0.003,
                diameterRatio: 1.6,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) => onChanged(min + i),
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: max - min + 1,
                  builder: (context, i) {
                    final value = min + i;
                    final selected = value == current;
                    return Center(
                      child: Text(
                        '$value',
                        style: TextStyle(
                          color: selected ? _neon : Colors.white54,
                          fontSize: selected ? 36 : 24,
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w500,
                          shadows: selected
                              ? [Shadow(blurRadius: 14, color: _neon)]
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

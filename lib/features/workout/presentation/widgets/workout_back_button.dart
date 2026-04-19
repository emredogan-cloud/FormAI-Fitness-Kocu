import 'package:flutter/material.dart';

class WorkoutBackButton extends StatelessWidget {
  const WorkoutBackButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(
        side: BorderSide(color: Color(0xFF00F0FF), width: 1),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF00F0FF),
            size: 16,
          ),
        ),
      ),
    );
  }
}

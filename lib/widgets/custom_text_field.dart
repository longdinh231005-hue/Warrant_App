import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A reusable text field with an uppercase label, prefix icon, and optional
/// suffix (e.g. visibility toggle).
class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.label,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.controller,
    this.validator,
    this.onChanged,
  });

  final String label;
  final String hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label ───────────────────────────────────────────────────
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),

        // ── Input ───────────────────────────────────────────────────
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 16, right: 12),
                    child: Icon(prefixIcon, size: 20, color: AppColors.textHint),
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

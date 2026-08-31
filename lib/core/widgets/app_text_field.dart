import 'package:flutter/material.dart';

/// Standard text input with label, validation, and optional obscure toggle.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.keyboardType,
    this.obscure = false,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.autocorrect,
    this.enableSuggestions,
  });

  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscure;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool? autocorrect;
  final bool? enableSuggestions;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmail = widget.keyboardType == TextInputType.emailAddress;
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscure && _obscured,
      autocorrect: widget.autocorrect ?? !widget.obscure && !isEmail,
      enableSuggestions:
          widget.enableSuggestions ?? !widget.obscure && !isEmail,
      enableInteractiveSelection: true,
      smartDashesType:
          isEmail ? SmartDashesType.disabled : SmartDashesType.enabled,
      smartQuotesType:
          isEmail ? SmartQuotesType.disabled : SmartQuotesType.enabled,
      textCapitalization: (isEmail || widget.obscure)
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      cursorColor: theme.colorScheme.primary,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onSubmitted,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: widget.label,
        floatingLabelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary,
        ),
        suffixIcon: widget.obscure
            ? IconButton(
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : null,
      ),
    );
  }
}

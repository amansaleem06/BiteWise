import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/locale_currency.dart';

/// Searchable list of fiat currencies for the create-post price field.
class CurrencyPickerSheet extends StatefulWidget {
  const CurrencyPickerSheet({super.key, required this.selected});

  final AppCurrency selected;

  static Future<AppCurrency?> show(
    BuildContext context, {
    required AppCurrency selected,
  }) {
    return showModalBottomSheet<AppCurrency>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CurrencyPickerSheet(selected: selected),
    );
  }

  @override
  State<CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<CurrencyPickerSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matches(AppCurrency c, String q) {
    if (q.isEmpty) return true;
    return c.code.toLowerCase().contains(q) ||
        c.name.toLowerCase().contains(q) ||
        c.symbol.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _query.text.trim().toLowerCase();
    final suggested = [
      for (final c in LocaleCurrency.suggested)
        if (_matches(c, q)) c,
    ];
    final suggestedCodes = {for (final c in suggested) c.code};
    final rest = [
      for (final c in LocaleCurrency.all)
        if (_matches(c, q) && !suggestedCodes.contains(c.code)) c,
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Currency',
                    style: GoogleFonts.fraunces(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _query,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search forint, euro, HUF…',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                children: [
                  if (suggested.isNotEmpty && q.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Text(
                        'Suggested',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  for (final c in suggested) _tile(c),
                  if (rest.isNotEmpty && q.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        'All currencies',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  for (final c in rest) _tile(c),
                  if (suggested.isEmpty && rest.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No currency matches that search.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tile(AppCurrency c) {
    final selected = c.code == widget.selected.code;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryLight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            c.symbol,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ),
      ),
      title: Text(c.name),
      subtitle: Text(c.code),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: AppColors.primary)
          : null,
      onTap: () => Navigator.pop(context, c),
    );
  }
}

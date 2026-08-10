import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../restaurants/domain/entities/restaurant.dart';
import '../providers/reservation_providers.dart';

/// Reservation request sheet: date, time, party size, note.
class BookingSheet extends ConsumerStatefulWidget {
  const BookingSheet({super.key, required this.restaurant});

  final Restaurant restaurant;

  static void show(BuildContext context, Restaurant restaurant) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => BookingSheet(restaurant: restaurant),
      );

  @override
  ConsumerState<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<BookingSheet> {
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 19, minute: 0);
  int _partySize = 2;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  DateTime get _dateTime => DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    final error = await ref.read(bookingControllerProvider.notifier).submit(
          restaurantId: widget.restaurant.id,
          restaurantName: widget.restaurant.name,
          restaurantLogoUrl: widget.restaurant.logoUrl,
          dateTime: _dateTime,
          partySize: _partySize,
          note: _note.text,
        );
    if (!mounted) return;
    if (error != null) {
      AppSnackbar.error(context, error);
    } else {
      Navigator.of(context).pop();
      AppSnackbar.success(
        context,
        'Request sent! You\'ll be notified when ${widget.restaurant.name} responds.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submitting = ref.watch(bookingControllerProvider).isLoading;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reserve at ${widget.restaurant.name}',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _PickerTile(
                  icon: Icons.calendar_today_rounded,
                  label: DateFormat.MMMEd().format(_date),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _PickerTile(
                  icon: Icons.schedule_rounded,
                  label: _time.format(context),
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text('Party size', style: theme.textTheme.titleSmall),
              const Spacer(),
              IconButton(
                onPressed: _partySize > 1
                    ? () => setState(() => _partySize--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '$_partySize',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: _partySize < 20
                    ? () => setState(() => _partySize++)
                    : null,
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _note,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'Allergies, occasion, seating preference…',
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Request reservation',
            isLoading: submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryDark),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

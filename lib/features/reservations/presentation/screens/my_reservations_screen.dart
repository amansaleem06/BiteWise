import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/reservation.dart';
import '../providers/reservation_providers.dart';

/// The viewer's reservations: upcoming and history.
class MyReservationsScreen extends ConsumerWidget {
  const MyReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reservationsAsync = ref.watch(myReservationsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reservations'),
          bottom: TabBar(
            labelStyle: theme.textTheme.titleSmall,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [Tab(text: 'Upcoming'), Tab(text: 'History')],
          ),
        ),
        body: reservationsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          error: (_, __) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(myReservationsProvider),
              child: const Text(AppStrings.retry),
            ),
          ),
          data: (all) {
            final upcoming = all.where((r) => r.isUpcoming).toList()
              ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
            final history =
                all.where((r) => !r.isUpcoming).toList();
            return TabBarView(
              children: [
                _ReservationList(
                  reservations: upcoming,
                  emptyText:
                      'No upcoming reservations.\nFind a restaurant and tap Reserve!',
                  canCancel: true,
                ),
                _ReservationList(
                  reservations: history,
                  emptyText: 'No past reservations yet.',
                  canCancel: false,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReservationList extends ConsumerWidget {
  const _ReservationList({
    required this.reservations,
    required this.emptyText,
    required this.canCancel,
  });

  final List<Reservation> reservations;
  final String emptyText;
  final bool canCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (reservations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            emptyText,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: reservations.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => _ReservationCard(
        reservation: reservations[i],
        canCancel: canCancel,
      ),
    );
  }
}

class _ReservationCard extends ConsumerWidget {
  const _ReservationCard({
    required this.reservation,
    required this.canCancel,
  });

  final Reservation reservation;
  final bool canCancel;

  (Color, Color) _statusColors(BuildContext context) =>
      switch (reservation.status) {
        ReservationStatus.pending => (
            AppColors.ratingStar.withValues(alpha: 0.18),
            const Color(0xFF92600A),
          ),
        ReservationStatus.confirmed => (
            AppColors.accentLight,
            AppColors.accent,
          ),
        ReservationStatus.completed => (
            Theme.of(context).colorScheme.surfaceContainerHighest,
            Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        _ => (
            AppColors.error.withValues(alpha: 0.12),
            AppColors.error,
          ),
      };

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel reservation?'),
        content: Text(
          '${reservation.restaurantName} · '
          '${DateFormat.MMMEd().add_jm().format(reservation.dateTime)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Cancel reservation',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(reservationRepositoryProvider).cancel(reservation.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (chipBg, chipFg) = _statusColors(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => context
                      .push(Routes.restaurantPath(reservation.restaurantId)),
                  child: CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: reservation.restaurantLogoUrl != null
                        ? CachedNetworkImageProvider(
                            reservation.restaurantLogoUrl!,)
                        : null,
                    child: reservation.restaurantLogoUrl == null
                        ? const Icon(
                            Icons.storefront_outlined,
                            color: AppColors.primaryDark,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    reservation.restaurantName,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    reservation.status.label,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: chipFg, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  DateFormat.MMMEd().add_jm().format(reservation.dateTime),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(width: AppSpacing.md),
                const Icon(
                  Icons.group_outlined,
                  size: 16,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text('${reservation.partySize}',
                    style: theme.textTheme.bodyMedium,),
              ],
            ),
            if (reservation.note != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                reservation.note!,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (canCancel && reservation.status.isActive) ...[
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _confirmCancel(context, ref),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

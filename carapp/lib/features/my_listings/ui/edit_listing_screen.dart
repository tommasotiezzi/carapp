import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../sell/data/sell_repository.dart';
import '../../sell/ui/sell_details_screen.dart';
import '../data/my_listings_repository.dart';
import '../state/my_listings_controller.dart';

/// The listing's data for "Modifica annuncio" (one request).
final listingForEditProvider = FutureProvider.autoDispose.family(
  (ref, String id) => ref.watch(myListingsRepositoryProvider).fetchForEdit(id),
);

/// `/listing/:id/edit`: the sell form on an online (or sold) listing.
/// Media stay as they are; data and price are saved with one update.
class EditListingScreen extends ConsumerWidget {
  const EditListingScreen({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final data = ref.watch(listingForEditProvider(listingId));
    final value = data.value;

    if (value == null || value.status == 'removed') {
      final loading = data.isLoading;
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(),
        body: Center(
          child: loading
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(data.hasError ? t.errorBody : t.editListingNotFound, textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.l),
                      if (data.hasError)
                        FilledButton(
                          onPressed: () => ref.invalidate(listingForEditProvider(listingId)),
                          child: Text(t.commonRetry),
                        )
                      else
                        FilledButton(onPressed: () => context.pop(), child: Text(t.commonClose)),
                    ],
                  ),
                ),
        ),
      );
    }

    final controller = ref.read(myListingsProvider.notifier);
    final sellRepo = ref.read(sellRepositoryProvider);
    return SellDetailsScreen(
      edit: ListingEdit(
        listingId: listingId,
        categoryId: value.categoryId,
        details: value.details,
        onSave: (details, {newPhone}) async {
          if (newPhone != null) await sellRepo.saveSellerPhone(newPhone);
          await controller.saveDetails(listingId, details);
        },
      ),
    );
  }
}

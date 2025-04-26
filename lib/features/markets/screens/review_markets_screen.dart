import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/market.dart';
import '../../../widgets/app_layout.dart';
import '../providers/review_markets_provider.dart';

class ReviewMarketsScreen extends ConsumerWidget {
  const ReviewMarketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewState = ref.watch(reviewMarketsProvider);
    final reviewNotifier = ref.read(reviewMarketsProvider.notifier);

    return AppLayout(
      title: 'Review New Markets',
      body: RefreshIndicator(
        onRefresh: () => reviewNotifier.loadPendingMarkets(),
        child: reviewState.isLoading && reviewState.pendingMarkets.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : reviewState.error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: ${reviewState.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => reviewNotifier.loadPendingMarkets(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : reviewState.pendingMarkets.isEmpty
                    ? Center(
                        child: Text(
                          'No markets are currently pending review.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    : ListView.builder(
                        itemCount: reviewState.pendingMarkets.length,
                        itemBuilder: (context, index) {
                          final market = reviewState.pendingMarkets[index];
                          return MarketReviewCard(market: market);
                        },
                      ),
      ),
    );
  }
}

class MarketReviewCard extends ConsumerWidget {
  final Market market;
  const MarketReviewCard({super.key, required this.market});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewNotifier = ref.read(reviewMarketsProvider.notifier);
    bool isProcessing = false; // Local state for button loading

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(market.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(market.address ?? 'No address provided'),
            const SizedBox(height: 8),
            Text(
              'Location: ${market.location.latitude.toStringAsFixed(4)}, ${market.location.longitude.toStringAsFixed(4)}',
            ),
            if (market.notes != null && market.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Notes: ${market.notes}'),
              ),
            const Divider(height: 24),
            StatefulBuilder(
              builder: (context, setCardState) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              setCardState(() => isProcessing = true);
                              final success =
                                  await reviewNotifier.updateMarketStatus(
                                market.id,
                                MarketStatus.noNeed,
                              );
                              if (!success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Failed to decline market.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                              // No need to set isProcessing back to false here because the list will rebuild
                            },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Decline'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              setCardState(() => isProcessing = true);
                              final success =
                                  await reviewNotifier.updateMarketStatus(
                                market.id,
                                MarketStatus.toVisit,
                              );
                              if (!success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Failed to approve market.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Approve'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../modules/friendships/widgets/people_you_may_know_widget.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_indicator.dart';
import '../providers/home_feed_provider.dart';
import 'feed_item_widget.dart';

class FeedList extends StatefulWidget {
  const FeedList({Key? key}) : super(key: key);

  @override
  State<FeedList> createState() => _FeedListState();
}

class _FeedListState extends State<FeedList> {
  final ScrollController _scrollController = ScrollController();
  static const double _scrollThreshold = 200.0;

  @override
  void initState() {
    super.initState();
    _initializeFeed();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeFeed() {
    Future.microtask(() {
      if (!mounted) return;
      Provider.of<HomeFeedProvider>(context, listen: false).initFeed();
    });
  }

  void _onScroll() {
    final provider = Provider.of<HomeFeedProvider>(context, listen: false);
    final isScrolledNearBottom = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - _scrollThreshold;

    if (isScrolledNearBottom && !provider.isLoading && provider.hasMore) {
      provider.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeFeedProvider>(
      builder: (context, provider, _) {
        if (_isInitialLoading(provider)) {
          return const Center(child: LoadingIndicator());
        }

        if (_hasError(provider)) {
          return ErrorDisplay(
            message: provider.errorMessage,
            onRetry: () => provider.refreshFeed(),
          );
        }

        return _buildFeedList(provider);
      },
    );
  }

  bool _isInitialLoading(HomeFeedProvider provider) {
    return provider.status == FeedStatus.loading && provider.feedItems.isEmpty;
  }

  bool _hasError(HomeFeedProvider provider) {
    return provider.status == FeedStatus.error && provider.feedItems.isEmpty;
  }

  Widget _buildFeedList(HomeFeedProvider provider) {
    return RefreshIndicator(
      onRefresh: provider.refreshFeed,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _calculateItemCount(provider),
        separatorBuilder: (context, index) {
          if (index == 0) return const SizedBox.shrink();
          if (provider.hasMore && index == provider.feedItems.length) {
            return const SizedBox.shrink();
          }
          return const Divider(height: 1);
        },
        itemBuilder: (context, index) => _buildListItem(provider, index),
      ),
    );
  }

  int _calculateItemCount(HomeFeedProvider provider) {
    return provider.feedItems.length + 1 + (provider.hasMore ? 1 : 0);
  }

  Widget _buildListItem(HomeFeedProvider provider, int index) {
    if (index == 0) {
      return const PeopleYouMayKnowWidget();
    }

    final adjustedIndex = index - 1;

    if (adjustedIndex == provider.feedItems.length && provider.hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return FeedItemWidget(item: provider.feedItems[adjustedIndex]);
  }
}

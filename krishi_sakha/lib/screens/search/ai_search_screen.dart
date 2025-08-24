import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:krishi_sakha/widgets/url_modal.dart';
import 'package:krishi_sakha/widgets/youtube_player_dialog.dart';
import 'package:krishi_sakha/widgets/youtube_widget.dart';
import 'package:provider/provider.dart';
import 'package:krishi_sakha/providers/ai_search_provider.dart';
import 'package:krishi_sakha/utils/theme/colors.dart';
import 'package:url_launcher/url_launcher.dart';

class AISearchScreen extends StatefulWidget {
  const AISearchScreen({super.key});

  @override
  State<AISearchScreen> createState() => _AISearchScreenState();
}

class _AISearchScreenState extends State<AISearchScreen> {
  late AISearchProvider _searchProvider;

  @override
  void initState() {
    super.initState();
    _searchProvider = AISearchProvider();
    
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.primaryBlack,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.primaryBlack,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _searchProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AISearchProvider>.value(
      value: _searchProvider,
      child: Scaffold(
        backgroundColor: AppColors.primaryBlack,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              Expanded(
                child: Consumer<AISearchProvider>(
                  builder: (context, provider, child) {
                    if (!provider.hasSearched) {
                      return _buildWelcomeScreen();
                    }
                    
                    return _buildSearchResults(provider);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios,
              color: AppColors.primaryWhite,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'AI Search',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryWhite,
            ),
          ),
          const Spacer(),
          Consumer<AISearchProvider>(
            builder: (context, provider, child) {
              if (provider.hasSearched) {
                return IconButton(
                  onPressed: provider.clearSearch,
                  icon: const Icon(
                    Icons.refresh,
                    color: AppColors.primaryGreen,
                    size: 24,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Consumer<AISearchProvider>(
        builder: (context, provider, child) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: provider.isSearching 
                    ? AppColors.primaryGreen 
                    : Colors.grey.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: provider.searchController,
              style: const TextStyle(
                color: AppColors.primaryWhite,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Ask anything about farming...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: provider.isSearching 
                      ? AppColors.primaryGreen 
                      : Colors.grey.shade400,
                ),
                suffixIcon: provider.isSearching
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      )
                    : IconButton(
                        onPressed: provider.performSearch,
                        icon: Icon(
                          Icons.send,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              onSubmitted: (_) => provider.performSearch(),
              enabled: !provider.isSearching,
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          
          // Logo/Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.search,
              size: 50,
              color: AppColors.primaryGreen,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Welcome text
          const Text(
            'Welcome to AI Search',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryWhite,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Get instant answers with sources from across the web. Ask anything about farming, agriculture, or any topic you\'re curious about.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade300,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 48),
          
          // Suggested searches
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Try searching for:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryWhite,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          ..._buildSuggestedSearches(),
        ],
      ),
    );
  }

  List<Widget> _buildSuggestedSearches() {
    final suggestions = [
      '🌾 Best crops for monsoon season',
      '🚜 Modern farming techniques',
      '🌱 Organic fertilizer methods',
      '💧 Water conservation in agriculture',
      '🐛 Natural pest control solutions',
      '📈 Agricultural market trends',
    ];

    return suggestions.map((suggestion) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () {
            _searchProvider.searchController.text = suggestion.substring(2); // Remove emoji
            _searchProvider.performSearch();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Text(
                  suggestion,
                  style: const TextStyle(
                    color: AppColors.primaryWhite,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSearchResults(AISearchProvider provider) {
    return SingleChildScrollView(
      controller: provider.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status indicator
          if (provider.currentStatus.isNotEmpty)
            _buildStatusIndicator(provider.currentStatus),
          
          // Error handling
          if (provider.error != null)
            _buildErrorWidget(provider),
          
          // Query display
          if (provider.currentQuery.isNotEmpty)
            _buildQueryDisplay(provider.currentQuery),
          
          const SizedBox(height: 24),
          
          // AI Response
          if (provider.aiResponse.isNotEmpty) ...[
            _buildAIResponse(provider.aiResponse),
            
            if(provider.showMetadata) ... [

            // Add Sources and YouTube widgets inline with AI response
            if (provider.searchResults.isNotEmpty) ...[
              const SizedBox(height: 12),
              UrlDropDown(urls: provider.searchResults.map((r) => r.url).toList())
            ],
            
            if (provider.youtubeResults.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildYouTubeSection(provider.youtubeResults),
            ],
            ],
          ],
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primaryGreen.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(AISearchProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Search Error',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            provider.error!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: provider.retrySearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildQueryDisplay(String query) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.search,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Your Search',
                style: TextStyle(
                  color: AppColors.primaryWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            query,
            style: const TextStyle(
              color: AppColors.primaryWhite,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIResponse(String response) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryGreen.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI Answer',
                style: TextStyle(
                  color: AppColors.primaryWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            response,
            style: const TextStyle(
              color: AppColors.primaryWhite,
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // YouTube section similar to chat screen
  Widget _buildYouTubeSection(List<YouTubeResult> videos) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_fill, size: 16, color: Colors.red.shade300),
              const SizedBox(width: 4),
              Text(
                'YouTube Videos (${videos.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...videos.take(3).map((video) => youTubeVideoWidget(context, {
            'title': video.title,
            'url': video.url,
            'thumbnail': video.thumbnail,
            'duration': video.duration,
            'channel': video.channel,
            'channel_url': video.channelUrl,
            'views': video.views,
            'published': video.published,
          })),
        ]
      ),
    );
  }

}



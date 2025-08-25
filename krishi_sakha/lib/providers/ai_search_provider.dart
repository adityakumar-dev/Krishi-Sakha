import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:krishi_sakha/apis/api_manager.dart';

class SearchResult {
  final String title;
  final String content;
  final String url;
  final bool success;
  final String? error;

  SearchResult({
    required this.title,
    required this.content,
    required this.url,
    required this.success,
    this.error,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      title: json['title'] ?? 'Web Search Result',
      content: json['content'] ?? '',
      url: json['url'] ?? '',
      success: json['success'] ?? true,
      error: json['error'],
    );
  }

  // Create from URL string only
  factory SearchResult.fromUrl(String url) {
    return SearchResult(
      title: _extractDomainFromUrl(url),
      content: 'Click to view content',
      url: url,
      success: true,
    );
  }

  static String _extractDomainFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (e) {
      return 'Web Result';
    }
  }
}

class YouTubeResult {
  final String title;
  final String videoId;
  final String url;
  final String thumbnail;
  final String channel;
  final String channelUrl;
  final String duration;
  final String views;
  final String published;

  YouTubeResult({
    required this.title,
    required this.videoId,
    required this.url,
    required this.thumbnail,
    required this.channel,
    required this.channelUrl,
    required this.duration,
    required this.views,
    required this.published,
  });

  factory YouTubeResult.fromJson(Map<String, dynamic> json) {
    return YouTubeResult(
      title: json['title'] ?? '',
      videoId: json['video_id'] ?? '',
      url: json['url'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      channel: json['channel'] ?? '',
      channelUrl: json['channel_url'] ?? '',
      duration: json['duration'] ?? '',
      views: json['views'] ?? '',
      published: json['published'] ?? '',
    );
  }
}

class AISearchProvider extends ChangeNotifier {
  StreamSubscription<String>? _streamSubscription;
  String _incompleteJsonBuffer = ''; // Buffer for incomplete JSON chunks

  // State variables
  bool _isSearching = false;
  bool _hasSearched = false;
  String _currentQuery = '';
  String _aiResponse = '';
  String _currentStatus = '';
  List<SearchResult> _searchResults = [];
  List<YouTubeResult> _youtubeResults = [];
  String? _error;
  bool showMetadata = false;

  // Smart scrolling state
  bool _userManuallyScrolled = false;
  bool _isAtBottom = true;
  Timer? _scrollTimer;

  // Text controllers
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  AISearchProvider() {
    _initializeScrollListener();
  }

  void _initializeScrollListener() {
    _scrollController.addListener(() {
      _updateScrollState();
    });
  }

  void _updateScrollState() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = 50.0; // Pixels from bottom to consider "at bottom"

    final wasAtBottom = _isAtBottom;
    _isAtBottom = (maxScroll - currentScroll) <= threshold;

    // Detect if user manually scrolled up
    if (wasAtBottom && !_isAtBottom && _isSearching) {
      _userManuallyScrolled = true;
    }

    // Reset manual scroll flag when user returns to bottom
    if (_isAtBottom && _userManuallyScrolled) {
      _userManuallyScrolled = false;
    }
  }

  void _autoScroll() {
    if (!_scrollController.hasClients || _userManuallyScrolled) return;

    _scrollTimer?.cancel();
    _scrollTimer = Timer(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients && !_userManuallyScrolled) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Getters
  bool get isSearching => _isSearching;
  bool get hasSearched => _hasSearched;
  String get currentQuery => _currentQuery;
  String get aiResponse => _aiResponse;
  String get currentStatus => _currentStatus;
  List<SearchResult> get searchResults => List.unmodifiable(_searchResults);
  List<YouTubeResult> get youtubeResults => List.unmodifiable(_youtubeResults);
  String? get error => _error;
  TextEditingController get searchController => _searchController;
  ScrollController get scrollController => _scrollController;
  
  // Smart scroll getters
  bool get showScrollToBottom => _userManuallyScrolled && _isSearching;
  bool get isAtBottom => _isAtBottom;

  // Method to manually scroll to bottom and resume auto-scroll
  void scrollToBottomManually() {
    _userManuallyScrolled = false;
    _isAtBottom = true;
    _scrollTimer?.cancel();
    
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _scrollTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void clearSearch() {
    _searchController.clear();
    _currentQuery = '';
    _aiResponse = '';
    _currentStatus = '';
    _searchResults.clear();
    _youtubeResults.clear();
    _hasSearched = false;
    _error = null;
    _incompleteJsonBuffer = ''; // Clear buffer
    
    // Reset scroll state
    _userManuallyScrolled = false;
    _isAtBottom = true;
    _scrollTimer?.cancel();
    
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _isSearching) return;

    try {
      _isSearching = true;
      _hasSearched = true;
      _currentQuery = query;
      _aiResponse = '';
      _currentStatus = 'Initializing search...';
      _searchResults.clear();
      _youtubeResults.clear();
      _error = null;
      _incompleteJsonBuffer = ''; // Clear buffer for new search
      notifyListeners();

      // Scroll to top when starting new search
      _scrollToTop();

      await _startSearchStream(query);
    } catch (e) {
      _setError('Failed to start search: ${e.toString()}');
    }
  }

  void _scrollToTop() {
    // Reset scroll state for new search
    _userManuallyScrolled = false;
    _isAtBottom = true;
    _scrollTimer?.cancel();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _setError(String errorMessage) {
    _error = errorMessage;
    _currentStatus = '';
    _isSearching = false;
    notifyListeners();
  }

  Future<void> _startSearchStream(String query) async {
    try {
      showMetadata = false;
      notifyListeners();
      final request = http.Request(
        'POST',
        Uri.parse(ApiManager.baseUrl + ApiManager.searchUrl), // Use local URL for testing
      );

      // Remove authentication and ngrok headers for local testing
      request.headers['Content-Type'] = 'application/json';
      
      request.body = jsonEncode({
        'query': query,
      });

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('Search timeout. Please try again.'),
      );

      if (streamedResponse.statusCode == 401) {
        throw Exception('Authentication expired. Please log in again.');
      } else if (streamedResponse.statusCode == 500) {
        throw Exception('Server error. Please try again later.');
      } else if (streamedResponse.statusCode != 200) {
        throw Exception(
          'Network error (${streamedResponse.statusCode}). Please check your connection.',
        );
      }

      await _streamSubscription?.cancel();

      _streamSubscription = streamedResponse.stream
          .transform(utf8.decoder)
          .listen(
            _handleStreamChunk,
            onError: (error) {
              _setError('Connection error: ${error.toString()}');
            },
            onDone: () {
              _streamSubscription = null;
              if (_isSearching) {
                _completeSearch();
              }
            },
            cancelOnError: false,
          );
    } catch (e) {
      _setError('Failed to perform search: ${e.toString()}');
    }
  }

  void _handleStreamChunk(String chunk) {
    if (chunk.isEmpty) return;

    debugPrint('🔍 RAW SEARCH CHUNK: $chunk');

    try {
      // Add chunk to buffer
      _incompleteJsonBuffer += chunk;
      
      // Process complete lines from buffer
      final lines = _incompleteJsonBuffer.split('\n');
      
      // Keep the last line in buffer if it doesn't end with newline
      if (!_incompleteJsonBuffer.endsWith('\n')) {
        _incompleteJsonBuffer = lines.last;
        lines.removeLast();
      } else {
        _incompleteJsonBuffer = '';
      }
      
      for (final line in lines) {
        _processCompleteLine(line);
      }
    } catch (e) {
      debugPrint('❌ Error in _handleStreamChunk: $e');
    }
  }

  void _processCompleteLine(String line) {
    try {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) return;

      String jsonStr = trimmedLine;
      if (jsonStr.startsWith('data: ')) {
        jsonStr = jsonStr.substring(6).trim();
      }

      if (jsonStr.isEmpty || jsonStr == '[DONE]') return;

      dynamic data;
      try {
        data = jsonDecode(jsonStr);
      } catch (e) {
        debugPrint('❌ JSON DECODE ERROR: $e for: $jsonStr');
        return;
      }

      if (data == null || data is! Map<String, dynamic>) {
        debugPrint('❌ DATA NOT MAP: $data (type: ${data.runtimeType})');
        return;
      }

      final type = data['type'];
      if (type == null || type is! String) {
        debugPrint('❌ TYPE MISSING OR NOT STRING: $type');
        return;
      }
      
      if(type != 'text'){
        debugPrint('🔍 SEARCH CHUNK TYPE: $type');
        debugPrint('🔍 SEARCH CHUNK DATA: $data');
      }
      
      switch (type) {
        case 'status':
          final message = data['message'];
          if (message != null && message is String && message.isNotEmpty) {
            _currentStatus = message;
            debugPrint('📊 Status: $message');
            notifyListeners();
          }
          break;

        case 'urls':
          final urls = data['urls'];
          debugPrint('🔗 Raw URLs data: $urls (type: ${urls.runtimeType})');
          if (urls != null && urls is List) {
            debugPrint('🔗 Processing ${urls.length} URLs: $urls');
            _searchResults.clear();
            for (final url in urls) {
              try {
                debugPrint('🔗 Processing URL: $url (type: ${url.runtimeType})');
                if (url is String) {
                  final searchResult = SearchResult.fromUrl(url);
                  _searchResults.add(searchResult);
                  debugPrint('🔗 Added URL result: ${searchResult.url}');
                } else if (url is Map<String, dynamic>) {
                  final searchResult = SearchResult.fromJson(url);
                  _searchResults.add(searchResult);
                  debugPrint('🔗 Added JSON result: ${searchResult.url}');
                }
              } catch (e) {
                debugPrint('❌ Error parsing URL: $e');
              }
            }
            debugPrint('🔗 Total search results: ${_searchResults.length}');
            notifyListeners();
          } else {
            debugPrint('❌ URLs data is null or not a list');
          }
          break;

        case 'youtube':
          final results = data['results'];
          debugPrint('🎥 Raw YouTube data: $results (type: ${results.runtimeType})');
          if (results != null && results is List) {
            debugPrint('🎥 Processing ${results.length} YouTube results: $results');
            _youtubeResults.clear();
            for (final video in results) {
              try {
                debugPrint('🎥 Processing video: $video (type: ${video.runtimeType})');
                if (video is Map<String, dynamic>) {
                  final youtubeResult = YouTubeResult.fromJson(video);
                  _youtubeResults.add(youtubeResult);
                  debugPrint('🎥 Added YouTube result: ${youtubeResult.title}');
                }
              } catch (e) {
                debugPrint('❌ Error parsing YouTube result: $e');
              }
            }
            debugPrint('🎥 Total YouTube results: ${_youtubeResults.length}');
            notifyListeners();
          } else {
            debugPrint('❌ YouTube results data is null or not a list');
          }
          break;

        case 'text':
          final textChunk = data['chunk'];
          if (textChunk != null && textChunk is String) {
            _aiResponse += textChunk;
            notifyListeners();
            
            // Smart auto-scroll
            _autoScroll();
          }
          break;

        case 'complete':
          debugPrint('✅ Search completed successfully');
          _completeSearch();
          break;

        case 'error':
          final errorMessage = data['message'] ?? 'Unknown error occurred';
          debugPrint('❌ Error: $errorMessage');
          _setError(errorMessage);
          break;
      }
    } catch (e) {
      debugPrint('❌ Error in _processCompleteLine: $e');
    }
  }

  void _completeSearch() {
    _isSearching = false;
    _currentStatus = 'Search completed';

    showMetadata = true;
    notifyListeners();
    
    // Clear status after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (_currentStatus == 'Search completed') {
        _currentStatus = '';
        notifyListeners();
      }
    });
  }

  void retrySearch() {
    if (_currentQuery.isNotEmpty) {
      _searchController.text = _currentQuery;
      performSearch();
    }
  }
}

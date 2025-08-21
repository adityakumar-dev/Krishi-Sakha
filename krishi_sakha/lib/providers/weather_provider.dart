import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:krishi_sakha/models/weather_model.dart';
import 'package:krishi_sakha/services/weather_service.dart';
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class WeatherProvider extends ChangeNotifier {
  static const String _weatherBoxName = 'weather_data';
  static const String _containerKey = 'weather_container';

  final WeatherService _weatherService = WeatherService();
  final Logger _logger = Logger();
  
  Box<WeatherDataContainer>? _weatherBox;
  WeatherDataContainer _weatherContainer = WeatherDataContainer.empty();
  
  // UI State
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isSearching = false;
  String? _error;
  List<CityLocation> _searchResults = [];
  
  // Current state
  int _currentCityIndex = 0;
  PageController? _pageController;
  Timer? _searchDebounceTimer;
  
  // Getters
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isSearching => _isSearching;
  String? get error => _error;
  List<CityLocation> get searchResults => _searchResults;
  List<CityLocation> get savedCities => _weatherContainer.savedCities;
  int get currentCityIndex => _currentCityIndex;
  WeatherDataContainer get weatherContainer => _weatherContainer;
  
  CityLocation? get currentCity {
    if (_weatherContainer.savedCities.isEmpty) return null;
    if (_currentCityIndex >= _weatherContainer.savedCities.length) return null;
    return _weatherContainer.savedCities[_currentCityIndex];
  }
  
  WeatherData? get currentWeatherData {
    final city = currentCity;
    if (city == null) return null;
    return _weatherContainer.getWeatherForCity(city);
  }

  PageController? get pageController => _pageController;

  WeatherProvider() {
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    try {
      _weatherBox = await Hive.openBox<WeatherDataContainer>(_weatherBoxName);
      _loadWeatherData();
    } catch (e) {
      _logger.e('Error initializing Hive: $e');
      _setError('Failed to initialize local storage');
    }
  }

  void _loadWeatherData() {
    try {
      final container = _weatherBox?.get(_containerKey);
      if (container != null) {
        _weatherContainer = container;
        _logger.i('Loaded weather data for ${_weatherContainer.savedCities.length} cities');
      }
      notifyListeners();
    } catch (e) {
      _logger.e('Error loading weather data: $e');
    }
  }

  Future<void> _saveWeatherData() async {
    try {
      await _weatherBox?.put(_containerKey, _weatherContainer);
    } catch (e) {
      _logger.e('Error saving weather data: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setRefreshing(bool refreshing) {
    _isRefreshing = refreshing;
    notifyListeners();
  }

  void _setSearching(bool searching) {
    _isSearching = searching;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Initialize the provider with current location
  Future<void> initializeWithCurrentLocation() async {
    _setLoading(true);
    _setError(null);

    try {
      // Check if we already have current location
      final hasCurrentLocation = _weatherContainer.savedCities
          .any((city) => city.isCurrentLocation);

      if (!hasCurrentLocation) {
        await _addCurrentLocationCity();
      }

      // If we have saved cities, load weather for all
      if (_weatherContainer.savedCities.isNotEmpty) {
        await _refreshAllWeatherData();
      }
    } catch (e) {
      _logger.e('Error initializing weather provider: $e');
      _setError('Failed to initialize weather data');
    } finally {
      _setLoading(false);
    }
  }

  /// Add current location as a city
  Future<void> _addCurrentLocationCity() async {
    try {
      final position = await _weatherService.getCurrentLocation();
      if (position != null) {
        final city = await _weatherService.getCityFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        if (city != null) {
          _weatherContainer = _weatherContainer.copyWith(
            savedCities: [city, ..._weatherContainer.savedCities],
          );
          await _saveWeatherData();
        }
      }
    } catch (e) {
      _logger.e('Error adding current location: $e');
    }
  }

  /// Refresh weather data for all saved cities
  Future<void> _refreshAllWeatherData() async {
    for (final city in _weatherContainer.savedCities) {
      if (_weatherContainer.isWeatherStale(city)) {
        await _fetchWeatherForCity(city);
      }
    }
  }

  /// Fetch weather data for a specific city
  Future<void> _fetchWeatherForCity(CityLocation city) async {
    try {
      final weatherData = await _weatherService.getWeatherData(city);
      if (weatherData != null) {
        _weatherContainer.updateWeatherForCity(city, weatherData);
        await _saveWeatherData();
        notifyListeners();
      }
    } catch (e) {
      _logger.e('Error fetching weather for ${city.name}: $e');
    }
  }

  /// Refresh current city weather
  Future<void> refreshCurrentWeather() async {
    final city = currentCity;
    if (city == null) return;

    _setRefreshing(true);
    _setError(null);

    try {
      await _fetchWeatherForCity(city);
    } catch (e) {
      _setError('Failed to refresh weather data');
    } finally {
      _setRefreshing(false);
    }
  }

  /// Refresh all cities weather
  Future<void> refreshAllWeather() async {
    _setRefreshing(true);
    _setError(null);

    try {
      await _refreshAllWeatherData();
    } catch (e) {
      _setError('Failed to refresh weather data');
    } finally {
      _setRefreshing(false);
    }
  }

  /// Search for cities with debouncing
  Future<void> searchCities(String query) async {
    // Cancel previous timer
    _searchDebounceTimer?.cancel();
    
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    // Set searching state immediately for UI feedback
    _setSearching(true);
    
    // Debounce the search
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await _weatherService.searchCities(query);
        _searchResults = results;
      } catch (e) {
        _logger.e('Error searching cities: $e');
        _setError('Failed to search cities');
        _searchResults = [];
      } finally {
        _setSearching(false);
      }
    });
  }

  /// Add a city to saved cities
  Future<void> addCity(CityLocation city) async {
    try {
      // Check if city already exists (with tolerance for slight coordinate differences)
      final existingCity = _weatherContainer.savedCities.firstWhere(
        (savedCity) => _isSameLocation(savedCity, city),
        orElse: () => CityLocation(
          name: '',
          country: '',
          state: '',
          latitude: 0,
          longitude: 0,
        ),
      );
      
      if (existingCity.name.isNotEmpty) {
        // City already exists, don't add duplicate
        return;
      }
      
      _weatherContainer.addCity(city);
      await _saveWeatherData();
      
      // Fetch weather data for the new city
      await _fetchWeatherForCity(city);
      
      notifyListeners();
    } catch (e) {
      _logger.e('Error adding city: $e');
      _setError('Failed to add city');
    }
  }

  bool _isSameLocation(CityLocation city1, CityLocation city2) {
    const double tolerance = 0.01; // ~1km tolerance
    return (city1.latitude - city2.latitude).abs() < tolerance &&
           (city1.longitude - city2.longitude).abs() < tolerance;
  }

  /// Remove a city from saved cities
  Future<void> removeCity(CityLocation city) async {
    try {
      _weatherContainer.removeCity(city);
      await _saveWeatherData();
      
      // Adjust current index if necessary
      if (_currentCityIndex >= _weatherContainer.savedCities.length) {
        _currentCityIndex = _weatherContainer.savedCities.length - 1;
      }
      if (_currentCityIndex < 0) _currentCityIndex = 0;
      
      notifyListeners();
    } catch (e) {
      _logger.e('Error removing city: $e');
      _setError('Failed to remove city');
    }
  }

  /// Set current city index
  void setCurrentCityIndex(int index) {
    if (index >= 0 && index < _weatherContainer.savedCities.length) {
      _currentCityIndex = index;
      notifyListeners();
    }
  }

  /// Set page controller
  void setPageController(PageController controller) {
    _pageController = controller;
  }

  /// Check if location permission is granted
  Future<bool> checkLocationPermission() async {
    return await _weatherService.isLocationPermissionGranted();
  }

  /// Check if location service is enabled
  Future<bool> checkLocationService() async {
    return await _weatherService.isLocationServiceEnabled();
  }

  /// Request location permission
  Future<LocationPermission> requestLocationPermission() async {
    return await _weatherService.requestLocationPermission();
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    return await _weatherService.openAppSettings();
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await _weatherService.openLocationSettings();
  }

  /// Get weather data for a city
  WeatherData? getWeatherForCity(CityLocation city) {
    return _weatherContainer.getWeatherForCity(city);
  }

  /// Check if city has weather data
  bool hasCityWeather(CityLocation city) {
    return _weatherContainer.hasCityWeather(city);
  }

  /// Check if weather data is stale
  bool isWeatherStale(CityLocation city) {
    return _weatherContainer.isWeatherStale(city);
  }

  /// Clear search results
  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _weatherService.dispose();
    _pageController?.dispose();
    super.dispose();
  }
}

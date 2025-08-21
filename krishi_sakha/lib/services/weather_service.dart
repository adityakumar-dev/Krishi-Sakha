import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:krishi_sakha/models/weather_model.dart';
import 'package:logger/logger.dart';

class WeatherService {
  static const String _openMeteoBaseUrl = 'https://api.open-meteo.com/v1';
  static const String _locationIqApiKey = "API_KEY";
  
  final Logger _logger = Logger();
  final http.Client _httpClient = http.Client();

  /// Get current device location
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _logger.w('Location services are disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _logger.w('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _logger.w('Location permissions are permanently denied');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );
    } catch (e) {
      _logger.e('Error getting current location: $e');
      return null;
    }
  }

  /// Get city name from coordinates
  Future<CityLocation?> getCityFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return CityLocation(
          name: placemark.locality ?? placemark.subAdministrativeArea ?? 'Unknown',
          country: placemark.country ?? 'Unknown',
          state: placemark.administrativeArea ?? '',
          latitude: latitude,
          longitude: longitude,
          isCurrentLocation: true,
        );
      }
    } catch (e) {
      _logger.e('Error getting city from coordinates: $e');
    }
    return null;
  }

  /// Search cities using LocationIQ Autocomplete API
  Future<List<CityLocation>> searchCities(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final url = Uri.parse(
        'https://api.locationiq.com/v1/autocomplete?key=$_locationIqApiKey&q=${Uri.encodeComponent(query)}&limit=10&dedupe=1',
      );

      final response = await _httpClient.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .where((item) => 
                item['class'] == 'place' || 
                item['class'] == 'boundary' ||
                (item['address'] != null && item['address']['city'] != null))
            .map((item) => CityLocation.fromLocationIQAutocomplete(item))
            .toList();
      } else if (response.statusCode == 429) {
        _logger.w('Rate limit exceeded for LocationIQ API. Please wait before making more searches.');
        throw Exception('Search rate limit exceeded. Please wait a moment and try again.');
      } else {
        _logger.e('Failed to search cities: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _logger.e('Error searching cities: $e');
      return [];
    }
  }

  /// Get weather data from Open-Meteo API
  Future<WeatherData?> getWeatherData(CityLocation city) async {
    try {
      final currentParams = {
        'latitude': city.latitude.toString(),
        'longitude': city.longitude.toString(),
        'current': [
          'temperature_2m',
          'relative_humidity_2m',
          'apparent_temperature',
          'precipitation',
          'weather_code',
          'cloud_cover',
          'surface_pressure',
          'wind_speed_10m',
          'wind_direction_10m',
          'uv_index',
          'visibility',
          'dew_point_2m',
        ].join(','),
        'daily': [
          'weather_code',
          'temperature_2m_max',
          'temperature_2m_min',
          'sunrise',
          'sunset',
          'uv_index_max',
          'precipitation_sum',
          'precipitation_probability_max',
          'wind_speed_10m_max',
          'wind_direction_10m_dominant',
          'relative_humidity_2m_mean',
          'surface_pressure_mean',
        ].join(','),
        'timezone': 'auto',
        'forecast_days': '14',
      };

      final uri = Uri.parse('$_openMeteoBaseUrl/forecast').replace(
        queryParameters: currentParams,
      );

      final response = await _httpClient.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Create weather data with proper structure
        final weatherData = WeatherData(
          cityName: city.name,
          country: city.country,
          latitude: city.latitude,
          longitude: city.longitude,
          timezone: data['timezone'] ?? '',
          current: CurrentWeather.fromJson(data['current'] ?? {}),
          dailyForecasts: _parseDailyForecasts(data['daily']),
          lastUpdated: DateTime.now(),
        );

        return weatherData;
      } else {
        _logger.e('Failed to fetch weather data: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.e('Error fetching weather data: $e');
      return null;
    }
  }

  List<DailyWeather> _parseDailyForecasts(Map<String, dynamic>? dailyData) {
    if (dailyData == null) return [];
    
    final timeList = dailyData['time'] as List?;
    if (timeList == null || timeList.isEmpty) return [];
    
    return List.generate(
      timeList.length,
      (index) => DailyWeather.fromJson(dailyData, index),
    );
  }

  /// Check if location permission is granted
  Future<bool> isLocationPermissionGranted() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always || 
           permission == LocationPermission.whileInUse;
  }

  /// Check if location service is enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Request location permission
  Future<LocationPermission> requestLocationPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }
Future<void> requestOnLocation()async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      await Geolocator.requestTemporaryFullAccuracy(purposeKey: 'location');
      _logger.w('Location services are disabled. Please enable them in settings.');
      return;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final newPermission = await Geolocator.requestPermission();
      if (newPermission == LocationPermission.denied) {
        _logger.w('Location permissions are denied. Cannot proceed.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _logger.w('Location permissions are permanently denied. Cannot proceed.');
      return;
    }
  }
  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  void dispose() {
    _httpClient.close();
  }
}

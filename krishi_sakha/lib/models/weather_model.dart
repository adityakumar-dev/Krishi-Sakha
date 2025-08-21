import 'package:hive/hive.dart';

part 'weather_model.g.dart';

@HiveType(typeId: 1)
class WeatherData extends HiveObject {
  @HiveField(0)
  final String cityName;

  @HiveField(1)
  final String country;

  @HiveField(2)
  final double latitude;

  @HiveField(3)
  final double longitude;

  @HiveField(4)
  final List<DailyWeather> dailyForecasts;

  @HiveField(5)
  final CurrentWeather current;

  @HiveField(6)
  final DateTime lastUpdated;

  @HiveField(7)
  final String timezone;

  WeatherData({
    required this.cityName,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.dailyForecasts,
    required this.current,
    required this.lastUpdated,
    required this.timezone,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      cityName: json['name'] ?? '',
      country: json['country'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      dailyForecasts: _parseDailyForecasts(json['daily']),
      current: CurrentWeather.fromJson(json['current'] ?? {}),
      lastUpdated: DateTime.now(),
      timezone: json['timezone'] ?? '',
    );
  }

  static List<DailyWeather> _parseDailyForecasts(Map<String, dynamic>? dailyData) {
    if (dailyData == null) return [];
    
    final timeList = dailyData['time'] as List?;
    if (timeList == null || timeList.isEmpty) return [];
    
    return List.generate(
      timeList.length,
      (index) => DailyWeather.fromJson(dailyData, index),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': cityName,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'daily': dailyForecasts.map((e) => e.toJson()).toList(),
      'current': current.toJson(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'timezone': timezone,
    };
  }

  bool get isDataStale {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);
    return difference.inHours > 1; // Consider stale after 1 hour
  }
}

@HiveType(typeId: 2)
class CurrentWeather extends HiveObject {
  @HiveField(0)
  final double temperature;

  @HiveField(1)
  final double feelsLike;

  @HiveField(2)
  final int humidity;

  @HiveField(3)
  final double pressure;

  @HiveField(4)
  final double windSpeed;

  @HiveField(5)
  final int windDirection;

  @HiveField(6)
  final double uvIndex;

  @HiveField(7)
  final double visibility;

  @HiveField(8)
  final String weatherCode;

  @HiveField(9)
  final String weatherDescription;

  @HiveField(10)
  final double cloudCover;

  @HiveField(11)
  final double precipitation;

  @HiveField(12)
  final double dewPoint;

  CurrentWeather({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.pressure,
    required this.windSpeed,
    required this.windDirection,
    required this.uvIndex,
    required this.visibility,
    required this.weatherCode,
    required this.weatherDescription,
    required this.cloudCover,
    required this.precipitation,
    required this.dewPoint,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      temperature: (json['temperature_2m'] ?? 0.0).toDouble(),
      feelsLike: (json['apparent_temperature'] ?? 0.0).toDouble(),
      humidity: (json['relative_humidity_2m'] ?? 0).toInt(),
      pressure: (json['surface_pressure'] ?? 0.0).toDouble(),
      windSpeed: (json['wind_speed_10m'] ?? 0.0).toDouble(),
      windDirection: (json['wind_direction_10m'] ?? 0).toInt(),
      uvIndex: (json['uv_index'] ?? 0.0).toDouble(),
      visibility: (json['visibility'] ?? 0.0).toDouble(),
      weatherCode: (json['weather_code'] ?? 0).toString(),
      weatherDescription: _getWeatherDescription((json['weather_code'] ?? 0).toInt()),
      cloudCover: (json['cloud_cover'] ?? 0.0).toDouble(),
      precipitation: (json['precipitation'] ?? 0.0).toDouble(),
      dewPoint: (json['dew_point_2m'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature_2m': temperature,
      'apparent_temperature': feelsLike,
      'relative_humidity_2m': humidity,
      'surface_pressure': pressure,
      'wind_speed_10m': windSpeed,
      'wind_direction_10m': windDirection,
      'uv_index': uvIndex,
      'visibility': visibility,
      'weather_code': int.parse(weatherCode),
      'cloud_cover': cloudCover,
      'precipitation': precipitation,
      'dew_point_2m': dewPoint,
    };
  }

  static String _getWeatherDescription(int code) {
    switch (code) {
      case 0:
        return 'Clear sky';
      case 1:
      case 2:
      case 3:
        return 'Partly cloudy';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 71:
      case 73:
      case 75:
        return 'Snow';
      case 80:
      case 81:
      case 82:
        return 'Rain showers';
      case 95:
        return 'Thunderstorm';
      default:
        return 'Unknown';
    }
  }
}

@HiveType(typeId: 3)
class DailyWeather extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final double temperatureMax;

  @HiveField(2)
  final double temperatureMin;

  @HiveField(3)
  final double precipitationSum;

  @HiveField(4)
  final double precipitationProbability;

  @HiveField(5)
  final double windSpeedMax;

  @HiveField(6)
  final int windDirection;

  @HiveField(7)
  final String weatherCode;

  @HiveField(8)
  final String weatherDescription;

  @HiveField(9)
  final double uvIndexMax;

  @HiveField(10)
  final double humidityAvg;

  @HiveField(11)
  final double pressureAvg;

  @HiveField(12)
  final DateTime sunrise;

  @HiveField(13)
  final DateTime sunset;

  DailyWeather({
    required this.date,
    required this.temperatureMax,
    required this.temperatureMin,
    required this.precipitationSum,
    required this.precipitationProbability,
    required this.windSpeedMax,
    required this.windDirection,
    required this.weatherCode,
    required this.weatherDescription,
    required this.uvIndexMax,
    required this.humidityAvg,
    required this.pressureAvg,
    required this.sunrise,
    required this.sunset,
  });

  factory DailyWeather.fromJson(Map<String, dynamic> json, int index) {
    return DailyWeather(
      date: DateTime.parse((json['time'] as List)[index]),
      temperatureMax: ((json['temperature_2m_max'] as List)[index] ?? 0.0).toDouble(),
      temperatureMin: ((json['temperature_2m_min'] as List)[index] ?? 0.0).toDouble(),
      precipitationSum: ((json['precipitation_sum'] as List)[index] ?? 0.0).toDouble(),
      precipitationProbability: ((json['precipitation_probability_max'] as List)[index] ?? 0.0).toDouble(),
      windSpeedMax: ((json['wind_speed_10m_max'] as List)[index] ?? 0.0).toDouble(),
      windDirection: ((json['wind_direction_10m_dominant'] as List)[index] ?? 0).toInt(),
      weatherCode: ((json['weather_code'] as List)[index] ?? 0).toString(),
      weatherDescription: CurrentWeather._getWeatherDescription(((json['weather_code'] as List)[index] ?? 0).toInt()),
      uvIndexMax: ((json['uv_index_max'] as List)[index] ?? 0.0).toDouble(),
      humidityAvg: ((json['relative_humidity_2m_mean'] as List)[index] ?? 0.0).toDouble(),
      pressureAvg: ((json['surface_pressure_mean'] as List)[index] ?? 0.0).toDouble(),
      sunrise: DateTime.parse((json['sunrise'] as List)[index]),
      sunset: DateTime.parse((json['sunset'] as List)[index]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'temperature_2m_max': temperatureMax,
      'temperature_2m_min': temperatureMin,
      'precipitation_sum': precipitationSum,
      'precipitation_probability_max': precipitationProbability,
      'wind_speed_10m_max': windSpeedMax,
      'wind_direction_10m_dominant': windDirection,
      'weather_code': int.parse(weatherCode),
      'uv_index_max': uvIndexMax,
      'relative_humidity_2m_mean': humidityAvg,
      'surface_pressure_mean': pressureAvg,
      'sunrise': sunrise.toIso8601String(),
      'sunset': sunset.toIso8601String(),
    };
  }
}

@HiveType(typeId: 4)
class CityLocation extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String country;

  @HiveField(2)
  final String state;

  @HiveField(3)
  final double latitude;

  @HiveField(4)
  final double longitude;

  @HiveField(5)
  final bool isCurrentLocation;

  @HiveField(6)
  final DateTime addedAt;

  CityLocation({
    required this.name,
    required this.country,
    required this.state,
    required this.latitude,
    required this.longitude,
    this.isCurrentLocation = false,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  factory CityLocation.fromJson(Map<String, dynamic> json) {
    return CityLocation(
      name: json['display_name']?.split(',')[0] ?? json['name'] ?? '',
      country: json['country'] ?? '',
      state: json['state'] ?? '',
      latitude: double.parse(json['lat'] ?? '0.0'),
      longitude: double.parse(json['lon'] ?? '0.0'),
    );
  }

  factory CityLocation.fromLocationIQAutocomplete(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};
    final displayPlace = json['display_place'] ?? '';
    
    // Extract city name - prefer display_place, then address name, then parse from display_name
    String cityName = displayPlace;
    if (cityName.isEmpty) {
      cityName = address['name'] ?? address['city'] ?? address['town'] ?? address['village'] ?? '';
    }
    if (cityName.isEmpty && json['display_name'] != null) {
      cityName = (json['display_name'] as String).split(',')[0].trim();
    }
    
    // Extract state/region
    String state = address['state'] ?? address['region'] ?? '';
    
    // Extract country
    String country = address['country'] ?? '';
    
    return CityLocation(
      name: cityName,
      country: country,
      state: state,
      latitude: double.parse(json['lat'] ?? '0.0'),
      longitude: double.parse(json['lon'] ?? '0.0'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'country': country,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'isCurrentLocation': isCurrentLocation,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  String get displayName {
    if (state.isNotEmpty && state != name) {
      return '$name, $state, $country';
    }
    return '$name, $country';
  }
}

@HiveType(typeId: 5)
class WeatherDataContainer extends HiveObject {
  @HiveField(0)
  final Map<String, WeatherData> cityWeatherData;

  @HiveField(1)
  final List<CityLocation> savedCities;

  @HiveField(2)
  final DateTime lastGlobalUpdate;

  WeatherDataContainer({
    Map<String, WeatherData>? cityWeatherData,
    List<CityLocation>? savedCities,
    DateTime? lastGlobalUpdate,
  })  : cityWeatherData = cityWeatherData ?? {},
        savedCities = savedCities ?? [],
        lastGlobalUpdate = lastGlobalUpdate ?? DateTime.now();

  factory WeatherDataContainer.empty() {
    return WeatherDataContainer();
  }

  WeatherDataContainer copyWith({
    Map<String, WeatherData>? cityWeatherData,
    List<CityLocation>? savedCities,
    DateTime? lastGlobalUpdate,
  }) {
    return WeatherDataContainer(
      cityWeatherData: cityWeatherData ?? Map.from(this.cityWeatherData),
      savedCities: savedCities ?? List.from(this.savedCities),
      lastGlobalUpdate: lastGlobalUpdate ?? this.lastGlobalUpdate,
    );
  }

  String _getCityKey(CityLocation city) {
    return '${city.latitude.toStringAsFixed(2)}_${city.longitude.toStringAsFixed(2)}';
  }

  WeatherData? getWeatherForCity(CityLocation city) {
    return cityWeatherData[_getCityKey(city)];
  }

  void updateWeatherForCity(CityLocation city, WeatherData weather) {
    cityWeatherData[_getCityKey(city)] = weather;
  }

  void addCity(CityLocation city) {
    if (!savedCities.any((c) => _getCityKey(c) == _getCityKey(city))) {
      savedCities.add(city);
    }
  }

  void removeCity(CityLocation city) {
    savedCities.removeWhere((c) => _getCityKey(c) == _getCityKey(city));
    cityWeatherData.remove(_getCityKey(city));
  }

  bool hasCityWeather(CityLocation city) {
    return cityWeatherData.containsKey(_getCityKey(city));
  }

  bool isWeatherStale(CityLocation city) {
    final weather = getWeatherForCity(city);
    return weather?.isDataStale ?? true;
  }
}

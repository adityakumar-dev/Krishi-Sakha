import 'package:flutter/material.dart';
import 'package:krishi_sakha/models/weather_model.dart';
import 'package:krishi_sakha/utils/theme/colors.dart';

class WeatherCard extends StatelessWidget {
  final CityLocation city;
  final WeatherData weatherData;
  final bool isStale;

  const WeatherCard({
    super.key,
    required this.city,
    required this.weatherData,
    this.isStale = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen.withOpacity(0.8),
            AppColors.primaryGreen.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location and update status
          Row(
            children: [
              Icon(
                city.isCurrentLocation ? Icons.my_location : Icons.location_on,
                color: AppColors.primaryBlack,
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  city.displayName,
                  style: const TextStyle(
                    color: AppColors.primaryBlack,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isStale)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Outdated',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Temperature and description
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Temperature
              Text(
                '${weatherData.current.temperature.round()}°C',
                style: const TextStyle(
                  color: AppColors.primaryBlack,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Weather icon and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _getWeatherIcon(weatherData.current.weatherCode),
                    const SizedBox(height: 8),
                    Text(
                      weatherData.current.weatherDescription,
                      style: const TextStyle(
                        color: AppColors.primaryBlack,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Feels like ${weatherData.current.feelsLike.round()}°C',
                      style: const TextStyle(
                        color: AppColors.primaryBlack,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Weather highlights
          Row(
            children: [
              _buildHighlight(
                Icons.water_drop,
                'Humidity',
                '${weatherData.current.humidity}%',
              ),
              const SizedBox(width: 24),
              _buildHighlight(
                Icons.air,
                'Wind',
                '${weatherData.current.windSpeed.round()} km/h',
              ),
              const SizedBox(width: 24),
              _buildHighlight(
                Icons.visibility,
                'Visibility',
                '${(weatherData.current.visibility / 1000).round()} km',
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Additional highlights
          Row(
            children: [
              _buildHighlight(
                Icons.compress,
                'Pressure',
                '${weatherData.current.pressure.round()} hPa',
              ),
              const SizedBox(width: 24),
              _buildHighlight(
                Icons.wb_sunny,
                'UV Index',
                weatherData.current.uvIndex.round().toString(),
              ),
              const SizedBox(width: 24),
              _buildHighlight(
                Icons.cloud,
                'Cloud Cover',
                '${weatherData.current.cloudCover.round()}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHighlight(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: AppColors.primaryBlack,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryBlack,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primaryBlack,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getWeatherIcon(String weatherCode) {
    IconData iconData;
    Color iconColor = AppColors.primaryBlack;
    
    switch (int.parse(weatherCode)) {
      case 0:
        iconData = Icons.wb_sunny;
        break;
      case 1:
      case 2:
      case 3:
        iconData = Icons.wb_cloudy;
        break;
      case 45:
      case 48:
        iconData = Icons.foggy;
        break;
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
        iconData = Icons.grain;
        break;
      case 71:
      case 73:
      case 75:
        iconData = Icons.ac_unit;
        break;
      case 80:
      case 81:
      case 82:
        iconData = Icons.shower;
        break;
      case 95:
        iconData = Icons.thunderstorm;
        break;
      default:
        iconData = Icons.help_outline;
    }
    
    return Icon(
      iconData,
      color: iconColor,
      size: 32,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:krishi_sakha/models/weather_model.dart';
import 'package:krishi_sakha/utils/theme/colors.dart';

class WeatherDetails extends StatelessWidget {
  final CurrentWeather current;

  const WeatherDetails({
    super.key,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryWhite.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Agricultural Conditions',
            style: TextStyle(
              color: AppColors.primaryWhite,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // First row
          Row(
            children: [
              _buildDetailCard(
                Icons.water_drop,
                'Humidity',
                '${current.humidity}%',
                _getHumidityAdvice(current.humidity),
              ),
              const SizedBox(width: 12),
              _buildDetailCard(
                Icons.thermostat,
                'Dew Point',
                '${current.dewPoint.round()}°C',
                _getDewPointAdvice(current.dewPoint),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Second row
          Row(
            children: [
              _buildDetailCard(
                Icons.compress,
                'Pressure',
                '${current.pressure.round()} hPa',
                _getPressureAdvice(current.pressure),
              ),
              const SizedBox(width: 12),
              _buildDetailCard(
                Icons.air,
                'Wind Speed',
                '${current.windSpeed.round()} km/h',
                _getWindAdvice(current.windSpeed),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Third row
          Row(
            children: [
              _buildDetailCard(
                Icons.wb_sunny,
                'UV Index',
                current.uvIndex.round().toString(),
                _getUVAdvice(current.uvIndex),
              ),
              const SizedBox(width: 12),
              _buildDetailCard(
                Icons.grain,
                'Precipitation',
                '${current.precipitation.round()} mm',
                _getPrecipitationAdvice(current.precipitation),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Fourth row
          Row(
            children: [
              _buildDetailCard(
                Icons.visibility,
                'Visibility',
                '${(current.visibility / 1000).round()} km',
                _getVisibilityAdvice(current.visibility),
              ),
              const SizedBox(width: 12),
              _buildDetailCard(
                Icons.cloud,
                'Cloud Cover',
                '${current.cloudCover.round()}%',
                _getCloudAdvice(current.cloudCover),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(IconData icon, String title, String value, String advice) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryBlack.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryGreen.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: AppColors.primaryGreen,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.primaryWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.primaryWhite,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              advice,
              style: TextStyle(
                color: AppColors.primaryGreen.withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _getHumidityAdvice(int humidity) {
    if (humidity < 30) {
      return 'Low - Irrigation needed';
    } else if (humidity < 60) {
      return 'Moderate - Good for crops';
    } else if (humidity < 80) {
      return 'High - Monitor diseases';
    } else {
      return 'Very high - Risk of diseases';
    }
  }

  String _getDewPointAdvice(double dewPoint) {
    if (dewPoint < 10) {
      return 'Dry - No dew formation';
    } else if (dewPoint < 15) {
      return 'Moderate - Light dew';
    } else if (dewPoint < 20) {
      return 'High - Heavy dew likely';
    } else {
      return 'Very high - Fog possible';
    }
  }

  String _getPressureAdvice(double pressure) {
    if (pressure < 1000) {
      return 'Low - Stormy weather';
    } else if (pressure < 1020) {
      return 'Normal - Stable weather';
    } else {
      return 'High - Clear skies';
    }
  }

  String _getWindAdvice(double windSpeed) {
    if (windSpeed < 5) {
      return 'Calm - Good for spraying';
    } else if (windSpeed < 15) {
      return 'Light - Ideal conditions';
    } else if (windSpeed < 25) {
      return 'Moderate - Avoid spraying';
    } else {
      return 'Strong - Stay indoors';
    }
  }

  String _getUVAdvice(double uvIndex) {
    if (uvIndex < 3) {
      return 'Low - Safe exposure';
    } else if (uvIndex < 6) {
      return 'Moderate - Use protection';
    } else if (uvIndex < 8) {
      return 'High - Limit exposure';
    } else if (uvIndex < 11) {
      return 'Very high - Avoid midday';
    } else {
      return 'Extreme - Stay indoors';
    }
  }

  String _getPrecipitationAdvice(double precipitation) {
    if (precipitation == 0) {
      return 'No rain - Check irrigation';
    } else if (precipitation < 5) {
      return 'Light rain - Good for crops';
    } else if (precipitation < 15) {
      return 'Moderate rain - Monitor drainage';
    } else {
      return 'Heavy rain - Check flooding';
    }
  }

  String _getVisibilityAdvice(double visibility) {
    if (visibility < 1000) {
      return 'Poor - Fog/mist present';
    } else if (visibility < 5000) {
      return 'Moderate - Reduced clarity';
    } else {
      return 'Good - Clear conditions';
    }
  }

  String _getCloudAdvice(double cloudCover) {
    if (cloudCover < 25) {
      return 'Clear - High solar radiation';
    } else if (cloudCover < 50) {
      return 'Partly cloudy - Good light';
    } else if (cloudCover < 75) {
      return 'Mostly cloudy - Reduced light';
    } else {
      return 'Overcast - Low light';
    }
  }
}

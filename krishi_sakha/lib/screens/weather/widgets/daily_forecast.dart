import 'package:flutter/material.dart';
import 'package:krishi_sakha/models/weather_model.dart';
import 'package:krishi_sakha/utils/theme/colors.dart';
import 'package:intl/intl.dart';

class DailyForecast extends StatelessWidget {
  final List<DailyWeather> dailyForecasts;

  const DailyForecast({
    super.key,
    required this.dailyForecasts,
  });

  @override
  Widget build(BuildContext context) {
    if (dailyForecasts.isEmpty) {
      return const SizedBox.shrink();
    }

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
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '14-Day Forecast',
                style: TextStyle(
                  color: AppColors.primaryWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Forecast list
          ...dailyForecasts.map((forecast) => _buildForecastItem(forecast)),
        ],
      ),
    );
  }

  Widget _buildForecastItem(DailyWeather forecast) {
    final isToday = DateFormat('yyyy-MM-dd').format(forecast.date) == 
                   DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isTomorrow = DateFormat('yyyy-MM-dd').format(forecast.date) == 
                      DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)));

    String dayLabel;
    if (isToday) {
      dayLabel = 'Today';
    } else if (isTomorrow) {
      dayLabel = 'Tomorrow';
    } else {
      dayLabel = DateFormat('EEE, MMM d').format(forecast.date);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryBlack.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryGreen.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Main forecast row
          Row(
            children: [
              // Day and weather icon
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    _getWeatherIcon(forecast.weatherCode),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dayLabel,
                          style: TextStyle(
                            color: AppColors.primaryWhite,
                            fontSize: 14,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        Text(
                          forecast.weatherDescription,
                          style: TextStyle(
                            color: AppColors.primaryGreen.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Temperature range
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${forecast.temperatureMax.round()}°',
                      style: const TextStyle(
                        color: AppColors.primaryWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${forecast.temperatureMin.round()}°',
                      style: TextStyle(
                        color: AppColors.primaryWhite.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Precipitation chance
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.water_drop,
                      color: AppColors.primaryGreen,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${forecast.precipitationProbability.round()}%',
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Agricultural details (expandable for today and tomorrow)
          if (isToday || isTomorrow) ...[
            const SizedBox(height: 12),
            _buildAgriculturalDetails(forecast),
          ],
        ],
      ),
    );
  }

  Widget _buildAgriculturalDetails(DailyWeather forecast) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // First row of details
          Row(
            children: [
              _buildDetailItem(
                Icons.air,
                'Wind',
                '${forecast.windSpeedMax.round()} km/h',
              ),
              _buildDetailItem(
                Icons.water_drop,
                'Humidity',
                '${forecast.humidityAvg.round()}%',
              ),
              _buildDetailItem(
                Icons.wb_sunny,
                'UV Max',
                forecast.uvIndexMax.round().toString(),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Second row of details
          Row(
            children: [
              _buildDetailItem(
                Icons.wb_sunny_outlined,
                'Sunrise',
                DateFormat('HH:mm').format(forecast.sunrise),
              ),
              _buildDetailItem(
                Icons.nightlight,
                'Sunset',
                DateFormat('HH:mm').format(forecast.sunset),
              ),
              _buildDetailItem(
                Icons.grain,
                'Rain',
                '${forecast.precipitationSum.round()} mm',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: AppColors.primaryGreen,
            size: 14,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppColors.primaryWhite.withOpacity(0.7),
              fontSize: 9,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primaryWhite,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getWeatherIcon(String weatherCode) {
    IconData iconData;
    Color iconColor = AppColors.primaryGreen;
    
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
      size: 24,
    );
  }
}

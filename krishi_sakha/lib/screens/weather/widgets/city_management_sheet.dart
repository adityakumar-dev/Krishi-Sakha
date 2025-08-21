import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:krishi_sakha/providers/weather_provider.dart';
import 'package:krishi_sakha/models/weather_model.dart';
import 'package:krishi_sakha/utils/theme/colors.dart';

class CityManagementSheet extends StatelessWidget {
  const CityManagementSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.primaryBlack,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.primaryWhite.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.manage_accounts,
                  color: AppColors.primaryGreen,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Manage Cities',
                  style: TextStyle(
                    color: AppColors.primaryWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.primaryWhite,
                  ),
                ),
              ],
            ),
          ),
          
          // Cities list
          Expanded(
            child: Consumer<WeatherProvider>(
              builder: (context, weatherProvider, child) {
                final cities = weatherProvider.savedCities;
                
                if (cities.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off,
                          color: AppColors.primaryGreen.withOpacity(0.5),
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No cities added',
                          style: TextStyle(
                            color: AppColors.primaryWhite.withOpacity(0.7),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use the search to add cities',
                          style: TextStyle(
                            color: AppColors.primaryWhite.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: cities.length,
                  onReorder: (oldIndex, newIndex) {
                    // Handle reordering if needed
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    // You can implement reordering logic here
                  },
                  itemBuilder: (context, index) {
                    final city = cities[index];
                    final weatherData = weatherProvider.getWeatherForCity(city);
                    final isCurrentCity = index == weatherProvider.currentCityIndex;
                    final isStale = weatherProvider.isWeatherStale(city);

                    return _buildCityCard(
                      key: ValueKey(city.name + city.latitude.toString()),
                      context: context,
                      city: city,
                      weatherData: weatherData,
                      isCurrentCity: isCurrentCity,
                      isStale: isStale,
                      index: index,
                      weatherProvider: weatherProvider,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityCard({
    required Key key,
    required BuildContext context,
    required CityLocation city,
    required WeatherData? weatherData,
    required bool isCurrentCity,
    required bool isStale,
    required int index,
    required WeatherProvider weatherProvider,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrentCity 
            ? AppColors.primaryGreen.withOpacity(0.2)
            : AppColors.primaryWhite.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentCity 
              ? AppColors.primaryGreen
              : AppColors.primaryGreen.withOpacity(0.3),
          width: isCurrentCity ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              city.isCurrentLocation ? Icons.my_location : Icons.location_on,
              color: isCurrentCity ? AppColors.primaryGreen : AppColors.primaryWhite,
              size: 20,
            ),
            if (isCurrentCity)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    color: AppColors.primaryBlack,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                city.name,
                style: TextStyle(
                  color: isCurrentCity ? AppColors.primaryGreen : AppColors.primaryWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (isStale)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Outdated',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              city.displayName,
              style: TextStyle(
                color: AppColors.primaryWhite.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
            if (weatherData != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _getWeatherIcon(weatherData.current.weatherCode),
                  const SizedBox(width: 8),
                  Text(
                    '${weatherData.current.temperature.round()}°C',
                    style: TextStyle(
                      color: isCurrentCity ? AppColors.primaryGreen : AppColors.primaryWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    weatherData.current.weatherDescription,
                    style: TextStyle(
                      color: AppColors.primaryWhite.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Refresh button
            IconButton(
              onPressed: () async {
                await weatherProvider.refreshCurrentWeather();
              },
              icon: weatherProvider.isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryGreen,
                      ),
                    )
                  : const Icon(
                      Icons.refresh,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
            ),
            
            // Delete button (only if not current location)
            if (!city.isCurrentLocation)
              IconButton(
                onPressed: () => _showDeleteConfirmation(context, city, weatherProvider),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 20,
                ),
              ),
          ],
        ),
        onTap: () {
          weatherProvider.setCurrentCityIndex(index);
          weatherProvider.pageController?.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _getWeatherIcon(String weatherCode) {
    IconData iconData;
    
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
      color: AppColors.primaryGreen,
      size: 16,
    );
  }

  void _showDeleteConfirmation(BuildContext context, CityLocation city, WeatherProvider weatherProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryBlack,
        title: const Text(
          'Remove City',
          style: TextStyle(color: AppColors.primaryWhite),
        ),
        content: Text(
          'Are you sure you want to remove ${city.name} from your saved cities?',
          style: const TextStyle(color: AppColors.primaryWhite),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.primaryGreen),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await weatherProvider.removeCity(city);
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

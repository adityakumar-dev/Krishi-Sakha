import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:krishi_sakha/providers/weather_provider.dart';
import 'package:krishi_sakha/models/weather_model.dart';
import 'package:krishi_sakha/utils/theme/colors.dart';
import 'package:krishi_sakha/screens/weather/widgets/weather_card.dart';
import 'package:krishi_sakha/screens/weather/widgets/weather_details.dart';
import 'package:krishi_sakha/screens/weather/widgets/daily_forecast.dart';
import 'package:krishi_sakha/screens/weather/widgets/city_search_delegate.dart';
import 'package:krishi_sakha/screens/weather/widgets/city_management_sheet.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.primaryBlack,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.primaryBlack,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWeather();
    });
  }

  Future<void> _initializeWeather() async {
    final weatherProvider = context.read<WeatherProvider>();
    weatherProvider.setPageController(_pageController);
    
    // Check permissions first
    final hasPermission = await weatherProvider.checkLocationPermission();
    final serviceEnabled = await weatherProvider.checkLocationService();
    
    if (!hasPermission || !serviceEnabled) {
      if (mounted) {
        _showLocationPermissionDialog();
      }
      return;
    }

    // Initialize with current location
    await weatherProvider.initializeWithCurrentLocation();
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryBlack,
        title: const Text(
          'Location Permission Required',
          style: TextStyle(color: AppColors.primaryWhite),
        ),
        content: const Text(
          'Location permission and location services are required for weather reports. Please enable them to continue.',
          style: TextStyle(color: AppColors.primaryWhite),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.primaryGreen)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final weatherProvider = context.read<WeatherProvider>();
              
              // Try to request permission
              await weatherProvider.requestLocationPermission();
              
              // Check again
              final hasPermission = await weatherProvider.checkLocationPermission();
              final serviceEnabled = await weatherProvider.checkLocationService();
              
              if (hasPermission && serviceEnabled) {
                await weatherProvider.initializeWithCurrentLocation();
              } else {
                // Open settings
                await weatherProvider.openAppSettings();
              }
            },
            child: const Text('Grant Permission', style: TextStyle(color: AppColors.primaryGreen)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlack,
      appBar: _buildAppBar(),
      body: Consumer<WeatherProvider>(
        builder: (context, weatherProvider, child) {
          if (weatherProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryGreen,
              ),
            );
          }

          if (weatherProvider.error != null) {
            return _buildErrorWidget(weatherProvider);
          }

          if (weatherProvider.savedCities.isEmpty) {
            return _buildEmptyState();
          }

          return _buildWeatherContent(weatherProvider);
        },
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primaryBlack,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.primaryWhite),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Weather Forecast',
        style: TextStyle(
          color: AppColors.primaryWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: AppColors.primaryWhite),
          onPressed: () => _showSearch(),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.primaryWhite),
          onPressed: () => _refreshWeather(),
        ),
      ],
    );
  }

  Widget _buildWeatherContent(WeatherProvider weatherProvider) {
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      backgroundColor: AppColors.primaryBlack,
      onRefresh: () => weatherProvider.refreshAllWeather(),
      child: Column(
        children: [
          // City indicator
          if (weatherProvider.savedCities.length > 1)
            _buildCityIndicator(weatherProvider),
          
          // Weather pages
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                weatherProvider.setCurrentCityIndex(index);
              },
              itemCount: weatherProvider.savedCities.length,
              itemBuilder: (context, index) {
                final city = weatherProvider.savedCities[index];
                final weatherData = weatherProvider.getWeatherForCity(city);
                
                return _buildWeatherPage(city, weatherData, weatherProvider);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityIndicator(WeatherProvider weatherProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          weatherProvider.savedCities.length,
          (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            width: 8.0,
            height: 8.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index == weatherProvider.currentCityIndex
                  ? AppColors.primaryGreen
                  : AppColors.primaryWhite.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherPage(CityLocation city, WeatherData? weatherData, WeatherProvider weatherProvider) {
    if (weatherData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primaryGreen),
            const SizedBox(height: 16),
            Text(
              'Loading weather for ${city.name}...',
              style: const TextStyle(color: AppColors.primaryWhite),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Main weather card
          WeatherCard(
            city: city,
            weatherData: weatherData,
            isStale: weatherProvider.isWeatherStale(city),
          ),
          
          const SizedBox(height: 24),
          
          // Weather details
          WeatherDetails(current: weatherData.current),
          
          const SizedBox(height: 24),
          
          // Daily forecast
          DailyForecast(dailyForecasts: weatherData.dailyForecasts),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(WeatherProvider weatherProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.primaryGreen,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Weather Error',
              style: const TextStyle(
                color: AppColors.primaryWhite,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              weatherProvider.error ?? 'Unknown error occurred',
              style: const TextStyle(
                color: AppColors.primaryWhite,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                weatherProvider.clearError();
                _initializeWeather();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.primaryBlack,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off,
              color: AppColors.primaryGreen,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Weather Data',
              style: TextStyle(
                color: AppColors.primaryWhite,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a city to view weather information',
              style: TextStyle(
                color: AppColors.primaryWhite,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showSearch(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.primaryBlack,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add City'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Consumer<WeatherProvider>(
      builder: (context, weatherProvider, child) {
        if (weatherProvider.savedCities.isEmpty) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.primaryBlack,
          onPressed: () => _showCityManagement(),
          child: const Icon(Icons.list),
        );
      },
    );
  }

  void _showSearch() async {
    final result = await showSearch(
      context: context,
      delegate: CitySearchDelegate(),
    );

    if (result != null && result is CityLocation) {
      final weatherProvider = context.read<WeatherProvider>();
      await weatherProvider.addCity(result);
    }
  }

  void _showCityManagement() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const CityManagementSheet(),
    );
  }

  void _refreshWeather() {
    final weatherProvider = context.read<WeatherProvider>();
    weatherProvider.refreshCurrentWeather();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

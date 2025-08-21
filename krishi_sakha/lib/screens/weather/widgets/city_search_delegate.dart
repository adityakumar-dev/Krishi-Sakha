import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:krishi_sakha/providers/weather_provider.dart';
import 'package:krishi_sakha/models/weather_model.dart';
import 'package:krishi_sakha/utils/theme/colors.dart';

class CitySearchDelegate extends SearchDelegate<CityLocation?> {
  @override
  String get searchFieldLabel => 'Search cities...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryBlack,
        iconTheme: IconThemeData(color: AppColors.primaryWhite),
        titleTextStyle: TextStyle(
          color: AppColors.primaryWhite,
          fontSize: 18,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: AppColors.primaryWhite),
        border: InputBorder.none,
      ),
      scaffoldBackgroundColor: AppColors.primaryBlack,
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      Consumer<WeatherProvider>(
        builder: (context, weatherProvider, child) {
          if (weatherProvider.isSearching && query.isNotEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryGreen,
                ),
              ),
            );
          }
          return IconButton(
            icon: const Icon(Icons.clear, color: AppColors.primaryWhite),
            onPressed: () {
              query = '';
              context.read<WeatherProvider>().clearSearchResults();
              showSuggestions(context);
            },
          );
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: AppColors.primaryWhite),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return _buildRecentCities(context);
    }

    // Trigger search with debouncing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeatherProvider>().searchCities(query);
    });

    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return Container(
      color: AppColors.primaryBlack,
      child: Consumer<WeatherProvider>(
        builder: (context, weatherProvider, child) {
          if (weatherProvider.isSearching) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryGreen,
              ),
            );
          }

          final searchResults = weatherProvider.searchResults;
          
          if (searchResults.isEmpty && query.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      color: AppColors.primaryGreen.withOpacity(0.5),
                      size: 80,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No cities found',
                      style: TextStyle(
                        color: AppColors.primaryWhite.withOpacity(0.8),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Try searching for:\n• City names (e.g., "New York")\n• State/Province names\n• Country names',
                      style: TextStyle(
                        color: AppColors.primaryWhite.withOpacity(0.6),
                        fontSize: 14,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primaryGreen.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        'Search query: "$query"',
                        style: TextStyle(
                          color: AppColors.primaryGreen.withOpacity(0.8),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              final city = searchResults[index];
              final isAlreadyAdded = weatherProvider.savedCities
                  .any((savedCity) => _isSameLocation(savedCity, city));

              return _buildCityTile(context, city, isAlreadyAdded);
            },
          );
        },
      ),
    );
  }

  Widget _buildRecentCities(BuildContext context) {
    return Container(
      color: AppColors.primaryBlack,
      padding: const EdgeInsets.all(16),
      child: Consumer<WeatherProvider>(
        builder: (context, weatherProvider, child) {
          final savedCities = weatherProvider.savedCities;
          
          if (savedCities.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_city,
                    color: AppColors.primaryGreen.withOpacity(0.5),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No saved cities',
                    style: TextStyle(
                      color: AppColors.primaryWhite.withOpacity(0.7),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Search for a city to add it',
                    style: TextStyle(
                      color: AppColors.primaryWhite.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saved Cities',
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: savedCities.length,
                  itemBuilder: (context, index) {
                    final city = savedCities[index];
                    return _buildCityTile(context, city, true);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCityTile(BuildContext context, CityLocation city, bool isAlreadyAdded) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryWhite.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryGreen.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            city.isCurrentLocation ? Icons.my_location : Icons.location_city,
            color: AppColors.primaryGreen,
            size: 20,
          ),
        ),
        title: Text(
          city.name,
          style: const TextStyle(
            color: AppColors.primaryWhite,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _buildLocationString(city),
              style: TextStyle(
                color: AppColors.primaryWhite.withOpacity(0.7),
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${city.latitude.toStringAsFixed(4)}, ${city.longitude.toStringAsFixed(4)}',
              style: TextStyle(
                color: AppColors.primaryGreen.withOpacity(0.6),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isAlreadyAdded 
                ? AppColors.primaryGreen.withOpacity(0.2)
                : AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAlreadyAdded ? Icons.check : Icons.add,
                color: isAlreadyAdded 
                    ? AppColors.primaryGreen
                    : AppColors.primaryBlack,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                isAlreadyAdded ? 'Added' : 'Add',
                style: TextStyle(
                  color: isAlreadyAdded 
                      ? AppColors.primaryGreen
                      : AppColors.primaryBlack,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        onTap: () {
          if (!isAlreadyAdded) {
            close(context, city);
          } else {
            // If already added, just close and navigate to that city
            final weatherProvider = context.read<WeatherProvider>();
            final cityIndex = weatherProvider.savedCities.indexWhere(
              (savedCity) => 
                  _isSameLocation(savedCity, city),
            );
            if (cityIndex != -1) {
              weatherProvider.setCurrentCityIndex(cityIndex);
              weatherProvider.pageController?.animateToPage(
                cityIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
            close(context, null);
          }
        },
      ),
    );
  }

  String _buildLocationString(CityLocation city) {
    List<String> parts = [];
    
    if (city.state.isNotEmpty && city.state != city.name) {
      parts.add(city.state);
    }
    
    if (city.country.isNotEmpty) {
      parts.add(city.country);
    }
    
    return parts.join(', ');
  }

  bool _isSameLocation(CityLocation city1, CityLocation city2) {
    const double tolerance = 0.01; // ~1km tolerance
    return (city1.latitude - city2.latitude).abs() < tolerance &&
           (city1.longitude - city2.longitude).abs() < tolerance;
  }
}

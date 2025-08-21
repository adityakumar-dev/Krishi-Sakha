# Krishi Sakha - Project Index

## Project Overview
Krishi Sakha is a Flutter-based AI chat application focused on agricultural assistance. The app integrates local LLM models (via GGUF/fllama) and server-based chat functionality with voice features.

## Project Structure

### Root Level
- `pubspec.yaml` - Flutter project configuration and dependencies
- `README.md` - Basic project documentation
- `analysis_options.yaml` - Dart analysis configuration
- `.env` - Environment variables (for Supabase configuration)

### Platform Directories
- `android/` - Android-specific configuration and build files
- `ios/` - iOS-specific configuration and build files
- `linux/` - Linux desktop build configuration
- `macos/` - macOS desktop build configuration
- `windows/` - Windows desktop build configuration
- `web/` - Web platform assets and configuration

### Assets
- `assets/lottie/` - Animation files
  - `error.json` - Error state animation
  - `IntroFirst.json` - Onboarding animation
  - `loading.json` - Loading state animation
  - `success.json` - Success state animation
  - `tractor.json` - Agricultural theme animation

## Source Code Structure (`lib/`)

### Core Application
- `main.dart` - Application entry point with providers setup and Supabase initialization

### APIs
- `apis/api_manager.dart` - HTTP API management and server communication

### Controllers
- `controllers/chat_controller.dart` - Chat functionality management
- `controllers/permission_controller.dart` - Device permissions handling

### Data Layer
- `data/` - Currently empty, likely for local data storage

### Models
- `models/llm_model.dart` - LLM model data structure
- `models/llm_model.g.dart` - Generated Hive adapter for model persistence
- `models/weather_model.dart` - Weather data structures (WeatherData, CurrentWeather, DailyWeather, CityLocation, WeatherDataContainer)
- `models/weather_model.g.dart` - Generated Hive adapters for weather models

### Providers (State Management)
- `providers/llama_provider.dart` - Local LLM model management
- `providers/model_provider.dart` - Model selection and configuration
- `providers/server_chat_handler_provider.dart` - Server-based chat functionality
- `providers/void_provider.dart` - Voice-related functionality
- `providers/weather_provider.dart` - Weather data management and city handling

### Screens (UI)
```
screens/
├── chat/           - Chat interface screens
├── download/       - Model download interface
├── home/           - Main application screen
├── login/          - Authentication screens
├── models/         - Model management screens
├── onboarding/     - First-time user experience
├── permission/     - Permission request screens
├── search/         - Search functionality
├── selector/       - Selection interfaces
├── settings/       - Application settings
├── splash/         - App startup screen
├── voice/          - Voice chat interface
└── weather/        - Weather forecast and agricultural conditions
    ├── weather_screen.dart - Main weather interface
    └── widgets/     - Weather-specific UI components
        ├── weather_card.dart - Main weather display card
        ├── weather_details.dart - Agricultural condition details
        ├── daily_forecast.dart - 14-day weather forecast
        ├── city_search_delegate.dart - City search functionality
        └── city_management_sheet.dart - Saved cities management
```

### Services
- `services/fllama_service.dart` - Local LLM model service
- `services/permission_service.dart` - Device permission management
- `services/weather_service.dart` - Weather API integration and location services

### Utils
```
utils/
├── auth/          - Authentication utilities
├── routes/        - Navigation and routing configuration
├── theme/         - UI theming and styling
└── ui/            - UI helper components
```

## Key Dependencies

### Core Flutter
- `flutter` - Flutter SDK
- `cupertino_icons` - iOS-style icons

### State Management & Navigation
- `provider` - State management
- `go_router` - Declarative routing

### AI & ML
- `fllama` - Local LLM model runner (GGUF format)
- `file_picker` - File selection for model files
- `image_picker` - Image input for chat

### Voice Features
- `flutter_tts` - Text-to-speech functionality
- `speech_to_text` - Voice input recognition

### Weather & Location
- `geolocator` - Location services and GPS access
- `geocoding` - Address and coordinate conversion
- `intl` - Internationalization and date formatting

### Backend & Storage
- `supabase_flutter` - Backend as a Service
- `hive` - Local NoSQL database
- `hive_flutter` - Flutter integration for Hive
- `shared_preferences` - Simple key-value storage

### UI & Animations
- `lottie` - Animation support
- `flutter_markdown` - Markdown rendering for chat messages

### Utilities
- `http` - HTTP client
- `path_provider` - File system path access
- `permission_handler` - Device permissions
- `uuid` - Unique identifier generation
- `flutter_dotenv` - Environment variable management
- `logger` - Logging functionality
- `fluttertoast` - Toast notifications

## App Features

### Core Functionality
1. **Local AI Chat** - Run LLM models locally using GGUF format
2. **Server-based Chat** - Cloud-based AI conversations via Supabase
3. **Voice Interface** - Speech-to-text and text-to-speech capabilities
4. **Weather Forecast** - 14-day weather predictions with agricultural insights
5. **Location Services** - GPS-based current location and city search
6. **Model Management** - Download and manage AI models
7. **Multi-platform** - Supports Android, iOS, Linux, macOS, Windows, and Web

### User Flow
1. **Splash Screen** - App initialization
2. **Onboarding** - First-time user experience
3. **Permissions** - Request necessary device permissions
4. **Home** - Main dashboard
5. **Chat Selection** - Choose between local or server-based chat
6. **Weather Dashboard** - View current and forecast weather with agricultural insights
7. **Voice Chat** - Voice-enabled conversations

## Configuration

### Environment Setup
- Supabase URL and API key configuration in `.env`
- Platform-specific build configurations in respective directories

### Data Persistence
- Hive database for local model storage
- Supabase for cloud data synchronization
- SharedPreferences for app settings

## Development Notes

### Architecture Pattern
- **Provider Pattern** for state management
- **Service Layer** for business logic
- **Repository Pattern** implied through API manager
- **Feature-based** directory structure

### Key Integrations
- **Supabase** for backend services
- **Local LLM** via fllama for offline AI capabilities
- **Open-Meteo API** for weather data
- **LocationIQ API** for city search and geocoding
- **Multi-platform** support across mobile, desktop, and web

## Build Configuration
- **Flutter SDK**: ^3.8.1
- **Material 3** UI design system
- **Development tools**: flutter_lints, build_runner, hive_generator

## Weather Feature Details

### Weather APIs
- **Open-Meteo**: Free weather API providing 14-day forecasts
- **LocationIQ**: City search and geocoding service

### Agricultural Focus
- **Humidity monitoring** for crop disease prevention
- **UV Index tracking** for farmer safety
- **Precipitation forecasts** for irrigation planning
- **Wind speed monitoring** for spraying conditions
- **Dew point analysis** for disease risk assessment
- **Pressure trends** for weather prediction

### Data Storage
- **Local persistence** via Hive for offline access
- **City management** with add/remove functionality
- **Automatic refresh** with stale data detection
- **GPS integration** for current location weather

---
*Last updated: August 20, 2025*
*Project Version: 1.0.0+1*

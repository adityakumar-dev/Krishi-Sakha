// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weather_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WeatherDataAdapter extends TypeAdapter<WeatherData> {
  @override
  final int typeId = 1;

  @override
  WeatherData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeatherData(
      cityName: fields[0] as String,
      country: fields[1] as String,
      latitude: fields[2] as double,
      longitude: fields[3] as double,
      dailyForecasts: (fields[4] as List).cast<DailyWeather>(),
      current: fields[5] as CurrentWeather,
      lastUpdated: fields[6] as DateTime,
      timezone: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, WeatherData obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.cityName)
      ..writeByte(1)
      ..write(obj.country)
      ..writeByte(2)
      ..write(obj.latitude)
      ..writeByte(3)
      ..write(obj.longitude)
      ..writeByte(4)
      ..write(obj.dailyForecasts)
      ..writeByte(5)
      ..write(obj.current)
      ..writeByte(6)
      ..write(obj.lastUpdated)
      ..writeByte(7)
      ..write(obj.timezone);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CurrentWeatherAdapter extends TypeAdapter<CurrentWeather> {
  @override
  final int typeId = 2;

  @override
  CurrentWeather read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CurrentWeather(
      temperature: fields[0] as double,
      feelsLike: fields[1] as double,
      humidity: fields[2] as int,
      pressure: fields[3] as double,
      windSpeed: fields[4] as double,
      windDirection: fields[5] as int,
      uvIndex: fields[6] as double,
      visibility: fields[7] as double,
      weatherCode: fields[8] as String,
      weatherDescription: fields[9] as String,
      cloudCover: fields[10] as double,
      precipitation: fields[11] as double,
      dewPoint: fields[12] as double,
    );
  }

  @override
  void write(BinaryWriter writer, CurrentWeather obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.temperature)
      ..writeByte(1)
      ..write(obj.feelsLike)
      ..writeByte(2)
      ..write(obj.humidity)
      ..writeByte(3)
      ..write(obj.pressure)
      ..writeByte(4)
      ..write(obj.windSpeed)
      ..writeByte(5)
      ..write(obj.windDirection)
      ..writeByte(6)
      ..write(obj.uvIndex)
      ..writeByte(7)
      ..write(obj.visibility)
      ..writeByte(8)
      ..write(obj.weatherCode)
      ..writeByte(9)
      ..write(obj.weatherDescription)
      ..writeByte(10)
      ..write(obj.cloudCover)
      ..writeByte(11)
      ..write(obj.precipitation)
      ..writeByte(12)
      ..write(obj.dewPoint);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurrentWeatherAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DailyWeatherAdapter extends TypeAdapter<DailyWeather> {
  @override
  final int typeId = 3;

  @override
  DailyWeather read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyWeather(
      date: fields[0] as DateTime,
      temperatureMax: fields[1] as double,
      temperatureMin: fields[2] as double,
      precipitationSum: fields[3] as double,
      precipitationProbability: fields[4] as double,
      windSpeedMax: fields[5] as double,
      windDirection: fields[6] as int,
      weatherCode: fields[7] as String,
      weatherDescription: fields[8] as String,
      uvIndexMax: fields[9] as double,
      humidityAvg: fields[10] as double,
      pressureAvg: fields[11] as double,
      sunrise: fields[12] as DateTime,
      sunset: fields[13] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DailyWeather obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.temperatureMax)
      ..writeByte(2)
      ..write(obj.temperatureMin)
      ..writeByte(3)
      ..write(obj.precipitationSum)
      ..writeByte(4)
      ..write(obj.precipitationProbability)
      ..writeByte(5)
      ..write(obj.windSpeedMax)
      ..writeByte(6)
      ..write(obj.windDirection)
      ..writeByte(7)
      ..write(obj.weatherCode)
      ..writeByte(8)
      ..write(obj.weatherDescription)
      ..writeByte(9)
      ..write(obj.uvIndexMax)
      ..writeByte(10)
      ..write(obj.humidityAvg)
      ..writeByte(11)
      ..write(obj.pressureAvg)
      ..writeByte(12)
      ..write(obj.sunrise)
      ..writeByte(13)
      ..write(obj.sunset);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyWeatherAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CityLocationAdapter extends TypeAdapter<CityLocation> {
  @override
  final int typeId = 4;

  @override
  CityLocation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CityLocation(
      name: fields[0] as String,
      country: fields[1] as String,
      state: fields[2] as String,
      latitude: fields[3] as double,
      longitude: fields[4] as double,
      isCurrentLocation: fields[5] as bool,
      addedAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, CityLocation obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.country)
      ..writeByte(2)
      ..write(obj.state)
      ..writeByte(3)
      ..write(obj.latitude)
      ..writeByte(4)
      ..write(obj.longitude)
      ..writeByte(5)
      ..write(obj.isCurrentLocation)
      ..writeByte(6)
      ..write(obj.addedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CityLocationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WeatherDataContainerAdapter extends TypeAdapter<WeatherDataContainer> {
  @override
  final int typeId = 5;

  @override
  WeatherDataContainer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeatherDataContainer(
      cityWeatherData: (fields[0] as Map?)?.cast<String, WeatherData>(),
      savedCities: (fields[1] as List?)?.cast<CityLocation>(),
      lastGlobalUpdate: fields[2] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, WeatherDataContainer obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.cityWeatherData)
      ..writeByte(1)
      ..write(obj.savedCities)
      ..writeByte(2)
      ..write(obj.lastGlobalUpdate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherDataContainerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

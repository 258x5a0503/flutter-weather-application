import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherLocation {
  const WeatherLocation({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String country;
  final double latitude;
  final double longitude;

  String get displayName => country.isEmpty ? name : '$name, $country';
}

class HourlyForecast {
  const HourlyForecast({
    required this.time,
    required this.temperature,
    required this.precipitationProbability,
    required this.weatherCode,
  });

  final DateTime time;
  final double temperature;
  final int precipitationProbability;
  final int weatherCode;
}

class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.high,
    required this.low,
    required this.weatherCode,
  });

  final DateTime date;
  final double high;
  final double low;
  final int weatherCode;
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.location,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.precipitation,
    required this.weatherCode,
    required this.isDay,
    required this.hourly,
    required this.daily,
  });

  final WeatherLocation location;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final double precipitation;
  final int weatherCode;
  final bool isDay;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;
}

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<WeatherLocation> findLocation(String city) async {
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': city,
      'count': '1',
      'language': 'en',
      'format': 'json',
    });
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw const WeatherException('Could not search for that city.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      throw const WeatherException('No city found. Try another name.');
    }
    final result = results.first as Map<String, dynamic>;
    return WeatherLocation(
      name: result['name'] as String? ?? city,
      country: result['country'] as String? ?? '',
      latitude: (result['latitude'] as num).toDouble(),
      longitude: (result['longitude'] as num).toDouble(),
    );
  }

  Future<WeatherSnapshot> getWeather(WeatherLocation location) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'current':
          'temperature_2m,relative_humidity_2m,apparent_temperature,'
          'is_day,precipitation,weather_code,wind_speed_10m',
      'hourly': 'temperature_2m,precipitation_probability,weather_code',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,'
          'sunrise,sunset,uv_index_max',
      'forecast_days': '7',
      'timezone': 'auto',
    });
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw const WeatherException('Weather data is unavailable right now.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final current = body['current'] as Map<String, dynamic>;
    final hourly = body['hourly'] as Map<String, dynamic>;
    final daily = body['daily'] as Map<String, dynamic>;
    final hourlyTimes = hourly['time'] as List<dynamic>;
    final now = DateTime.parse(current['time'] as String);
    var firstHour = hourlyTimes.indexWhere(
      (time) => !DateTime.parse(time as String).isBefore(now),
    );
    if (firstHour < 0) firstHour = 0;
    final hourlyTemperatures = hourly['temperature_2m'] as List<dynamic>;
    final hourlyPrecipitation =
        hourly['precipitation_probability'] as List<dynamic>;
    final hourlyCodes = hourly['weather_code'] as List<dynamic>;
    final hourlyForecast = <HourlyForecast>[];
    for (var index = firstHour;
        index < hourlyTimes.length && hourlyForecast.length < 24;
        index++) {
      hourlyForecast.add(
        HourlyForecast(
          time: DateTime.parse(hourlyTimes[index] as String),
          temperature: (hourlyTemperatures[index] as num).toDouble(),
          precipitationProbability:
              (hourlyPrecipitation[index] as num).toInt(),
          weatherCode: (hourlyCodes[index] as num).toInt(),
        ),
      );
    }

    final dailyTimes = daily['time'] as List<dynamic>;
    final dailyMax = daily['temperature_2m_max'] as List<dynamic>;
    final dailyMin = daily['temperature_2m_min'] as List<dynamic>;
    final dailyCodes = daily['weather_code'] as List<dynamic>;
    final dailyForecast = <DailyForecast>[];
    for (var index = 0; index < dailyTimes.length; index++) {
      dailyForecast.add(
        DailyForecast(
          date: DateTime.parse(dailyTimes[index] as String),
          high: (dailyMax[index] as num).toDouble(),
          low: (dailyMin[index] as num).toDouble(),
          weatherCode: (dailyCodes[index] as num).toInt(),
        ),
      );
    }

    return WeatherSnapshot(
      location: location,
      temperature: (current['temperature_2m'] as num).toDouble(),
      feelsLike: (current['apparent_temperature'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).toInt(),
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      precipitation: (current['precipitation'] as num).toDouble(),
      weatherCode: (current['weather_code'] as num).toInt(),
      isDay: (current['is_day'] as num).toInt() == 1,
      hourly: hourlyForecast,
      daily: dailyForecast,
    );
  }

  void close() => _client.close();
}

class WeatherException implements Exception {
  const WeatherException(this.message);

  final String message;

  @override
  String toString() => message;
}

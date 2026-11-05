import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/weather_service.dart';

void main() {
  testWidgets('shows weather and searches for another city', (
    WidgetTester tester,
  ) async {
    final service = _FakeWeatherService();
    await tester.pumpWidget(WeatherApp(weatherService: service));
    await tester.pumpAndSettle();

    expect(find.text('weatherly'), findsOneWidget);
    expect(find.text('London, United Kingdom'), findsOneWidget);
    expect(find.text('18°'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Tokyo');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text('Tokyo, Japan'), findsOneWidget);
    expect(service.lastSearchedCity, 'Tokyo');
  });
}

class _FakeWeatherService extends WeatherService {
  _FakeWeatherService() : super();

  String? lastSearchedCity;

  @override
  Future<WeatherLocation> findLocation(String city) async {
    lastSearchedCity = city;
    return WeatherLocation(
      name: city,
      country: city == 'Tokyo' ? 'Japan' : 'United Kingdom',
      latitude: 0,
      longitude: 0,
    );
  }

  @override
  Future<WeatherSnapshot> getWeather(WeatherLocation location) async {
    final now = DateTime.now();
    return WeatherSnapshot(
      location: location,
      temperature: 18,
      feelsLike: 17,
      humidity: 62,
      windSpeed: 12,
      precipitation: 0,
      weatherCode: 2,
      isDay: true,
      hourly: [
        HourlyForecast(
          time: now,
          temperature: 18,
          precipitationProbability: 10,
          weatherCode: 2,
        ),
      ],
      daily: [
        DailyForecast(
          date: now,
          high: 20,
          low: 12,
          weatherCode: 2,
        ),
      ],
    );
  }
}

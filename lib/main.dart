import 'package:flutter/material.dart';

import 'weather_service.dart';

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key, this.weatherService});

  final WeatherService? weatherService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weatherly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF147D8C),
          brightness: Brightness.light,
        ),
      ),
      home: WeatherHomePage(
        weatherService: weatherService ?? WeatherService(),
      ),
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key, required this.weatherService});

  final WeatherService weatherService;

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final _searchController = TextEditingController(text: 'London');
  WeatherSnapshot? _weather;
  String? _error;
  bool _isLoading = true;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _search('London');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search([String? city]) async {
    final query = (city ?? _searchController.text).trim();
    if (query.isEmpty) {
      setState(() {
        _error = 'Enter a city name to see its weather.';
        _isLoading = false;
      });
      return;
    }

    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final location = await widget.weatherService.findLocation(query);
      final forecast = await widget.weatherService.getWeather(location);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _weather = forecast;
        _searchController.text = location.name;
        _isLoading = false;
      });
    } on WeatherException catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    } on Exception catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error =
            'Could not load weather ($error). Check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final weather = _weather;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F8),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _search(weather?.location.name),
          color: const Color(0xFF147D8C),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 22),
                      _buildSearchBar(),
                      const SizedBox(height: 22),
                      if (_isLoading && weather == null)
                        const _LoadingPanel()
                      else if (_error != null && weather == null)
                        _ErrorPanel(message: _error!, onRetry: () => _search())
                      else if (weather != null) ...[
                        if (_isLoading) const LinearProgressIndicator(),
                        if (_error != null) _InlineError(message: _error!),
                        _CurrentWeatherCard(weather: weather),
                        const SizedBox(height: 18),
                        _SectionHeading(
                          title: 'Today',
                          trailing: 'Next 24 hours',
                        ),
                        const SizedBox(height: 12),
                        _HourlyForecastCard(forecasts: weather.hourly),
                        const SizedBox(height: 22),
                        _SectionHeading(
                          title: 'This week',
                          trailing: '${weather.daily.length} days',
                        ),
                        const SizedBox(height: 12),
                        _WeeklyForecastCard(forecasts: weather.daily),
                        const SizedBox(height: 22),
                        _SectionHeading(title: 'Weather details'),
                        const SizedBox(height: 12),
                        _WeatherDetailsGrid(weather: weather),
                        const SizedBox(height: 20),
                        const Center(
                          child: Text(
                            'Weather data by Open-Meteo',
                            style: TextStyle(
                              color: Color(0xFF82949A),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFDCEFF0),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.wb_sunny_rounded,
            color: Color(0xFF147D8C),
            size: 23,
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Text(
            'weatherly',
            style: TextStyle(
              color: Color(0xFF142E35),
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Refresh weather',
          onPressed: _isLoading ? null : () => _search(),
          icon: const Icon(Icons.refresh_rounded),
          color: const Color(0xFF39575E),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE1E9EA)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF17383F).withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Color(0xFF789095)),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                hintText: 'Search for a city',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            child: FilledButton(
              onPressed: _isLoading ? null : () => _search(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF147D8C),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Search'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentWeatherCard extends StatelessWidget {
  const _CurrentWeatherCard({required this.weather});

  final WeatherSnapshot weather;

  @override
  Widget build(BuildContext context) {
    final condition = weatherDescription(weather.weatherCode);
    final icon = weatherIcon(weather.weatherCode, isDay: weather.isDay);
    final today = DateTime.now();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF126C7B), Color(0xFF238F9B), Color(0xFF58B9B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF147D8C).withValues(alpha: 0.21),
            blurRadius: 24,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: Colors.white70,
                size: 17,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  weather.location.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _formatDate(today),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${weather.temperature.round()}°',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 76,
                        height: 0.98,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      condition,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Feels like ${weather.feelsLike.round()}°',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(icon, size: 94, color: const Color(0xFFFFE38D)),
            ],
          ),
          const SizedBox(height: 22),
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: 17),
          Row(
            children: [
              _QuickStat(
                icon: Icons.water_drop_outlined,
                value: '${weather.humidity}%',
                label: 'Humidity',
              ),
              _QuickStat(
                icon: Icons.air_rounded,
                value: '${weather.windSpeed.round()} km/h',
                label: 'Wind',
              ),
              _QuickStat(
                icon: Icons.grain_rounded,
                value: '${weather.precipitation.toStringAsFixed(1)} mm',
                label: 'Rain',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF18343B),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              color: Color(0xFF83979C),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
}

class _HourlyForecastCard extends StatelessWidget {
  const _HourlyForecastCard({required this.forecasts});

  final List<HourlyForecast> forecasts;

  @override
  Widget build(BuildContext context) {
    return _CardSurface(
      child: SizedBox(
        height: 137,
        child: forecasts.isEmpty
            ? const Center(child: Text('Hourly forecast unavailable'))
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: forecasts.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 20),
                itemBuilder: (context, index) {
                  final forecast = forecasts[index];
                  final hour = forecast.time.hour;
                  return SizedBox(
                    width: 49,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          index == 0 ? 'Now' : _formatHour(hour),
                          style: TextStyle(
                            color: index == 0
                                ? const Color(0xFF147D8C)
                                : const Color(0xFF83979C),
                            fontSize: 12,
                            fontWeight: index == 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        Icon(
                          weatherIcon(forecast.weatherCode, isDay: hour > 6 && hour < 19),
                          color: const Color(0xFFE5AD3B),
                          size: 25,
                        ),
                        Text(
                          '${forecast.temperature.round()}°',
                          style: const TextStyle(
                            color: Color(0xFF243F46),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.water_drop_rounded,
                              color: Color(0xFF62AFC0),
                              size: 12,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${forecast.precipitationProbability}%',
                              style: const TextStyle(
                                color: Color(0xFF83979C),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _WeeklyForecastCard extends StatelessWidget {
  const _WeeklyForecastCard({required this.forecasts});

  final List<DailyForecast> forecasts;

  @override
  Widget build(BuildContext context) {
    return _CardSurface(
      child: Column(
        children: [
          for (var index = 0; index < forecasts.length; index++) ...[
            if (index > 0)
              const Divider(height: 19, color: Color(0xFFEDF1F2)),
            _DayForecastRow(forecast: forecasts[index], index: index),
          ],
        ],
      ),
    );
  }
}

class _DayForecastRow extends StatelessWidget {
  const _DayForecastRow({required this.forecast, required this.index});

  final DailyForecast forecast;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 66,
          child: Text(
            index == 0 ? 'Today' : _weekday(forecast.date),
            style: const TextStyle(
              color: Color(0xFF314C53),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(
          weatherIcon(forecast.weatherCode),
          size: 22,
          color: const Color(0xFFE5AD3B),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            weatherDescription(forecast.weatherCode),
            style: const TextStyle(color: Color(0xFF83979C), fontSize: 12),
          ),
        ),
        Text(
          '${forecast.low.round()}°',
          style: const TextStyle(
            color: Color(0xFF91A2A6),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 30,
          child: Text(
            '${forecast.high.round()}°',
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFF314C53),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _WeatherDetailsGrid extends StatelessWidget {
  const _WeatherDetailsGrid({required this.weather});

  final WeatherSnapshot weather;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.65,
      children: [
        _DetailTile(
          icon: Icons.thermostat_rounded,
          label: 'Feels like',
          value: '${weather.feelsLike.round()}°',
          color: const Color(0xFFE9A755),
        ),
        _DetailTile(
          icon: Icons.water_drop_outlined,
          label: 'Humidity',
          value: '${weather.humidity}%',
          color: const Color(0xFF5BA9BE),
        ),
        _DetailTile(
          icon: Icons.air_rounded,
          label: 'Wind speed',
          value: '${weather.windSpeed.toStringAsFixed(1)} km/h',
          color: const Color(0xFF648DA0),
        ),
        _DetailTile(
          icon: Icons.grain_rounded,
          label: 'Precipitation',
          value: '${weather.precipitation.toStringAsFixed(1)} mm',
          color: const Color(0xFF6C9BCE),
        ),
      ],
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _CardSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 21),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF243F46),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF83979C),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardSurface extends StatelessWidget {
  const _CardSurface({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9EFF0)),
      ),
      child: child,
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 360,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF147D8C)),
            SizedBox(height: 16),
            Text(
              'Checking the skies...',
              style: TextStyle(color: Color(0xFF71878C)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _CardSurface(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xFF709197),
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF49636A)),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF9A6B25), size: 18),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF80602C), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
}

String _weekday(DateTime date) {
  const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return weekdays[date.weekday - 1];
}

String _formatHour(int hour) {
  final normalized = hour % 12 == 0 ? 12 : hour % 12;
  return '$normalized ${hour < 12 ? 'AM' : 'PM'}';
}

String weatherDescription(int code) {
  if (code == 0) return 'Clear sky';
  if (code == 1) return 'Mainly clear';
  if (code == 2) return 'Partly cloudy';
  if (code == 3) return 'Overcast';
  if (code == 45 || code == 48) return 'Foggy';
  if (code == 51 || code == 53 || code == 55) return 'Drizzle';
  if (code == 56 || code == 57) return 'Freezing drizzle';
  if (code == 61 || code == 63 || code == 65) return 'Rain';
  if (code == 66 || code == 67) return 'Freezing rain';
  if (code == 71 || code == 73 || code == 75 || code == 77) return 'Snow';
  if (code == 80 || code == 81 || code == 82) return 'Rain showers';
  if (code == 85 || code == 86) return 'Snow showers';
  if (code == 95 || code == 96 || code == 99) return 'Thunderstorm';
  return 'Unknown';
}

IconData weatherIcon(int code, {bool isDay = true}) {
  if (code == 0) {
    return isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
  }
  if (code == 1 || code == 2) return Icons.wb_cloudy_rounded;
  if (code == 3 || code == 45 || code == 48) return Icons.cloud_rounded;
  if (code >= 51 && code <= 67) return Icons.grain_rounded;
  if (code >= 71 && code <= 86) return Icons.ac_unit_rounded;
  if (code >= 95) return Icons.thunderstorm_rounded;
  if (code >= 80) return Icons.water_rounded;
  return Icons.cloud_rounded;
}

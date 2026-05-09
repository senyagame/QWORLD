import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'main.dart'; // Импорт для доступа к localeNotifier
import 'air_quality_screen.dart'; // Импорт нового экрана качества воздуха

class WeatherScreen extends StatefulWidget {
  final Position? position;
  const WeatherScreen({super.key, this.position});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  // ВНИМАНИЕ: Замени "YOUR_API_KEY" на свой реальный ключ перед запуском
  final String apiKey = "YOUR_API_KEY";
  Map<String, dynamic>? weatherData;
  Map<String, dynamic>? airPollutionData;
  List<Map<String, dynamic>>? processedForecast; // Список обработанных дней
  List<dynamic>? hourlyForecast; // Список для почасового прогноза
  Position? _currentPosition;
  bool isLoading = true;
  bool showHourly = false; // Состояние видимости почасового прогноза
  String errorMessage = "";
  String? displayCityName; // Переменная для хранения чистого названия города

  // Контроллер для почасового списка (нужен для Scrollbar)
  final ScrollController _hourlyScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.position;

    Future.wait([
      initializeDateFormatting('ru', null),
      initializeDateFormatting('en', null),
    ]).then((_) {
      _initData();
    });
  }

  @override
  void dispose() {
    _hourlyScrollController.dispose(); // Освобождаем ресурсы
    super.dispose();
  }

  Future<void> _initData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      if (_currentPosition == null) {
        try {
          _currentPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 3),
          );
        } catch (e) {
          debugPrint("GPS error, using default");
        }
      }

      await Future.wait([
        fetchWeather(),
        fetchAirPollution(),
        fetchForecast(),
      ]);

      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      debugPrint("Init Error: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = "Ошибка обновления";
        });
      }
    }
  }

  Future<void> fetchWeather() async {
    double lat = _currentPosition?.latitude ?? 43.2389;
    double lon = _currentPosition?.longitude ?? 76.8897;
    String lang = localeNotifier.value.languageCode;

    // Сначала получаем данные о погоде по координатам
    final url = 'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=$lang';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      weatherData = json.decode(response.body);

      try {
        final geoUrl = 'https://api.openweathermap.org/geo/1.0/reverse?lat=$lat&lon=$lon&limit=1&appid=$apiKey';
        final geoResponse = await http.get(Uri.parse(geoUrl));
        if (geoResponse.statusCode == 200) {
          final List<dynamic> geoData = json.decode(geoResponse.body);
          if (geoData.isNotEmpty) {
            final names = geoData[0]['local_names'];
            displayCityName = names != null && names[lang] != null
                ? names[lang]
                : geoData[0]['name'];
          }
        }
      } catch (e) {
        debugPrint("Geo Error: $e");
      }

      displayCityName ??= weatherData?['name'];
    }
  }

  Future<void> fetchAirPollution() async {
    double lat = _currentPosition?.latitude ?? 43.2389;
    double lon = _currentPosition?.longitude ?? 76.8897;

    final url = 'https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$apiKey';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      airPollutionData = json.decode(response.body);
    }
  }

  Future<void> fetchForecast() async {
    double lat = _currentPosition?.latitude ?? 43.2389;
    double lon = _currentPosition?.longitude ?? 76.8897;
    String lang = localeNotifier.value.languageCode;

    final url = 'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=$lang';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> list = data['list'];

      hourlyForecast = list.take(12).toList();

      Map<String, Map<String, dynamic>> dailyMap = {};
      String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      for (var entry in list) {
        DateTime date = DateTime.fromMillisecondsSinceEpoch(entry['dt'] * 1000);
        String dateStr = DateFormat('yyyy-MM-dd').format(date);

        if (dateStr == todayStr) continue;

        if (!dailyMap.containsKey(dateStr)) {
          dailyMap[dateStr] = {
            'date': date,
            'temp_max': entry['main']['temp_max'],
            'temp_min': entry['main']['temp_min'],
            'condition': entry['weather'][0]['main'],
            'icon': entry['weather'][0]['icon'],
          };
        } else {
          if (entry['main']['temp_max'] > dailyMap[dateStr]!['temp_max']) {
            dailyMap[dateStr]!['temp_max'] = entry['main']['temp_max'];
            dailyMap[dateStr]!['icon'] = entry['weather'][0]['icon'];
            dailyMap[dateStr]!['condition'] = entry['weather'][0]['main'];
          }
          if (entry['main']['temp_min'] < dailyMap[dateStr]!['temp_min']) {
            dailyMap[dateStr]!['temp_min'] = entry['main']['temp_min'];
          }
        }
      }

      var sortedKeys = dailyMap.keys.toList()..sort();
      processedForecast = sortedKeys.take(3).map((key) => dailyMap[key]!).toList();

      setState(() {});
    }
  }

  String _getAirQualityText(int aqi, bool isRu) {
    switch (aqi) {
      case 1: return isRu ? "Отлично" : "Excellent";
      case 2: return isRu ? "Хорошо" : "Good";
      case 3: return isRu ? "Средне" : "Fair";
      case 4: return isRu ? "Плохо" : "Poor";
      case 5: return isRu ? "Опасно" : "Hazardous";
      default: return isRu ? "Нет данных" : "No data";
    }
  }

  Color _getAirQualityColor(int aqi, Color defaultColor) {
    switch (aqi) {
      case 1: return Colors.greenAccent;
      case 2: return Colors.yellowAccent;
      case 3: return Colors.orangeAccent;
      case 4: return Colors.redAccent;
      case 5: return Colors.purpleAccent;
      default: return defaultColor;
    }
  }

  Color _getContentColor(String condition, bool isDay) {
    final cond = condition.toLowerCase().trim();
    if (cond == 'snow' && isDay) return Colors.black87;
    if (cond == 'clouds' && isDay) return Colors.black87;
    return Colors.white;
  }

  IconData _getWeatherIcon(String condition, bool isDay) {
    switch (condition.toLowerCase().trim()) {
      case 'clear': return isDay ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded;
      case 'clouds': return isDay ? Icons.wb_cloudy_rounded : Icons.cloud_rounded;
      case 'rain':
      case 'drizzle': return Icons.water_drop_rounded;
      case 'thunderstorm': return Icons.thunderstorm_rounded;
      case 'snow': return Icons.ac_unit_rounded;
      case 'mist':
      case 'smoke':
      case 'haze':
      case 'dust':
      case 'fog':
      case 'sand':
      case 'ash':
      case 'squall': return Icons.foggy;
      case 'tornado': return Icons.tornado_rounded;
      default: return Icons.wb_cloudy_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRu = localeNotifier.value.languageCode == 'ru';

    final String mainCond = (weatherData?['weather']?[0]?['main'] ?? "Clear").toString().trim();
    final String currentIconCode = (weatherData?['weather']?[0]?['icon'] ?? "01d").toString();
    final bool currentIsDay = currentIconCode.endsWith('d');

    final cityName = displayCityName ?? (isRu ? "Загрузка..." : "Loading...");
    final desc = weatherData?['weather']?[0]?['description'] ?? "";

    final int temp = (weatherData?['main']?['temp'] as num?)?.round() ?? 0;
    final int feelsLike = (weatherData?['main']?['feels_like'] as num?)?.round() ?? 0;
    final int aqi = (airPollutionData?['list']?[0]?['main']?['aqi'] as num?)?.toInt() ?? 0;
    final double pm25 = (airPollutionData?['list']?[0]?['components']?['pm2_5'] as num?)?.toDouble() ?? 0.0;
    final double pm10 = (airPollutionData?['list']?[0]?['components']?['pm10'] as num?)?.toDouble() ?? 0.0;
    final double windSpeed = (weatherData?['wind']?['speed'] as num?)?.toDouble() ?? 0.0;

    final contentColor = _getContentColor(mainCond, currentIsDay);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: contentColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: contentColor, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Stack(
        children: [
          AnimatedWeatherBackground(
            condition: mainCond,
            isDay: currentIsDay,
            windSpeed: windSpeed,
          ),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: (isLoading && weatherData == null)
                ? Center(
              key: const ValueKey('loader'),
              child: SatelliteLoader(color: contentColor),
            )
                : SafeArea(
              key: const ValueKey('content'),
              child: RefreshIndicator(
                onRefresh: _initData,
                color: contentColor,
                backgroundColor: Colors.transparent,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        cityName,
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: contentColor, letterSpacing: -0.5),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        DateFormat(isRu ? 'EEEE, d MMMM' : 'EEEE, d MMMM', isRu ? 'ru' : 'en').format(DateTime.now()),
                        style: TextStyle(fontSize: 16, color: contentColor.withOpacity(0.7), fontWeight: FontWeight.w400),
                      ),
                      const SizedBox(height: 30),
                      Icon(_getWeatherIcon(mainCond, currentIsDay), size: 120, color: contentColor),
                      const SizedBox(height: 10),
                      Text(
                        "$temp°",
                        style: TextStyle(fontSize: 100, fontWeight: FontWeight.w300, color: contentColor, height: 1.0, letterSpacing: -2),
                      ),
                      Text(
                        isRu ? "Ощущается как $feelsLike°" : "Feels like $feelsLike°",
                        style: TextStyle(fontSize: 18, color: contentColor.withOpacity(0.8), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: contentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          desc.toUpperCase(),
                          style: TextStyle(fontSize: 12, color: contentColor, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 40),

                      _buildForecastCard(isRu, contentColor),

                      const SizedBox(height: 24),

                      _buildHourlyToggleButton(isRu, contentColor),

                      _buildHourlyForecast(isRu, contentColor),

                      const SizedBox(height: 24),
                      _buildAirQualityCard(aqi, pm25, pm10, isRu, contentColor),
                      const SizedBox(height: 24),
                      _buildMetricsCard(isRu, contentColor),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyToggleButton(bool isRu, Color textColor) {
    return FilledButton.tonalIcon(
      onPressed: () => setState(() => showHourly = !showHourly),
      style: FilledButton.styleFrom(
        backgroundColor: textColor.withOpacity(0.15),
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      icon: Icon(
        showHourly ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
        size: 20,
      ),
      label: Text(
        isRu
            ? (showHourly ? "Скрыть детали" : "Почасовой прогноз")
            : (showHourly ? "Hide details" : "Hourly forecast"),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }

  Widget _buildHourlyForecast(bool isRu, Color textColor) {
    if (!showHourly || hourlyForecast == null) return const SizedBox.shrink();

    Color cardColor = textColor == Colors.white
        ? Colors.white.withOpacity(0.12)
        : Colors.white.withOpacity(0.4);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(top: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.0),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 125,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      scrollbarTheme: ScrollbarThemeData(
                        thumbColor: WidgetStateProperty.all(textColor.withOpacity(0.4)),
                        thickness: WidgetStateProperty.all(3.0),
                        radius: const Radius.circular(10),
                      ),
                    ),
                    child: Scrollbar(
                      controller: _hourlyScrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: _hourlyScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
                        itemCount: hourlyForecast!.length,
                        itemBuilder: (context, index) {
                          final item = hourlyForecast![index];
                          final time = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
                          final temp = (item['main']['temp'] as num).round();
                          final cond = item['weather'][0]['main'];
                          final iconCode = item['weather'][0]['icon'];
                          final isDay = iconCode.endsWith('d');
                          final hourStr = DateFormat('HH:mm').format(time);

                          return Container(
                            width: 80,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: textColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  index == 0 ? (isRu ? "Сейчас" : "Now") : hourStr,
                                  style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 12),
                                Icon(_getWeatherIcon(cond, isDay), color: textColor, size: 32),
                                const SizedBox(height: 12),
                                Text(
                                  "$temp°",
                                  style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForecastCard(bool isRu, Color textColor) {
    if (processedForecast == null || processedForecast!.isEmpty) return const SizedBox.shrink();

    Color cardColor = textColor == Colors.white
        ? Colors.white.withOpacity(0.12)
        : Colors.white.withOpacity(0.4);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.0),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: textColor.withOpacity(0.6), size: 18),
                  const SizedBox(width: 10),
                  Text(
                    isRu ? "ПРОГНОЗ НА 3 ДНЯ" : "3-DAY FORECAST",
                    style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Column(
                children: processedForecast!.map((item) {
                  final DateTime date = item['date'];
                  final String dayName = DateFormat('EEEE', isRu ? 'ru' : 'en').format(date);

                  final int tempMax = (item['temp_max'] as num).round();
                  final int tempMin = (item['temp_min'] as num).round();

                  final String condition = item['condition'];
                  final String iconCode = item['icon'];
                  final bool isDay = iconCode.endsWith('d');

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            dayName[0].toUpperCase() + dayName.substring(1),
                            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Icon(_getWeatherIcon(condition, isDay), color: textColor, size: 24),
                        ),
                        Expanded(
                          flex: 4,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(Icons.wb_sunny_rounded, size: 14, color: textColor.withOpacity(0.5)),
                              const SizedBox(width: 6),
                              Text(
                                "$tempMax°",
                                style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.mode_night_rounded, size: 14, color: textColor.withOpacity(0.5)),
                              const SizedBox(width: 6),
                              Text(
                                "$tempMin°",
                                style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 18, fontWeight: FontWeight.w400),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAirQualityCard(int aqi, double pm25, double pm10, bool isRu, Color textColor) {
    Color cardColor = textColor == Colors.white
        ? Colors.white.withOpacity(0.12)
        : Colors.white.withOpacity(0.4);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AirQualityScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.0),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.bubble_chart_rounded, color: textColor.withOpacity(0.6), size: 20),
                    const SizedBox(width: 10),
                    Text(
                        isRu ? "КАЧЕСТВО ВОЗДУХА" : "AIR QUALITY",
                        style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getAirQualityColor(aqi, textColor).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getAirQualityText(aqi, isRu),
                        style: TextStyle(color: _getAirQualityColor(aqi, textColor), fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios_rounded, color: textColor.withOpacity(0.4), size: 14),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _airMetric("PM2.5", pm25.toStringAsFixed(1), textColor),
                    _airMetric("PM10", pm10.toStringAsFixed(1), textColor),
                    _airMetric("AQI", "$aqi", textColor),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _airMetric(String label, String value, Color textColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMetricsCard(bool isRu, Color textColor) {
    final int humidity = (weatherData?['main']?['humidity'] as num?)?.toInt() ?? 0;
    final double wind = (weatherData?['wind']?['speed'] as num?)?.toDouble() ?? 0.0;
    final int visibility = (weatherData?['visibility'] as num?)?.toInt() ?? 10000;
    final int pressure = (weatherData?['main']?['pressure'] as num?)?.toInt() ?? 0;

    Color cardColor = textColor == Colors.white
        ? Colors.white.withOpacity(0.12)
        : Colors.white.withOpacity(0.4);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.0),
          ),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.6,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _weatherMetric(Icons.water_drop_rounded, "$humidity%", isRu ? "Влажность" : "Humidity", textColor),
              _weatherMetric(Icons.air_rounded, "${wind.toStringAsFixed(1)} ${isRu ? 'м/с' : 'm/s'}", isRu ? "Ветер" : "Wind", textColor),
              _weatherMetric(Icons.visibility_rounded, "${(visibility / 1000).toStringAsFixed(1)} ${isRu ? 'км' : 'km'}", isRu ? "Вид" : "Visibility", textColor),
              _weatherMetric(Icons.compress_rounded, "$pressure", isRu ? "Давление" : "Pressure", textColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weatherMetric(IconData icon, String value, String label, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor.withOpacity(0.7), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                Text(label, style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.6), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SatelliteLoader extends StatefulWidget {
  final Color? color;
  const SatelliteLoader({super.key, this.color});

  @override
  State<SatelliteLoader> createState() => _SatelliteLoaderState();
}

class _SatelliteLoaderState extends State<SatelliteLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).primaryColor;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(100, 120),
              painter: _SatellitePainter(
                animationValue: _controller.value,
                color: color,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SatellitePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _SatellitePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    const satelliteY = 30.0;

    final bodyPaint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(centerX, satelliteY), width: 24, height: 18),
        const Radius.circular(4),
      ),
      bodyPaint,
    );
    canvas.drawRect(Rect.fromLTWH(centerX - 30, satelliteY - 4, 16, 8), bodyPaint);
    canvas.drawRect(Rect.fromLTWH(centerX + 14, satelliteY - 4, 16, 8), bodyPaint);
    canvas.drawLine(Offset(centerX - 14, satelliteY), Offset(centerX - 12, satelliteY), paint);
    canvas.drawLine(Offset(centerX + 12, satelliteY), Offset(centerX + 14, satelliteY), paint);

    for (int i = 0; i < 3; i++) {
      double waveProgress = (animationValue + (i / 3)) % 1.0;
      double opacity = (1.0 - waveProgress).clamp(0.0, 1.0);
      double yOffset = satelliteY + 20 + (waveProgress * 60);
      double waveWidth = 10 + (waveProgress * 30);

      final wavePaint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCenter(center: Offset(centerX, yOffset), width: waveWidth, height: waveWidth / 2);
      canvas.drawArc(rect, 0, math.pi, false, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SatellitePainter oldDelegate) => true;
}

class Particle {
  double x;
  double y;
  double speedY;
  double speedX;
  double length;
  double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.speedY,
    required this.speedX,
    required this.length,
    required this.opacity,
  });
}

class AnimatedWeatherBackground extends StatefulWidget {
  final String condition;
  final bool isDay;
  final double windSpeed;

  const AnimatedWeatherBackground({
    super.key,
    required this.condition,
    required this.isDay,
    required this.windSpeed,
  });

  @override
  State<AnimatedWeatherBackground> createState() => _AnimatedWeatherBackgroundState();
}

class _AnimatedWeatherBackgroundState extends State<AnimatedWeatherBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<Particle> particles = [];
  final int particleCount = 100;
  final math.Random random = math.Random();
  double lightningFlash = 0.0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(() {
        if (!mounted || !_isInitialized) return;
        _updateParticles();
        if (widget.condition.toLowerCase() == 'thunderstorm') {
          _generateLightning();
        } else {
          lightningFlash = 0.0;
        }
        setState(() {});
      })
      ..repeat();
  }

  @override
  void didUpdateWidget(AnimatedWeatherBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.condition != widget.condition || oldWidget.isDay != widget.isDay) {
      _isInitialized = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initParticles(Size size) {
    particles.clear();
    final cond = widget.condition.toLowerCase();
    bool isSnow = cond == 'snow';
    bool isRain = cond == 'rain' || cond == 'drizzle' || cond == 'thunderstorm';

    if (!isSnow && !isRain) {
      _isInitialized = true;
      return;
    }

    double visualWind = widget.windSpeed * 0.4;

    for (int i = 0; i < particleCount; i++) {
      particles.add(Particle(
        x: random.nextDouble() * size.width,
        y: random.nextDouble() * size.height,
        speedY: isSnow ? random.nextDouble() * 2.0 + 1.0 : random.nextDouble() * 10 + 15,
        speedX: visualWind + (random.nextDouble() * 0.5),
        length: isSnow ? random.nextDouble() * 3 + 1.5 : random.nextDouble() * 15 + 15,
        opacity: random.nextDouble() * 0.4 + 0.2,
      ));
    }
    _isInitialized = true;
  }

  void _updateParticles() {
    if (particles.isEmpty) return;
    final size = MediaQuery.of(context).size;
    final double surfaceY = size.height;

    for (var p in particles) {
      p.y += p.speedY;
      p.x += p.speedX;

      if (p.y >= surfaceY) {
        p.y = -p.length;
        p.x = random.nextDouble() * size.width;
      }

      if (p.x > size.width) p.x = -p.length;
      if (p.x < -p.length) p.x = size.width;
    }
  }

  void _generateLightning() {
    if (random.nextDouble() > 0.97) {
      lightningFlash = random.nextDouble() * 0.5 + 0.2;
    } else {
      lightningFlash *= 0.8;
      if (lightningFlash < 0.01) lightningFlash = 0.0;
    }
  }

  List<Color> _getBackgroundColors(String condition, bool isDay) {
    switch (condition.toLowerCase().trim()) {
      case 'clear':
        return isDay
            ? [const Color(0xFF56CCF2), const Color(0xFF2F80ED)]
            : [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)];
      case 'clouds':
        return isDay
            ? [const Color(0xFF8e9eab), const Color(0xFFeef2f3)]
            : [const Color(0xFF2c3e50), const Color(0xFF3498db)];
      case 'rain':
      case 'drizzle':
        return [const Color(0xFF2b5876), const Color(0xFF4e4376)];
      case 'thunderstorm':
        return [const Color(0xFF141E30), const Color(0xFF243B55)];
      case 'snow':
        return isDay
            ? [const Color(0xFFE0EAFC), const Color(0xFFCFDEF3)]
            : [const Color(0xFF1c2837), const Color(0xFF3b4d61)];
      default:
        return [const Color(0xFF4A90E2), const Color(0xFF003399)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) {
          if (!_isInitialized && constraints.maxWidth > 0) {
            _initParticles(Size(constraints.maxWidth, constraints.maxHeight));
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 1000),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _getBackgroundColors(widget.condition, widget.isDay),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CustomPaint(
              painter: WeatherPainter(
                particles: particles,
                condition: widget.condition,
                lightningFlash: lightningFlash,
              ),
              size: Size.infinite,
            ),
          );
        }
    );
  }
}

class WeatherPainter extends CustomPainter {
  final List<Particle> particles;
  final String condition;
  final double lightningFlash;

  WeatherPainter({
    required this.particles,
    required this.condition,
    required this.lightningFlash,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cond = condition.toLowerCase();
    bool isSnow = cond == 'snow';

    if (cond == 'thunderstorm' && lightningFlash > 0) {
      final paint = Paint()..color = Colors.white.withOpacity(lightningFlash);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }

    if (particles.isEmpty) return;

    final paint = Paint()..strokeCap = StrokeCap.round;

    for (var p in particles) {
      paint.color = Colors.white.withOpacity(p.opacity);

      if (isSnow) {
        canvas.drawCircle(Offset(p.x, p.y), p.length / 2, paint);
      } else {
        paint.strokeWidth = 2.0;
        canvas.drawLine(
          Offset(p.x, p.y),
          Offset(p.x - p.speedX * 1.5, p.y - p.length),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

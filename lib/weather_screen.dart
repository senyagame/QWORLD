import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'main.dart'; // Импорт для доступа к localeNotifier

class WeatherScreen extends StatefulWidget {
  final Position? position;
  const WeatherScreen({super.key, this.position});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final String apiKey = "8176cdd345a6be81bb9361a182580d03";
  Map<String, dynamic>? weatherData;
  Map<String, dynamic>? airPollutionData;
  List<dynamic>? forecastData;
  Position? _currentPosition;
  bool isLoading = true;
  String errorMessage = "";

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

    final url = 'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=$lang';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      weatherData = json.decode(response.body);
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
      setState(() {
        forecastData = [data['list'][8], data['list'][16], data['list'][24]];
      });
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

  List<Color> _getWeatherGradient(String condition) {
    switch (condition.toLowerCase().trim()) {
      case 'clear': return [const Color(0xFF4facfe), const Color(0xFF00f2fe)];
      case 'clouds': return [const Color(0xFFbdc3c7), const Color(0xFF2c3e50)];
      case 'rain':
      case 'drizzle': return [const Color(0xFF203a43), const Color(0xFF2c5364)];
      case 'thunderstorm': return [const Color(0xFF0f0c29), const Color(0xFF302b63)];
      case 'snow': return [const Color(0xFFe6e9f0), const Color(0xFFeef1f5)];
      default: return [const Color(0xFF4A90E2), const Color(0xFF003399)];
    }
  }

  Color _getContentColor(String condition) {
    // Если снег или очень светлый фон — используем черный текст
    if (condition.toLowerCase().trim() == 'snow') {
      return Colors.black;
    }
    return Colors.white;
  }

  IconData _getWeatherIcon(String condition) {
    switch (condition.toLowerCase().trim()) {
      case 'clear': return Icons.wb_sunny_rounded;
      case 'clouds': return Icons.wb_cloudy_rounded;
      case 'rain': return Icons.umbrella_rounded;
      case 'snow': return Icons.ac_unit_rounded;
      case 'thunderstorm': return Icons.thunderstorm_rounded;
      default: return Icons.wb_cloudy_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRu = localeNotifier.value.languageCode == 'ru';
    // Достаем состояние погоды и чистим его от лишних пробелов
    final String mainCond = (weatherData?['weather']?[0]?['main'] ?? "Clear").toString().trim();

    final cityName = weatherData?['name'] ?? (isRu ? "Загрузка..." : "Loading...");
    final temp = weatherData?['main']?['temp']?.round() ?? 0;
    final desc = weatherData?['weather']?[0]?['description'] ?? "";

    final aqi = airPollutionData?['list']?[0]?['main']?['aqi'] ?? 0;
    final pm25 = airPollutionData?['list']?[0]?['components']?['pm2_5'] ?? 0;
    final pm10 = airPollutionData?['list']?[0]?['components']?['pm10'] ?? 0;

    final contentColor = _getContentColor(mainCond);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: contentColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _getWeatherGradient(mainCond),
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading && weatherData == null
            ? Center(child: CircularProgressIndicator(color: contentColor))
            : SafeArea(
          child: RefreshIndicator(
            onRefresh: _initData,
            color: contentColor,
            backgroundColor: Colors.transparent,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    cityName,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: contentColor),
                  ),
                  Text(
                    DateFormat(isRu ? 'EEEE, d MMMM' : 'EEEE, d MMMM', isRu ? 'ru' : 'en').format(DateTime.now()),
                    style: TextStyle(fontSize: 16, color: contentColor.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 30),
                  Icon(_getWeatherIcon(mainCond), size: 100, color: contentColor),
                  const SizedBox(height: 10),
                  Text(
                    "$temp°",
                    style: TextStyle(fontSize: 90, fontWeight: FontWeight.w200, color: contentColor),
                  ),
                  Text(
                    desc.toUpperCase(),
                    style: TextStyle(fontSize: 14, color: contentColor.withOpacity(0.7), letterSpacing: 2, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),

                  _buildForecastCard(isRu, contentColor),

                  const SizedBox(height: 20),
                  _buildAirQualityCard(aqi, pm25, pm10, isRu, contentColor),
                  const SizedBox(height: 20),
                  _buildMetricsCard(isRu, contentColor),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForecastCard(bool isRu, Color textColor) {
    if (forecastData == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: textColor == Colors.white ? Colors.black.withOpacity(0.15) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: textColor.withOpacity(0.7), size: 16),
              const SizedBox(width: 8),
              Text(
                isRu ? "ПРОГНОЗ НА 3 ДНЯ" : "3-DAY FORECAST",
                style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            children: forecastData!.map((item) {
              final date = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
              final dayName = DateFormat('EEEE', isRu ? 'ru' : 'en').format(date);
              final tempMax = item['main']['temp_max'].round();
              final tempMin = item['main']['temp_min'].round();
              final condition = (item['weather'][0]['main'] ?? "Clear").toString().trim();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        dayName,
                        style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Icon(_getWeatherIcon(condition), color: textColor, size: 24),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        "$tempMax° / $tempMin°",
                        textAlign: TextAlign.right,
                        style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAirQualityCard(int aqi, dynamic pm25, dynamic pm10, bool isRu, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: textColor == Colors.white ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.air_rounded, color: textColor.withOpacity(0.7), size: 18),
              const SizedBox(width: 8),
              Text(
                  isRu ? "ВОЗДУХ" : "AIR QUALITY",
                  style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold)
              ),
              const Spacer(),
              Text(
                _getAirQualityText(aqi, isRu),
                style: TextStyle(color: _getAirQualityColor(aqi, textColor), fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _airMetric("PM2.5", "$pm25", textColor),
              _airMetric("PM10", "$pm10", textColor),
              _airMetric("AQI", "$aqi", textColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _airMetric(String label, String value, Color textColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11)),
      ],
    );
  }

  Widget _buildMetricsCard(bool isRu, Color textColor) {
    final humidity = weatherData?['main']?['humidity'] ?? 0;
    final wind = weatherData?['wind']?['speed'] ?? 0;
    final feelsLike = weatherData?['main']?['feels_like']?.round() ?? 0;
    final pressure = weatherData?['main']?['pressure'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: textColor == Colors.white ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.8,
        children: [
          _weatherMetric(Icons.water_drop, "$humidity%", isRu ? "Влажность" : "Humidity", textColor),
          _weatherMetric(Icons.air, "$wind ${isRu ? 'м/с' : 'm/s'}", isRu ? "Ветер" : "Wind", textColor),
          _weatherMetric(Icons.thermostat, "$feelsLike°", isRu ? "Ощущается" : "Feels like", textColor),
          _weatherMetric(Icons.compress, "$pressure", isRu ? "Давление" : "Pressure", textColor),
        ],
      ),
    );
  }

  Widget _weatherMetric(IconData icon, String value, String label, Color textColor) {
    return Row(
      children: [
        Icon(icon, color: textColor.withOpacity(0.7), size: 24),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
            Text(label, style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.6))),
          ],
        ),
      ],
    );
  }
}
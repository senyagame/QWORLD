import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart'; // Для доступа к локали

class AirQualityScreen extends StatefulWidget {
  const AirQualityScreen({super.key});

  @override
  State<AirQualityScreen> createState() => _AirQualityScreenState();
}

class _AirQualityScreenState extends State<AirQualityScreen> {
  Map<String, dynamic>? _aqiData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAirQualityOptimized();
  }

  // Оптимизированный метод загрузки
  Future<void> _fetchAirQualityOptimized() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Пытаемся получить последнее известное местоположение (мгновенно)
      // Если оно есть, используем его сразу, чтобы не ждать холодного старта GPS
      Position? position = await Geolocator.getLastKnownPosition();

      // Если данных нет, запрашиваем текущие с жестким таймаутом
      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );

      // 2. Выполняем запрос к API
      const apiKey = "8176cdd345a6be81bb9361a182580d03";
      final url = 'https://api.openweathermap.org/data/2.5/air_pollution?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey';

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _aqiData = json.decode(response.body);
            _isLoading = false;
          });
        }
      } else {
        throw Exception("API Error");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _getAqiStatus(int aqi, bool isRu) {
    switch (aqi) {
      case 1: return isRu ? "Отлично" : "Good";
      case 2: return isRu ? "Средне" : "Fair";
      case 3: return isRu ? "Умеренно" : "Moderate";
      case 4: return isRu ? "Плохо" : "Poor";
      case 5: return isRu ? "Очень плохо" : "Very Poor";
      default: return "...";
    }
  }

  Color _getAqiColor(int aqi) {
    switch (aqi) {
      case 1: return Colors.green;
      case 2: return Colors.lightGreen;
      case 3: return Colors.orange;
      case 4: return Colors.red;
      case 5: return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRu = localeNotifier.value.languageCode == 'ru';

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(
            isRu ? "Качество воздуха" : "Air Quality",
            style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(onPressed: _fetchAirQualityOptimized, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _errorMessage != null
          ? _buildErrorWidget(isRu)
          : RefreshIndicator(
        onRefresh: _fetchAirQualityOptimized,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildAQICard(isDark, isRu),
              const SizedBox(height: 24),
              _buildPollutantsList(isDark),
              const SizedBox(height: 24),
              _buildHealthAdvice(isDark, isRu),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(bool isRu) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(isRu ? "Не удалось загрузить данные" : "Failed to load data"),
          TextButton(onPressed: _fetchAirQualityOptimized, child: Text(isRu ? "Повторить" : "Retry")),
        ],
      ),
    );
  }

  Widget _buildAQICard(bool isDark, bool isRu) {
    final aqi = _aqiData?['list'][0]['main']['aqi'] ?? 1;
    final color = _getAqiColor(aqi);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Column(
        children: [
          Text(
              isRu ? "Индекс качества (AQI)" : "AQI Index",
              style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w600)
          ),
          const SizedBox(height: 8),
          Text("$aqi", style: TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: color)),
          Text(
              _getAqiStatus(aqi, isRu),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: aqi / 5,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollutantsList(bool isDark) {
    final components = _aqiData?['list'][0]['components'] ?? {};

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _pollutantTile(isDark, "PM2.5", "${components['pm2_5'] ?? 0}"),
        _pollutantTile(isDark, "PM10", "${components['pm10'] ?? 0}"),
        _pollutantTile(isDark, "NO₂", "${components['no2'] ?? 0}"),
        _pollutantTile(isDark, "O₃", "${components['o3'] ?? 0}"),
      ],
    );
  }

  Widget _pollutantTile(bool isDark, String name, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(name, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("$value μg/m³", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildHealthAdvice(bool isDark, bool isRu) {
    final aqi = _aqiData?['list'][0]['main']['aqi'] ?? 1;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.health_and_safety_outlined, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                  isRu ? "Рекомендации" : "Advice",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (aqi <= 2) ...[
            _adviceItem(Icons.wb_sunny_outlined, isRu ? "Идеально для прогулок" : "Ideal for walking"),
            _adviceItem(Icons.air_outlined, isRu ? "Проветривание безопасно" : "Ventilation is safe"),
          ] else ...[
            _adviceItem(Icons.masks_outlined, isRu ? "Наденьте маску на улице" : "Wear a mask outside"),
            _adviceItem(Icons.door_front_door_outlined, isRu ? "Закройте окна" : "Close the windows"),
          ],
          const Divider(height: 24),
          _adviceItem(Icons.update, isRu ? "Обновлено только что" : "Just updated"),
        ],
      ),
    );
  }

  Widget _adviceItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueAccent.withOpacity(0.7)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
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

  // Оптимизированный метод загрузки данных о качестве воздуха
  Future<void> _fetchAirQualityOptimized() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Получаем местоположение (сначала последнее известное для скорости)
      Position? position = await Geolocator.getLastKnownPosition();

      // Если данных нет, запрашиваем текущие с таймаутом
      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );

      // 2. Запрос к OpenWeatherMap API
      // ВНИМАНИЕ: Замени "YOUR_API_KEY" на свой реальный ключ перед запуском
      const apiKey = "YOUR_API_KEY";
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

  // Текстовый статус индекса
  String _getAqiStatus(int aqi, bool isRu) {
    switch (aqi) {
      case 1: return isRu ? "Отлично" : "Excellent";
      case 2: return isRu ? "Хорошо" : "Good";
      case 3: return isRu ? "Умеренно" : "Moderate";
      case 4: return isRu ? "Вредно" : "Unhealthy";
      case 5: return isRu ? "Опасно" : "Hazardous";
      default: return "...";
    }
  }

  // Цветовая палитра
  Color _getAqiColor(int aqi) {
    switch (aqi) {
      case 1: return const Color(0xFF4CAF50);
      case 2: return const Color(0xFF8BC34A);
      case 3: return const Color(0xFFFFC107);
      case 4: return const Color(0xFFFF5722);
      case 5: return const Color(0xFF9C27B0);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRu = localeNotifier.value.languageCode == 'ru';
    final aqi = _aqiData?['list'][0]['main']['aqi'] ?? 1;
    final color = _getAqiColor(aqi);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F2FA),
      appBar: AppBar(
        title: Text(
          isRu ? "Качество воздуха" : "Air Quality",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
              onPressed: _fetchAirQualityOptimized,
              icon: const Icon(Icons.refresh_rounded)
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: SatelliteLoader())
          : _errorMessage != null
          ? _buildErrorWidget(isRu)
          : RefreshIndicator(
        onRefresh: _fetchAirQualityOptimized,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              _buildMainAqiCard(isDark, isRu, aqi, color),
              const SizedBox(height: 32),
              _buildGridTitle(isRu ? "Состав воздуха" : "Pollutants"),
              const SizedBox(height: 16),
              _buildPollutantsGrid(isDark, color),
              const SizedBox(height: 32),
              _buildAdviceSection(isDark, isRu, aqi),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildMainAqiCard(bool isDark, bool isRu, int aqi, Color color) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF211F26) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.rotate(
                    angle: value * 2 * math.pi,
                    child: CustomPaint(
                      size: const Size(220, 220),
                      painter: MaterialShapePainter(
                        color: color.withOpacity(0.12),
                        shapeType: MaterialShapeType.flower,
                      ),
                    ),
                  );
                },
              ),
              Column(
                children: [
                  Text(
                    "$aqi",
                    style: TextStyle(
                        fontSize: 90,
                        fontWeight: FontWeight.w900,
                        color: color,
                        height: 1
                    ),
                  ),
                  Text(
                    _getAqiStatus(aqi, isRu).toUpperCase(),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 2
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: aqi / 5,
              minHeight: 12,
              backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollutantsGrid(bool isDark, Color mainColor) {
    final components = _aqiData?['list'][0]['components'] ?? {};

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _pollutantTile(isDark, "PM2.5", "${components['pm2_5'] ?? 0}", MaterialShapeType.squircle, mainColor),
        _pollutantTile(isDark, "PM10", "${components['pm10'] ?? 0}", MaterialShapeType.squircle, mainColor),
        _pollutantTile(isDark, "NO₂", "${components['no2'] ?? 0}", MaterialShapeType.squircle, mainColor),
        _pollutantTile(isDark, "O₃", "${components['o3'] ?? 0}", MaterialShapeType.squircle, mainColor),
      ],
    );
  }

  Widget _pollutantTile(bool isDark, String name, String value, MaterialShapeType shape, Color mainColor) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF211F26) : Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -45,
            bottom: -45,
            child: Opacity(
              opacity: 0.1,
              child: CustomPaint(
                size: const Size(130, 130),
                painter: MaterialShapePainter(color: mainColor, shapeType: shape),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const Text("μg/m³", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdviceSection(bool isDark, bool isRu, int aqi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF211F26) : const Color(0xFFEADDFF),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_rounded, color: isDark ? Colors.purpleAccent : const Color(0xFF6750A4)),
              const SizedBox(width: 12),
              Text(
                isRu ? "Совет дня" : "Health Tip",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            aqi <= 2
                ? (isRu ? "Воздух чист! Отличное время для долгой прогулки в парке." : "The air is clear! Great time for a long walk in the park.")
                : (isRu ? "Уровень загрязнения повышен. Постарайтесь меньше времени проводить у дорог." : "Pollution levels are up. Try to spend less time near busy roads."),
            style: const TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(bool isRu) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(isRu ? "Ошибка загрузки данных" : "Connection Error"),
          const SizedBox(height: 24),
          FilledButton.tonal(
              onPressed: _fetchAirQualityOptimized,
              child: Text(isRu ? "Обновить" : "Retry")
          ),
        ],
      ),
    );
  }
}

class SatelliteLoader extends StatefulWidget {
  const SatelliteLoader({super.key});

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
    final color = Theme.of(context).primaryColor;
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

enum MaterialShapeType { flower, clover, squircle, tiltedSquircle, circle }

class MaterialShapePainter extends CustomPainter {
  final Color color;
  final MaterialShapeType shapeType;

  MaterialShapePainter({required this.color, required this.shapeType});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill..isAntiAlias = true;
    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width / 2;

    switch (shapeType) {
      case MaterialShapeType.flower:
        _drawScalloped(path, centerX, centerY, radius, 12, 0.88);
        break;
      case MaterialShapeType.clover:
        _drawClover(path, size);
        break;
      case MaterialShapeType.squircle:
        _drawSquircle(path, size, rotation: 0);
        break;
      case MaterialShapeType.tiltedSquircle:
        _drawSquircle(path, size, rotation: 0.2);
        break;
      case MaterialShapeType.circle:
        path.addOval(Rect.fromLTWH(0, 0, size.width, size.height));
        break;
    }

    canvas.drawPath(path, paint);
  }

  void _drawScalloped(Path path, double cx, double cy, double r, int points, double innerScale) {
    final double step = (2 * math.pi) / (points * 2);
    for (int i = 0; i <= points * 2; i++) {
      final double angle = i * step;
      final double currentR = (i % 2 == 0) ? r : r * innerScale;
      final double x = cx + currentR * math.cos(angle);
      final double y = cy + currentR * math.sin(angle);
      if (i == 0) path.moveTo(x, y);
      else {
        final double midAngle = angle - (step / 2);
        final double midR = (r + r * innerScale) / 2 * 1.05;
        path.quadraticBezierTo(cx + midR * math.cos(midAngle), cy + midR * math.sin(midAngle), x, y);
      }
    }
  }

  void _drawClover(Path path, Size size) {
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.5, h * 0.15);
    path.cubicTo(w * 0.85, h * 0.15, w * 0.85, h * 0.5, w * 0.5, h * 0.5);
    path.cubicTo(w * 0.85, h * 0.5, w * 0.85, h * 0.85, w * 0.5, h * 0.85);
    path.cubicTo(w * 0.15, h * 0.85, w * 0.15, h * 0.5, w * 0.5, h * 0.5);
    path.cubicTo(w * 0.15, h * 0.5, w * 0.15, h * 0.15, w * 0.5, h * 0.15);
  }

  void _drawSquircle(Path path, Size size, {double rotation = 0}) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final Matrix4 matrix = Matrix4.identity()
      ..translate(centerX, centerY)
      ..rotateZ(rotation)
      ..translate(-centerX, -centerY);

    final r = size.width * 0.35;
    final rectPath = Path()..addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.1, size.height * 0.1, size.width * 0.8, size.height * 0.8),
      Radius.circular(r),
    ));

    path.addPath(rectPath, Offset.zero, matrix4: matrix.storage);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

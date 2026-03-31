import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;

// Экраны
import 'weather_screen.dart';
import 'events_ai_screen.dart';
import 'air_quality_screen.dart';
import 'notes_screen.dart';
import 'settings_screen.dart';
import 'notification_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('ru'));

class AppSettings {
  static SharedPreferences? _prefs;
  static ThemeMode theme = ThemeMode.system;
  static Locale locale = const Locale('ru');
  static bool notifications = true;
  static String lastVersion = "";

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final themeIndex = _prefs?.getInt('theme_mode') ?? 0;
      theme = ThemeMode.values[themeIndex];
      themeNotifier.value = theme;
      final langCode = _prefs?.getString('language_code') ?? 'ru';
      locale = Locale(langCode);
      localeNotifier.value = locale;
      notifications = _prefs?.getBool('notifications') ?? true;
      lastVersion = _prefs?.getString('last_version') ?? "";
    } catch (e) {
      debugPrint("Ошибка загрузки настроек: $e");
    }
  }

  static Future<void> saveTheme(ThemeMode mode) async {
    theme = mode;
    themeNotifier.value = mode;
    await _prefs?.setInt('theme_mode', mode.index);
  }

  static Future<void> saveLocale(Locale loc) async {
    locale = loc;
    localeNotifier.value = loc;
    await _prefs?.setString('language_code', loc.languageCode);
  }

  static Future<void> saveNotifications(bool val) async {
    notifications = val;
    await _prefs?.setBool('notifications', val);
  }

  static Future<void> saveVersion(String version) async {
    lastVersion = version;
    await _prefs?.setString('last_version', version);
  }
}

const String currentAppVersion = "2.2.0";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru', null);
  await initializeDateFormatting('en', null);
  await NotificationService.init();
  await AppSettings.init();
  runApp(const QWorldApp());
}

class QWorldApp extends StatelessWidget {
  const QWorldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return ValueListenableBuilder<Locale>(
          valueListenable: localeNotifier,
          builder: (_, locale, __) {
            return MaterialApp(
              title: 'QWORLD!',
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              locale: locale,
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                scaffoldBackgroundColor: const Color(0xFFF2F2F7),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  centerTitle: false,
                  titleTextStyle: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.w900),
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                scaffoldBackgroundColor: Colors.black,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  centerTitle: false,
                  titleTextStyle: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                ),
              ),
              home: AppSettings.lastVersion != currentAppVersion
                  ? const OnboardingScreen()
                  : const HomeScreen(),
            );
          },
        );
      },
    );
  }
}

class MorphingWavyPainter extends CustomPainter {
  final double waveIntensity;
  final Color colorStart;
  final Color colorEnd;
  final double gradientOffset;

  MorphingWavyPainter({
    required this.waveIntensity,
    required this.colorStart,
    required this.colorEnd,
    required this.gradientOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double animX = math.sin(gradientOffset * 2 * math.pi) * 0.5;
    final double animY = math.cos(gradientOffset * 2 * math.pi) * 0.5;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [colorStart, colorEnd],
        begin: Alignment(-1.0 + animX, -1.0 + animY),
        end: Alignment(1.0 + animX, 1.0 + animY),
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    final path = Path();
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = size.width / 2.3;
    const int pointsCount = 180;

    for (int i = 0; i <= pointsCount; i++) {
      double angle = (i * 360 / pointsCount) * math.pi / 180;
      double wavePhase = gradientOffset * 2 * math.pi;
      double wave = math.cos(angle * 8 + wavePhase) * (8 * waveIntensity);
      double currentRadius = radius + wave;

      double x = centerX + currentRadius * math.cos(angle);
      double y = centerY + currentRadius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    if (waveIntensity > 0.01) {
      canvas.drawShadow(
        path.shift(const Offset(0, 8)),
        colorStart.withOpacity(0.3 * waveIntensity),
        12,
        true,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(MorphingWavyPainter oldDelegate) {
    return oldDelegate.waveIntensity != waveIntensity ||
        oldDelegate.colorStart != colorStart ||
        oldDelegate.colorEnd != colorEnd ||
        oldDelegate.gradientOffset != gradientOffset;
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  bool _isLocationGranted = false;
  bool _isTermsAccepted = false;
  bool _isNotificationGranted = false;
  bool _isVisible = false;
  String _centerText = "Q";
  double _rotationAngle = 0.0;

  late AnimationController _morphController;
  late Animation<double> _waveAnimation;

  late AnimationController _gradientLoopController;
  late Animation<Color?> _colorStartAnimation;
  late Animation<Color?> _colorEndAnimation;

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();

    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _morphController, curve: Curves.easeInOutCubic),
    );

    _gradientLoopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _colorStartAnimation = ColorTween(
      begin: Colors.blueAccent,
      end: Colors.indigoAccent.shade700,
    ).animate(CurvedAnimation(parent: _morphController, curve: Curves.easeInOut));

    _colorEndAnimation = ColorTween(
      begin: Colors.cyanAccent.shade400,
      end: Colors.purpleAccent.shade400,
    ).animate(CurvedAnimation(parent: _morphController, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isVisible = true);
      });
    });

    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (!mounted) return;
      setState(() {
        _centerText = "2";
        _rotationAngle = 0.5; // Классический поворот на пол-оборота
      });
      _morphController.forward();
    });
  }

  @override
  void dispose() {
    _morphController.dispose();
    _gradientLoopController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialPermissions() async {
    LocationPermission locPermission = await Geolocator.checkPermission();
    var notifStatus = await Permission.notification.status;
    if (mounted) {
      setState(() {
        _isLocationGranted = (locPermission == LocationPermission.always || locPermission == LocationPermission.whileInUse);
        _isNotificationGranted = notifStatus.isGranted;
      });
    }
  }

  Future<void> _requestLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      if (mounted) setState(() => _isLocationGranted = true);
    }
  }

  Future<void> _requestNotification() async {
    var status = await Permission.notification.request();
    if (status.isGranted) {
      if (mounted) setState(() => _isNotificationGranted = true);
    }
  }

  void _showTermsDialog() {
    final isRu = localeNotifier.value.languageCode == 'ru';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(isRu ? "Условия использования" : "Terms of Use"),
        content: SingleChildScrollView(
          child: Text(isRu
              ? "1. Мы используем данные OpenWeather для предоставления прогнозов.\n2. Ваша геопозиция обрабатывается локально для точности данных.\n3. ИИ-гид предоставляет справочную информацию, требующую проверки.\n4. GPS необходим для работы погодных виджетов.\n5. Приложение в разработке, об ошибках сообщайте разработчику."
              : "1. We use OpenWeather data to provide forecasts.\n2. Your location is processed locally for data accuracy.\n3. AI Guide provides reference information that requires verification.\n4. GPS is essential for weather widgets."),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isTermsAccepted = false);
            },
            child: Text(isRu ? "Отмена" : "Cancel", style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isTermsAccepted = true);
            },
            child: Text(isRu ? "Принять" : "Accept"),
          ),
        ],
      ),
    );
  }

  void _finishOnboarding() async {
    await AppSettings.saveVersion(currentAppVersion);
    NotificationService.showNotification(
      title: localeNotifier.value.languageCode == 'ru' ? "Готово! 🚀" : "Ready! 🚀",
      body: localeNotifier.value.languageCode == 'ru'
          ? "Добро пожаловать в QWorld."
          : "Welcome to QWorld.",
    );
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRu = localeNotifier.value.languageCode == 'ru';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Изменено: масштаб увеличен с 1.0 до 1.15
              AnimatedScale(
                scale: _isVisible ? 1.15 : 0.0,
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutBack,
                child: AnimatedRotation(
                  turns: _rotationAngle,
                  duration: const Duration(milliseconds: 2500),
                  curve: Curves.easeInOutQuart,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Фигура с переливающимся градиентом
                      AnimatedBuilder(
                        animation: Listenable.merge([_morphController, _gradientLoopController]),
                        builder: (context, child) {
                          return CustomPaint(
                            size: const Size(140, 140),
                            painter: MorphingWavyPainter(
                              waveIntensity: _waveAnimation.value,
                              colorStart: _colorStartAnimation.value ?? Colors.blueAccent,
                              colorEnd: _colorEndAnimation.value ?? Colors.cyanAccent,
                              gradientOffset: _gradientLoopController.value,
                            ),
                          );
                        },
                      ),
                      // Текст (компенсирует вращение, чтобы не переворачиваться)
                      AnimatedRotation(
                        turns: -_rotationAngle,
                        duration: const Duration(milliseconds: 2500),
                        curve: Curves.easeInOutQuart,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
                          child: Text(
                            _centerText,
                            key: ValueKey<String>(_centerText),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 58,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 50),
              Text(
                isRu ? "Добро пожаловать в QWORLD!" : "Welcome to QWORLD!",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 40),
              _onboardingActionRow(
                icon: _isLocationGranted ? Icons.check_circle : Icons.location_on_outlined,
                label: isRu ? "Разрешить геопозицию" : "Allow Location",
                isCompleted: _isLocationGranted,
                onTap: _isLocationGranted ? null : _requestLocation,
              ),
              const SizedBox(height: 12),
              _onboardingActionRow(
                icon: _isNotificationGranted ? Icons.check_circle : Icons.notifications_active_outlined,
                label: isRu ? "Включить уведомления" : "Enable Notifications",
                isCompleted: _isNotificationGranted,
                onTap: _isNotificationGranted ? null : _requestNotification,
              ),
              const SizedBox(height: 12),
              _onboardingActionRow(
                icon: _isTermsAccepted ? Icons.check_circle : Icons.description_outlined,
                label: isRu ? "Принять условия пользования" : "Accept Terms of Use",
                isCompleted: _isTermsAccepted,
                onTap: _isTermsAccepted ? null : _showTermsDialog,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: (_isLocationGranted && _isTermsAccepted && _isNotificationGranted) ? _finishOnboarding : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    disabledBackgroundColor: Colors.grey.withOpacity(0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: Text(isRu ? "Начать" : "Start", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _onboardingActionRow({required IconData icon, required String label, required bool isCompleted, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isCompleted ? Colors.green.withOpacity(0.08) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isCompleted ? Colors.green.withOpacity(0.5) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, color: isCompleted ? Colors.green : Colors.blueAccent),
            const SizedBox(width: 15),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            if (isCompleted) const Icon(Icons.done, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Position? _currentPosition;
  Map<String, dynamic>? _quickWeather;
  Map<String, dynamic>? _quickAir;
  bool _isLoading = true;
  bool _locationError = false;

  @override
  void initState() {
    super.initState();
    _markVersionAsSeen();
    _initAppData();
    localeNotifier.addListener(_onLocaleChanged);
  }

  Future<void> _markVersionAsSeen() async {
    if (AppSettings.lastVersion != currentAppVersion) {
      await AppSettings.saveVersion(currentAppVersion);
    }
  }

  @override
  void dispose() {
    localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    _fetchQuickData();
  }

  Future<void> _initAppData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _locationError = false;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission != LocationPermission.deniedForever && permission != LocationPermission.denied) {
        _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 3),
        );
      } else {
        _locationError = true;
      }
    } catch (e) {
      _locationError = true;
    }

    await _fetchQuickData();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchQuickData() async {
    const apiKey = "8176cdd345a6be81bb9361a182580d03";
    double lat = _currentPosition?.latitude ?? 43.2389;
    double lon = _currentPosition?.longitude ?? 76.8897;
    String lang = localeNotifier.value.languageCode;

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=$lang')),
        http.get(Uri.parse('https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$apiKey')),
      ]);

      if (mounted) {
        setState(() {
          if (responses[0].statusCode == 200) _quickWeather = json.decode(responses[0].body);
          if (responses[1].statusCode == 200) _quickAir = json.decode(responses[1].body);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRu = localeNotifier.value.languageCode == 'ru';
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Text("QWORLD!"),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _initAppData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              _buildWidgetCard(
                context,
                title: isRu ? "Погода" : "Weather",
                child: WeatherPreviewWidget(
                  weatherData: _quickWeather,
                  isLoading: _isLoading,
                  locationError: _locationError,
                ),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => WeatherScreen(position: _currentPosition))),
              ),
              const SizedBox(height: 16),
              _buildWidgetCard(
                context,
                title: isRu ? "ИИ Гид" : "AI Guide",
                color: isDark ? const Color(0xFF2C1C3D) : Colors.purple.withOpacity(0.08),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.auto_awesome, color: Colors.purple, size: 36),
                  title: Text(isRu ? "Ваш помощник активен" : "Assistant is active", style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text("${isRu ? 'Сегодня' : 'Today'} ${now.day}.${now.month}, ${now.hour}:${now.minute.toString().padLeft(2, '0')}"),
                ),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EventsAiScreen())),
              ),
              const SizedBox(height: 16),
              _buildWidgetCard(
                context,
                title: isRu ? "Качество воздуха" : "Air Quality",
                child: Row(
                  children: [
                    Icon(Icons.air, color: _quickAir != null ? Colors.green : Colors.grey, size: 30),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        _quickAir != null
                            ? "${isRu ? 'Индекс' : 'Index'} ${_quickAir!['list'][0]['main']['aqi']}"
                            : (_locationError ? (isRu ? "Включите GPS" : "Enable GPS") : (isRu ? "Загрузка..." : "Loading...")),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AirQualityScreen())),
              ),
              const SizedBox(height: 16),
              _buildWidgetCard(
                context,
                title: isRu ? "Заметки" : "Notes",
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_note, color: Colors.blue, size: 30),
                  title: Text(isRu ? "Ваши личные записи" : "Your personal notes"),
                ),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotesScreen())),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetCard(BuildContext context, {required String title, required Widget child, Color? color, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color ?? (isDark ? const Color(0xFF1C1C1E) : Colors.white),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class WeatherPreviewWidget extends StatelessWidget {
  final Map<String, dynamic>? weatherData;
  final bool isLoading;
  final bool locationError;

  const WeatherPreviewWidget({super.key, this.weatherData, required this.isLoading, required this.locationError});

  @override
  Widget build(BuildContext context) {
    final isRu = localeNotifier.value.languageCode == 'ru';

    if (isLoading && weatherData == null) return const LinearProgressIndicator();
    if (weatherData == null) {
      return Text(
        locationError
            ? (isRu ? "Ошибка GPS" : "GPS Error")
            : "...",
        style: const TextStyle(color: Colors.grey),
      );
    }

    final temp = weatherData!['main']['temp'].round();
    final desc = weatherData!['weather'][0]['description'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("$temp°C", style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold)),
        Text(desc, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
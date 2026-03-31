import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';

class AiPlace {
  final String name;
  final String description;
  final String type;
  final bool isPopular;

  AiPlace({
    required this.name,
    required this.description,
    required this.type,
    required this.isPopular,
  });

  factory AiPlace.fromJson(Map<String, dynamic> json) {
    return AiPlace(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? 'general',
      isPopular: json['is_popular'] is bool
          ? json['is_popular']
          : (json['is_popular']?.toString().toLowerCase() == 'true'),
    );
  }
}

class CityOption {
  final String name;
  final double lat;
  final double lon;
  final String icon;

  CityOption(this.name, this.lat, this.lon, this.icon);
}

class EventsAiScreen extends StatefulWidget {
  const EventsAiScreen({super.key});

  @override
  State<EventsAiScreen> createState() => _EventsAiScreenState();
}

class _EventsAiScreenState extends State<EventsAiScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isInitialLoading = true;
  List<AiPlace> _popularPlaces = [];
  List<AiPlace> _otherPlaces = [];
  String? _error;
  String _currentCity = "";
  bool _showButtons = false;

  final List<CityOption> _manualCities = [
    CityOption("Астана", 51.1605, 71.4704, "🇰🇿"),
    CityOption("Алматы", 43.2389, 76.8897, "🇰🇿"),
    CityOption("Москва", 55.7558, 37.6173, "🇷🇺"),
    CityOption("Санкт-Петербург", 59.9343, 30.3351, "🇷🇺"),
    CityOption("Екатеринбург", 56.8389, 60.6057, "🇷🇺"),
    CityOption("Казань", 55.7887, 49.1221, "🇷🇺"),
    CityOption("Новосибирск", 55.0084, 82.9357, "🇷🇺"),
    CityOption("Краснодар", 45.0355, 38.9747, "🇷🇺"),
    CityOption("Сочи", 43.5853, 39.7203, "🇷🇺"),
    CityOption("Владивосток", 43.1155, 131.8855, "🇷🇺"),
    CityOption("Нью-Йорк", 40.7128, -74.0060, "🇺🇸"),
    CityOption("Лос-Анджелес", 34.0522, -118.2437, "🇺🇸"),
    CityOption("Сан-Франциско", 37.7749, -122.4194, "🇺🇸"),
    CityOption("Чикаго", 41.8781, -87.6298, "🇺🇸"),
    CityOption("Лас-Вегас", 36.1716, -115.1391, "🇺🇸"),
    CityOption("Майами", 25.7617, -80.1918, "🇺🇸"),
    CityOption("Лондон", 51.5074, -0.1278, "🇬🇧"),
    CityOption("Париж", 48.8566, 2.3522, "🇫🇷"),
    CityOption("Берлин", 52.5200, 13.4050, "🇩🇪"),
    CityOption("Рим", 41.9028, 12.4964, "🇮🇹"),
    CityOption("Мадрид", 40.4168, -3.7038, "🇪🇸"),
    CityOption("Амстердам", 52.3676, 4.9041, "🇳🇱"),
    CityOption("Токио", 35.6762, 139.6503, "🇯🇵"),
  ];

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  Future<String> _callAi(Uri url, String key, List<Map<String, String>> messages, {bool isJson = false}) async {
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "llama-3.1-8b-instant",
        "messages": messages,
        if (isJson) "response_format": {"type": "json_object"},
        "temperature": 0.5, // Немного снизила для более стабильных ответов
        "max_tokens": 1000, // Ограничение для скорости
      }),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return utf8.decode(response.bodyBytes);
    } else {
      throw 'API Error: ${response.statusCode}';
    }
  }

  Future<void> _launchMap(String placeName) async {
    final String query = Uri.encodeComponent("$placeName $_currentCity");
    Uri url;

    if (Platform.isAndroid) {
      url = Uri.parse("geo:0,0?q=$query");
    } else {
      url = Uri.parse("http://maps.apple.com/?q=$query");
    }

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        final browserUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");
        await launchUrl(browserUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть карту')),
        );
      }
    }
  }

  Future<void> _fetchRecommendations({double? manualLat, double? manualLon, String? manualName}) async {
    if (!mounted) return;
    setState(() {
      _isInitialLoading = true;
      _error = null;
      _showButtons = false;
    });

    try {
      if (manualLat != null && manualLon != null && manualName != null) {
        _currentCity = manualName;
      } else {
        Position position = await _determinePosition();
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty && placemarks.first.locality != null) {
            _currentCity = placemarks.first.locality!;
          } else {
            _currentCity = "Ваш город";
          }
        } catch (_) {
          _currentCity = "Ваш город";
        }
      }

      const groqKey = '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';
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final isRu = localeNotifier.value.languageCode == 'ru';

      // ОПТИМИЗАЦИЯ: Объединяем генерацию и "аудит" в один жесткий системный промпт
      final responseRaw = await _callAi(url, groqKey, [
        {
          "role": "system",
          "content": "You are an expert local guide for $_currentCity. Return ONLY a JSON object with 'places' key. "
              "Each place must have: name, description (max 12 words), type (food, park, museum, culture, landmark), is_popular (boolean). "
              "CRITICAL: All 8 places MUST be strictly within $_currentCity limits. Verify locations before answering. "
              "Language: ${isRu ? 'Russian' : 'English'}."
        },
        {
          "role": "user",
          "content": "Suggest 8 mixed popular and hidden places strictly in $_currentCity."
        }
      ], isJson: true);

      final decodedResponse = jsonDecode(responseRaw);
      final content = jsonDecode(decodedResponse['choices'][0]['message']['content']);
      final List<dynamic> list = content['places'] ?? [];

      final allPlaces = list.map((e) => AiPlace.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          _popularPlaces = allPlaces.where((p) => p.isPopular).toList();
          _otherPlaces = allPlaces.where((p) => !p.isPopular).toList();
          _isInitialLoading = false;
        });

        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _showButtons = true);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "needs_manual_selection";
          _isInitialLoading = false;
        });
      }
    }
  }

  Future<void> _fetchDetailedInfo(String placeName, String type) async {
    final isRu = localeNotifier.value.languageCode == 'ru';
    setState(() => _isLoading = true);

    try {
      const groqKey = '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';
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      // Убираем двойной аудит и здесь для скорости
      final detailRaw = await _callAi(url, groqKey, [
        {
          "role": "system",
          "content": "Professional local expert in $_currentCity. Provide a concise 4-sentence paragraph about $placeName. "
              "Ensure the info is accurate for $_currentCity. Language: ${isRu ? 'Russian' : 'English'}."
        },
        {"role": "user", "content": "Tell me about $placeName in $_currentCity."}
      ]);

      final detailText = jsonDecode(detailRaw)['choices'][0]['message']['content'];

      if (mounted) {
        _navigateToDetails(placeName, detailText, type);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при загрузке деталей')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToDetails(String title, String content, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceDetailScreen(title: title, content: content, type: type),
      ),
    );
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('GPS off');
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Permission denied');
    }
    // Снижена точность для ускорения получения координат
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 5),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'food': return FontAwesomeIcons.utensils;
      case 'park': return FontAwesomeIcons.tree;
      case 'museum': return FontAwesomeIcons.buildingColumns;
      case 'culture': return FontAwesomeIcons.masksTheater;
      case 'landmark': return FontAwesomeIcons.landmark;
      default: return FontAwesomeIcons.locationDot;
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    const accentColor = Color(0xFF9C27B0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 16, 12),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(AiPlace place, Color cardColor, Color textColor, Color accentColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: accentColor.withOpacity(0.1),
          child: FaIcon(_getIconForType(place.type), color: accentColor, size: 16),
        ),
        title: Text(place.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(place.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 13)),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: accentColor.withOpacity(0.5)),
        onTap: () => _showPlaceActionSheet(place),
      ),
    );
  }

  Future<void> _showPlaceActionSheet(AiPlace place) async {
    final isRu = localeNotifier.value.languageCode == 'ru';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFF9C27B0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 60),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              ),
              Text(place.name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 24),
              ListTile(
                leading: CircleAvatar(backgroundColor: accentColor.withOpacity(0.1), child: const Icon(Icons.map_outlined, color: accentColor, size: 20)),
                title: Text(isRu ? "Открыть карты" : "Open Maps"),
                onTap: () {
                  Navigator.pop(context);
                  _launchMap(place.name);
                },
              ),
              ListTile(
                leading: CircleAvatar(backgroundColor: accentColor.withOpacity(0.1), child: const Icon(Icons.auto_awesome, color: accentColor, size: 20)),
                title: Text(isRu ? "Уточнить детали" : "Refine details"),
                onTap: () {
                  Navigator.pop(context);
                  _fetchDetailedInfo(place.name, place.type);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRefineSheet() async {
    final isRu = localeNotifier.value.languageCode == 'ru';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFF9C27B0);
    final allItems = [..._popularPlaces, ..._otherPlaces];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(isRu ? "О чем рассказать подробнее?" : "What to refine?", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: allItems.length,
                  itemBuilder: (context, index) {
                    final place = allItems[index];
                    return Card(
                      elevation: 0,
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: FaIcon(_getIconForType(place.type), color: accentColor, size: 16),
                        title: Text(place.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(context);
                          _fetchDetailedInfo(place.name, place.type);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFF9C27B0);
    final isRu = localeNotifier.value.languageCode == 'ru';
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(isRu ? 'ИИ Гид' : 'AI Guide', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
      body: (_isInitialLoading || _isLoading)
          ? _AiLoadingWidget(
        cityName: _currentCity,
        isInitial: _isInitialLoading,
        accentColor: accentColor,
      )
          : _error == "needs_manual_selection"
          ? _buildManualCitySelection(isRu, textColor, accentColor, cardColor)
          : ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
        physics: const BouncingScrollPhysics(),
        children: [
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_outlined, color: accentColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isRu ? 'ИИ собрал для вас интересные места' : 'Your personal guide to $_currentCity',
                    style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.8), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          if (_popularPlaces.isNotEmpty) ...[
            _buildSectionHeader(isRu ? "ПОПУЛЯРНОЕ" : "POPULAR", Icons.star_rounded),
            ..._popularPlaces.map((place) => _buildPlaceCard(place, cardColor, textColor, accentColor, isDark)),
          ],
          if (_otherPlaces.isNotEmpty) ...[
            _buildSectionHeader(isRu ? "ИНТЕРЕСНЫЕ НАХОДКИ" : "HIDDEN GEMS", Icons.explore_rounded),
            ..._otherPlaces.map((place) => _buildPlaceCard(place, cardColor, textColor, accentColor, isDark)),
          ],
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AnimatedOpacity(
        opacity: _showButtons ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 700),
        child: AnimatedSlide(
          offset: _showButtons ? Offset.zero : const Offset(0, 0.3),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutExpo,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white12 : Colors.black12,
                        foregroundColor: textColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _fetchRecommendations,
                      child: const Icon(Icons.refresh_rounded, size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: (_popularPlaces.isEmpty && _otherPlaces.isEmpty) ? null : _showRefineSheet,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(isRu ? "УТОЧНИТЬ" : "REFINE", style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ],
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

  Widget _buildManualCitySelection(bool isRu, Color textColor, Color accentColor, Color cardColor) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_city_rounded, size: 48, color: accentColor.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(isRu ? "Выберите ваш город" : "Select your city", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          Text(
            isRu ? "Мы подготовили список самых интересных мест России и мира:" : "We've prepared a list of the most interesting places:",
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor.withOpacity(0.6)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _manualCities.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final city = _manualCities[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withOpacity(0.1)),
                  ),
                  child: ListTile(
                    leading: Text(city.icon, style: const TextStyle(fontSize: 24)),
                    title: Text(city.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => _fetchRecommendations(manualLat: city.lat, manualLon: city.lon, manualName: city.name),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => _fetchRecommendations(),
            icon: const Icon(Icons.gps_fixed_rounded, size: 18),
            label: Text(isRu ? "Определить по GPS" : "Detect via GPS"),
          ),
        ],
      ),
    );
  }
}

class _AiLoadingWidget extends StatefulWidget {
  final String cityName;
  final bool isInitial;
  final Color accentColor;

  const _AiLoadingWidget({
    required this.cityName,
    required this.isInitial,
    required this.accentColor,
  });

  @override
  State<_AiLoadingWidget> createState() => _AiLoadingWidgetState();
}

class _AiLoadingWidgetState extends State<_AiLoadingWidget> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  int _textIndex = 0;

  final List<String> _loadingTextsRu = [
    "Подключаемся к нейросети...",
    "Изучаем карту города...",
    "Ищем секретные локации...",
    "Проверяем отзывы местных жителей...",
    "Почти готово, наводим красоту...",
  ];

  final List<IconData> _icons = [
    Icons.auto_awesome,
    Icons.map_rounded,
    Icons.explore_rounded,
    Icons.restaurant_rounded,
    Icons.museum_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _startTextCycle();
  }

  void _startTextCycle() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _textIndex = (_textIndex + 1) % _loadingTextsRu.length;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRu = localeNotifier.value.languageCode == 'ru';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Transform.translate(
      offset: const Offset(0, -30),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: Tween(begin: 0.9, end: 1.1).animate(
                CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Icon(
                    _icons[_textIndex % _icons.length],
                    key: ValueKey(_textIndex),
                    color: widget.accentColor,
                    size: 40,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              widget.cityName.isEmpty
                  ? (isRu ? "ОПРЕДЕЛЯЕМ МЕСТОПОЛОЖЕНИЕ" : "LOCATING...")
                  : widget.cityName.toUpperCase(),
              style: TextStyle(
                color: widget.accentColor,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 20,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  isRu ? _loadingTextsRu[_textIndex] : "Thinking...",
                  key: ValueKey(_textIndex),
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            _AnimatedDots(color: widget.accentColor),
          ],
        ),
      ),
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  final Color color;
  const _AnimatedDots({required this.color});

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double offset = (index * 0.2);
        final double value = (_controller.value - offset) % 1.0;
        final double opacity = value < 0.5 ? value * 2 : (1.0 - value) * 2;
        final double scale = 0.5 + (opacity * 0.5);

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity.clamp(0.2, 1.0),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) => _buildDot(index)),
    );
  }
}

class PlaceDetailScreen extends StatelessWidget {
  final String title;
  final String content;
  final String type;

  const PlaceDetailScreen({super.key, required this.title, required this.content, required this.type});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFF9C27B0);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: accentColor.withOpacity(0.1), shape: BoxShape.circle),
              child: FaIcon(_getIconForType(type), color: accentColor, size: 32),
            ),
            const SizedBox(height: 24),
            Text(content, style: TextStyle(color: textColor.withOpacity(0.9), fontSize: 18, height: 1.6, letterSpacing: 0.2)),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'food': return FontAwesomeIcons.utensils;
      case 'park': return FontAwesomeIcons.tree;
      case 'museum': return FontAwesomeIcons.buildingColumns;
      case 'culture': return FontAwesomeIcons.masksTheater;
      case 'landmark': return FontAwesomeIcons.landmark;
      default: return FontAwesomeIcons.locationDot;
    }
  }
}
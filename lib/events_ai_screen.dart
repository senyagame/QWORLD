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

class ChatMessage {
  final String text;
  final bool isUser;
  final String? imageUrl;

  ChatMessage({required this.text, required this.isUser, this.imageUrl});
}

class EventsAiScreen extends StatefulWidget {
  const EventsAiScreen({super.key});

  @override
  State<EventsAiScreen> createState() => _EventsAiScreenState();
}

class _EventsAiScreenState extends State<EventsAiScreen> with SingleTickerProviderStateMixin {
  // Ключ удален для безопасности. Не забудь вставить свой перед запуском!
  static const String _groqApiKey = 'YOUR_GROQ_API_KEY';

  bool _isLoading = false;
  bool _isInitialLoading = true;
  List<AiPlace> _popularPlaces = [];
  List<AiPlace> _otherPlaces = [];
  String? _error;
  String _currentCity = "";
  bool _showButtons = false;

  bool _isChatOpen = false;
  final List<ChatMessage> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isTyping = false;
  bool _showQuickActions = false;

  String _currentPlaceForChat = "";

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
    CityOption("Варшава", 52.2298, 21.0118, "🇵🇱"),
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

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<String> _callAi(Uri url, String key, List<Map<String, String>> messages, {bool isJson = false}) async {
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "llama-3.3-70b-versatile",
        "messages": messages,
        if (isJson) "response_format": {"type": "json_object"},
        "temperature": 0.1,
        "max_tokens": 1000,
      }),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return utf8.decode(response.bodyBytes);
    } else {
      debugPrint("API Error body: ${response.body}");
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
      if (manualName != null) _currentCity = manualName;
    });

    try {
      if (manualLat == null || manualLon == null) {
        try {
          Position position = await _determinePosition();
          List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty && placemarks.first.locality != null) {
            _currentCity = placemarks.first.locality!;
          } else {
            _currentCity = "Алматы";
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _error = "needs_manual_selection";
              _isInitialLoading = false;
            });
          }
          return;
        }
      }

      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final isRu = localeNotifier.value.languageCode == 'ru';

      final responseRaw = await _callAi(url, _groqApiKey, [
        {
          "role": "system",
          "content": "You are a strict, factual local guide for $_currentCity. Return ONLY a JSON object with a 'places' array. "
              "Each place must have: 'name' (use EXACT official local names. DO NOT translate proper names into English! If the language is Russian, leave the local Russian name, e.g., 'Зеленый базар' instead of 'Green market'), "
              "'description' (max 12 words), 'type' (food, park, museum, culture, landmark), 'is_popular' (boolean). "
              "CRITICAL RULES: 1) ALL 8 places MUST truly exist in $_currentCity right now. 2) DO NOT invent, guess, or hallucinate names. 3) NEVER translate place names into English if isRu is true. "
              "Language for descriptions: ${isRu ? 'Russian' : 'English'}."
        },
        {
          "role": "user",
          "content": "Suggest 8 mixed popular and hidden places strictly in $_currentCity. Only real places!"
        }
      ], isJson: true);

      final decodedResponse = jsonDecode(responseRaw);
      final content = jsonDecode(decodedResponse['choices'][0]['message']['content']);
      final List<dynamic> list = content['places'] ?? [];

      final allPlaces = list.map((e) => AiPlace.fromJson(e)).toList();

      List<AiPlace?> verifiedPlacesFuture = await Future.wait(allPlaces.map((place) async {
        try {
          List<Location> locations = await locationFromAddress("${place.name}, $_currentCity");
          if (locations.isNotEmpty) {
            return place;
          }
        } catch (e) {
          debugPrint("ИИ нафантазировал (отбраковано картами): ${place.name}");
        }
        return null;
      }));

      List<AiPlace> verifiedPlaces = verifiedPlacesFuture.whereType<AiPlace>().toList();

      if (verifiedPlaces.isEmpty) {
        debugPrint("Геокодер отвалился или ничего не нашел, используем сырые данные ИИ.");
        verifiedPlaces = allPlaces;
      }

      if (mounted) {
        setState(() {
          _popularPlaces = verifiedPlaces.where((p) => p.isPopular).toList();
          _otherPlaces = verifiedPlaces.where((p) => !p.isPopular).toList();
          _isInitialLoading = false;
        });

        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _showButtons = true);
        });
      }
    } catch (e) {
      debugPrint("Recommendation Error: $e");
      if (mounted) {
        setState(() {
          _error = "needs_manual_selection";
          _isInitialLoading = false;
        });
      }
    }
  }

  void _openChatWithPlace(String placeName) {
    setState(() {
      _isChatOpen = true;
      _currentPlaceForChat = placeName;
      _chatMessages.clear();
      _showQuickActions = false;
    });
    _sendChatMessage("Расскажи подробнее про $placeName в городе $_currentCity");
  }

  Future<String?> _fetchImageForPlace(String placeName) async {
    try {
      final query = Uri.encodeComponent("$placeName $_currentCity");

      final searchUrl = Uri.parse(
          'https://commons.wikimedia.org/w/api.php?action=query&generator=search&gsrsearch=$query&gsrnamespace=6&gsrlimit=5&prop=imageinfo&iiprop=url&format=json'
      );

      final response = await http.get(searchUrl);
      final data = jsonDecode(response.body);

      if (data['query'] != null && data['query']['pages'] != null) {
        final pages = data['query']['pages'] as Map<String, dynamic>;
        final List<String> imageUrls = [];

        for (var page in pages.values) {
          if (page['imageinfo'] != null && page['imageinfo'].isNotEmpty) {
            imageUrls.add(page['imageinfo'][0]['url']);
          }
        }

        if (imageUrls.isNotEmpty) {
          imageUrls.shuffle();
          return imageUrls.first;
        }
      }
    } catch (e) {
      debugPrint("Commons API error: $e");
    }
    return null;
  }

  Future<void> _sendChatMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _chatMessages.add(ChatMessage(text: text, isUser: true));
      _isTyping = true;
      _showQuickActions = false;
    });

    _scrollToBottom();

    final isRu = localeNotifier.value.languageCode == 'ru';
    final textLower = text.toLowerCase();

    if (textLower.contains('фото') ||
        textLower.contains('картинк') ||
        textLower.contains('photo') ||
        textLower.contains('image') ||
        textLower.contains('покажи') ||
        textLower.contains('еще') ||
        textLower.contains('another') ||
        textLower.contains('picture')) {

      final imageUrl = await _fetchImageForPlace(_currentPlaceForChat);

      if (mounted) {
        setState(() {
          if (imageUrl != null) {
            _chatMessages.add(ChatMessage(
                text: isRu ? "Вот фото $_currentPlaceForChat:" : "Here is a photo of $_currentPlaceForChat:",
                isUser: false,
                imageUrl: imageUrl
            ));
          } else {
            _chatMessages.add(ChatMessage(
                text: isRu ? "К сожалению, не удалось найти больше фото для $_currentPlaceForChat." : "Sorry, couldn't find more photos for $_currentPlaceForChat.",
                isUser: false
            ));
          }
          _isTyping = false;
          _showQuickActions = true;
        });
        _scrollToBottom();
      }
      return;
    }

    try {
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      List<Map<String, String>> history = [
        {
          "role": "system",
          "content": "You are a strict, factual local guide in $_currentCity. Answer concisely and confidently. "
              "CRITICAL RULES: 1) ONLY state verified facts. 2) DO NOT invent places, details, or histories. "
              "3) If you are not sure, simply say you don't have exact details. "
              "4) DO NOT apologize or say 'I made a mistake', just provide accurate information. "
              "Language: ${isRu ? 'Russian' : 'English'}."
        }
      ];

      for (var msg in _chatMessages) {
        if (msg.imageUrl == null) {
          history.add({
            "role": msg.isUser ? "user" : "assistant",
            "content": msg.text,
          });
        }
      }

      final responseRaw = await _callAi(url, _groqApiKey, history);
      String aiText = jsonDecode(responseRaw)['choices'][0]['message']['content'];

      if (mounted) {
        setState(() {
          _chatMessages.add(ChatMessage(text: aiText, isUser: false));
          _isTyping = false;
          _showQuickActions = true;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Chat AI Error: $e");
      if (mounted) {
        setState(() {
          _chatMessages.add(ChatMessage(
              text: isRu ? "Извини, произошла ошибка соединения." : "Sorry, connection error.",
              isUser: false
          ));
          _isTyping = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('GPS off');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Permission denied');
    }

    if (permission == LocationPermission.deniedForever) return Future.error('Permission permanently denied');

    Position? lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) return lastKnown;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 10),
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
    const accentColor = Color(0xFF9C27B0);
    final sheetColor = Theme.of(context).cardColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 60),
          decoration: BoxDecoration(
            color: sheetColor,
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
                  _openChatWithPlace(place.name);
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
    final sheetColor = Theme.of(context).cardColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: sheetColor,
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
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: FaIcon(_getIconForType(place.type), color: accentColor, size: 16),
                        title: Text(place.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(context);
                          _openChatWithPlace(place.name);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accentColor = Color(0xFF9C27B0);
    final isRu = localeNotifier.value.languageCode == 'ru';

    final scaffoldColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : const Color(0xFF1A1A1A));
    final appBarTextColor = theme.appBarTheme.titleTextStyle?.color ?? textColor;

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: _isChatOpen
            ? IconButton(
          icon: Icon(Icons.close_rounded, color: appBarTextColor),
          onPressed: () => setState(() => _isChatOpen = false),
        )
            : null,
        title: Text(
            _isChatOpen ? (isRu ? 'Nexus Ai чат' : 'Nexus Ai Chat') : (isRu ? 'ИИ Гид' : 'AI Guide'),
            style: TextStyle(color: appBarTextColor, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: appBarTextColor),
      ),
      body: Stack(
        children: [
          if (!_isChatOpen)
            (_isInitialLoading || _isLoading)
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
                          isRu ? 'Наш Nexus Ai собрал для вас интересные места' : 'Your personal guide to $_currentCity',
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
          if (_isChatOpen) _buildChatUI(isRu, isDark, textColor, accentColor, cardColor),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: (!_isChatOpen && _showButtons)
          ? Padding(
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
                  onPressed: () => _fetchRecommendations(),
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
      )
          : null,
    );
  }

  Widget _buildChatUI(bool isRu, bool isDark, Color textColor, Color accentColor, Color cardColor) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _chatMessages.length + (_isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _chatMessages.length) {
                return const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.all(8.0), child: _AnimatedDots(color: Colors.grey)));
              }
              final msg = _chatMessages[index];
              return Align(
                alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                  decoration: BoxDecoration(
                    color: msg.isUser ? accentColor : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                      bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (msg.imageUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            msg.imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2)));
                            },
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 150,
                              color: Colors.black12,
                              child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(msg.text, style: TextStyle(color: msg.isUser ? Colors.white : textColor, fontSize: 15)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_showQuickActions)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _quickActionBtn(isRu ? "Показать картинку" : "Show image", Icons.image_outlined, accentColor, () {
                    _sendChatMessage(isRu ? "Покажи фото этого места" : "Show me a photo");
                  }),
                  const SizedBox(width: 8),
                  _quickActionBtn(isRu ? "Перепроверь информацию" : "Double check", Icons.fact_check_outlined, accentColor, () {
                    _sendChatMessage(isRu ? "Перепроверь информацию, точно ли это место в $_currentCity?" : "Double check if this place is really in $_currentCity?");
                  }),
                ],
              ),
            ),
          ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
          decoration: BoxDecoration(
              color: cardColor,
              border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1)))
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: isRu ? "Напишите что-нибудь..." : "Type something...",
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
                  ),
                  onSubmitted: (val) {
                    _sendChatMessage(val);
                    _chatController.clear();
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.send_rounded, color: accentColor),
                onPressed: () {
                  _sendChatMessage(_chatController.text);
                  _chatController.clear();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickActionBtn(String label, IconData icon, Color accentColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: accentColor.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: accentColor),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
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
            isRu ? "Не удалось определить местоположение. Выберите город из списка:" : "Could not detect location. Please select a city:",
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
                    title: Text(city.name, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textColor.withOpacity(0.5)),
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
            label: Text(isRu ? "Попробовать GPS снова" : "Try GPS again"),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accentColor = Color(0xFF9C27B0);

    final textColor = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : const Color(0xFF1A1A1A));
    final appBarTextColor = theme.appBarTheme.titleTextStyle?.color ?? textColor;
    final scaffoldColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: appBarTextColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: TextStyle(color: appBarTextColor, fontWeight: FontWeight.bold)),
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

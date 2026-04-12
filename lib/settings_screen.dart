import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'main.dart';
import 'notification_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onThemeChanged;
  const SettingsScreen({super.key, this.onThemeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = AppSettings.notifications;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onGlobalStateChanged);
    localeNotifier.addListener(_onGlobalStateChanged);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onGlobalStateChanged);
    localeNotifier.removeListener(_onGlobalStateChanged);
    super.dispose();
  }

  void _onGlobalStateChanged() {
    if (mounted) setState(() {});
  }

  String _getThemeName(AppTheme mode) {
    final isRu = localeNotifier.value.languageCode == 'ru';
    switch (mode) {
      case AppTheme.light: return isRu ? "Светлая" : "Light";
      case AppTheme.dark: return isRu ? "Темная" : "Dark";
      case AppTheme.ocean: return isRu ? "Океан" : "Ocean";
      case AppTheme.neon: return isRu ? "Неон" : "Neon";
      case AppTheme.system: return isRu ? "Системная" : "System";
      case AppTheme.custom: return isRu ? "Своя" : "Custom";
    }
  }

  void _showTermsOfService() {
    final isRu = localeNotifier.value.languageCode == 'ru';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(isRu ? "Условия использования" : "Terms of Service"),
        content: SingleChildScrollView(
          child: Text(
            isRu
                ? "1. Мы используем данные OpenWeather для предоставления прогнозов.\n\n"
                "2. Ваша геопозиция обрабатывается локально для точности данных.\n\n"
                "3. ИИ-гид предоставляет справочную информацию, требующую проверки.\n\n"
                "4. GPS необходим для работы погодных виджетов."
                : "1. We use OpenWeather data to provide forecasts.\n\n"
                "2. Your location is processed locally for data accuracy.\n\n"
                "3. AI Guide provides reference information that requires verification.\n\n"
                "4. GPS is essential for weather widgets.",
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isRu ? "Понятно" : "Got it", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAboutProject() {
    final isRu = localeNotifier.value.languageCode == 'ru';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(isRu ? "О проекте QWorld" : "About QWorld"),
        content: Text(
            isRu
                ? "QWorld — это ваш интеллектуальный спутник в любой точке мира. Мы объединяем глобальные данные о погоде, качестве воздуха и возможности ИИ-гида."
                : "QWorld is your intelligent companion anywhere in the world. We combine global weather data, air quality, and AI guide capabilities."
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(isRu ? "Закрыть" : "Close")),
        ],
      ),
    );
  }

  void _showThemeCustomization() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return ThemeCustomizationScreen(onThemeChanged: widget.onThemeChanged);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _showLanguagePicker() {
    final isRu = localeNotifier.value.languageCode == 'ru';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isRu ? "Выберите язык" : "Select Language", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              title: const Text("Русский"),
              trailing: localeNotifier.value.languageCode == 'ru' ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () async {
                await AppSettings.saveLocale(const Locale('ru'));
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text("English"),
              trailing: localeNotifier.value.languageCode == 'en' ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () async {
                await AppSettings.saveLocale(const Locale('en'));
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRu = localeNotifier.value.languageCode == 'ru';

    // Используем Theme.of(context).scaffoldBackgroundColor для правильного цвета в светлых темах
    return Scaffold(
      backgroundColor: themeNotifier.value == AppTheme.custom ? Colors.transparent : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isRu ? "Настройки" : "Settings", style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSettingsGroup(context, isRu ? "Дизайн" : "Design", [
              _settingsActionTile(
                  Icons.palette_outlined,
                  isRu ? "Тема оформления" : "Theme",
                  _getThemeName(themeNotifier.value),
                  onTap: _showThemeCustomization
              ),
            ]),
            const SizedBox(height: 24),
            _buildSettingsGroup(context, isRu ? "Основные" : "General", [
              _settingsSwitchTile(
                  Icons.notifications_none_rounded,
                  isRu ? "Уведомления" : "Notifications",
                  _notificationsEnabled,
                      (val) async {
                    setState(() => _notificationsEnabled = val);
                    await AppSettings.saveNotifications(val);

                    if (val) {
                      await NotificationService.requestPermissions();
                      await NotificationService.showNotification(
                        title: isRu ? "Уведомления активны!" : "Notifications Active!",
                        body: isRu ? "Теперь вы будете получать новости" : "Now you will receive updates",
                      );
                    } else {
                      await NotificationService.cancelAll();
                    }
                  }
              ),
              _settingsActionTile(
                  Icons.language,
                  isRu ? "Язык приложения" : "Language",
                  localeNotifier.value.languageCode == 'ru' ? "Русский" : "English",
                  onTap: _showLanguagePicker
              ),
            ]),
            const SizedBox(height: 24),
            _buildSettingsGroup(context, isRu ? "О приложении" : "About", [
              _settingsActionTile(Icons.info_outline, isRu ? "О проекте QWorld" : "About QWorld", "", onTap: _showAboutProject),
              _settingsActionTile(Icons.description_outlined, isRu ? "Условия использования" : "Terms of Service", "", onTap: _showTermsOfService),
            ]),
            const SizedBox(height: 40),
            Text(isRu ? "Версия 2.6.0 (полная)" : "Version 2.6.0 (full)", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            Text(isRu ? "Последнее обновление: 04.04.2026" : "Last update: 04.04.2026", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor, // Идеально подстраивается под все темы, избегая черноты
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _settingsSwitchTile(IconData icon, String label, bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.blueAccent, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Switch.adaptive(value: value, onChanged: onChanged, activeColor: Colors.blueAccent),
    );
  }

  Widget _settingsActionTile(IconData icon, String label, String value, {required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.blueAccent, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty) Text(value, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
        ],
      ),
    );
  }
}

class ThemeCustomizationScreen extends StatefulWidget {
  final VoidCallback? onThemeChanged;
  const ThemeCustomizationScreen({super.key, this.onThemeChanged});

  @override
  State<ThemeCustomizationScreen> createState() => _ThemeCustomizationScreenState();
}

class _ThemeCustomizationScreenState extends State<ThemeCustomizationScreen> with SingleTickerProviderStateMixin {
  final List<AppTheme> _themes = [
    AppTheme.system,
    AppTheme.light,
    AppTheme.dark,
    AppTheme.ocean,
    AppTheme.neon,
  ];

  late int _currentIndex;
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  Offset _tapPosition = Offset.zero;

  File? _customImage;
  double _blurValue = AppSettings.customBlur;
  double _brightnessValue = AppSettings.customBrightness;
  bool _customIsDark = AppSettings.customIsDark;

  @override
  void initState() {
    super.initState();
    if (themeNotifier.value == AppTheme.custom) {
      _currentIndex = _themes.length;
    } else {
      _currentIndex = _themes.indexOf(themeNotifier.value);
    }
    if (_currentIndex == -1) _currentIndex = 0;

    if (AppSettings.customImagePath.isNotEmpty) {
      _customImage = File(AppSettings.customImagePath);
    }

    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOutQuart,
    ));
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _customImage = File(pickedFile.path);
      });
    }
  }

  void _nextTheme() => setState(() => _currentIndex = (_currentIndex + 1) % (_themes.length + 1));
  void _prevTheme() => setState(() => _currentIndex = (_currentIndex - 1 + (_themes.length + 1)) % (_themes.length + 1));

  Future<void> _applyTheme(BuildContext context, TapDownDetails details) async {
    setState(() => _tapPosition = details.localPosition);
    await _waveController.forward();

    if (_currentIndex < _themes.length) {
      await AppSettings.saveTheme(_themes[_currentIndex]);
    } else {
      if (_customImage != null) {
        await AppSettings.saveCustomTheme(
          path: _customImage!.path,
          blur: _blurValue,
          brightness: _brightnessValue,
          isDark: _customIsDark,
        );
        await AppSettings.saveTheme(AppTheme.custom);
      }
    }

    if (widget.onThemeChanged != null) widget.onThemeChanged!();
    if (mounted) Navigator.pop(context);
  }

  String _getThemeTitle(int index, bool isRu) {
    if (index == _themes.length) return isRu ? "Своё" : "Custom";
    AppTheme mode = _themes[index];
    switch (mode) {
      case AppTheme.light: return isRu ? "Светлая" : "Light";
      case AppTheme.dark: return isRu ? "Темная" : "Dark";
      case AppTheme.ocean: return isRu ? "Океан" : "Ocean";
      case AppTheme.neon: return isRu ? "Неон" : "Neon";
      case AppTheme.system: return isRu ? "Системная" : "System";
      case AppTheme.custom: return isRu ? "Своя" : "Custom";
    }
  }

  IconData _getThemeIcon(AppTheme mode) {
    switch (mode) {
      case AppTheme.light: return Icons.light_mode_outlined;
      case AppTheme.dark: return Icons.dark_mode_outlined;
      case AppTheme.ocean: return Icons.water_drop_outlined;
      case AppTheme.neon: return Icons.bolt_outlined;
      case AppTheme.system: return Icons.settings_brightness_outlined;
      case AppTheme.custom: return Icons.auto_awesome;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRu = localeNotifier.value.languageCode == 'ru';
    final isDarkSystem = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final bool isCustomSelection = _currentIndex == _themes.length;

    return Scaffold(
      backgroundColor: themeNotifier.value == AppTheme.custom ? Colors.transparent : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: Text(isRu ? "Выбор темы" : "Appearance", style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: GestureDetector(
                  key: ValueKey<int>(_currentIndex),
                  onTapDown: (details) => _applyTheme(context, details),
                  child: _buildPreviewCard(isCustomSelection, isDarkSystem, isRu),
                ),
              ),
            ),
          ),
          _buildControlPanel(isCustomSelection, isRu),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(bool isCustom, bool isDarkSystem, bool isRu) {
    final double blockBR = 40.0;

    return Container(
      width: 240,
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(blockBR),
        boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(blockBR),
        child: Stack(
          children: [
            // Фон карточки
            if (!isCustom)
              Container(color: _getPreviewColor(_themes[_currentIndex], isDarkSystem))
            else if (_customImage != null)
              Positioned.fill(child: Image.file(_customImage!, fit: BoxFit.cover))
            else
              Container(color: Colors.grey[800], child: const Center(child: Icon(Icons.image, size: 50, color: Colors.white24))),

            // Фильтры для кастомной темы: белый слой для светлой темы, черный слой для темной. Без зеленых рамок!
            if (isCustom && _customImage != null)
              Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: _blurValue, sigmaY: _blurValue),
                    child: Container(color: (_customIsDark ? Colors.black : Colors.white).withOpacity(1.0 - _brightnessValue)),
                  ),
                ),
              ),

            // Текст и иконка
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCustom ? Icons.auto_awesome : _getThemeIcon(_themes[_currentIndex]),
                    size: 64,
                    color: isCustom
                        ? (_customIsDark ? Colors.white : Colors.black)
                        : _getIconAndTextColor(_themes[_currentIndex], isDarkSystem),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _getThemeTitle(_currentIndex, isRu),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isCustom
                            ? (_customIsDark ? Colors.white : Colors.black)
                            : _getIconAndTextColor(_themes[_currentIndex], isDarkSystem)
                    ),
                  ),
                ],
              ),
            ),

            // Анимация волны
            AnimatedBuilder(
              animation: _waveAnimation,
              builder: (context, child) {
                if (_waveAnimation.value == 0) return const SizedBox.shrink();
                return Positioned(
                  left: _tapPosition.dx - 20,
                  top: _tapPosition.dy - 20,
                  child: Transform.scale(
                    scale: _waveAnimation.value * 50,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.3)),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel(bool isCustom, bool isRu) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      constraints: BoxConstraints(
        maxHeight: isCustom ? MediaQuery.of(context).size.height * 0.5 : 220,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: _prevTheme,
                    icon: const Icon(Icons.arrow_back_ios_rounded),
                    color: Colors.blueAccent,
                  ),
                  Text(
                      "${_currentIndex + 1} / ${_themes.length + 1}",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                  IconButton(
                    onPressed: _nextTheme,
                    icon: const Icon(Icons.arrow_forward_ios_rounded),
                    color: Colors.blueAccent,
                  ),
                ],
              ),
              if (isCustom) ...[
                const SizedBox(height: 12),
                _buildSlider(Icons.blur_on, _blurValue, 0, 15, (v) => setState(() => _blurValue = v)),
                _buildSlider(Icons.brightness_6, _brightnessValue, 0, 1, (v) => setState(() => _brightnessValue = v)),
                SwitchListTile.adaptive(
                  title: Text(isRu ? "Темный интерфейс" : "Dark UI mode", style: const TextStyle(fontWeight: FontWeight.w500)),
                  value: _customIsDark,
                  activeColor: Colors.blueAccent,
                  onChanged: (v) => setState(() => _customIsDark = v),
                ),
                TextButton.icon(
                  onPressed: _pickImage,
                  style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                  icon: const Icon(Icons.photo_library),
                  label: Text(isRu ? "Выбрать своё фото" : "Pick Your Photo"),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  onPressed: () => _applyTheme(context, TapDownDetails()),
                  child: Text(isRu ? "Применить" : "Apply", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlider(IconData icon, double value, double min, double max, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.blueAccent),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              activeColor: Colors.blueAccent,
              inactiveColor: Colors.blueAccent.withOpacity(0.2),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPreviewColor(AppTheme mode, bool isDarkSystem) {
    switch (mode) {
      case AppTheme.light: return const Color(0xFFF2F2F7);
      case AppTheme.dark: return const Color(0xFF1C1C1E);
      case AppTheme.ocean: return const Color(0xFFE0F7FA);
      case AppTheme.neon: return const Color(0xFF121212);
      case AppTheme.system: return isDarkSystem ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
      case AppTheme.custom: return Colors.transparent;
    }
  }

  Color _getIconAndTextColor(AppTheme mode, bool isDarkSystem) {
    switch (mode) {
      case AppTheme.light: return Colors.black87;
      case AppTheme.dark: return Colors.white;
      case AppTheme.ocean: return const Color(0xFF006064);
      case AppTheme.neon: return Colors.greenAccent;
      case AppTheme.system: return isDarkSystem ? Colors.white : Colors.black;
      case AppTheme.custom: return Colors.white;
    }
  }
}

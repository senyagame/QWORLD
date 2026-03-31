import 'package:flutter/material.dart';
import 'main.dart';
import 'notification_service.dart'; // Не забудь создать этот файл!

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

  String _getThemeName(ThemeMode mode) {
    final isRu = localeNotifier.value.languageCode == 'ru';
    switch (mode) {
      case ThemeMode.light: return isRu ? "Светлая" : "Light";
      case ThemeMode.dark: return isRu ? "Темная" : "Dark";
      case ThemeMode.system: return isRu ? "Системная" : "System";
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

  void _showThemePicker() {
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
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
            ),
            Text(isRu ? "Тема оформления" : "Theme Mode", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _themeOption(isRu ? "Светлая" : "Light", Icons.light_mode_outlined, ThemeMode.light),
            _themeOption(isRu ? "Темная" : "Dark", Icons.dark_mode_outlined, ThemeMode.dark),
            _themeOption(isRu ? "Системная" : "System", Icons.settings_brightness_outlined, ThemeMode.system),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(String title, IconData icon, ThemeMode mode) {
    bool isSelected = themeNotifier.value == mode;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.blueAccent : Colors.grey),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.blueAccent : null, fontWeight: isSelected ? FontWeight.bold : null)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blueAccent) : null,
      onTap: () async {
        await AppSettings.saveTheme(mode);
        if (mounted) {
          Navigator.pop(context);
          if (widget.onThemeChanged != null) widget.onThemeChanged!();
        }
      },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRu = localeNotifier.value.languageCode == 'ru';

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F7),
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
            _buildSettingsGroup(isDark, isRu ? "Дизайн" : "Design", [
              _settingsActionTile(
                  Icons.palette_outlined,
                  isRu ? "Тема оформления" : "Theme",
                  _getThemeName(themeNotifier.value),
                  onTap: _showThemePicker
              ),
            ]),
            const SizedBox(height: 24),
            _buildSettingsGroup(isDark, isRu ? "Основные" : "General", [
              _settingsSwitchTile(
                  Icons.notifications_none_rounded,
                  isRu ? "Уведомления" : "Notifications",
                  _notificationsEnabled,
                      (val) async {
                    setState(() => _notificationsEnabled = val);
                    await AppSettings.saveNotifications(val);

                    if (val) {
                      await NotificationService.requestPermissions(); // Просим разрешение у юзера
                      // 2. Мгновенное уведомление "Ура, включили!" (смахиваемое)
                      await NotificationService.showNotification(
                        title: isRu ? "Уведомления активны!" : "Notifications Active!",
                        body: isRu ? "Теперь вы будете получать новости" : "Now you will receive updates",
                      );

                      // 3. Ежедневное напоминание на 9:00 утра
                      await NotificationService.scheduleDailyNotification(
                        id: 10,
                        title: "QWorld",
                        body: isRu
                            ? "Сколько сейчас градусов на улице? Давайте проверим в приложении!"
                            : "What's the temperature outside? Let's check in the app!",
                        hour: 9,
                        minute: 30,
                      );
                    } else {
                      // Если выключили — чистим всё (включая постоянное)
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
            _buildSettingsGroup(isDark, isRu ? "О приложении" : "About", [
              _settingsActionTile(Icons.info_outline, isRu ? "О проекте QWorld" : "About QWorld", "", onTap: _showAboutProject),
              _settingsActionTile(Icons.description_outlined, isRu ? "Условия использования" : "Terms of Service", "", onTap: _showTermsOfService),
            ]),
            const SizedBox(height: 40),
            Text(isRu ? "Версия 2.5.0 (полная версия)" : "Version 2.5.0 (full version)", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            Text(isRu ? "Последнее обновление: 22.03.2026" : "Last update: 22.03.2026", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(bool isDark, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
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
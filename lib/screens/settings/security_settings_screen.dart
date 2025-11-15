

import 'package:flutter/material.dart';
import 'package:gwid/screens/settings/session_spoofing_screen.dart';
import 'package:gwid/screens/settings/sessions_screen.dart';
import 'package:gwid/screens/settings/export_session_screen.dart';
import 'package:gwid/screens/settings/qr_login_screen.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Безопасность")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          _buildSecurityOption(
            context,
            icon: Icons.qr_code_scanner_outlined,
            title: "Вход по QR-коду",
            subtitle: "Показать QR-код для входа на другом устройстве",
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const QrLoginScreen()),
              );
            },
          ),
          _buildSecurityOption(
            context,
            icon: Icons.history_toggle_off,
            title: "Активные сессии",
            subtitle: "Просмотр и управление активными сессиями",
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SessionsScreen()),
              );
            },
          ),
          _buildSecurityOption(
            context,
            icon: Icons.upload_file_outlined,
            title: "Экспорт сессии",
            subtitle: "Сохранить данные сессии для переноса",
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ExportSessionScreen(),
                ),
              );
            },
          ),
          _buildSecurityOption(
            context,
            icon: Icons.devices_other_outlined,
            title: "Подмена данных сессии",
            subtitle: "Изменение User-Agent, версии ОС и т.д.",
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SessionSpoofingScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

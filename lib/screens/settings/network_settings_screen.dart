

import 'package:flutter/material.dart';
import 'package:gwid/screens/settings/network_screen.dart';
import 'package:gwid/screens/settings/proxy_settings_screen.dart';
import 'package:gwid/screens/settings/socket_log_screen.dart';

class NetworkSettingsScreen extends StatelessWidget {
  final bool isModal;
  
  const NetworkSettingsScreen({super.key, this.isModal = false});

  @override
  Widget build(BuildContext context) {
    if (isModal) {
      return buildModalContent(context);
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Сеть")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildNetworkOption(
            context,
            icon: Icons.bar_chart_outlined,
            title: "Мониторинг сети",
            subtitle: "Просмотр статистики использования и скорости соединения",
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const NetworkScreen()),
              );
            },
          ),
          _buildNetworkOption(
            context,
            icon: Icons.shield_outlined,
            title: "Настройки прокси",
            subtitle: "Настроить подключение через прокси-сервер",
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ProxySettingsScreen(),
                ),
              );
            },
          ),
          _buildNetworkOption(
            context,
            icon: Icons.history_outlined,
            title: "Журнал WebSocket",
            subtitle: "Просмотр логов подключения WebSocket для отладки",
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SocketLogScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildModalContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildNetworkOption(
          context,
          icon: Icons.bar_chart_outlined,
          title: "Мониторинг сети",
          subtitle: "Статистика подключений и производительности",
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NetworkScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildNetworkOption(
          context,
          icon: Icons.vpn_key_outlined,
          title: "Настройки прокси",
          subtitle: "HTTP/HTTPS прокси, SOCKS",
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ProxySettingsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildNetworkOption(
          context,
          icon: Icons.list_alt_outlined,
          title: "Логи сокетов",
          subtitle: "Отладочная информация о соединениях",
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SocketLogScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildModalSettings(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [

          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.3),
            ),
          ),
          

          Center(
            child: Container(
              width: 400,
              height: 600,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Назад',
                        ),
                        const Expanded(
                          child: Text(
                            "Сеть",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: 'Закрыть',
                        ),
                      ],
                    ),
                  ),
                  

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildNetworkOption(
                          context,
                          icon: Icons.bar_chart_outlined,
                          title: "Мониторинг сети",
                          subtitle: "Статистика подключений и производительности",
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const NetworkScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildNetworkOption(
                          context,
                          icon: Icons.vpn_key_outlined,
                          title: "Настройки прокси",
                          subtitle: "HTTP/HTTPS прокси, SOCKS",
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const ProxySettingsScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildNetworkOption(
                          context,
                          icon: Icons.list_alt_outlined,
                          title: "Логи сокетов",
                          subtitle: "Отладочная информация о соединениях",
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const SocketLogScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkOption(
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

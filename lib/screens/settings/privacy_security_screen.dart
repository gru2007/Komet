

import 'package:flutter/material.dart';
import 'package:gwid/screens/settings/privacy_settings_screen.dart';
import 'package:gwid/screens/settings/security_settings_screen.dart';

class PrivacySecurityScreen extends StatelessWidget {
  final bool isModal;
  
  const PrivacySecurityScreen({super.key, this.isModal = false});

  @override
  Widget build(BuildContext context) {
    if (isModal) {
      return buildModalContent(context);
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Приватность и безопасность")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text("Приватность"),
              subtitle: const Text("Статус онлайн, кто может вас найти"),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PrivacySettingsScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text("Безопасность"),
              subtitle: const Text("Пароль, сессии, заблокированные"),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SecuritySettingsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
                            "Приватность и безопасность",
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
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.privacy_tip_outlined),
                            title: const Text("Приватность"),
                            subtitle: const Text("Статус онлайн, кто может вас найти"),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const PrivacySettingsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.security_outlined),
                            title: const Text("Безопасность"),
                            subtitle: const Text("Пароли, сессии, двухфакторная аутентификация"),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const SecuritySettingsScreen(),
                                ),
                              );
                            },
                          ),
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

  Widget buildModalContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text("Приватность"),
            subtitle: const Text("Статус онлайн, кто может вас найти"),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PrivacySettingsScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.security_outlined),
            title: const Text("Безопасность"),
            subtitle: const Text("Пароли, сессии, двухфакторная аутентификация"),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SecuritySettingsScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

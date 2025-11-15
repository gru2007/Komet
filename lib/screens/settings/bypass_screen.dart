import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gwid/theme_provider.dart';

class BypassScreen extends StatelessWidget {
  final bool isModal;
  
  const BypassScreen({super.key, this.isModal = false});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (isModal) {
      return buildModalContent(context);
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Bypass")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: colors.primary),
                    const SizedBox(width: 8),
                    Text(
                      "Обход блокировки",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Эта функция позволяет отправлять сообщения заблокированным пользователям, "
                  "даже если они заблокировали вас. Включите эту опцию, если хотите обойти "
                  "стандартные ограничения мессенджера.",
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Card(
                child: SwitchListTile(
                  title: const Text(
                    "Обход блокировки",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    "Разрешить отправку сообщений заблокированным пользователям",
                  ),
                  value: themeProvider.blockBypass,
                  onChanged: (value) {
                    themeProvider.setBlockBypass(value);
                  },
                  secondary: Icon(
                    themeProvider.blockBypass
                        ? Icons.psychology
                        : Icons.psychology_outlined,
                    color: themeProvider.blockBypass
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.outline.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_outlined,
                      color: colors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Важно знать",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Используя любую из bypass функций мы не несем ответственности за ваш аккаунт",
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalSettings(BuildContext context, ColorScheme colors) {
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
                            "Bypass",
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
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colors.outline.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: colors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Информация",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Эта функция предназначена для обхода ограничений и блокировок. Используйте с осторожностью и только в законных целях.",
                                style: TextStyle(
                                  color: colors.onSurface.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Consumer<ThemeProvider>(
                          builder: (context, themeProvider, child) {
                            return SwitchListTile(
                              title: const Text("Включить обход"),
                              subtitle: const Text("Активировать функции обхода ограничений"),
                              value: false, // Временно отключено
                              onChanged: (value) {

                              },
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

  Widget buildModalContent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colors.outline.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: colors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Информация",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Эта функция предназначена для обхода ограничений и блокировок. Используйте с осторожностью. Всю ответственность за ваш аккаунт несете только вы.",
                style: TextStyle(
                  color: colors.onSurface.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return SwitchListTile(
              title: const Text("Обход блокировки"),
              subtitle: const Text("Активировать функции обхода ограничений"),
              value: themeProvider.blockBypass,
              onChanged: (value) {
                themeProvider.setBlockBypass(value);
              },
            );
          },
        ),
      ],
    );
  }
}

import 'package:http/http.dart' as http;

class VersionChecker {




  static Future<String> getLatestVersion() async {
    try {

      final html = await _fetchPage('https://web.max.ru/');


      final mainChunkUrl = _extractMainChunkUrl(html);
      print('[INFO] Загружаем главный chunk: $mainChunkUrl');


      final mainChunkCode = await _fetchPage(mainChunkUrl);


      final chunkPaths = _extractChunkPaths(mainChunkCode);


      for (final path in chunkPaths) {
        if (path.contains('/chunks/')) {
          final url = _buildChunkUrl(path);
          print('[INFO] Загружаем chunk: $url');

          try {
            final jsCode = await _fetchPage(url);
            final version = _extractVersion(jsCode);

            if (version != null) {
              print('[SUCCESS] Версия: $version из $url');
              return version;
            }
          } catch (e) {
            print('[WARN] Не удалось скачать $url: $e');
            continue;
          }
        }
      }

      throw Exception('Версия не найдена ни в одном из чанков');
    } catch (e) {
      throw Exception('Не удалось проверить версию: $e');
    }
  }


  static Future<String> _fetchPage(String url) async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки $url (${response.statusCode})');
    }

    return response.body;
  }


  static String _extractMainChunkUrl(String html) {
    final parts = html.split('import(');
    if (parts.length < 3) {
      throw Exception('Не найден import() в HTML');
    }

    final mainChunkImport = parts[2]
        .split(')')[0]
        .replaceAll('"', '')
        .replaceAll("'", '');

    return 'https://web.max.ru$mainChunkImport';
  }


  static List<String> _extractChunkPaths(String mainChunkCode) {
    final firstLine = mainChunkCode.split('\n')[0];
    final arrayContent = firstLine.split('[')[1].split(']')[0];

    return arrayContent.split(',');
  }


  static String _buildChunkUrl(String path) {
    final cleanPath = path.substring(3, path.length - 1);
    return 'https://web.max.ru/_app/immutable$cleanPath';
  }


  static String? _extractVersion(String jsCode) {
    const wsAnchor = 'wss://ws-api.oneme.ru/websocket';
    final pos = jsCode.indexOf(wsAnchor);

    if (pos == -1) {
      print('[INFO] ws-якорь не найден');
      return null;
    }

    print('[INFO] Найден ws-якорь на позиции $pos');


    final snippet = jsCode.substring(pos, (pos + 2000).clamp(0, jsCode.length));

    print('[INFO] Анализируем snippet (первые 500 символов):');
    print('${snippet.substring(0, 500.clamp(0, snippet.length))}...\n');


    final versionRegex = RegExp(r'[:=]\s*"(\d{1,2}\.\d{1,2}\.\d{1,2})"');
    final match = versionRegex.firstMatch(snippet);

    if (match != null) {
      return match.group(1);
    }

    print('[INFO] Версия не найдена в snippet');
    return null;
  }
}

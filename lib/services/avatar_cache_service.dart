import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gwid/services/cache_service.dart';

class AvatarCacheService {
  static final AvatarCacheService _instance = AvatarCacheService._internal();
  factory AvatarCacheService() => _instance;
  AvatarCacheService._internal();

  final CacheService _cacheService = CacheService();

  final Map<String, Uint8List> _imageMemoryCache = {};
  final Map<String, DateTime> _imageCacheTimestamps = {};

  static const Duration _imageTTL = Duration(days: 7);
  static const int _maxMemoryImages = 50;
  static const int _maxImageSizeMB = 5;

  Future<void> initialize() async {
    await _cacheService.initialize();
    print('AvatarCacheService инициализирован');
  }

  Future<ImageProvider?> getAvatar(String? avatarUrl, {int? userId}) async {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return null;
    }

    try {
      final cacheKey = _generateCacheKey(avatarUrl, userId);

      if (_imageMemoryCache.containsKey(cacheKey)) {
        final timestamp = _imageCacheTimestamps[cacheKey];
        if (timestamp != null && !_isExpired(timestamp, _imageTTL)) {
          final imageData = _imageMemoryCache[cacheKey]!;
          return MemoryImage(imageData);
        } else {
          _imageMemoryCache.remove(cacheKey);
          _imageCacheTimestamps.remove(cacheKey);
        }
      }

      final cachedFile = await _cacheService.getCachedFile(
        avatarUrl,
        customKey: cacheKey,
      );
      if (cachedFile != null && await cachedFile.exists()) {
        final imageData = await cachedFile.readAsBytes();

        _imageMemoryCache[cacheKey] = imageData;
        _imageCacheTimestamps[cacheKey] = DateTime.now();

        if (_imageMemoryCache.length > _maxMemoryImages) {
          await _evictOldestImages();
        }

        return MemoryImage(imageData);
      }

      final imageData = await _downloadImage(avatarUrl);
      if (imageData != null) {
        await _cacheService.cacheFile(avatarUrl, customKey: cacheKey);

        _imageMemoryCache[cacheKey] = imageData;
        _imageCacheTimestamps[cacheKey] = DateTime.now();

        return MemoryImage(imageData);
      }
    } catch (e) {
      print('Ошибка получения аватарки: $e');
    }

    return null;
  }

  Future<File?> getAvatarFile(String? avatarUrl, {int? userId}) async {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return null;
    }

    try {
      final cacheKey = _generateCacheKey(avatarUrl, userId);
      return await _cacheService.getCachedFile(avatarUrl, customKey: cacheKey);
    } catch (e) {
      print('Ошибка получения файла аватарки: $e');
      return null;
    }
  }

  Future<void> preloadAvatars(List<String> avatarUrls) async {
    final futures = avatarUrls.map((url) => getAvatar(url));
    await Future.wait(futures);
    print('Предзагружено ${avatarUrls.length} аватарок');
  }

  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final imageData = response.bodyBytes;

        if (imageData.length > _maxImageSizeMB * 1024 * 1024) {
          print('Изображение слишком большое: ${imageData.length} байт');
          return null;
        }

        return imageData;
      }
    } catch (e) {
      print('Ошибка загрузки изображения $url: $e');
    }
    return null;
  }

  String _generateCacheKey(String url, int? userId) {
    if (userId != null) {
      return 'avatar_${userId}_${_hashUrl(url)}';
    }
    return 'avatar_${_hashUrl(url)}';
  }

  String _hashUrl(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  bool _isExpired(DateTime timestamp, Duration ttl) {
    return DateTime.now().difference(timestamp) > ttl;
  }

  Future<void> _evictOldestImages() async {
    if (_imageMemoryCache.isEmpty) return;

    final sortedEntries = _imageCacheTimestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final toRemove = (sortedEntries.length * 0.2).ceil();
    for (int i = 0; i < toRemove && i < sortedEntries.length; i++) {
      final key = sortedEntries[i].key;
      _imageMemoryCache.remove(key);
      _imageCacheTimestamps.remove(key);
    }
  }

  Future<void> clearAvatarCache() async {
    _imageMemoryCache.clear();
    _imageCacheTimestamps.clear();

    try {
      final cacheDir = await getApplicationCacheDirectory();
      final avatarDir = Directory('${cacheDir.path}/avatars');
      if (await avatarDir.exists()) {
        await _clearDirectoryContents(avatarDir);
      }
    } catch (e) {
      print('Ошибка очистки кэша аватарок: $e');
    }

    print('Кэш аватарок очищен');
  }

  Future<void> _clearDirectoryContents(Directory directory) async {
    try {
      // Очищаем содержимое директории, удаляя файлы по одному
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          try {
            await entity.delete();
            // Небольшая задержка между удалениями для избежания конфликтов
            await Future.delayed(const Duration(milliseconds: 5));
          } catch (fileError) {
            // Игнорируем ошибки удаления отдельных файлов
            print('Не удалось удалить файл ${entity.path}: $fileError');
          }
        } else if (entity is Directory) {
          try {
            // Рекурсивно очищаем поддиректории
            await _clearDirectoryContents(entity);
            try {
              await entity.delete();
            } catch (dirError) {
              print(
                'Не удалось удалить поддиректорию ${entity.path}: $dirError',
              );
            }
          } catch (subDirError) {
            print('Ошибка очистки поддиректории ${entity.path}: $subDirError');
          }
        }
      }
      print('Содержимое директории ${directory.path} очищено');
    } catch (e) {
      print('Ошибка очистки содержимого директории ${directory.path}: $e');
    }
  }

  Future<void> removeAvatarFromCache(String avatarUrl, {int? userId}) async {
    try {
      final cacheKey = _generateCacheKey(avatarUrl, userId);

      _imageMemoryCache.remove(cacheKey);
      _imageCacheTimestamps.remove(cacheKey);

      await _cacheService.removeCachedFile(avatarUrl, customKey: cacheKey);
    } catch (e) {
      print('Ошибка удаления аватарки из кэша: $e');
    }
  }

  Future<Map<String, dynamic>> getAvatarCacheStats() async {
    try {
      final memoryImages = _imageMemoryCache.length;
      int totalMemorySize = 0;

      for (final imageData in _imageMemoryCache.values) {
        totalMemorySize += imageData.length;
      }

      int diskSize = 0;
      try {
        final cacheDir = await getApplicationCacheDirectory();
        final avatarDir = Directory('${cacheDir.path}/avatars');
        if (await avatarDir.exists()) {
          await for (final entity in avatarDir.list(recursive: true)) {
            if (entity is File) {
              diskSize += await entity.length();
            }
          }
        }
      } catch (e) {
        print('Ошибка подсчета размера файлового кэша: $e');
      }

      return {
        'memoryImages': memoryImages,
        'memorySizeMB': (totalMemorySize / (1024 * 1024)).toStringAsFixed(2),
        'diskSizeMB': (diskSize / (1024 * 1024)).toStringAsFixed(2),
        'maxMemoryImages': _maxMemoryImages,
        'maxImageSizeMB': _maxImageSizeMB,
      };
    } catch (e) {
      print('Ошибка получения статистики кэша аватарок: $e');
      return {};
    }
  }

  Future<bool> hasAvatarInCache(String avatarUrl, {int? userId}) async {
    try {
      final cacheKey = _generateCacheKey(avatarUrl, userId);

      if (_imageMemoryCache.containsKey(cacheKey)) {
        final timestamp = _imageCacheTimestamps[cacheKey];
        if (timestamp != null && !_isExpired(timestamp, _imageTTL)) {
          return true;
        }
      }

      return await _cacheService.hasCachedFile(avatarUrl, customKey: cacheKey);
    } catch (e) {
      print('Ошибка проверки существования аватарки в кэше: $e');
      return false;
    }
  }

  Widget getAvatarWidget(
    String? avatarUrl, {
    int? userId,
    double size = 40,
    String? fallbackText,
    Color? backgroundColor,
    Color? textColor,
  }) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return _buildFallbackAvatar(
        fallbackText,
        size,
        backgroundColor,
        textColor,
      );
    }

    return FutureBuilder<ImageProvider?>(
      future: getAvatar(avatarUrl, userId: userId),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return CircleAvatar(
            radius: size / 2,
            backgroundImage: snapshot.data,
            backgroundColor: backgroundColor,
          );
        } else {
          return _buildFallbackAvatar(
            fallbackText,
            size,
            backgroundColor,
            textColor,
          );
        }
      },
    );
  }

  Widget _buildFallbackAvatar(
    String? text,
    double size,
    Color? backgroundColor,
    Color? textColor,
  ) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor ?? Colors.grey[300],
      child: text != null && text.isNotEmpty
          ? Text(
              text[0].toUpperCase(),
              style: TextStyle(
                color: textColor ?? Colors.white,
                fontSize: size * 0.4,
                fontWeight: FontWeight.bold,
              ),
            )
          : Icon(
              Icons.person,
              size: size * 0.6,
              color: textColor ?? Colors.white,
            ),
    );
  }
}

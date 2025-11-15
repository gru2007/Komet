import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';


class ImageCacheService {
  ImageCacheService._privateConstructor();
  static final ImageCacheService instance =
      ImageCacheService._privateConstructor();

  static const String _cacheDirectoryName = 'image_cache';
  static const Duration _cacheExpiration = Duration(
    days: 7,
  ); // Кеш изображений на 7 дней
  late Directory _cacheDirectory;


  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDirectory = Directory(path.join(appDir.path, _cacheDirectoryName));

    if (!_cacheDirectory.existsSync()) {
      await _cacheDirectory.create(recursive: true);
    }


    await _cleanupExpiredCache();
  }


  String getCachedImagePath(String url) {
    final fileName = _generateFileName(url);
    return path.join(_cacheDirectory.path, fileName);
  }


  bool isImageCached(String url) {
    final file = File(getCachedImagePath(url));
    return file.existsSync();
  }


  Future<File?> loadImage(String url, {bool forceRefresh = false}) async {
    if (!forceRefresh && isImageCached(url)) {
      final cachedFile = File(getCachedImagePath(url));
      if (await _isFileValid(cachedFile)) {
        return cachedFile;
      } else {

        await cachedFile.delete();
      }
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(getCachedImagePath(url));
        await file.writeAsBytes(response.bodyBytes);


        await _updateFileAccessTime(file);

        return file;
      }
    } catch (e) {
      print('Ошибка загрузки изображения $url: $e');
    }

    return null;
  }


  Future<Uint8List?> loadImageAsBytes(
    String url, {
    bool forceRefresh = false,
  }) async {
    final file = await loadImage(url, forceRefresh: forceRefresh);
    if (file != null) {
      return await file.readAsBytes();
    }
    return null;
  }


  Future<void> preloadImage(String url) async {
    await loadImage(url);
  }


  Future<void> preloadContactAvatar(String? photoUrl) async {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      await preloadImage(photoUrl);
    }
  }


  Future<void> preloadProfileAvatar(String? photoUrl) async {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      await preloadImage(photoUrl);
    }
  }


  Future<void> preloadContactAvatars(List<String?> photoUrls) async {
    final futures = photoUrls
        .where((url) => url != null && url.isNotEmpty)
        .map((url) => preloadImage(url!))
        .toList();

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }


  Future<void> clearCache() async {
    if (_cacheDirectory.existsSync()) {
      await _cacheDirectory.delete(recursive: true);
      await _cacheDirectory.create(recursive: true);
    }
  }


  Future<int> getCacheSize() async {
    int totalSize = 0;
    if (_cacheDirectory.existsSync()) {
      await for (final entity in _cacheDirectory.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }
    return totalSize;
  }


  Future<int> getCacheFileCount() async {
    int count = 0;
    if (_cacheDirectory.existsSync()) {
      await for (final entity in _cacheDirectory.list(recursive: true)) {
        if (entity is File) {
          count++;
        }
      }
    }
    return count;
  }


  Future<void> _cleanupExpiredCache() async {
    if (!_cacheDirectory.existsSync()) return;

    await for (final entity in _cacheDirectory.list(recursive: true)) {
      if (entity is File && await _isFileExpired(entity)) {
        await entity.delete();
      }
    }
  }


  Future<bool> _isFileValid(File file) async {
    if (!file.existsSync()) return false;


    final stat = await file.stat();
    final age = DateTime.now().difference(stat.modified);

    return age < _cacheExpiration;
  }


  Future<bool> _isFileExpired(File file) async {
    if (!file.existsSync()) return false;

    final stat = await file.stat();
    final age = DateTime.now().difference(stat.modified);

    return age >= _cacheExpiration;
  }


  Future<void> _updateFileAccessTime(File file) async {

    try {
      await file.setLastModified(DateTime.now());
    } catch (e) {

    }
  }


  String _generateFileName(String url) {

    final hash = url.hashCode.abs().toString();
    final extension = path.extension(url).isNotEmpty
        ? path.extension(url)
        : '.jpg'; // По умолчанию jpg

    return '$hash$extension';
  }


  Future<Map<String, dynamic>> getCacheStats() async {
    final size = await getCacheSize();
    final fileCount = await getCacheFileCount();

    return {
      'cache_size_bytes': size,
      'cache_size_mb': (size / (1024 * 1024)).toStringAsFixed(2),
      'file_count': fileCount,
      'cache_directory': _cacheDirectory.path,
    };
  }
}


extension CachedImageExtension on String {

  Widget getCachedNetworkImage({
    Key? key,
    double? width,
    double? height,
    BoxFit? fit,
    Widget? placeholder,
    Widget? errorWidget,
    Duration? fadeInDuration,
    bool useMemoryCache = true,
  }) {
    return CachedNetworkImage(
      key: key,
      imageUrl: this,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.image, color: Colors.grey),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
      fadeInDuration: fadeInDuration ?? const Duration(milliseconds: 300),
      useOldImageOnUrlChange: true,
      memCacheWidth: useMemoryCache ? (width ?? 200).toInt() : null,
      memCacheHeight: useMemoryCache ? (height ?? 200).toInt() : null,
    );
  }


  Future<void> preloadImage() async {
    await ImageCacheService.instance.loadImage(this);
  }
}

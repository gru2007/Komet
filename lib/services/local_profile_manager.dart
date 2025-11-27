import 'package:gwid/models/profile.dart';
import 'package:gwid/services/profile_cache_service.dart';

class LocalProfileManager {
  static final LocalProfileManager _instance = LocalProfileManager._internal();
  factory LocalProfileManager() => _instance;
  LocalProfileManager._internal();

  final ProfileCacheService _profileCache = ProfileCacheService();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _profileCache.initialize();
    _initialized = true;
  }

  Future<Profile?> getActualProfile(Profile? serverProfile) async {
    await initialize();

    final localAvatarPath = await _profileCache.getLocalAvatarPath();
    final mergedProfile = await _profileCache.getMergedProfile(serverProfile);

    if (mergedProfile != null && localAvatarPath != null) {
      return Profile(
        id: mergedProfile.id,
        phone: mergedProfile.phone,
        firstName: mergedProfile.firstName,
        lastName: mergedProfile.lastName,
        description: mergedProfile.description,
        photoBaseUrl: 'file://$localAvatarPath',
        photoId: mergedProfile.photoId,
        updateTime: mergedProfile.updateTime,
        options: mergedProfile.options,
        accountStatus: mergedProfile.accountStatus,
        profileOptions: mergedProfile.profileOptions,
      );
    }

    return mergedProfile;
  }

  Future<String?> getLocalAvatarPath() async {
    await initialize();
    return await _profileCache.getLocalAvatarPath();
  }

  Future<bool> hasLocalChanges() async {
    await initialize();
    return await _profileCache.hasLocalChanges();
  }

  Future<void> clearLocalChanges() async {
    await initialize();
    await _profileCache.clearProfileCache();
  }
}

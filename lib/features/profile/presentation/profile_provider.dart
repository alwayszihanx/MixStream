import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/storage/storage_service.dart';

part 'profile_provider.g.dart';

@Riverpod(keepAlive: true)
class UserProfile extends _$UserProfile {
  @override
  UserProfileData build() {
    final storage = ref.watch(storageServiceProvider);
    final name = storage.getProfileName() ?? 'User';
    final colorIndex = storage.getProfileColorIndex();
    final avatarIndex = storage.getProfileAvatarIndex();
    final imagePath = storage.getProfileImagePath();
    return UserProfileData(
      name: name,
      colorIndex: colorIndex,
      avatarIndex: avatarIndex,
      imagePath: imagePath,
    );
  }

  Future<void> updateName(String name) async {
    final storage = ref.read(storageServiceProvider);
    await storage.saveProfileName(name);
    state = state.copyWith(name: name);
  }

  Future<void> updateColor(int index) async {
    final storage = ref.read(storageServiceProvider);
    await storage.saveProfileColorIndex(index);
    state = state.copyWith(colorIndex: index);
  }

  Future<void> updateAvatar(int index) async {
    final storage = ref.read(storageServiceProvider);
    await storage.saveProfileAvatarIndex(index);
    state = state.copyWith(avatarIndex: index, imagePath: null);
  }

  Future<void> updateImage(String path) async {
    final storage = ref.read(storageServiceProvider);
    await storage.saveProfileImagePath(path);
    state = state.copyWith(imagePath: path);
  }

  Future<void> clearImage() async {
    final storage = ref.read(storageServiceProvider);
    await storage.saveProfileImagePath(null);
    state = state.copyWith(imagePath: null);
  }

  /// Load a different profile by id
  Future<void> switchToProfile(String profileId) async {
    final storage = ref.read(storageServiceProvider);
    final profiles = await _getProfiles(storage);
    final profile = profiles.where((p) => p['id'] == profileId).firstOrNull;
    if (profile == null) return;

    await storage.saveProfileName(profile['name'] as String? ?? 'User');
    await storage.saveProfileColorIndex(profile['colorIndex'] as int? ?? 0);
    await storage.saveProfileAvatarIndex(profile['avatarIndex'] as int? ?? 0);
    await storage.saveProfileImagePath(profile['imagePath'] as String?);

    state = UserProfileData(
      name: profile['name'] as String? ?? 'User',
      colorIndex: profile['colorIndex'] as int? ?? 0,
      avatarIndex: profile['avatarIndex'] as int? ?? 0,
      imagePath: profile['imagePath'] as String?,
    );
  }

  /// Create a new profile and switch to it
  Future<void> createProfile(String name, int colorIndex) async {
    final storage = ref.read(storageServiceProvider);
    final profiles = await _getProfiles(storage);

    final newProfile = {
      'id': 'profile_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'colorIndex': colorIndex,
      'avatarIndex': profiles.length % UserProfileData.avatarIcons.length,
      'imagePath': null,
    };

    profiles.add(newProfile);
    await _saveProfiles(storage, profiles);

    // Switch to the new profile
    await switchToProfile(newProfile['id'] as String);
  }

  /// Delete a profile (cannot delete the last one)
  Future<void> deleteProfile(String profileId) async {
    final storage = ref.read(storageServiceProvider);
    final profiles = await _getProfiles(storage);
    if (profiles.length <= 1) return;

    profiles.removeWhere((p) => p['id'] == profileId);
    await _saveProfiles(storage, profiles);

    // If we deleted the current profile, switch to the first one
    if (state.name == profiles.firstOrNull?['name']) {
      await switchToProfile(profiles.first['id'] as String);
    }
  }

  /// Get all saved profiles
  Future<List<Map<String, dynamic>>> getAllProfiles() async {
    final storage = ref.read(storageServiceProvider);
    return _getProfiles(storage);
  }

  Future<List<Map<String, dynamic>>> _getProfiles(StorageService storage) async {
    final json = storage.getString('user_profiles');
    if (json == null || json.isEmpty) {
      // Return default profile
      return [
        {
          'id': 'profile_default',
          'name': state.name,
          'colorIndex': state.colorIndex,
          'avatarIndex': state.avatarIndex,
          'imagePath': state.imagePath,
        },
      ];
    }
    final decoded = jsonDecode(json);
    return (decoded as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _saveProfiles(StorageService storage, List<Map<String, dynamic>> profiles) async {
    await storage.setString('user_profiles', jsonEncode(profiles));
  }
}

class UserProfileData {
  final String name;
  final int colorIndex;
  final int avatarIndex;
  final String? imagePath;

  const UserProfileData({
    required this.name,
    required this.colorIndex,
    required this.avatarIndex,
    this.imagePath,
  });

  bool get hasCustomImage =>
      imagePath != null && imagePath!.isNotEmpty && File(imagePath!).existsSync();

  UserProfileData copyWith({
    String? name,
    int? colorIndex,
    int? avatarIndex,
    String? imagePath,
    bool clearImage = false,
  }) {
    return UserProfileData(
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
    );
  }

  static const avatarColors = [
    Color(0xFF6C63FF),
    Color(0xFFFF3D71),
    Color(0xFF00D68F),
    Color(0xFF0095FF),
    Color(0xFFFFAA00),
    Color(0xFFE040FB),
    Color(0xFF00BCD4),
    Color(0xFFFF5722),
  ];

  static const avatarIcons = [
    'person',
    'smart_display',
    'movie',
    'music_note',
    'sports_esports',
    'flight',
    'restaurant',
    'pets',
  ];

  Color get color => avatarColors[colorIndex % avatarColors.length];
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

///Remembers the player's display name and (optional) profile photo locally, so returning
///players don't have to redo the profile setup screen every launch.
class ProfileService {
  static const _nameKey = 'profile_name';
  static const _photoKey = 'profile_photo_base64';

  static Future<String?> loadName() async =>
      (await SharedPreferences.getInstance()).getString(_nameKey);

  static Future<String?> loadPhotoBase64() async =>
      (await SharedPreferences.getInstance()).getString(_photoKey);

  static Future<void> save({required String name, String? photoBase64}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    if (photoBase64 != null) {
      await prefs.setString(_photoKey, photoBase64);
    } else {
      await prefs.remove(_photoKey);
    }
  }
}

///Decodes a base64 profile photo back to bytes for `Image.memory`. Kept here so callers
///don't need to import `dart:convert` just for this one call.
List<int> decodePhoto(String base64Photo) => base64Decode(base64Photo);

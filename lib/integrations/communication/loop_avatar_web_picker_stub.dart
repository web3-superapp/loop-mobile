import 'dart:typed_data';

const bool avatarWebPickerAvailable = false;
Future<Uint8List?> pickAvatarWebImage(int maximumBytes) =>
    throw UnsupportedError('Browser image picker unavailable');

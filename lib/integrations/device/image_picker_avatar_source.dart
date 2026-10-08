import 'package:image_picker/image_picker.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_media.dart';

/// The system photo library, through `image_picker` (decision 0112).
///
/// Only the library is offered — no camera — and the picture is scaled to at
/// most 2048 px on its long edge by the platform before LOOP sees it. The
/// square crop and the upload happen afterwards, on the bytes alone; no path
/// and no metadata of the original file leaves this adapter.
final class ImagePickerAvatarSource implements AvatarImagePicker {
  ImagePickerAvatarSource({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  bool get available => true;

  @override
  Future<PickedAvatarImage?> pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 92,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    return PickedAvatarImage(bytes: await file.readAsBytes());
  }
}

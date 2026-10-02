import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

const bool avatarWebPickerAvailable = true;

@JS('document')
external _AvatarDocument get _document;

extension type _AvatarDocument(JSObject _) implements JSObject {
  external _AvatarInput createElement(String tag);
  external _AvatarBody get body;
}

extension type _AvatarBody(JSObject _) implements JSObject {
  external JSObject appendChild(JSObject child);
}

extension type _AvatarInput(JSObject _) implements JSObject {
  external set type(String value);
  external set accept(String value);
  external _AvatarFileList? get files;
  external void setAttribute(String name, String value);
  external void addEventListener(String name, JSFunction callback);
  external void removeEventListener(String name, JSFunction callback);
  external void click();
  external void remove();
}

extension type _AvatarFileList(JSObject _) implements JSObject {
  external int get length;
  external _AvatarFile? item(int index);
}

extension type _AvatarFile(JSObject _) implements JSObject {
  external int get size;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

/// Uses the browser's local chooser, including Flutter's WASM runtime.
/// No Stream upload, remote URL or persistent browser storage is involved.
Future<Uint8List?> pickAvatarWebImage(int maximumBytes) {
  final result = Completer<Uint8List?>();
  final input = _document.createElement('input');
  input.type = 'file';
  input.accept = 'image/*';
  input.setAttribute('style', 'display:none');
  var claimed = false;
  late final JSFunction change;
  late final JSFunction cancel;

  void cleanup() {
    input.removeEventListener('change', change);
    input.removeEventListener('cancel', cancel);
    input.remove();
  }

  Future<void> readSelection() async {
    if (claimed) return;
    claimed = true;
    final files = input.files;
    final file = files == null || files.length == 0 ? null : files.item(0);
    cleanup();
    try {
      if (file == null) {
        result.complete(null);
      } else if (file.size > maximumBytes) {
        // Preserve the controller's existing size refusal without reading
        // an arbitrarily large file into memory.
        result.complete(Uint8List(maximumBytes + 1));
      } else {
        final buffer = await file.arrayBuffer().toDart;
        result.complete(buffer.toDart.asUint8List());
      }
    } catch (error, stack) {
      result.completeError(error, stack);
    }
  }

  change = ((JSAny? _) => unawaited(readSelection())).toJS;
  cancel = ((JSAny? _) {
    if (claimed) return;
    claimed = true;
    cleanup();
    result.complete(null);
  }).toJS;
  input.addEventListener('change', change);
  input.addEventListener('cancel', cancel);
  _document.body.appendChild(input);
  try {
    input.click();
  } catch (error, stack) {
    claimed = true;
    cleanup();
    result.completeError(error, stack);
  }
  return result.future;
}

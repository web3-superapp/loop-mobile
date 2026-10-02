import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_upload.dart';

class _Session extends LoopSessionController {
  @override
  LoopSessionState build() =>
      const LoopSessionState(mode: LoopSessionMode.preview);
  void leave() =>
      state = const LoopSessionState(mode: LoopSessionMode.signedOut);
}

class _Picker implements AvatarImagePicker {
  _Picker(this.next);
  Future<Uint8List?> Function() next;
  int calls = 0;
  @override
  Future<Uint8List?> pick() {
    calls++;
    return next();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('thumbnail decoding bounds both axes without upscaling', () {
    for (final sample in <(int, int, int, int)>[
      (1, 8192, 1, 256),
      (8192, 1, 256, 1),
      (8192, 8192, 256, 256),
      (1024, 512, 256, 128),
      (512, 1024, 128, 256),
      (1, 1, 1, 1),
      (120, 240, 120, 240),
    ]) {
      final (width, height, expectedWidth, expectedHeight) = sample;
      final target = avatarDecodeDimensions(width, height);
      expect(target, (width: expectedWidth, height: expectedHeight));
      expect(target.width, lessThanOrEqualTo(width));
      expect(target.height, lessThanOrEqualTo(height));
      expect(target.width * target.height, lessThanOrEqualTo(256 * 256));
    }
  });

  final image = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
  );
  test(
    'web-compatible codec accepts valid bytes and rejects corrupt bytes',
    () async {
      await validateAvatarWebImage(image);
      await expectLater(
        validateAvatarWebImage(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<Exception>()),
      );
    },
  );

  ProviderContainer scope(_Picker picker) {
    final container = ProviderContainer(
      overrides: [
        loopSessionProvider.overrideWith(_Session.new),
        avatarImagePickerProvider.overrideWithValue(picker),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'valid image remains local; cancel and invalid selection preserve it',
    () async {
      final picker = _Picker(() async => image);
      final container = scope(picker);
      final controller = container.read(
        avatarUploadControllerProvider.notifier,
      );
      await controller.pick();
      expect(container.read(avatarUploadControllerProvider).bytes, image);
      expect(
        container.read(avatarUploadControllerProvider).message,
        contains('尚未上传'),
      );
      picker.next = () async => null;
      await controller.pick();
      expect(container.read(avatarUploadControllerProvider).bytes, image);
      picker.next = () async => Uint8List.fromList([1, 2, 3]);
      await controller.pick();
      expect(container.read(avatarUploadControllerProvider).bytes, image);
      expect(
        container.read(avatarUploadControllerProvider).message,
        contains('未能读取'),
      );
      picker.next = () async => Uint8List(avatarImageMaxBytes + 1);
      await controller.pick();
      expect(
        container.read(avatarUploadControllerProvider).message,
        contains('5 MB'),
      );
      expect(container.read(avatarUploadControllerProvider).bytes, image);
    },
  );
  test('leaving preview erases image and ignores pending selection', () async {
    final pending = Completer<Uint8List?>();
    final picker = _Picker(() => pending.future);
    final container = scope(picker);
    final operation = container
        .read(avatarUploadControllerProvider.notifier)
        .pick();
    (container.read(loopSessionProvider.notifier) as _Session).leave();
    expect(container.read(avatarUploadControllerProvider).bytes, isNull);
    pending.complete(image);
    await operation;
    expect(container.read(avatarUploadControllerProvider).bytes, isNull);
    await container.read(avatarUploadControllerProvider.notifier).pick();
    expect(picker.calls, 1);
    expect(
      container.read(avatarUploadControllerProvider).message,
      contains('暂不可用'),
    );
  });
}

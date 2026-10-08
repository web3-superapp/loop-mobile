import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_editor.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_media.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/media/loop_v2_media.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';

const _mediaId = '0c6b1f3e-6a51-4a2d-9b7e-3f1c2d4e5a6b';

Map<String, Object?> _uploadWire() => <String, Object?>{
  'mediaId': _mediaId,
  'ref': 'avatar:media/$_mediaId',
  'url': '/v2/media/$_mediaId.webp',
  'width': 512,
  'height': 512,
  'contractVersion': '2.0',
};

final class _Resolver implements LoopMediaUrlResolver {
  const _Resolver();

  @override
  String? urlFor(String mediaId) => 'https://api.test/v2/media/$mediaId.webp';
}

final class _Picker implements AvatarImagePicker {
  _Picker({this.picked});

  final PickedAvatarImage? picked;
  var calls = 0;

  @override
  bool get available => true;

  @override
  Future<PickedAvatarImage?> pick() async {
    calls += 1;
    return picked;
  }
}

final class _Uploads implements AvatarUploadGateway {
  _Uploads({this.failure});

  @override
  AvatarUploadMode get mode => AvatarUploadMode.preview;
  final AvatarUploadFailureKind? failure;
  Uint8List? sent;
  String? contentType;

  @override
  Future<UploadedAvatar> upload({
    required Uint8List bytes,
    required String contentType,
  }) async {
    sent = bytes;
    this.contentType = contentType;
    final kind = failure;
    if (kind != null) throw AvatarUploadException(kind);
    return const UploadedAvatar(
      mediaId: _mediaId,
      avatarRef: 'avatar:media/$_mediaId',
      width: 512,
      height: 512,
    );
  }
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required ValueChanged<String?> onChanged,
  AvatarImagePicker? picker,
  AvatarUploadGateway? uploads,
  String? avatarRef,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        avatarImagePickerProvider.overrideWithValue(
          picker ?? const UnavailableAvatarImagePicker(),
        ),
        avatarUploadGatewayProvider.overrideWithValue(
          uploads ?? const UnavailableAvatarUploadGateway(),
        ),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: Scaffold(
          body: LoopMediaScope(
            resolver: const _Resolver(),
            child: Center(
              child: LoopAvatarEditor(
                avatarRef: avatarRef,
                alias: 'Voyager',
                enabled: true,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    debugAvatarCropOverride = null;
    debugLoopRemoteAvatarImageProvider = null;
  });

  group('media references (S107 §1)', () {
    test('avatar:media and logo:media name a media id; presets do not', () {
      expect(loopMediaIdOf('avatar:media/$_mediaId'), _mediaId);
      expect(loopMediaIdOf('logo:media/$_mediaId'), _mediaId);
      expect(loopMediaIdOf('avatar:preset/people-01'), isNull);
      expect(loopMediaIdOf('avatar:preset/monogram'), isNull);
      expect(loopMediaIdOf('avatar:media/not-a-uuid'), isNull);
      expect(loopMediaIdOf(null), isNull);
    });

    test('the backend resolver builds /v2/media/{id}.webp on its origin', () {
      final resolver = LoopV2MediaUrlResolver(Uri.parse('https://api.test'));
      expect(
        resolver.urlFor(_mediaId),
        'https://api.test/v2/media/$_mediaId.webp',
      );
      expect(resolver.urlFor('../etc/passwd'), isNull);
      expect(const NoLoopMediaUrlResolver().urlFor(_mediaId), isNull);
    });

    test('an uploaded avatar is submittable; a V1 value still is not', () {
      expect(isProfilePresetAvatarRef('avatar:media/$_mediaId'), isTrue);
      expect(isProfilePresetAvatarRef('avatar:preset/people-12'), isTrue);
      expect(isProfilePresetAvatarRef('avatar:legacy/upload-9f2c'), isFalse);
      expect(profileSubmittableAvatarRef('avatar:legacy/upload-9f2c'), isNull);
    });

    test('a community logo may be an uploaded picture', () {
      final pattern = LoopV2ProjectionCodec.communityLogoPattern;
      expect(pattern.hasMatch('logo:media/$_mediaId'), isTrue);
      expect(pattern.hasMatch('avatar:preset/community-03'), isTrue);
      expect(pattern.hasMatch('avatar:media/$_mediaId'), isFalse);
      expect(pattern.hasMatch('https://example.com/logo.png'), isFalse);
    });
  });

  group('rendering', () {
    testWidgets('an uploaded avatar draws the picture over its monogram', (
      tester,
    ) async {
      String? asked;
      debugLoopRemoteAvatarImageProvider = (url) {
        asked = url;
        return MemoryImage(Uint8List(0));
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: LoopMediaScope(
            resolver: const _Resolver(),
            child: const Center(
              child: LoopProfileAvatar(
                avatarRef: 'avatar:media/$_mediaId',
                alias: 'Voyager',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(LoopRemoteAvatar), findsOneWidget);
      expect(asked, 'https://api.test/v2/media/$_mediaId.webp');
      // The bytes never decode here, so the monogram stays in the slot.
      expect(
        find.byKey(const ValueKey<String>('loop-profile-avatar-monogram')),
        findsOneWidget,
      );
    });

    testWidgets('without a backend the same reference is the monogram', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Center(
            child: LoopProfileAvatar(
              avatarRef: 'avatar:media/$_mediaId',
              alias: 'Voyager',
            ),
          ),
        ),
      );
      expect(find.byType(LoopRemoteAvatar), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('loop-profile-avatar-monogram')),
        findsOneWidget,
      );
    });

    testWidgets('a legacy preset avatar still draws its illustration', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: LoopMediaScope(
            resolver: const _Resolver(),
            child: const Center(
              child: LoopProfileAvatar(
                avatarRef: 'avatar:preset/people-03',
                alias: 'Voyager',
              ),
            ),
          ),
        ),
      );
      expect(find.byType(LoopRemoteAvatar), findsNothing);
      expect(
        find.byKey(
          const ValueKey<String>('loop-profile-avatar-avatar:preset/people-03'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('an uploaded community logo draws over its tile', (
      tester,
    ) async {
      debugLoopRemoteAvatarImageProvider = (url) => MemoryImage(Uint8List(0));
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: LoopMediaScope(
            resolver: const _Resolver(),
            child: const Center(
              child: CommunityLogo(
                identity: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                name: 'Frog',
                logoRef: 'logo:media/$_mediaId',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey<String>('community-logo-media-logo:media/$_mediaId'),
        ),
        findsOneWidget,
      );
    });
  });

  group('POST /v2/media/avatars codec', () {
    test('reads the contract example', () {
      final uploaded = LoopV2AvatarUploadCodec.decode(_uploadWire());
      expect(uploaded.mediaId, _mediaId);
      expect(uploaded.avatarRef, 'avatar:media/$_mediaId');
      expect(uploaded.width, 512);
    });

    test('refuses an extra key, a missing version and a mismatched ref', () {
      expect(
        () => LoopV2AvatarUploadCodec.decode(_uploadWire()..['sha256'] = 'x'),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        () => LoopV2AvatarUploadCodec.decode(
          _uploadWire()..remove('contractVersion'),
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        () => LoopV2AvatarUploadCodec.decode(
          _uploadWire()..['ref'] = 'avatar:media/$_mediaId-x',
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        () => LoopV2AvatarUploadCodec.decode(
          _uploadWire()..['url'] = 'https://elsewhere.test/a.webp',
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('404 and 503 are unavailable, 429 is the rate limit', () {
      AvatarUploadFailureKind kind(int status, [String? code]) =>
          avatarUploadFailureKind(
            LoopBackendFailure(
              LoopBackendFailureKind.invalidPayload,
              statusCode: status,
              code: code,
            ),
          );
      expect(kind(404), AvatarUploadFailureKind.unavailable);
      expect(
        kind(503, 'CAPABILITY_UNAVAILABLE'),
        AvatarUploadFailureKind.unavailable,
      );
      expect(kind(429, 'RATE_LIMITED'), AvatarUploadFailureKind.rateLimited);
      expect(kind(413), AvatarUploadFailureKind.rejected);
      expect(kind(415), AvatarUploadFailureKind.rejected);
      expect(
        avatarUploadFailureKind(
          const LoopBackendFailure(LoopBackendFailureKind.connection),
        ),
        AvatarUploadFailureKind.offline,
      );
    });

    test('a route the server does not mount answers unavailable', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = _StatusAdapter(404);
      await expectLater(
        DioLoopV2AvatarUploadApi(dio).upload(
          accessToken: 'token',
          clientVersion: '1.0.0',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          contentType: 'image/png',
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            avatarUploadFailureKind,
            'kind',
            AvatarUploadFailureKind.unavailable,
          ),
        ),
      );
    });

    test('a file the server would refuse never leaves the device', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = _StatusAdapter(201);
      await expectLater(
        DioLoopV2AvatarUploadApi(dio).upload(
          accessToken: 'token',
          clientVersion: '1.0.0',
          bytes: Uint8List.fromList(<int>[1]),
          contentType: 'image/gif',
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });
  });

  group('square crop', () {
    test('the initial square is the centre of the picture', () {
      const image = Size(2000, 1000);
      final transform = avatarCropInitialTransform(viewport: 300, image: image);
      final rect = avatarCropRect(
        viewport: 300,
        transform: transform,
        image: image,
      );
      expect(rect.left, closeTo(500, 0.01));
      expect(rect.top, closeTo(0, 0.01));
      expect(rect.width, closeTo(1000, 0.01));
      expect(rect.height, closeTo(1000, 0.01));
    });

    test('the cover scale fills the square on the short edge', () {
      expect(
        avatarCropCoverScale(viewport: 300, image: const Size(600, 1200)),
        0.5,
      );
    });
  });

  group('LoopAvatarEditor', () {
    testWidgets('closed upload: disabled button and one line saying why', (
      tester,
    ) async {
      await _pumpEditor(tester, onChanged: (_) {});
      expect(
        tester
            .widget<LoopButton>(
              find.byKey(const ValueKey<String>('loop-avatar-upload')),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('头像上传暂未开放，先用默认头像。'), findsOneWidget);
      // The monogram is the default; there is nothing to reset.
      expect(
        find.byKey(const ValueKey<String>('loop-avatar-reset')),
        findsNothing,
      );
    });

    testWidgets('pick, crop and upload hand back the uploaded reference', (
      tester,
    ) async {
      String? changed;
      final uploads = _Uploads();
      debugAvatarCropOverride = (context, bytes) async =>
          Uint8List.fromList(<int>[9, 9, 9]);
      await _pumpEditor(
        tester,
        onChanged: (value) => changed = value,
        picker: _Picker(
          picked: PickedAvatarImage(bytes: Uint8List.fromList(<int>[1])),
        ),
        uploads: uploads,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('loop-avatar-upload')),
      );
      await tester.pumpAndSettle();

      expect(changed, 'avatar:media/$_mediaId');
      expect(uploads.sent, <int>[9, 9, 9]);
      expect(uploads.contentType, 'image/png');
    });

    testWidgets('a closed picker uploads nothing', (tester) async {
      String? changed = 'unchanged';
      final uploads = _Uploads();
      await _pumpEditor(
        tester,
        onChanged: (value) => changed = value,
        picker: _Picker(),
        uploads: uploads,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('loop-avatar-upload')),
      );
      await tester.pumpAndSettle();
      expect(changed, 'unchanged');
      expect(uploads.sent, isNull);
    });

    for (final (kind, copy) in <(AvatarUploadFailureKind, String)>[
      (AvatarUploadFailureKind.rateLimited, '上传太频繁'),
      (AvatarUploadFailureKind.rejected, '这张图片不能用'),
      (AvatarUploadFailureKind.offline, '网络未连接'),
      (AvatarUploadFailureKind.unavailable, '头像上传暂不可用'),
    ]) {
      testWidgets('a ${kind.name} upload says so and changes nothing', (
        tester,
      ) async {
        String? changed = 'unchanged';
        debugAvatarCropOverride = (context, bytes) async =>
            Uint8List.fromList(<int>[9]);
        await _pumpEditor(
          tester,
          onChanged: (value) => changed = value,
          picker: _Picker(
            picked: PickedAvatarImage(bytes: Uint8List.fromList(<int>[1])),
          ),
          uploads: _Uploads(failure: kind),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('loop-avatar-upload')),
        );
        await tester.pumpAndSettle();
        expect(changed, 'unchanged');
        expect(find.textContaining(copy), findsOneWidget);
      });
    }

    testWidgets('an uploaded avatar can go back to the default', (
      tester,
    ) async {
      String? changed = 'unchanged';
      await _pumpEditor(
        tester,
        avatarRef: 'avatar:media/$_mediaId',
        onChanged: (value) => changed = value,
      );
      await tester.tap(find.byKey(const ValueKey<String>('loop-avatar-reset')));
      await tester.pumpAndSettle();
      expect(changed, isNull);
    });
  });
}

final class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);

  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"message":"Route not found"}',
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}

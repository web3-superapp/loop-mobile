import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_gateway.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_models.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'loop_ground_probe.dart';

/// A 1 × 1 transparent PNG: a real picture the engine can decode.
final Uint8List s332Png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

BetaFeedbackPickedImage s332Picked() =>
    BetaFeedbackPickedImage(bytes: s332Png, contentType: 'image/png');

const s332Environment = BetaFeedbackEnvironment(
  appVersion: '1.0.0',
  build: '57',
  platform: 'ios',
  osVersion: 'iOS 26.1.0',
  deviceModel: 'iPhone17,1',
);

const s332Origin = BetaFeedbackOrigin(route: '/meme', locale: 'zh-CN');

String s332Uuid(int n) =>
    '00000000-0000-4000-8000-${n.toRadixString(16).padLeft(12, '0')}';

BetaFeedbackItem s332Item(
  int n, {
  BetaFeedbackStatus status = BetaFeedbackStatus.open,
  List<String> images = const <String>[],
}) => BetaFeedbackItem(
  id: s332Uuid(n),
  category: BetaFeedbackCategory.bug,
  body: '第 $n 条反馈',
  status: status,
  createdAt: DateTime.utc(2026, 11, 2, 6, n),
  images: images,
);

/// A recording port double.
final class FakeBetaFeedbackGateway implements BetaFeedbackGateway {
  FakeBetaFeedbackGateway({this.mode = LoopChainGatewayMode.production});

  @override
  final LoopChainGatewayMode mode;

  /// `upload:<localId>` and `submit` in the order they were asked.
  final List<String> calls = <String>[];
  final List<BetaFeedbackSubmission> submissions = <BetaFeedbackSubmission>[];
  final List<String?> listCursors = <String?>[];

  LoopChainFailureKind? uploadFailure;
  LoopChainFailureKind? submitFailure;
  Completer<void>? submitGate;

  /// Answers to `listMine`, consumed in order; the last one repeats.
  List<Future<BetaFeedbackPage> Function()> pages =
      <Future<BetaFeedbackPage> Function()>[];

  int _media = 0;

  @override
  Future<BetaFeedbackUploadedImage> uploadImage(BetaFeedbackImage image) async {
    calls.add('upload:${image.localId}');
    final failure = uploadFailure;
    if (failure != null) throw LoopChainException(failure);
    final mediaId = s332Uuid(0x100 + _media++);
    return BetaFeedbackUploadedImage(
      mediaId: mediaId,
      url: 'https://api.example/v2/media/$mediaId.webp',
    );
  }

  @override
  Future<BetaFeedbackReceipt> submit(BetaFeedbackSubmission submission) async {
    calls.add('submit');
    submissions.add(submission);
    final gate = submitGate;
    if (gate != null) await gate.future;
    final failure = submitFailure;
    if (failure != null) throw LoopChainException(failure);
    return BetaFeedbackReceipt(
      id: s332Uuid(0x200),
      status: BetaFeedbackStatus.open,
      createdAt: DateTime.utc(2026, 11, 2),
    );
  }

  @override
  Future<BetaFeedbackPage> listMine({String? cursor}) {
    listCursors.add(cursor);
    if (pages.isEmpty) {
      return Future<BetaFeedbackPage>.value(BetaFeedbackPage(items: const []));
    }
    final answer = pages.length == 1 ? pages.first : pages.removeAt(0);
    return answer();
  }
}

final class FakeBetaFeedbackPicker implements BetaFeedbackImagePicker {
  List<BetaFeedbackPickedImage> library = <BetaFeedbackPickedImage>[];
  BetaFeedbackPickedImage? photo;
  BetaFeedbackPickFailure? failure;
  final List<int> limits = <int>[];

  @override
  Future<List<BetaFeedbackPickedImage>> pickFromLibrary({
    required int limit,
  }) async {
    limits.add(limit);
    final kind = failure;
    if (kind != null) throw BetaFeedbackPickException(kind);
    return library;
  }

  @override
  Future<BetaFeedbackPickedImage?> takePhoto() async {
    final kind = failure;
    if (kind != null) throw BetaFeedbackPickException(kind);
    return photo;
  }
}

final class FixedBetaFeedbackEnvironment
    implements BetaFeedbackEnvironmentSource {
  const FixedBetaFeedbackEnvironment([this.value = s332Environment]);

  final BetaFeedbackEnvironment value;

  @override
  Future<BetaFeedbackEnvironment> read() async => value;
}

Future<void> pumpS332Page(
  WidgetTester tester,
  Widget page, {
  required BetaFeedbackGateway gateway,
  BetaFeedbackImagePicker? picker,
  BetaFeedbackEnvironmentSource environment =
      const FixedBetaFeedbackEnvironment(),
  List<Override> overrides = const <Override>[],
  Size size = const Size(390, 1600),
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  loopArmGroundProbe(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        betaFeedbackGatewayProvider.overrideWithValue(gateway),
        if (picker != null)
          betaFeedbackImagePickerProvider.overrideWithValue(picker),
        betaFeedbackEnvironmentSourceProvider.overrideWithValue(environment),
        ...overrides,
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => LoopToastHost(child: child!),
        home: page,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

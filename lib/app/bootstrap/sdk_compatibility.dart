import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:privy_flutter/privy_flutter.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_chat_persistence/stream_chat_persistence.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

/// Direct SDK pins exercised by the dependency and native build gates.
const directSdkVersions = <String, String>{
  'firebase_core': '4.13.0',
  'firebase_messaging': '16.5.0',
  'privy_flutter': '0.10.1',
  'stream_chat_flutter': '10.3.0',
  'stream_chat_persistence': '10.3.0',
  'stream_video_flutter': '1.4.3',
};

/// Type references make the analyzer and compiler check every direct SDK API.
const phaseZeroSdkSurface = <Type>[
  FirebaseApp,
  FirebaseMessaging,
  Privy,
  StreamChatClient,
  StreamChatPersistenceClient,
  StreamVideo,
];

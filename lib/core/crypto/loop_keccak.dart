/// Keccak-256 and the EIP-55 address checksum (decision 0113).
///
/// WHY first-party, like `loop_qr_code.dart`: the scanner must refuse a
/// mixed-case address whose checksum is wrong — one mistyped character in a
/// payee is a fund-loss surface — and the only Keccak in the lockfile is a
/// transitive dependency of another SDK. Keccak-f[1600] is a fixed, fully
/// specified permutation; ~80 lines here cost less than a new direct pin.
///
/// The original Keccak padding (`0x01 … 0x80`) is used, not SHA-3's `0x06`:
/// Ethereum hashes with pre-standard Keccak. Lanes are 64-bit Dart integers,
/// which is exact on the Dart VM and AOT targets the App ships on.
library;

import 'dart:convert';
import 'dart:typed_data';

const List<int> _roundConstants = <int>[
  0x0000000000000001,
  0x0000000000008082,
  0x800000000000808A,
  0x8000000080008000,
  0x000000000000808B,
  0x0000000080000001,
  0x8000000080008081,
  0x8000000000008009,
  0x000000000000008A,
  0x0000000000000088,
  0x0000000080008009,
  0x000000008000000A,
  0x000000008000808B,
  0x800000000000008B,
  0x8000000000008089,
  0x8000000000008003,
  0x8000000000008002,
  0x8000000000000080,
  0x000000000000800A,
  0x800000008000000A,
  0x8000000080008081,
  0x8000000000008080,
  0x0000000080000001,
  0x8000000080008008,
];

const List<int> _rotations = <int>[
  1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14, //
  27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44,
];

const List<int> _piLanes = <int>[
  10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4, //
  15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1,
];

int _rotl(int value, int shift) => (value << shift) | (value >>> (64 - shift));

void _permute(List<int> state) {
  final columns = List<int>.filled(5, 0);
  for (var round = 0; round < 24; round += 1) {
    for (var i = 0; i < 5; i += 1) {
      columns[i] =
          state[i] ^
          state[i + 5] ^
          state[i + 10] ^
          state[i + 15] ^
          state[i + 20];
    }
    for (var i = 0; i < 5; i += 1) {
      final t = columns[(i + 4) % 5] ^ _rotl(columns[(i + 1) % 5], 1);
      for (var j = 0; j < 25; j += 5) {
        state[j + i] ^= t;
      }
    }
    var carry = state[1];
    for (var i = 0; i < 24; i += 1) {
      final lane = _piLanes[i];
      final next = state[lane];
      state[lane] = _rotl(carry, _rotations[i]);
      carry = next;
    }
    for (var j = 0; j < 25; j += 5) {
      for (var i = 0; i < 5; i += 1) {
        columns[i] = state[j + i];
      }
      for (var i = 0; i < 5; i += 1) {
        state[j + i] ^= (~columns[(i + 1) % 5]) & columns[(i + 2) % 5];
      }
    }
    state[0] ^= _roundConstants[round];
  }
}

/// Keccak-256 of [input] (32 bytes).
Uint8List loopKeccak256(List<int> input) {
  const rate = 136;
  final padded = Uint8List(((input.length ~/ rate) + 1) * rate)
    ..setRange(0, input.length, input);
  padded[input.length] ^= 0x01;
  padded[padded.length - 1] ^= 0x80;
  final state = List<int>.filled(25, 0);
  final view = ByteData.sublistView(padded);
  for (var offset = 0; offset < padded.length; offset += rate) {
    for (var lane = 0; lane < rate ~/ 8; lane += 1) {
      state[lane] ^= view.getUint64(offset + lane * 8, Endian.little);
    }
    _permute(state);
  }
  final out = ByteData(32);
  for (var lane = 0; lane < 4; lane += 1) {
    out.setUint64(lane * 8, state[lane], Endian.little);
  }
  return out.buffer.asUint8List();
}

final RegExp _hexAddress = RegExp(r'^0x[0-9a-fA-F]{40}$');

/// The EIP-55 checksum form of [address], or null when it is not a 20-byte
/// hex address.
String? loopEip55Checksum(String address) {
  if (!_hexAddress.hasMatch(address)) return null;
  final lower = address.substring(2).toLowerCase();
  final hash = loopKeccak256(ascii.encode(lower));
  final buffer = StringBuffer('0x');
  for (var i = 0; i < 40; i += 1) {
    final char = lower[i];
    final nibble = (hash[i ~/ 2] >> (i.isEven ? 4 : 0)) & 0x0f;
    buffer.write(nibble >= 8 ? char.toUpperCase() : char);
  }
  return buffer.toString();
}

/// Whether [address] is a 20-byte hex address whose letter case is either
/// uniform (no checksum claimed) or exactly its EIP-55 checksum.
bool loopIsAcceptableHexAddress(String address) {
  if (!_hexAddress.hasMatch(address)) return false;
  final body = address.substring(2);
  if (body == body.toLowerCase() || body == body.toUpperCase()) return true;
  return loopEip55Checksum(address) == address;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/bootstrap/sdk_compatibility.dart';

void main() {
  test('direct provider SDK surface remains locked and analyzable', () {
    expect(directSdkVersions, hasLength(6));
    expect(directSdkVersions['privy_flutter'], '0.10.1');
    expect(directSdkVersions['stream_chat_flutter'], '10.3.0');
    expect(directSdkVersions['stream_video_flutter'], '1.4.3');
    expect(phaseZeroSdkSurface, hasLength(directSdkVersions.length));
  });
}

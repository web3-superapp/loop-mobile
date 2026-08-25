import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/features/perp/private/perp_private_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_perp_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        perpPrivateGatewayProvider.overrideWith((ref) {
          return ref.watch(loopPerpSessionProvider) ??
              const UnavailablePerpPrivateGateway();
        }),
      ],
      child: const LoopApp(),
    ),
  );
}

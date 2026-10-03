import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// Collect and confirm an application in place, retaining the reviewed
/// backend command. A session change retires this form's completion.
Future<void> openCommunityApplication(
  BuildContext context,
  WidgetRef ref,
) async {
  final gateway = ref.read(communityGatewayProvider);
  final owner = ref.read(loopAccountScopeProvider);
  bool available() => !communityCapabilityBlocks(
    gateway.mode,
    ref.read(loopCapabilityProvider(LoopV2CapabilityId.community)),
  );
  if (!available()) {
    LoopToast.show(context, message: '社区当前不可用', kind: LoopToastKind.warn);
    return;
  }
  bool current() =>
      context.mounted &&
      identical(gateway, ref.read(communityGatewayProvider)) &&
      owner == ref.read(loopAccountScopeProvider) &&
      available();
  final application = await showCommunityApplySheet(context);
  if (application == null || !context.mounted || !current()) return;
  final confirmed = await confirmCommunityAction(
    context,
    title: '提交社区申请？',
    body: '提交后社区状态为「审核中」，你是所有者。短链接一旦被接受就不能再改。',
    confirmLabel: '提交',
    sheetKey: 'community-apply-confirm-sheet',
  );
  if (!confirmed || !context.mounted || !current()) return;
  final outcome = await ref
      .read(communityApplicationControllerProvider.notifier)
      .submit(application);
  if (!context.mounted || !current()) return;
  final detail = outcome.detail;
  if (detail == null) {
    LoopToast.show(
      context,
      message: communityApplyFailureReason(outcome.failureKind),
      kind: LoopToastKind.err,
    );
    return;
  }
  ref.invalidate(communityHomeControllerProvider);
  await showCommunityApplicationSubmittedSheet(
    context,
    communityName: detail.community.name,
  );
  if (!context.mounted || !current()) return;
  unawaited(
    context.push<void>(
      '/community/profile?id=${Uri.encodeQueryComponent(detail.community.communityId)}',
    ),
  );
}

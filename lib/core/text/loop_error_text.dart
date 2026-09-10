import 'package:flutter/foundation.dart';

/// zh-CN copy for the frozen V2 error catalog (loop-api decision 0029,
/// extended to 30 codes by decision 0030's two alias codes and decision
/// 0031's `PROFILE_ACTIVATION_REQUIRED` and `RESOURCE_CONFLICT`).
///
/// The wire contract is `code` first; `userMessageKey` is the backend's
/// localisation key (`errors.<family>.<name>`, `errors.internal` keeps its
/// two-segment form) and is recorded here only so the two sides can be
/// diffed. Never branch on the key; branch on [LoopErrorCopy.code].
@immutable
final class LoopErrorCopy {
  const LoopErrorCopy({
    required this.code,
    required this.userMessageKey,
    required this.title,
    required this.message,
    required this.retryable,
  });

  final String code;
  final String userMessageKey;
  final String title;
  final String message;
  final bool retryable;
}

abstract final class LoopErrorText {
  /// Shown when the code is absent, unknown or the envelope was invalid.
  static const LoopErrorCopy unknown = LoopErrorCopy(
    code: 'UNKNOWN',
    userMessageKey: 'errors.internal',
    title: '暂时无法完成',
    message: '服务没有返回可识别的结果。请稍后重试；如果已经提交过资金动作，请先查看最新状态。',
    retryable: false,
  );

  static const List<LoopErrorCopy> catalog = <LoopErrorCopy>[
    LoopErrorCopy(
      code: 'ACCOUNT_BOOTSTRAP_REQUIRED',
      userMessageKey: 'errors.account.bootstrapRequired',
      title: '账号尚未初始化',
      message: '需要先完成 LOOP 账号引导才能继续。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'ALIAS_BLOCKED',
      userMessageKey: 'errors.alias.blocked',
      title: '这个名称不可用',
      message: '该名称在当前的运营名单内，请换一个再试。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'ALIAS_RESERVED',
      userMessageKey: 'errors.alias.reserved',
      title: '这个名称已被保留',
      message: '该名称属于 LOOP 保留词（如官方、支持、管理），请换一个再试。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'AUTH_INVALID',
      userMessageKey: 'errors.auth.invalid',
      title: '登录凭证无效',
      message: '登录状态已失效，请重新登录。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'AUTH_REQUIRED',
      userMessageKey: 'errors.auth.required',
      title: '需要登录',
      message: '此操作需要已登录的账号。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'AUTH_STEP_UP_REQUIRED',
      userMessageKey: 'errors.auth.stepUpRequired',
      title: '需要更高等级的验证',
      message: '当前登录有效，但此操作需要额外的身份验证。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'CAPABILITY_UNAVAILABLE',
      userMessageKey: 'errors.capability.unavailable',
      title: '功能暂不可用',
      message: '这个功能暂时不可用，稍后再试。',
      retryable: true,
    ),
    LoopErrorCopy(
      code: 'CHAIN_MISMATCH',
      userMessageKey: 'errors.chain.mismatch',
      title: '链不匹配',
      message: '请求的网络与资产或钱包所在链不一致。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'DATA_STALE',
      userMessageKey: 'errors.data.stale',
      title: '数据已过期',
      message: '页面数据已不是最新，请刷新后再操作。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'IDEMPOTENCY_CONFLICT',
      userMessageKey: 'errors.idempotency.conflict',
      title: '重复请求冲突',
      message: '同一操作已被提交过且内容不同，请检查最新状态后再试。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'INDEXING_DELAYED',
      userMessageKey: 'errors.indexing.delayed',
      title: '链上数据延迟',
      message: '索引尚未追上最新区块，数据可能滞后，稍后可以再试。',
      retryable: true,
    ),
    LoopErrorCopy(
      code: 'INSUFFICIENT_BALANCE',
      userMessageKey: 'errors.balance.insufficient',
      title: '余额不足',
      message: '可用余额不足以完成此操作（含手续费）。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'INTERNAL_ERROR',
      userMessageKey: 'errors.internal',
      title: '服务内部错误',
      message: '出了点问题，结果未确认。请查看最新状态后再决定是否重试。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'INVALID_REQUEST',
      userMessageKey: 'errors.request.invalid',
      title: '请求无效',
      message: '请求格式不正确，请更新 App 或稍后再试。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'MAINTENANCE',
      userMessageKey: 'errors.service.maintenance',
      title: '系统维护中',
      message: '相关服务正在维护，稍后可以再试。',
      retryable: true,
    ),
    LoopErrorCopy(
      code: 'NOT_FOUND',
      userMessageKey: 'errors.resource.notFound',
      title: '未找到',
      message: '请求的对象不存在或已被移除。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'PERMISSION_DENIED',
      userMessageKey: 'errors.permission.denied',
      title: '没有权限',
      message: '当前账号无权执行此操作。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'POLICY_BLOCKED',
      userMessageKey: 'errors.policy.blocked',
      title: '被策略拦截',
      message: '此操作被当前生效的策略拦截。具体规则由发起该操作的功能说明。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'PROFILE_ACTIVATION_REQUIRED',
      userMessageKey: 'errors.profile.activationRequired',
      title: '需要先激活 LOOP ID',
      message: '社区与社交操作需要已激活的 LOOP ID。完成激活后可以重试。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'PROVIDER_DISCONNECTED',
      userMessageKey: 'errors.provider.disconnected',
      title: '服务提供方未连接',
      message: '所需的外部服务暂时不可用，稍后可以再试。',
      retryable: true,
    ),
    LoopErrorCopy(
      code: 'QUOTE_EXPIRED',
      userMessageKey: 'errors.quote.expired',
      title: '报价已过期',
      message: '价格已变动，请刷新报价后再确认。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'RATE_LIMITED',
      userMessageKey: 'errors.rateLimit.exceeded',
      title: '操作过于频繁',
      message: '请稍等片刻再试。',
      retryable: true,
    ),
    LoopErrorCopy(
      code: 'REGION_BLOCKED',
      userMessageKey: 'errors.region.blocked',
      title: '地区限制',
      message: '此功能在当前地区不可用。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'REQUEST_TIMEOUT',
      userMessageKey: 'errors.request.timeout',
      title: '请求超时',
      message: '服务没有及时响应。超时不代表失败，资金动作请先查看最新状态。',
      retryable: true,
    ),
    LoopErrorCopy(
      code: 'RESOURCE_CONFLICT',
      userMessageKey: 'errors.conflict.resource',
      title: '标识已被占用',
      message: '该标识已经属于另一个对象，请换一个再提交。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'SESSION_NOT_FOUND',
      userMessageKey: 'errors.session.notFound',
      title: '会话不存在',
      message: '设备会话已失效，请重新登录。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'SIMULATION_FAILED',
      userMessageKey: 'errors.simulation.failed',
      title: '模拟失败',
      message: '交易预演没有返回可验证结果，当前不能确认。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'SUBMISSION_UNKNOWN',
      userMessageKey: 'errors.submission.unknown',
      title: '提交结果未知',
      message: '请求可能已被接受。请勿重复提交，等待对账结果。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'VALIDATION_FAILED',
      userMessageKey: 'errors.validation.failed',
      title: '校验未通过',
      message: '输入内容不符合要求，请检查后重试。',
      retryable: false,
    ),
    LoopErrorCopy(
      code: 'VERSION_CONFLICT',
      userMessageKey: 'errors.version.conflict',
      title: '版本冲突',
      message: '数据已被其他设备修改，请重新加载后再保存。',
      retryable: false,
    ),
  ];

  static final Map<String, LoopErrorCopy> _byCode = <String, LoopErrorCopy>{
    for (final copy in catalog) copy.code: copy,
  };

  /// Copy for a backend `code`; unknown or absent codes use [unknown].
  static LoopErrorCopy forCode(String? code) =>
      code == null ? unknown : (_byCode[code] ?? unknown);

  static bool isKnownCode(String code) => _byCode.containsKey(code);
}

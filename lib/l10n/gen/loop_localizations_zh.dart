// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'loop_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class LoopLocalizationsZh extends LoopLocalizations {
  LoopLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get betaFeedback_cameraFailed => '无法打开相机';

  @override
  String get betaFeedback_categoryOther => '其他';

  @override
  String get betaFeedback_categorySuggestion => '建议';

  @override
  String get betaFeedback_copyBootstrapRequired => '账号尚未完成初始化，请稍后再试。';

  @override
  String get betaFeedback_copyLoadFailed => '没有读到反馈，请稍后再试。';

  @override
  String get betaFeedback_copyLoadMalformed => '返回的数据不完整。';

  @override
  String get betaFeedback_copyLoadOffline => '网络不可用，没有读到反馈。';

  @override
  String get betaFeedback_copyRateLimited => '提交太频繁，请稍后再试。';

  @override
  String get betaFeedback_copyRegionBlocked => '当前账号不能使用意见反馈。';

  @override
  String get betaFeedback_copySubmissionUnknown => '结果未确认，再次提交不会重复。';

  @override
  String get betaFeedback_copySubmitFailed => '反馈没有提交，请稍后再试。';

  @override
  String get betaFeedback_copySubmitMalformed => '返回的数据不完整，结果未确认。';

  @override
  String get betaFeedback_copySubmitOffline => '网络不可用，反馈没有提交。';

  @override
  String get betaFeedback_copyUnavailable => '反馈服务暂不可用。';

  @override
  String get betaFeedback_copyValidationFailed => '内容或图片不符合要求，请修改后再试。';

  @override
  String get betaFeedback_description => '描述';

  @override
  String get betaFeedback_envDevice => '设备';

  @override
  String get betaFeedback_envPage => '页面';

  @override
  String get betaFeedback_envSystem => '系统';

  @override
  String get betaFeedback_envVersion => '版本';

  @override
  String get betaFeedback_environment => '环境';

  @override
  String get betaFeedback_feedback => '意见反馈';

  @override
  String betaFeedback_imageLimit(Object? maximumImages) {
    return '最多 $maximumImages 张图片';
  }

  @override
  String get betaFeedback_imageUnusable => '有图片无法使用';

  @override
  String get betaFeedback_images => '图片';

  @override
  String get betaFeedback_mineEmpty => '还没有提交过反馈';

  @override
  String get betaFeedback_mineErrorTitle => '没有读到反馈';

  @override
  String get betaFeedback_minePermissionTitle => '没有权限';

  @override
  String get betaFeedback_mineTitle => '我的反馈';

  @override
  String get betaFeedback_mineUnavailableMessage => '现在读不到反馈记录。';

  @override
  String get betaFeedback_mineUnavailableTitle => '意见反馈暂不可用';

  @override
  String get betaFeedback_noCameraAccess => '没有相机权限';

  @override
  String get betaFeedback_noPhotoAccess => '没有相册权限';

  @override
  String get betaFeedback_notSent => '没有提交';

  @override
  String get betaFeedback_photos => '相册';

  @override
  String get betaFeedback_photosFailed => '无法打开相册';

  @override
  String get betaFeedback_removeImage => '删除图片';

  @override
  String get betaFeedback_send => '提交反馈';

  @override
  String get betaFeedback_statusOpen => '待处理';

  @override
  String get betaFeedback_statusResolved => '已解决';

  @override
  String get betaFeedback_statusWontFix => '暂不处理';

  @override
  String get betaFeedback_takePhoto => '拍照';

  @override
  String get betaFeedback_unavailableMessage => '现在无法提交反馈。';

  @override
  String betaFeedback_uploading(Object? images, Object? uploaded) {
    return '上传图片 $uploaded / $images';
  }

  @override
  String get chain_contractBootstrapRequired => '账号尚未完成初始化，请稍后重试。';

  @override
  String get chain_contractCancelled => '请求已被取消，结果未知。请查看最新状态后再决定是否重试。';

  @override
  String get chain_contractChainMismatch =>
      '这条链现在不支持：钱包、行情、兑换与授权都在 BNB Smart Chain 上，Launch 在 LOOP 发布的 Launch 链上。';

  @override
  String get chain_contractDerived => '按成交价折算';

  @override
  String get chain_contractIdempotencyConflict => '同一操作已被提交过且内容不同，请检查最新状态后再试。';

  @override
  String get chain_contractIndexingDelayed => '链上记录还在同步，这里是暂时读不到，不是没有记录。';

  @override
  String get chain_contractInsufficientBalance =>
      '余额不足以覆盖这笔金额、最高网络费或手续费保留，没有提交任何交易。';

  @override
  String get chain_contractInvalidData => '返回的数据不完整，这一页没有采用任何内容。';

  @override
  String get chain_contractLoopCurve => 'LOOP 曲线';

  @override
  String get chain_contractLoopIndexer => 'LOOP 链上索引';

  @override
  String get chain_contractNotFound => '目标不存在、未登记，或对当前账号不可见。';

  @override
  String get chain_contractOffline => '设备已离线，这一页没有读到数据，也没有提交任何操作。';

  @override
  String get chain_contractOutcomeUnknown => '返回的数据不完整，结果未确认。请刷新查看最新状态，不要重复提交。';

  @override
  String get chain_contractPermissionDenied => '当前账号没有执行这个操作的权限。';

  @override
  String get chain_contractPoolSlot0 => '池子推算';

  @override
  String get chain_contractProxied => '以 WBNB 计价';

  @override
  String get chain_contractQuoteExpired => '报价已过期，没有提交任何兑换。请重新报价后再确认。';

  @override
  String get chain_contractRateLimited => '请求过于频繁，请稍等片刻再试。';

  @override
  String get chain_contractReadFailed => '这一页暂时读不到，没有提交任何内容。请稍后重试。';

  @override
  String get chain_contractRegionBlocked =>
      '你所在的地区暂时不支持这个操作，没有发生任何变化。这与账号或资产无关，换一个也不会改变结果。';

  @override
  String get chain_contractSimulationFailed => '这笔交易试算没有通过，不能签名。请返回确认页重新准备一次。';

  @override
  String get chain_contractStale => '数据可能过期';

  @override
  String get chain_contractStepUpCancelled => '已取消，没有发生任何变化。';

  @override
  String get chain_contractStepUpRequired => '这一步需要二次验证，二次验证还没有开放，没有发生任何变化。';

  @override
  String get chain_contractSubmissionUnknown =>
      '这笔操作已经提交过一次且结果未知，已锁定。请只查看最新状态，不要重复提交。';

  @override
  String get chain_contractSwitch => '链上数据暂时读不到。';

  @override
  String get chain_contractSwitch10 => '这次余额没有读到，因此不显示数字。';

  @override
  String get chain_contractSwitch11 => '转账记录暂时读不到。';

  @override
  String get chain_contractSwitch12 => '成交与 K 线暂时读不到。';

  @override
  String get chain_contractSwitch13 => 'BNB 转账记录暂时读不到。';

  @override
  String get chain_contractSwitch14 => '跨链与挖矿领取记录暂时读不到。';

  @override
  String get chain_contractSwitch15 => 'Launch 链的 MEME 记录还没有开始同步，下面只列出转账。';

  @override
  String get chain_contractSwitch16 => 'MEME 记录这次没有读到，下面只列出转账，稍后再看。';

  @override
  String get chain_contractSwitch17 => '这个资产无法与钱包记录核对。';

  @override
  String get chain_contractSwitch18 => '外部钱包无法与钱包记录核对。';

  @override
  String get chain_contractSwitch19 => '余额核对没有成功，链上数字不受影响。';

  @override
  String get chain_contractSwitch2 => '链上数据暂时不可用，稍后再试。';

  @override
  String get chain_contractSwitch20 => '兑换还没有开放，这一页没有买卖入口。';

  @override
  String get chain_contractSwitch21 => '这个资产已经读不到，保留这一行方便你移除。';

  @override
  String get chain_contractSwitch22 => '这个地址不在 LOOP 资产目录里，下面的数据来自行情数据源，不能买卖。';

  @override
  String get chain_contractSwitch23 => '这个资产已被屏蔽。';

  @override
  String get chain_contractSwitch24 => '行情暂时不可用，稍后再试。';

  @override
  String get chain_contractSwitch25 => '暂时读不到价格，不显示估值。';

  @override
  String get chain_contractSwitch26 => 'DexScreener 数据当前已关闭。';

  @override
  String get chain_contractSwitch27 => '安全信息与持有人数暂时读不到。';

  @override
  String get chain_contractSwitch28 => '新币发现与相关行情暂时读不到。';

  @override
  String get chain_contractSwitch29 => '数据服务限流中，暂时没有新数值。';

  @override
  String get chain_contractSwitch3 => '正在校验链上连接，暂时不显示链上数字。';

  @override
  String get chain_contractSwitch30 => '数据服务拒绝了这次请求，与你的网络无关，稍后再看。';

  @override
  String get chain_contractSwitch31 => '行情数据暂时读不到，这一项没有数值，稍后再看。';

  @override
  String get chain_contractSwitch32 => '行情暂时取不到，与你的网络无关，稍后再看。';

  @override
  String get chain_contractSwitch33 => '返回的数据不完整，已整体丢弃。';

  @override
  String get chain_contractSwitch34 => '没有找到这个资产的交易对。';

  @override
  String get chain_contractSwitch35 => '数据源没有报告这一项。';

  @override
  String get chain_contractSwitch36 => '原生 BNB 没有合约地址，这一项不适用。';

  @override
  String get chain_contractSwitch37 => '这个资产还没有 PancakeSwap V3 交易池。';

  @override
  String get chain_contractSwitch38 => '所选区间内没有成交。';

  @override
  String get chain_contractSwitch39 => '这一行余额读不到，无法估值。';

  @override
  String get chain_contractSwitch4 => '链上节点暂时连不上，与你的网络无关，稍后再看。';

  @override
  String get chain_contractSwitch40 => '未报告';

  @override
  String get chain_contractSwitch5 => '连接到的不是 BNB Smart Chain，这一页不可用。';

  @override
  String get chain_contractSwitch6 => 'Launch 链上数据暂时读不到。';

  @override
  String get chain_contractSwitch7 => '正在校验 Launch 链连接，暂时不显示链上数字。';

  @override
  String get chain_contractSwitch8 => 'Launch 链节点暂时连不上，与你的网络无关，稍后再看。';

  @override
  String get chain_contractSwitch9 => '连接到的不是 Launch 链，Launch 相关内容不可用。';

  @override
  String get chain_contractText => '持有人分布暂时读不到。';

  @override
  String get chain_contractText10 => '资金操作暂时不可用，稍后再试。';

  @override
  String get chain_contractText11 => '链上操作当前已关闭，现在只能查看。';

  @override
  String get chain_contractText12 => '兑换暂时不可用，稍后再试。';

  @override
  String get chain_contractText13 => '兑换还在验证中，可以查看报价，但不能执行。';

  @override
  String get chain_contractText14 => '兑换暂时无法试算，因此不能执行。';

  @override
  String get chain_contractText15 => '暂时无法核对这个地址是否在已知诈骗名单里。这不代表它安全。';

  @override
  String get chain_contractText16 => '授权风险信息暂时读不到。';

  @override
  String get chain_contractText17 => '这一行的授权额度读不到，因此不显示数字。';

  @override
  String get chain_contractText18 => '这笔交易试算时被链上拒绝，不能签名。';

  @override
  String get chain_contractText19 => '试算没有返回可核对的结果，不能签名。';

  @override
  String get chain_contractText2 => '聪明钱追踪还没有开放。';

  @override
  String get chain_contractText20 => '无法估算网络费，因此不能构造可签名的交易。';

  @override
  String get chain_contractText21 => '这次操作已过期，请重新准备一次。';

  @override
  String get chain_contractText22 => '这个钱包已经准备了新的操作，这一笔被取代，没有提交。';

  @override
  String get chain_contractText23 => '这次操作已由你取消，没有提交任何交易。';

  @override
  String get chain_contractText24 => '交易已提交，链上还没有查到，LOOP 会继续核对。';

  @override
  String get chain_contractText25 => '提交的交易与准备好的内容不一致，已拒绝。';

  @override
  String get chain_contractText26 => '交易已上链但执行失败，网络费已消耗。';

  @override
  String get chain_contractText27 => '交易回执暂时读不到，结果待确认。';

  @override
  String get chain_contractText28 => '钱包拒绝了这次兑换，没有提交到链上。';

  @override
  String get chain_contractText29 => '这次操作的结果还不确定，请等待确认，不要重复提交。';

  @override
  String get chain_contractText3 => '推送还没有开放，提醒只出现在应用内的通知列表里。';

  @override
  String get chain_contractText30 => '价格影响超过 5%，已阻止这笔兑换。';

  @override
  String get chain_contractText31 => '无法计算这笔兑换的价格影响，已阻止。';

  @override
  String get chain_contractText32 => '这笔操作暂时无法进入钱包签名。';

  @override
  String get chain_contractText33 => '这条链不支持这个操作：发送、授权、回收与兑换只能在主网进行。';

  @override
  String get chain_contractText34 => '安全设置还没有开放。';

  @override
  String get chain_contractText35 => '安全设置暂时不可用，稍后再试。';

  @override
  String get chain_contractText36 => '账号设置还没有开放。';

  @override
  String get chain_contractText37 => '设置暂时不可用，稍后再试。';

  @override
  String get chain_contractText38 => '客服还没有开放。';

  @override
  String get chain_contractText39 => '客服暂时不可用，稍后再试。';

  @override
  String get chain_contractText4 => '还没有社区绑定这个资产。';

  @override
  String get chain_contractText40 => '设备列表暂时读不到。';

  @override
  String get chain_contractText41 => '最近的安全事件暂时读不到。';

  @override
  String get chain_contractText42 => '需要二次验证，二次验证还没有开放。';

  @override
  String get chain_contractText43 => '工单暂时不能上传附件。';

  @override
  String get chain_contractText44 => '法律文件链接暂时打不开。';

  @override
  String get chain_contractText45 => '新版协议还没有生效。';

  @override
  String get chain_contractText46 => '版本与构建号来自这台设备。';

  @override
  String get chain_contractText47 => '还没有选择钱包。';

  @override
  String get chain_contractText48 => '授权列表暂时读不到。';

  @override
  String get chain_contractText49 => '授权列表还没有开放。';

  @override
  String get chain_contractText5 => '按资产拆分的挖矿数字暂未开放；算力与明细在挖矿页。';

  @override
  String get chain_contractText50 => '链上记录还在同步，授权列表暂时读不到。';

  @override
  String get chain_contractText51 => '这个功能当前不可用。';

  @override
  String get chain_contractText52 => '多因素验证还没有开放。';

  @override
  String get chain_contractText53 => 'Passkey 还没有开放。';

  @override
  String get chain_contractText54 => '恢复密码还没有开放。';

  @override
  String get chain_contractText55 => '自动恢复还没有开放。';

  @override
  String get chain_contractText56 => '社交恢复还没有开放。';

  @override
  String get chain_contractText57 => '私钥导出还没有开放。';

  @override
  String get chain_contractText58 => '扫码支付还没有开放，这里不会打开相机或生成收款码。';

  @override
  String get chain_contractText59 => '跨链还没有开放，这里不会发起任何跨链操作。';

  @override
  String get chain_contractText6 => '指标与画线工具还没有开放。';

  @override
  String get chain_contractText60 => 'DApp 连接与签名还没有开放，这一页只做本地检查。';

  @override
  String get chain_contractText61 => 'Community AI 还没有开放。';

  @override
  String get chain_contractText7 => '净值走势与 24h 涨跌暂时读不到。';

  @override
  String get chain_contractText8 => '自定义网络还没有开放，这里只显示 LOOP 支持的网络。';

  @override
  String get chain_contractText9 => '安全中心与 DApp 状态还没有开放。';

  @override
  String get chain_contractTimedOut => 'LOOP 响应超时，这一页没有读到数据，也没有提交任何操作。';

  @override
  String get chain_contractUnavailable => '暂时读不到链上数据，请稍后再试。';

  @override
  String get chain_contractUnexpected => '操作没有完成，请稍后再试。';

  @override
  String get chain_contractValidationFailed =>
      '输入内容不符合要求（例如资产未登记或阈值非法），请修改后重试。';

  @override
  String get chain_contractVersionConflict =>
      '数据已被其他设备修改。请重新加载后再提交，本次没有覆盖任何内容。';

  @override
  String get chain_modelsBlocked => '已屏蔽';

  @override
  String get chain_modelsErc20Transfer => 'ERC-20 转账索引';

  @override
  String get chain_modelsLoopProvenanceLabel => '来源未知';

  @override
  String chain_modelsLoopProvenanceLabel2(
    Object? observedAtLabel,
    Object? sourceLabel,
  ) {
    return '$sourceLabel · 观察于 $observedAtLabel';
  }

  @override
  String get chain_modelsMismatched => '不一致';

  @override
  String get chain_modelsPending => '待核验';

  @override
  String get chain_modelsPoolEvent => '池事件索引';

  @override
  String chain_modelsS(Object? factSourceLabel) {
    return '来源 $factSourceLabel';
  }

  @override
  String get chain_modelsUnavailable => '暂时读不到';

  @override
  String get chain_modelsUnreachable => '连不上';

  @override
  String get chain_modelsUnregistered => '未登记';

  @override
  String get chain_modelsVerified => '已核验';

  @override
  String get chain_modelsVerified2 => '通过';

  @override
  String chain_widgetsChainPreviewNoticeBody(Object? resource) {
    return '$resource只存在于这次开发预览里，不会写入账号，也不会上传。';
  }

  @override
  String get chain_widgetsLabel => '来源';

  @override
  String get chain_widgetsLoopFactProvenance => '来源未标注';

  @override
  String chain_widgetsLoopFactProvenance2(Object? label, Object? relativeTime) {
    return '$label · 观察于 $relativeTime';
  }

  @override
  String get chain_widgetsLoopOfflineState => '切换钱包';

  @override
  String get chain_widgetsLoopOfflineState2 => '保存自选';

  @override
  String chain_widgetsLoopRelativeTime(Object? inSeconds) {
    return '$inSeconds 秒前';
  }

  @override
  String chain_widgetsLoopRelativeTime2(Object? inMinutes) {
    return '$inMinutes 分钟前';
  }

  @override
  String chain_widgetsLoopRelativeTime3(Object? inHours) {
    return '$inHours 小时前';
  }

  @override
  String chain_widgetsLoopRelativeTime4(Object? inDays) {
    return '$inDays 天前';
  }

  @override
  String chain_widgetsProvenanceFooterSemanticsLabel(
    Object? text,
    Object? title,
  ) {
    return '$text，查看$title';
  }

  @override
  String chain_widgetsRegionBlocked(Object? chainFailureReason) {
    return '$chainFailureReason本页已读到的内容不受影响。';
  }

  @override
  String get chain_widgetsRetryLabel => '稍后重试';

  @override
  String chain_widgetsSemanticsLabel(Object? factProvenance) {
    return '$factProvenance，查看数据来源说明';
  }

  @override
  String chain_widgetsStepUpRequired(Object? chainFailureReason) {
    return '$chainFailureReason请到安全中心查看当前可用的验证方式；本页已读到的内容不受影响。';
  }

  @override
  String chain_widgetsSwitch(Object? chainFailureReason) {
    return '$chainFailureReason这项权限不能在应用里自行调整；可以换一个已获授权的账号或资产，本页已读到的内容不受影响。';
  }

  @override
  String get chain_widgetsTitle => '该内容当前不可用';

  @override
  String get chain_widgetsTitle2 => '这一步需要二次验证';

  @override
  String get chain_widgetsTitle3 => '当前地区不能执行此操作';

  @override
  String get common_about => '说明';

  @override
  String get common_aboutSection => '关于';

  @override
  String get common_actionIncomplete => '操作没有完成。';

  @override
  String get common_actions => '操作';

  @override
  String get common_all => '全部';

  @override
  String get common_amount => '数量';

  @override
  String get common_assets => '资产';

  @override
  String get common_awaitingSignature => '待签名';

  @override
  String get common_back => '返回';

  @override
  String get common_blockList => '屏蔽名单';

  @override
  String get common_bridge => '跨链';

  @override
  String get common_broadcast => '已广播';

  @override
  String get common_buy => '买入';

  @override
  String get common_cancel => '取消';

  @override
  String get common_cancelled => '已取消';

  @override
  String get common_chart => '图表';

  @override
  String get common_chat => '聊天';

  @override
  String get common_claim => '领取';

  @override
  String get common_close => '关闭';

  @override
  String get common_community => '社区';

  @override
  String get common_confirm => '确认';

  @override
  String get common_confirmed => '已确认';

  @override
  String get common_continueAction => '继续';

  @override
  String get common_contract => '合约';

  @override
  String get common_copied => '已复制';

  @override
  String get common_copy => '复制';

  @override
  String get common_dataSource => '数据来源';

  @override
  String get common_dataUnavailable => '数据不可得';

  @override
  String get common_delete => '删除';

  @override
  String get common_demoData => '演示数据';

  @override
  String get common_details => '详情';

  @override
  String get common_devPreview => '开发预览';

  @override
  String get common_directMessage => '私聊';

  @override
  String get common_disconnected => '已断开';

  @override
  String get common_done => '完成';

  @override
  String get common_draft => '草稿';

  @override
  String get common_edit => '编辑';

  @override
  String get common_ended => '已结束';

  @override
  String get common_estimatedReceive => '预计获得';

  @override
  String get common_exit => '退出';

  @override
  String get common_expired => '已过期';

  @override
  String get common_failed => '失败';

  @override
  String get common_feed => '动态';

  @override
  String get common_follow => '关注';

  @override
  String get common_followers => '粉丝';

  @override
  String get common_following => '已关注';

  @override
  String get common_gotIt => '知道了';

  @override
  String get common_graduate => '毕业';

  @override
  String get common_graduated => '已毕业';

  @override
  String get common_groupChat => '群聊';

  @override
  String get common_holders => '持有人';

  @override
  String get common_holdings => '持仓';

  @override
  String get common_inProgress => '进行中';

  @override
  String get common_inReview => '审核中';

  @override
  String get common_itemUnavailable => '这一项暂时读不到。';

  @override
  String get common_joining => '正在加入…';

  @override
  String get common_justNow => '刚刚';

  @override
  String get common_language => '语言';

  @override
  String get common_lastActionIncomplete => '上一次操作没有完成';

  @override
  String get common_launchpad => '发射台';

  @override
  String get common_learnMore => '了解更多';

  @override
  String get common_link => '链接';

  @override
  String get common_linkCopied => '已复制链接';

  @override
  String get common_liquidity => '流动性';

  @override
  String get common_listSeparator => '，';

  @override
  String get common_loading => '读取中';

  @override
  String get common_loadingEllipsis => '加载中…';

  @override
  String get common_market => '行情';

  @override
  String get common_marketCap => '市值';

  @override
  String get common_me => '我';

  @override
  String get common_members => '成员';

  @override
  String get common_messageRequests => '陌生人请求';

  @override
  String get common_minimumReceive => '最少获得';

  @override
  String get common_mining => '挖矿';

  @override
  String get common_more => '更多';

  @override
  String get common_mute => '静音';

  @override
  String get common_muted => '已静音';

  @override
  String get common_name => '名称';

  @override
  String get common_network => '网络';

  @override
  String get common_next => '下一步';

  @override
  String get common_nextPageFailed => '下一页没有读到';

  @override
  String get common_noPermission => '当前账号没有权限';

  @override
  String get common_noTradesYet => '还没有成交';

  @override
  String get common_none => '暂无';

  @override
  String get common_normal => '正常';

  @override
  String get common_notConfigured => '未配置';

  @override
  String get common_notOpenYet => '未开放';

  @override
  String get common_nothingHereYet => '这里还没有内容';

  @override
  String get common_notificationSettings => '通知设置';

  @override
  String get common_notifications => '通知';

  @override
  String get common_ok => '确定';

  @override
  String get common_on => '已开启';

  @override
  String get common_openSecurityCenter => '前往安全中心';

  @override
  String get common_openSettings => '去设置';

  @override
  String get common_paused => '已暂停';

  @override
  String get common_pay => '支付';

  @override
  String get common_pendingConfirmation => '待确认';

  @override
  String get common_power => '算力';

  @override
  String get common_priceAlerts => '价格提醒';

  @override
  String get common_profile => '资料';

  @override
  String get common_receive => '接收';

  @override
  String get common_refresh => '刷新';

  @override
  String get common_rejected => '未通过';

  @override
  String get common_reload => '重新加载';

  @override
  String get common_report => '举报';

  @override
  String get common_retry => '重试';

  @override
  String get common_reverted => '已回滚';

  @override
  String get common_save => '保存';

  @override
  String get common_scan => '扫一扫';

  @override
  String get common_search => '搜索';

  @override
  String get common_security => '安全';

  @override
  String get common_securityCenter => '安全中心';

  @override
  String get common_sell => '卖出';

  @override
  String get common_send => '发送';

  @override
  String get common_settings => '设置';

  @override
  String get common_share => '分享';

  @override
  String get common_sign => '签名';

  @override
  String get common_simulationPassed => '试算通过';

  @override
  String get common_simulationRejected => '试算被拒绝';

  @override
  String get common_simulationResult => '模拟结果';

  @override
  String get common_simulationUnavailable => '试算不可用';

  @override
  String get common_slippageLimit => '滑点上限';

  @override
  String get common_snapshotBlock => '快照区块';

  @override
  String get common_submit => '提交';

  @override
  String get common_submitted => '已提交';

  @override
  String get common_submitting => '提交中';

  @override
  String get common_success => '成功';

  @override
  String get common_swap => '兑换';

  @override
  String get common_today => '今天';

  @override
  String get common_token => '代币';

  @override
  String get common_tokenApprovals => '授权盘点';

  @override
  String get common_totalSupply => '总量';

  @override
  String get common_trade => '交易';

  @override
  String get common_unavailable => '不可用';

  @override
  String get common_unknown => '未知';

  @override
  String get common_unmute => '取消静音';

  @override
  String get common_unread => '未读';

  @override
  String get common_uploading => '上传中…';

  @override
  String get common_user => '用户';

  @override
  String get common_validUntil => '有效期至';

  @override
  String get common_verifying => '验证中…';

  @override
  String get common_voiceRooms => '语音房';

  @override
  String get common_waitingForData => '等待数据';

  @override
  String get common_watchlist => '自选';

  @override
  String launch2Creator_figureWithNote(Object? figure, Object? note) {
    return '$figure（$note）';
  }

  @override
  String get launch2Creator_launch2AwaitingExecutor => '排队中';

  @override
  String get launch2Creator_launch2BootstrapRequired => '账号还在初始化，稍后再试。';

  @override
  String get launch2Creator_launch2Build => '内盘可售';

  @override
  String get launch2Creator_launch2Build10 => '由平台模板固定，不能修改。';

  @override
  String get launch2Creator_launch2Build11 => '平台还没有配置回购收币地址，暂时不能提交。';

  @override
  String get launch2Creator_launch2Build2 => '毕业储备';

  @override
  String get launch2Creator_launch2Build3 => '内盘买卖税';

  @override
  String get launch2Creator_launch2Build4 => '外盘买卖税';

  @override
  String get launch2Creator_launch2Build5 => '外盘买入税';

  @override
  String get launch2Creator_launch2Build6 => '单地址上限';

  @override
  String get launch2Creator_launch2Build7 => '铸造价格';

  @override
  String get launch2Creator_launch2Build8 => '铸造期';

  @override
  String get launch2Creator_launch2Build9 => '由实例决定';

  @override
  String launch2Creator_launch2CapFigure(Object? launch2CurveCapFigure) {
    return '$launch2CurveCapFigure 枚';
  }

  @override
  String get launch2Creator_launch2Claimed => '准备部署';

  @override
  String get launch2Creator_launch2Confirmed => '核验中';

  @override
  String get launch2Creator_launch2CreateBody => '已填写的内容不会保存。';

  @override
  String get launch2Creator_launch2CreateCancelLabel => '继续编辑';

  @override
  String get launch2Creator_launch2CreateConfig => '正在保存配置…';

  @override
  String get launch2Creator_launch2CreateConfirmLabel => '放弃';

  @override
  String get launch2Creator_launch2CreateEmptyMessage => '找不到这个项目';

  @override
  String launch2Creator_launch2CreateFailed(Object? memeFailureText) {
    return '图片没有上传成功：$memeFailureText';
  }

  @override
  String get launch2Creator_launch2CreateFor => 'X（可不填）';

  @override
  String get launch2Creator_launch2CreateFor2 => 'Telegram（可不填）';

  @override
  String get launch2Creator_launch2CreateFor3 => '官网（可不填）';

  @override
  String get launch2Creator_launch2CreateFor4 => 'Discord（可不填）';

  @override
  String get launch2Creator_launch2CreateGroupTitle => '图片资料';

  @override
  String get launch2Creator_launch2CreateGroupTitle2 => '基础信息';

  @override
  String get launch2Creator_launch2CreateHint => '输入项目名称';

  @override
  String get launch2Creator_launch2CreateHint2 => '输入代币代码';

  @override
  String get launch2Creator_launch2CreateHint3 => '介绍一下你的项目';

  @override
  String get launch2Creator_launch2CreateIf => '只支持 https:// 开头的链接';

  @override
  String get launch2Creator_launch2CreateLabel => '重试提交';

  @override
  String get launch2Creator_launch2CreateLabel2 => '提交审核';

  @override
  String get launch2Creator_launch2CreateLabel3 => '代码';

  @override
  String get launch2Creator_launch2CreateLabel4 => '简介（可不填）';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateLinksCommunityHint =>
      '要绑定社区，请由社区群主在社区侧「社区管理 → 绑定代币」里操作。';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateLinksHeading => '外部链接';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateLinksLine =>
      '项目的 X / Telegram / 官网 / Discord，都可不填；审核与用户都会看到。';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateLogoMissing => '头像';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateLogoMissing2 =>
      '发射需要一张方形头像';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateNftMissing => 'NFT 图';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateNftMissing2 =>
      'NFT 图（可不传）';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateNftMissing3 =>
      '发射需要一张 NFT 图';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateRejectionTitle => '审核意见';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateSaleStartLabel =>
      '选择铸造开始时间';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateSaleStartMissingBody =>
      '请先选择铸造开始时间。';

  @override
  String launch2Creator_launch2CreateLaunch2CreateSaleTooEarlyBody(
    Object? leadLabel,
    Object? localTimestampLabel,
  ) {
    return '铸造开始时间太早：平台要求至少提前 $leadLabel，最早 $localTimestampLabel，请重新选择。';
  }

  @override
  String get launch2Creator_launch2CreateLaunch2CreateScreenTitle => '修改资料';

  @override
  String get launch2Creator_launch2CreateLaunch2CreateScreenTitle2 =>
      '发起 v2 发射';

  @override
  String get launch2Creator_launch2CreateLaunch2NameInvisibleMessage =>
      '名称需包含可见字符';

  @override
  String get launch2Creator_launch2CreateLaunch2SaleStartHint =>
      '最早可选时间由平台决定，太早会被退回。';

  @override
  String launch2Creator_launch2CreateLaunch2SaleStartHint2(
    Object? leadLabel,
    Object? localTimestampLabel,
  ) {
    return '平台要求至少提前 $leadLabel开始铸造，最早 $localTimestampLabel。';
  }

  @override
  String get launch2Creator_launch2CreateLaunch2TickerInvisibleMessage =>
      '代码需包含可见字符';

  @override
  String launch2Creator_launch2CreateLeadLabel(Object? minutes) {
    return '$minutes 小时';
  }

  @override
  String launch2Creator_launch2CreateLeadLabel2(Object? minutes) {
    return '$minutes 分钟';
  }

  @override
  String get launch2Creator_launch2CreateLoopButton => '正在提交审核…';

  @override
  String get launch2Creator_launch2CreateLoopLabel => '回购收币地址';

  @override
  String get launch2Creator_launch2CreateLoopLabel2 => '发射模板';

  @override
  String get launch2Creator_launch2CreateLoopSheetHeading => '铸造开始时间';

  @override
  String get launch2Creator_launch2CreateNote => '方形图片，上传前可裁剪';

  @override
  String get launch2Creator_launch2CreateProject => '正在保存资料…';

  @override
  String get launch2Creator_launch2CreateText => '发射';

  @override
  String get launch2Creator_launch2CreateTitle => '放弃发起？';

  @override
  String get launch2Creator_launch2DeploymentAction => '查看项目页';

  @override
  String get launch2Creator_launch2DeploymentAction2 => '重新签名';

  @override
  String launch2Creator_launch2DeploymentBuild(Object? confirmations) {
    return '$confirmations 确认';
  }

  @override
  String launch2Creator_launch2DeploymentBuild2(Object? blockNumber) {
    return '区块 $blockNumber';
  }

  @override
  String get launch2Creator_launch2DeploymentLabel => '部署交易';

  @override
  String get launch2Creator_launch2DeploymentLabel2 => '激活交易';

  @override
  String get launch2Creator_launch2DeploymentLabel3 => '复制 BscScan 链接';

  @override
  String get launch2Creator_launch2DeploymentLaunch2DeploymentActivatedBody =>
      '已激活，项目页生成中…';

  @override
  String get launch2Creator_launch2DeploymentLaunch2DeploymentActivatedBody2 =>
      '已激活，你是这个项目的项目方。';

  @override
  String get launch2Creator_launch2DeploymentLaunch2DeploymentCancelledBody =>
      '这次部署已取消。';

  @override
  String get launch2Creator_launch2DeploymentLaunch2DeploymentMissingMessage =>
      '链接里没有有效的项目或任务编号。';

  @override
  String get launch2Creator_launch2DeploymentLaunch2DeploymentMissingTitle =>
      '找不到这次部署';

  @override
  String get launch2Creator_launch2DeploymentLaunch2DeploymentQueuedBody =>
      '已验签登记，等待平台执行器部署。这一步还没有上链。';

  @override
  String get launch2Creator_launch2DeploymentLaunch2DeploymentScreenTitle =>
      '部署进度';

  @override
  String get launch2Creator_launch2DeploymentLaunch2DeploymentStaleBody =>
      '最新进度没有读到，下面是上一次读到的状态，会自动重试。';

  @override
  String get launch2Creator_launch2DeploymentLoopLabel => '进度';

  @override
  String get launch2Creator_launch2DeploymentMessage => 'BscScan 链接已复制';

  @override
  String get launch2Creator_launch2EntryLaunch2CreateChooserClassicSubtitle =>
      '联合曲线发币，打满自动上 PancakeSwap';

  @override
  String get launch2Creator_launch2EntryLaunch2CreateChooserClassicTitle =>
      '经典发射';

  @override
  String get launch2Creator_launch2EntryLaunch2CreateChooserV2Subtitle =>
      'NFT 预售 + 提前购 + 公开内盘，毕业进官方外盘';

  @override
  String get launch2Creator_launch2EntryLaunch2CreateChooserV2Title => 'v2 发射';

  @override
  String get launch2Creator_launch2EntryLaunch2CreatorEntryLabel =>
      'v2 发射（NFT 预售 + 官方外盘）';

  @override
  String get launch2Creator_launch2EntryLaunch2MyProjectsEntryLabel => '我的项目';

  @override
  String get launch2Creator_launch2IdempotencyConflict => '这次提交和上一次内容不同，请重新签名。';

  @override
  String get launch2Creator_launch2InvalidData =>
      '服务端没有接受这份资料。最常见的原因是铸造开始时间太早，需要给部署和激活留出时间，往后调整后再提交。';

  @override
  String launch2Creator_launch2Label(
    Object? current,
    Object? labels,
    Object? labels2,
  ) {
    return '第 $current 步，共 $labels 步，$labels2';
  }

  @override
  String launch2Creator_launch2Label2(Object? semanticLabel) {
    return '上传$semanticLabel';
  }

  @override
  String launch2Creator_launch2Label3(Object? semanticLabel) {
    return '$semanticLabel，换一张';
  }

  @override
  String get launch2Creator_launch2Launch2ConfigVersionUsedCode =>
      '这一版配置的版本号已被你钱包的另一个项目用过，请修改资料重新保存一版。';

  @override
  String launch2Creator_launch2Launch2DurationLabel(Object? seconds) {
    return '$seconds 天';
  }

  @override
  String launch2Creator_launch2Launch2DurationLabel2(Object? seconds) {
    return '$seconds 小时';
  }

  @override
  String launch2Creator_launch2Launch2DurationLabel3(Object? seconds) {
    return '$seconds 分钟';
  }

  @override
  String get launch2Creator_launch2Launch2FixedRecipientAddress => '暂未配置';

  @override
  String get launch2Creator_launch2Launch2FixedRecipientAddressLabel =>
      '回购收币地址暂未配置';

  @override
  String launch2Creator_launch2Launch2FixedRecipientAddressLabel2(
    Object? value,
  ) {
    return '回购收币地址 $value，平台固定，不可修改';
  }

  @override
  String get launch2Creator_launch2Launch2NftImageHelp => '将作为项目 NFT 图片显示在钱包里';

  @override
  String get launch2Creator_launch2Launch2RecipientFixedCode =>
      '回购收币地址必须是平台固定地址。这一版配置用的是其他地址，请修改资料重新保存一版（需要重新审核）。';

  @override
  String get launch2Creator_launch2Launch2RecipientUnavailableCode =>
      '平台回购收币地址暂未配置，暂时不能保存或签名，稍后再试。';

  @override
  String launch2Creator_launch2Launch2RejectedRowText(Object? label) {
    return '已拒绝 · $label';
  }

  @override
  String launch2Creator_launch2Launch2RejectionTitle(Object? label) {
    return '审核未通过：$label';
  }

  @override
  String launch2Creator_launch2Launch2SaleStartLabel(
    Object? inDays,
    Object? local,
  ) {
    return '$local（$inDays 天后）';
  }

  @override
  String launch2Creator_launch2Launch2SaleStartLabel2(
    Object? inHours,
    Object? local,
  ) {
    return '$local（$inHours 小时后）';
  }

  @override
  String launch2Creator_launch2Launch2SaleStartLabel3(
    Object? inMinutes,
    Object? local,
  ) {
    return '$local（$inMinutes 分钟后）';
  }

  @override
  String launch2Creator_launch2Launch2SupplyLabel(Object? formatDecimal) {
    return '$formatDecimal 亿';
  }

  @override
  String launch2Creator_launch2Launch2SupplyLabel2(Object? formatDecimal) {
    return '$formatDecimal 万';
  }

  @override
  String get launch2Creator_launch2LoopBadge => '平台固定';

  @override
  String launch2Creator_launch2LoopNotice(Object? note) {
    return '审核意见：$note';
  }

  @override
  String launch2Creator_launch2LoopNotice2(
    Object? configuration,
    Object? localTimestampLabel,
  ) {
    return '$localTimestampLabel $configuration未通过审核，修改后可以重新提交。';
  }

  @override
  String get launch2Creator_launch2ModelsActive => '已激活';

  @override
  String get launch2Creator_launch2ModelsDeployFailed => '部署失败';

  @override
  String get launch2Creator_launch2ModelsDeployed => '已上链';

  @override
  String get launch2Creator_launch2ModelsDeploying => '部署中';

  @override
  String get launch2Creator_launch2ModelsIsFailure => '审核';

  @override
  String get launch2Creator_launch2ModelsIsFailure2 => '部署';

  @override
  String get launch2Creator_launch2ModelsIsFailure3 => '激活';

  @override
  String get launch2Creator_launch2ModelsSigning => '签名中';

  @override
  String get launch2Creator_launch2ModelsVerified => '激活中';

  @override
  String get launch2Creator_launch2NotFound => '找不到这个项目，它可能不属于当前账号。';

  @override
  String get launch2Creator_launch2PermissionDenied => '当前账号不能执行这一步。';

  @override
  String get launch2Creator_launch2ProjectAction => '继续填写';

  @override
  String get launch2Creator_launch2ProjectAction2 => '修改后重新提交';

  @override
  String get launch2Creator_launch2ProjectAction3 => '去签名部署';

  @override
  String get launch2Creator_launch2ProjectAction4 => '查看部署进度';

  @override
  String get launch2Creator_launch2ProjectLabel => '配置版本';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectMissingMessage =>
      '链接里没有有效的项目编号。';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectNextActiveBody =>
      '已激活，项目页生成中，下拉可刷新。';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectNextDeployingBody =>
      '部署进行中。';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectNextDraftBody =>
      '资料已保存，还差发射配置。';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectNextDraftBody2 =>
      '还没有提交审核。';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectNextFailedBody =>
      '部署没有完成。';

  @override
  String
  get launch2Creator_launch2ProjectLaunch2ProjectNextRecipientOutdatedBody =>
      '这一版配置的回购收币地址不是平台固定地址，不能签名部署。修改资料重新保存一版后需要重新审核。';

  @override
  String
  get launch2Creator_launch2ProjectLaunch2ProjectNextRecipientOutdatedTitle =>
      '回购收币地址需要更新';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectNextRejectedBody =>
      '这次审核没有通过，修改后可以重新提交。';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectNextReviewBody =>
      '平台审核发射配置，结果会显示在这里，下拉可刷新。';

  @override
  String launch2Creator_launch2ProjectLaunch2ProjectNextReviewBody2(
    Object? localTimestampLabel,
  ) {
    return '$localTimestampLabel 提交，结果会显示在这里，下拉可刷新。';
  }

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectNextSignBody =>
      '用钱包签名后，平台会部署并激活。';

  @override
  String launch2Creator_launch2ProjectLaunch2ProjectNextSignBody2(
    Object? localTimestampLabel,
  ) {
    return '$localTimestampLabel 批准。用钱包签名后，平台会部署并激活。';
  }

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectNextSignTitle => '已批准';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectSaleStartLabel =>
      '铸造开始';

  @override
  String get launch2Creator_launch2ProjectLaunch2ProjectScreenTitle => '项目';

  @override
  String get launch2Creator_launch2ProjectLoopLabel => '发射配置';

  @override
  String launch2Creator_launch2ProjectSemanticLabel(
    Object? label,
    Object? launch2CreatorMilestones,
  ) {
    return '进度：$launch2CreatorMilestones，$label';
  }

  @override
  String get launch2Creator_launch2ProjectsLaunch2ProjectsEmptyMessage =>
      'NFT 预售 + 官方外盘，一次发起。';

  @override
  String get launch2Creator_launch2ProjectsLaunch2ProjectsEmptyTitle =>
      '还没有发起项目';

  @override
  String launch2Creator_launch2ProjectsSemanticLabel(Object? name) {
    return '$name，发射配置暂时读不到';
  }

  @override
  String get launch2Creator_launch2ProjectsSubtitle => '发射配置暂时读不到，下拉刷新或点开重试';

  @override
  String get launch2Creator_launch2ProjectsSwitch => '已拒绝';

  @override
  String get launch2Creator_launch2ProjectsSwitch2 => '还没有发射配置';

  @override
  String launch2Creator_launch2ProjectsSwitch3(Object? localTimestampLabel) {
    return '$localTimestampLabel 开始铸造';
  }

  @override
  String get launch2Creator_launch2Reorged => '链上重组，重新确认中';

  @override
  String get launch2Creator_launch2S => 'v2 发射暂未开放，开放后这里可以继续。';

  @override
  String get launch2Creator_launch2S2 => '发射工厂暂时不可用（或正在计算地址），稍后再试。';

  @override
  String get launch2Creator_launch2S3 => '配置还在等平台审批，审批通过后再签名。';

  @override
  String get launch2Creator_launch2S4 => '签名请求已过期，续期后重新签名。';

  @override
  String launch2Creator_launch2S5(Object? confirmations) {
    return '已上链，$confirmations 确认';
  }

  @override
  String get launch2Creator_launch2S6 => '回购买到的代币转入这个地址。地址由平台固定，不能修改。';

  @override
  String get launch2Creator_launch2S7 => '上传';

  @override
  String get launch2Creator_launch2S8 => '换一张';

  @override
  String get launch2Creator_launch2SignIf => '正在准备签名请求，服务端计算地址可能要几秒。';

  @override
  String launch2Creator_launch2SignLabel(Object? address) {
    return '代币地址 $address';
  }

  @override
  String get launch2Creator_launch2SignLabel2 => '签名有效期';

  @override
  String get launch2Creator_launch2SignLaunch2SignExpiredBody =>
      '签名请求已过期。续期后会拿到新的请求，需要重新签名。';

  @override
  String get launch2Creator_launch2SignLaunch2SignNoWalletBody => '正在读取钱包…';

  @override
  String get launch2Creator_launch2SignLaunch2SignNoWalletBody2 =>
      '还没有可用的钱包，先在钱包里创建或激活一个。';

  @override
  String get launch2Creator_launch2SignLaunch2SignRefreshedBody =>
      '配置或 nonce 已变化，已刷新签名请求，请重新签名。';

  @override
  String get launch2Creator_launch2SignLaunch2SignRenewLabel => '续期签名请求';

  @override
  String get launch2Creator_launch2SignLaunch2SignScreenTitle => '签名部署';

  @override
  String get launch2Creator_launch2SignLaunch2SignSheetTitle => '授权部署';

  @override
  String get launch2Creator_launch2SignLoopButton => '签名并提交';

  @override
  String get launch2Creator_launch2SignLoopLabel => '签名内容';

  @override
  String launch2Creator_launch2SignLoopSignFact(Object? tickerLabel) {
    return '授权部署 $tickerLabel';
  }

  @override
  String get launch2Creator_launch2SignLoopSignFact2 => '签名钱包';

  @override
  String get launch2Creator_launch2SignLoopSignFact3 => '花费';

  @override
  String get launch2Creator_launch2SignLoopSignFact4 => '无（只签名，不发交易）';

  @override
  String get launch2Creator_launch2SignReady => '代币地址';

  @override
  String get launch2Creator_launch2SignSigning => '等待钱包签名…';

  @override
  String get launch2Creator_launch2SignSubmitting => '正在提交…';

  @override
  String get launch2Creator_launch2SignSwitch => '你在钱包里取消了签名，没有提交任何内容。';

  @override
  String get launch2Creator_launch2SignSwitch2 => '签名请求属于另一个钱包，请切换到项目方钱包。';

  @override
  String get launch2Creator_launch2SignSwitch3 => '签名请求的网络不对，没有签名。';

  @override
  String get launch2Creator_launch2SignSwitch4 => '内嵌钱包不可用，请重新登录后再试。';

  @override
  String get launch2Creator_launch2SignSwitch5 => '钱包没有完成签名，没有提交任何内容。';

  @override
  String get launch2Creator_launch2SignText =>
      '这是一次授权签名，不花费资产；平台收到后部署并激活，进度在下一页。';

  @override
  String launch2Creator_launch2SignValue(Object? minutes, Object? seconds) {
    return '$minutes:$seconds 后过期';
  }

  @override
  String get launch2Creator_launch2Switch => '签名已过期，请重新签名提交。';

  @override
  String get launch2Creator_launch2Switch10 => '平台处理中，会自动重试。';

  @override
  String get launch2Creator_launch2Switch11 => '部署没有完成，请联系平台。';

  @override
  String get launch2Creator_launch2Switch12 => '修改名称或代码';

  @override
  String get launch2Creator_launch2Switch13 => '修改铸造开始时间';

  @override
  String get launch2Creator_launch2Switch14 => '已上链，等待确认';

  @override
  String get launch2Creator_launch2Switch15 => '重试中';

  @override
  String get launch2Creator_launch2Switch16 => '已验签登记';

  @override
  String get launch2Creator_launch2Switch17 => '执行器已认领';

  @override
  String get launch2Creator_launch2Switch18 => '部署交易已广播';

  @override
  String get launch2Creator_launch2Switch19 => '交易已打包';

  @override
  String get launch2Creator_launch2Switch2 => '配置已更新，请重新签名。';

  @override
  String get launch2Creator_launch2Switch20 => '部署已确认';

  @override
  String get launch2Creator_launch2Switch21 => '模块核验通过';

  @override
  String get launch2Creator_launch2Switch22 => '激活交易已广播';

  @override
  String get launch2Creator_launch2Switch23 => '激活交易已打包';

  @override
  String get launch2Creator_launch2Switch24 => '链上重组，重新确认';

  @override
  String get launch2Creator_launch2Switch25 => '状态更新';

  @override
  String get launch2Creator_launch2Switch3 => '配置审批已失效，等待平台审批后重新签名。';

  @override
  String get launch2Creator_launch2Switch4 => '签名无效，请重新签名。';

  @override
  String get launch2Creator_launch2Switch5 => '钱包 nonce 已变化，请重新签名。';

  @override
  String get launch2Creator_launch2Switch6 => '该版本已在链上部署，请联系平台。';

  @override
  String get launch2Creator_launch2Switch7 => '距铸造开始太近无法激活，修改铸造开始时间后重新提交。';

  @override
  String get launch2Creator_launch2Switch8 => '名称 / 代码不合规，请修改后重新提交。';

  @override
  String get launch2Creator_launch2Switch9 => '部署核验不一致，项目未激活，请联系平台。';

  @override
  String get launch2Creator_launch2VersionConflict => '资料在别处被改过，已重新读取，请确认后再提交。';

  @override
  String get launch2Creator_projectDetails => '项目资料';

  @override
  String get launch2_buybackExecuted => '成交';

  @override
  String get launch2_candlesCandles => 'K 线';

  @override
  String get launch2_candlesGraduationMark => '，含毕业时刻';

  @override
  String get launch2_candlesLine => '收盘价折线';

  @override
  String get launch2_intentAction => '操作';

  @override
  String get launch2_intentNounBuy => '买入';

  @override
  String get launch2_intentNounSell => '卖出';

  @override
  String get launch2_launch2AtmosphereActionLabel => '我要发射';

  @override
  String launch2_launch2AtmosphereBuild(Object? prefix) {
    return '$prefix待定';
  }

  @override
  String get launch2_launch2AtmosphereCountdown => '距铸造 ';

  @override
  String get launch2_launch2AtmosphereCountdown2 => '剩 ';

  @override
  String get launch2_launch2AtmosphereIf => '实时成交，暂无成交';

  @override
  String get launch2_launch2AtmosphereLaunch2TickerAllLabel => '全部实时成交';

  @override
  String get launch2_launch2AtmosphereLaunch2TickerEmpty => '暂无成交';

  @override
  String get launch2_launch2AtmosphereMessage => '还没有排队中的项目';

  @override
  String launch2_launch2AtmosphereS(Object? items) {
    return '实时成交，$items';
  }

  @override
  String launch2_launch2AtmosphereSwitch(Object? soldCount) {
    return '已铸 $soldCount';
  }

  @override
  String get launch2_launch2AtmosphereSwitch2 => '名单生成中';

  @override
  String get launch2_launch2AtmosphereSwitch3 => '平台核对中';

  @override
  String get launch2_launch2AtmosphereText => '实时';

  @override
  String get launch2_launch2Build => '名单地址不在 App 内列出，可在发布交易里核对。';

  @override
  String get launch2_launch2CampaignsLaunch2CampaignDefaultCta => '查看';

  @override
  String launch2_launch2CampaignsLaunch2CampaignKicker(
    Object? monthDay,
    Object? monthDay2,
  ) {
    return '$monthDay 至 $monthDay2';
  }

  @override
  String launch2_launch2CampaignsLaunch2CampaignStamp(Object? monthDay) {
    return '$monthDay 开始';
  }

  @override
  String get launch2_launch2CampaignsLaunch2CampaignStamp2 => '今天结束';

  @override
  String launch2_launch2CampaignsLaunch2CampaignStamp3(Object? inDays) {
    return '剩 $inDays 天';
  }

  @override
  String get launch2_launch2CampaignsMessage => '没能打开浏览器，链接已复制';

  @override
  String get launch2_launch2CandleChartLaunch2CandlesEmptyText =>
      '还没有成交，第一笔成交后出现 K 线';

  @override
  String get launch2_launch2CandleChartLaunch2CandlesExpandLabel => '打开全屏图表';

  @override
  String get launch2_launch2CandleChartLaunch2CandlesFailedText =>
      'K 线暂时读不到，点按重试';

  @override
  String launch2_launch2CandleChartSemanticLabel(
    Object? candles,
    Object? label,
    Object? line,
    Object? mark,
  ) {
    return '$candles 根$label$line，单位 USD1$mark';
  }

  @override
  String get launch2_launch2CandleModelsFifteenMinutes => '15分';

  @override
  String get launch2_launch2CandleModelsFiveMinutes => '5分';

  @override
  String get launch2_launch2CandleModelsFourHours => '4时';

  @override
  String get launch2_launch2CandleModelsOneDay => '1天';

  @override
  String get launch2_launch2CandleModelsOneHour => '1时';

  @override
  String get launch2_launch2CandleModelsOneMinute => '1分';

  @override
  String get launch2_launch2Countdown => '铸造 ';

  @override
  String get launch2_launch2DynamicPoolImpact => '这个项目的外盘交易与奖励暂时不能进行。';

  @override
  String get launch2_launch2DynamicPoolLabel => '买入基础税累计';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynProvenanceDetail =>
      '跌幅按 5 分钟 K 线计算；回购买入不计奖励权重。';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynRewardsLink => '本轮状态';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynRewardsLinkLabel => '我的奖励';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicEndText =>
      '出现一根收盘不低于开盘的 5 分钟 K 线即结束（收涨、收平或无成交都算）';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicFeeRows => '动态税累计';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicFeeRows2 => '卖出基础税累计';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicIdleText =>
      '价格 5 分钟内跌超 10% 将开启动态税与买入奖励';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicRoundRows => '奖金池';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicRoundRows2 => '当前跌幅';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicRoundRows3 => 'K 线已结束，待结算';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicRoundRows4 => '本轮我的权重';

  @override
  String launch2_launch2DynamicPoolLaunch2DynamicRoundRows5(
    Object? formatDecimal,
    Object? launch2Usd1Label,
  ) {
    return '$launch2Usd1Label · 占 $formatDecimal%';
  }

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicRoundRows6 => '本根 K 线结束';

  @override
  String get launch2_launch2DynamicPoolLaunch2DynamicRoundRows7 => '结束条件';

  @override
  String get launch2_launch2DynamicPoolLaunch2SectionLabel => '费用累计';

  @override
  String get launch2_launch2DynamicPoolLoopBadge => '已激活';

  @override
  String get launch2_launch2DynamicPoolNext => '稍后点「重试」再读一次。';

  @override
  String get launch2_launch2DynamicPoolS => '未激活';

  @override
  String get launch2_launch2DynamicPoolTitle => '外盘暂不可用';

  @override
  String get launch2_launch2DynamicRewardsBuild => '你在本轮还没有买入';

  @override
  String get launch2_launch2DynamicRewardsBuild2 =>
      '轮次开启期间买入即计入本轮权重，本轮结束后在这里领取。';

  @override
  String get launch2_launch2DynamicRewardsConfirmedText => '外盘奖励已领取，已在链上确认。';

  @override
  String launch2_launch2DynamicRewardsConfirmedText2(
    Object? launch2ShortAddress,
  ) {
    return '领取已提交（$launch2ShortAddress），正在等待链上确认。不要重复领取。';
  }

  @override
  String get launch2_launch2DynamicRewardsLabel => '正在准备…';

  @override
  String get launch2_launch2DynamicRewardsLabel2 => '已领取';

  @override
  String get launch2_launch2DynamicRewardsLabel3 => '领取确认中…';

  @override
  String get launch2_launch2DynamicRewardsLabel4 => '起止';

  @override
  String get launch2_launch2DynamicRewardsLabel5 => '我的权重 / 总权重';

  @override
  String get launch2_launch2DynamicRewardsLabel6 => '本轮奖金';

  @override
  String get launch2_launch2DynamicRewardsLabel7 => '可领';

  @override
  String get launch2_launch2DynamicRewardsLabel8 => '已领';

  @override
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsBlockedTitle =>
      'MEME v2 暂时不可用';

  @override
  String launch2_launch2DynamicRewardsLaunch2DynRewardsEmptyMessage(
    Object? launch2DynamicIdleText,
  ) {
    return '$launch2DynamicIdleText。开启后用任何软件买入都计入本轮权重，本轮结束后在这里领取。';
  }

  @override
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsEmptyTitle =>
      '还没有外盘奖励';

  @override
  String
  get launch2_launch2DynamicRewardsLaunch2DynRewardsInvalidIdentityMessage =>
      '没有请求任何数据，也没有回退到其他项目。';

  @override
  String
  get launch2_launch2DynamicRewardsLaunch2DynRewardsInvalidIdentityTitle =>
      '路由中没有可用的项目标识';

  @override
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsInvalidRouteTitle =>
      '外盘奖励';

  @override
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsNoWalletMessage =>
      '外盘奖励按钱包记录，激活钱包后可查看与领取。';

  @override
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsNoWalletTitle =>
      '还没有可用的钱包';

  @override
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsNoneMessage =>
      '只有开启动态税的项目才有按轮次的外盘奖励。';

  @override
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsNoneTitle =>
      '这个项目没有外盘奖励';

  @override
  String get launch2_launch2DynamicRewardsLaunch2DynRewardsProvenanceDetail =>
      '权重按钱包在本轮的买入金额记（USD1）；回购买入不计。领取以链上确认为准。';

  @override
  String get launch2_launch2DynamicRewardsLaunch2DynamicNoRewardText =>
      '本轮没有可领取的奖励';

  @override
  String launch2_launch2DynamicRewardsLaunch2SectionLabel(Object? id) {
    return '第 $id 轮';
  }

  @override
  String get launch2_launch2DynamicRewardsOpen => '本轮结束后可领';

  @override
  String get launch2_launch2DynamicRewardsPending =>
      '已广播，但还没有读到确认。它可能仍在确认中，请稍后再查；不要重复领取。';

  @override
  String get launch2_launch2DynamicRewardsReason => '外盘池子正在同步，请稍后再试';

  @override
  String get launch2_launch2DynamicRewardsS => '没有可领';

  @override
  String get launch2_launch2DynamicRewardsS2 => '你在本轮没有买入，没有奖励权重。';

  @override
  String launch2_launch2DynamicRewardsSpan(Object? start) {
    return '$start 起 · 进行中';
  }

  @override
  String launch2_launch2DynamicRewardsStart(Object? startCandle) {
    return 'K 线 #$startCandle';
  }

  @override
  String launch2_launch2DynamicRewardsText(Object? text) {
    return '$text 上报没有成功，链上结果不受影响；不要重复领取。';
  }

  @override
  String get launch2_launch2DynamicRewardsValue => '本轮结束后结算';

  @override
  String get launch2_launch2FormatActivationMissing => '链上还没有看到激活记录，平台正在核对';

  @override
  String get launch2_launch2FormatBalance => '钱包余额';

  @override
  String get launch2_launch2FormatBroadcast => '名单发布中';

  @override
  String get launch2_launch2FormatClosed => '当前阶段不可交易';

  @override
  String get launch2_launch2FormatClosedNoHolders => '已关闭';

  @override
  String get launch2_launch2FormatDeployedEventMismatch =>
      '链上部署记录与登记不一致，平台正在核对';

  @override
  String get launch2_launch2FormatGraduated => '官方池交易中';

  @override
  String get launch2_launch2FormatInventory => '内盘剩余库存';

  @override
  String launch2_launch2FormatLaunch2ActionFailure(Object? parts) {
    return 'USD1 余额不足：$parts';
  }

  @override
  String launch2_launch2FormatLaunch2ActionFailure2(Object? parts) {
    return '卖出数量超过持有：$parts';
  }

  @override
  String get launch2_launch2FormatLaunch2AddressFrozenText =>
      '本项目合约地址被 USD1 发行方限制，买卖和领取暂不可用';

  @override
  String get launch2_launch2FormatLaunch2BuybackHeldLine => '来源：链上读数 · 自动回购';

  @override
  String get launch2_launch2FormatLaunch2ClosedNoHoldersText => '无人铸造，已关闭';

  @override
  String launch2_launch2FormatLaunch2CountdownText(
    Object? days,
    Object? two,
    Object? two2,
    Object? two3,
  ) {
    return '$days天 $two:$two2:$two3';
  }

  @override
  String launch2_launch2FormatLaunch2CurveCapSentence(
    Object? launch2CurveCapFigure,
  ) {
    return '每个地址最多买 $launch2CurveCapFigure 枚';
  }

  @override
  String launch2_launch2FormatLaunch2GasFailureText(Object? bnb) {
    return '这笔约需 $bnb';
  }

  @override
  String launch2_launch2FormatLaunch2GasFailureText2(Object? bnb) {
    return '钱包有 $bnb';
  }

  @override
  String launch2_launch2FormatLaunch2GasFailureText3(
    Object? loopLaunchNativeSymbolText,
    Object? parts,
  ) {
    return '$loopLaunchNativeSymbolText 手续费不足：$parts，充值后再试';
  }

  @override
  String launch2_launch2FormatLaunch2GasShortText(
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchNativeSymbolText2,
  ) {
    return '$loopLaunchNativeSymbolText 手续费不足：钱包里的 $loopLaunchNativeSymbolText2 不够付这笔的网络手续费，充值后再试';
  }

  @override
  String get launch2_launch2FormatLaunch2KeeperLine => '自动回购运行中';

  @override
  String get launch2_launch2FormatLaunch2KeeperLine2 => '一笔正在上链';

  @override
  String launch2_launch2FormatLaunch2KeeperLine3(Object? dateTimeLabel) {
    return '上次 $dateTimeLabel';
  }

  @override
  String launch2_launch2FormatLaunch2KeeperLine4(Object? reason) {
    return '回购暂缓：$reason';
  }

  @override
  String launch2_launch2FormatLaunch2KeeperLine5(Object? clockLabel) {
    return '$clockLabel 后再试';
  }

  @override
  String get launch2_launch2FormatLaunch2NoMemeText => '还没有这个代币';

  @override
  String get launch2_launch2FormatLaunch2NoUsd1Text => '钱包里还没有 USD1';

  @override
  String get launch2_launch2FormatLaunch2OpenedWithoutHoldersText =>
      '无 NFT 持有人，直接开放公开内盘';

  @override
  String launch2_launch2FormatLaunch2QuotaExhaustedText(
    Object? launch2CurveCapFigure,
  ) {
    return '已用完单地址累计 $launch2CurveCapFigure 枚额度';
  }

  @override
  String get launch2_launch2FormatLaunch2QuoteZeroText => '这个金额买不到最小单位，换个金额试试';

  @override
  String launch2_launch2FormatLaunch2SaleDurationLabel(Object? hours) {
    return '$hours 天';
  }

  @override
  String launch2_launch2FormatLaunch2SaleDurationLabel2(Object? hours) {
    return '$hours 小时';
  }

  @override
  String launch2_launch2FormatLaunch2SaleDurationLabel3(Object? minutes) {
    return '$minutes 分钟';
  }

  @override
  String get launch2_launch2FormatLaunch2SnapshotPendingMessage =>
      '等待截止块确认，名单发布后开始 1 小时提前购';

  @override
  String launch2_launch2FormatLaunch2SnapshotPendingMessage2(
    Object? groupedFigure,
  ) {
    return '截止块 #$groupedFigure，名单发布后开始 1 小时提前购';
  }

  @override
  String launch2_launch2FormatLaunch2SpokenDuration(
    Object? days,
    Object? hours,
  ) {
    return '$days 天 $hours 小时';
  }

  @override
  String launch2_launch2FormatLaunch2SpokenDuration2(
    Object? hours,
    Object? minutes,
  ) {
    return '$hours 小时 $minutes 分';
  }

  @override
  String launch2_launch2FormatLaunch2SpokenDuration3(Object? minutes) {
    return '$minutes 分';
  }

  @override
  String get launch2_launch2FormatLaunch2SpokenDuration4 => '不到 1 分';

  @override
  String launch2_launch2FormatLaunch2TradingHoldSinceText(
    Object? localClockLabel,
  ) {
    return '自 $localClockLabel 起';
  }

  @override
  String get launch2_launch2FormatLaunch2Usd1PausedText =>
      'USD1 已被发行方暂停，买卖和领取暂不可用';

  @override
  String get launch2_launch2FormatMismatch => '名单发布异常，平台处理中';

  @override
  String get launch2_launch2FormatMismatch2 => '核验不一致，平台处理中';

  @override
  String get launch2_launch2FormatNftSale => '铸造中';

  @override
  String get launch2_launch2FormatNftSale2 => '剩余';

  @override
  String get launch2_launch2FormatPaused => '暂停中';

  @override
  String get launch2_launch2FormatPending => '核验中';

  @override
  String get launch2_launch2FormatPriority => '提前购';

  @override
  String get launch2_launch2FormatPriority2 => '持有人优先 · 剩余';

  @override
  String get launch2_launch2FormatPublic => '公开内盘';

  @override
  String get launch2_launch2FormatPublic2 => '人人可买，卖满即毕业';

  @override
  String launch2_launch2FormatQuota(Object? launch2CurveCapFigure) {
    return '单地址累计上限 $launch2CurveCapFigure 枚';
  }

  @override
  String launch2_launch2FormatReason(Object? live) {
    return '下一笔暂缓：$live';
  }

  @override
  String launch2_launch2FormatReason2(Object? live, Object? reason) {
    return '下一笔暂缓：$live（链上读数）；$reason（自动回购）';
  }

  @override
  String get launch2_launch2FormatReplaceAll => '，暂不执行';

  @override
  String get launch2_launch2FormatReplaceAll2 => '，稍后执行';

  @override
  String get launch2_launch2FormatS => '从到手的 MEME 扣';

  @override
  String launch2_launch2FormatS2(Object? localTimestampLabel) {
    return '自 $localTimestampLabel 起';
  }

  @override
  String get launch2_launch2FormatS3 => '名单已上链，同步中';

  @override
  String launch2_launch2FormatS4(Object? days) {
    return '$days 天';
  }

  @override
  String get launch2_launch2FormatSnapshotPending => '名单发布后开始 1 小时提前购';

  @override
  String get launch2_launch2FormatSoldSupply => '内盘可卖数量';

  @override
  String get launch2_launch2FormatSwitch => '平台正在核对这个项目';

  @override
  String get launch2_launch2FormatSwitch10 => '旧版合约价格保护生效，暂不执行';

  @override
  String get launch2_launch2FormatSwitch11 => '暂不执行';

  @override
  String get launch2_launch2FormatSwitch12 =>
      '官方池本金保护，本金不足 10,000 USD1 或单笔超过 1%';

  @override
  String get launch2_launch2FormatSwitch13 => '合约回购已暂停';

  @override
  String get launch2_launch2FormatSwitch14 => '项目还没有毕业';

  @override
  String get launch2_launch2FormatSwitch15 => '回购执行账户未就绪，平台处理中';

  @override
  String get launch2_launch2FormatSwitch16 => '托管记录与链上不一致，平台核对中';

  @override
  String get launch2_launch2FormatSwitch17 => '成交到账为 0，平台处理中';

  @override
  String get launch2_launch2FormatSwitch18 => '旧版合约价格保护生效';

  @override
  String get launch2_launch2FormatSwitch19 => '链上手续费过高';

  @override
  String get launch2_launch2FormatSwitch2 => '从付出的 USD1 扣';

  @override
  String get launch2_launch2FormatSwitch20 => '合约拒绝执行，平台处理中';

  @override
  String get launch2_launch2FormatSwitch21 => '执行账户手续费不足，平台处理中';

  @override
  String get launch2_launch2FormatSwitch22 => '链上手续费过高，稍后重试';

  @override
  String get launch2_launch2FormatSwitch23 => '上一笔没有执行，稍后重试';

  @override
  String get launch2_launch2FormatSwitch24 => '项目不存在';

  @override
  String get launch2_launch2FormatSwitch25 => '当前阶段不能交易，已重新读取项目状态';

  @override
  String get launch2_launch2FormatSwitch26 => '提前购阶段只能买入，公开内盘开始后可卖出';

  @override
  String get launch2_launch2FormatSwitch27 => '内盘已卖满';

  @override
  String get launch2_launch2FormatSwitch28 => '已用完单地址累计买入额度';

  @override
  String get launch2_launch2FormatSwitch29 => '项目已暂停';

  @override
  String get launch2_launch2FormatSwitch3 => '下一笔可以执行';

  @override
  String get launch2_launch2FormatSwitch30 => '这个钱包已经买过 NFT（每个地址终身 1 枚）';

  @override
  String get launch2_launch2FormatSwitch31 => '价格已变化，已刷新';

  @override
  String get launch2_launch2FormatSwitch32 => '报价已过期，已重新报价';

  @override
  String get launch2_launch2FormatSwitch33 => 'USD1 余额不足';

  @override
  String get launch2_launch2FormatSwitch34 => '卖出数量超过持有';

  @override
  String launch2_launch2FormatSwitch35(Object? loopLaunchNativeSymbolText) {
    return '$loopLaunchNativeSymbolText 手续费不足，充值后再试';
  }

  @override
  String get launch2_launch2FormatSwitch36 => '金额不正确';

  @override
  String get launch2_launch2FormatSwitch37 => '超出可买上限';

  @override
  String get launch2_launch2FormatSwitch38 => '报价已变化，请重新报价';

  @override
  String get launch2_launch2FormatSwitch39 => '只能用 LOOP 内置钱包购买';

  @override
  String get launch2_launch2FormatSwitch4 => '回购已暂停';

  @override
  String get launch2_launch2FormatSwitch40 => '提前购仅限名单内持有人';

  @override
  String get launch2_launch2FormatSwitch41 => '暂不可用';

  @override
  String get launch2_launch2FormatSwitch42 => '这笔交易已过期，没有提交任何交易，请重新发起';

  @override
  String get launch2_launch2FormatSwitch43 => '试算没有通过，这笔交易在链上会被拒绝';

  @override
  String get launch2_launch2FormatSwitch44 => '需要先授权，授权前无法试算';

  @override
  String get launch2_launch2FormatSwitch45 => '名单核验中，提前购暂不可用';

  @override
  String get launch2_launch2FormatSwitch46 => 'MEME v2 合约还没有配置';

  @override
  String get launch2_launch2FormatSwitch47 => 'MEME v2 服务暂时不可用';

  @override
  String get launch2_launch2FormatSwitch48 => '链上读数暂时取不到';

  @override
  String get launch2_launch2FormatSwitch49 => '钱包目录暂时读不到';

  @override
  String get launch2_launch2FormatSwitch5 => '毕业后才开始回购';

  @override
  String get launch2_launch2FormatSwitch50 => '交易暂时关闭';

  @override
  String get launch2_launch2FormatSwitch51 => '主网签名暂未开放';

  @override
  String get launch2_launch2FormatSwitch52 => 'MEME v2 暂未开放';

  @override
  String get launch2_launch2FormatSwitch53 => '超过单笔金额上限';

  @override
  String get launch2_launch2FormatSwitch54 => '超过今日金额上限';

  @override
  String get launch2_launch2FormatSwitch55 => '这笔交易暂不在允许范围内';

  @override
  String launch2_launch2FormatSwitch56(Object? usd1) {
    return '需要 $usd1';
  }

  @override
  String launch2_launch2FormatSwitch57(Object? usd1) {
    return '当前 $usd1';
  }

  @override
  String launch2_launch2FormatSwitch58(Object? usd1) {
    return '最多可付 $usd1';
  }

  @override
  String launch2_launch2FormatSwitch59(Object? meme) {
    return '需要 $meme';
  }

  @override
  String get launch2_launch2FormatSwitch6 => '托管余额不足一笔';

  @override
  String launch2_launch2FormatSwitch60(Object? meme) {
    return '当前持有 $meme';
  }

  @override
  String launch2_launch2FormatSwitch61(Object? meme) {
    return '最多可卖 $meme';
  }

  @override
  String get launch2_launch2FormatSwitch62 => 'NFT名单公布';

  @override
  String get launch2_launch2FormatSwitch7 => '距上一笔不到 10 秒，稍后执行';

  @override
  String get launch2_launch2FormatSwitch8 =>
      '官方池本金保护：本金不足 10,000 USD1 或单笔超过 1%';

  @override
  String get launch2_launch2FormatSwitch9 => '合约报价暂时读不到，暂不执行';

  @override
  String get launch2_launch2FormatUpcoming => '即将铸造';

  @override
  String get launch2_launch2FormatUpcoming2 => '铸造倒计时';

  @override
  String get launch2_launch2FormatVerified => '已核验';

  @override
  String get launch2_launch2FullChartLaunch2ChartFullBlockedTitle => '全屏图表';

  @override
  String get launch2_launch2FullChartLaunch2ChartFullInvalidTitle => '无法打开这张图表';

  @override
  String launch2_launch2Graduated(Object? launch2PriceLabel) {
    return '毕业价 $launch2PriceLabel';
  }

  @override
  String launch2_launch2HeroLaunch2RecordFoot(
    Object? launch2HeroDetail,
    Object? past,
  ) {
    return '铸造期已过 $past% · $launch2HeroDetail';
  }

  @override
  String get launch2_launch2HeroNftSale => '共识勋章铸造中';

  @override
  String launch2_launch2HeroNftSale2(Object? perNft, Object? soldCount) {
    return '已铸 $soldCount 枚 · $perNft';
  }

  @override
  String launch2_launch2HeroNftSale3(Object? perNft, Object? soldCount) {
    return '已铸 $soldCount 枚 · $perNft。持有即进快照名单，名单发布后 1 小时提前购。';
  }

  @override
  String launch2_launch2HeroNftSale4(
    Object? launch2SaleDurationLabel,
    Object? launch2ShortDateTime,
  ) {
    return '铸造期 $launch2SaleDurationLabel · 截止 $launch2ShortDateTime';
  }

  @override
  String get launch2_launch2HeroNftSale5 => '铸造剩余';

  @override
  String launch2_launch2HeroPerNft(Object? launch2Usd1Label) {
    return '$launch2Usd1Label / 枚';
  }

  @override
  String get launch2_launch2HeroPriority => '提前购进行中';

  @override
  String launch2_launch2HeroPriority2(
    Object? launch2BpsLabel,
    Object? launch2HeroPrice,
  ) {
    return '内盘已售 $launch2BpsLabel · $launch2HeroPrice';
  }

  @override
  String launch2_launch2HeroPriority3(
    Object? launch2BpsLabel,
    Object? launch2HeroPrice,
    Object? soldCount,
  ) {
    return '已铸 $soldCount 枚 · 内盘已售 $launch2BpsLabel · $launch2HeroPrice';
  }

  @override
  String get launch2_launch2HeroPriority4 => '提前购剩余';

  @override
  String launch2_launch2HeroPublic(Object? launch2HeroPrice) {
    return '$launch2HeroPrice · 卖满自动毕业';
  }

  @override
  String launch2_launch2HeroPublic2(Object? launch2HeroPrice) {
    return '$launch2HeroPrice · 卖满 8 亿自动毕业';
  }

  @override
  String launch2_launch2HeroS(Object? left) {
    return '距铸造 $left';
  }

  @override
  String launch2_launch2HeroS2(Object? launch2ShortDateTime) {
    return '提前购进行中 · 截止 $launch2ShortDateTime';
  }

  @override
  String get launch2_launch2HeroSnapshotPending => '名单发布后 1 小时提前购';

  @override
  String get launch2_launch2HeroSwitch => '内盘冲刺';

  @override
  String get launch2_launch2HeroSwitch2 => '铸造时间待定';

  @override
  String launch2_launch2HeroSwitch3(Object? left) {
    return '剩 $left';
  }

  @override
  String launch2_launch2HeroSwitch4(Object? soldCount) {
    return '已铸 $soldCount 枚';
  }

  @override
  String launch2_launch2HeroSwitch5(Object? launch2BpsLabel) {
    return '内盘已售 $launch2BpsLabel';
  }

  @override
  String get launch2_launch2HeroSwitch6 => '内盘进度';

  @override
  String launch2_launch2HeroUpcoming(
    Object? launch2SaleDurationLabel,
    Object? perNft,
  ) {
    return '$perNft · 铸造期 $launch2SaleDurationLabel';
  }

  @override
  String launch2_launch2HeroUpcoming2(
    Object? launch2SaleDurationLabel,
    Object? launch2ShortDateTime,
    Object? perNft,
  ) {
    return '$launch2ShortDateTime 开始铸造 · $perNft · 铸造期 $launch2SaleDurationLabel';
  }

  @override
  String launch2_launch2HeroUpcoming3(Object? launch2ShortDateTime) {
    return '$launch2ShortDateTime 开始铸造';
  }

  @override
  String get launch2_launch2HeroUpcoming4 => '距铸造';

  @override
  String launch2_launch2InstanceAside(Object? launch2Usd1Label) {
    return '24h 成交 $launch2Usd1Label';
  }

  @override
  String get launch2_launch2InstanceBody => '每个 v2 项目用同一套参数，项目方不能修改。';

  @override
  String launch2_launch2InstanceBody2(
    Object? launch2MemeCompact,
    Object? launch2Usd1Label,
  ) {
    return '勋章铸造（$launch2Usd1Label 一枚，每个地址终身 1 枚）→ 快照名单与 1 小时提前购 → 公开内盘。任何一轮卖满 $launch2MemeCompact 枚即自动建官方池毕业。';
  }

  @override
  String get launch2_launch2InstanceBody3 =>
      '每个地址终身只能铸 1 枚。铸造结束时持有勋章的地址进入快照名单，名单发布后有 1 小时提前购。';

  @override
  String launch2_launch2InstanceBody4(
    Object? launch2BpsLabel,
    Object? tickSpacing,
  ) {
    return 'LP 费 $launch2BpsLabel，tickSpacing $tickSpacing';
  }

  @override
  String launch2_launch2InstanceBody5(
    Object? buybackMinIntervalSeconds,
    Object? launch2Usd1Label,
  ) {
    return '每笔 $launch2Usd1Label，两笔间隔至少 $buybackMinIntervalSeconds 秒；官方池 USD1 本金不足 10,000 或单笔超过本金 1% 时不执行，被拒的尝试不留记录。';
  }

  @override
  String get launch2_launch2InstanceBuild => '铸造进度';

  @override
  String get launch2_launch2InstanceBuild2 => '最近一笔';

  @override
  String get launch2_launch2InstanceLabel => '内盘';

  @override
  String get launch2_launch2InstanceLabel2 => '毕业储备';

  @override
  String get launch2_launch2InstanceLabel3 => '内盘买卖税';

  @override
  String get launch2_launch2InstanceLabel4 => '外盘税';

  @override
  String get launch2_launch2InstanceLabel5 => '单地址上限';

  @override
  String get launch2_launch2InstanceLabel6 => '价格 / 枚';

  @override
  String get launch2_launch2InstanceLabel7 => '毕业时间';

  @override
  String get launch2_launch2InstanceLabel8 => '毕业价';

  @override
  String get launch2_launch2InstanceLaunch2BuyNftLabel => '已持有勋章';

  @override
  String get launch2_launch2InstanceLaunch2BuyNftLabel2 => '铸造勋章';

  @override
  String get launch2_launch2InstanceLaunch2BuybackEscrowLabel => '托管余额';

  @override
  String get launch2_launch2InstanceLaunch2BuybackInfoLabel => '关于回购';

  @override
  String get launch2_launch2InstanceLaunch2BuybackLatestValue => '还没有';

  @override
  String launch2_launch2InstanceLaunch2BuybackLiveUnavailableMessage(
    Object? launch2ReasonText,
  ) {
    return '链上实时读数暂时取不到 · $launch2ReasonText';
  }

  @override
  String get launch2_launch2InstanceLaunch2BuybackNextLabel => '下一笔';

  @override
  String get launch2_launch2InstanceLaunch2BuybackNotBurnBody =>
      '回购买到的代币转给项目登记的收币地址，不会销毁。';

  @override
  String get launch2_launch2InstanceLaunch2BuybackNotBurnTitle => '回购不等于销毁';

  @override
  String get launch2_launch2InstanceLaunch2BuybackTotalLabel => '累计回购';

  @override
  String launch2_launch2InstanceLaunch2BuybackTotalValue(
    Object? executedCount,
    Object? launch2Usd1Label,
  ) {
    return '$launch2Usd1Label · $executedCount 笔';
  }

  @override
  String launch2_launch2InstanceLaunch2BuybackUnavailableMessage(
    Object? chainFailureReason,
  ) {
    return '回购明细暂时读不到 · $chainFailureReason';
  }

  @override
  String launch2_launch2InstanceLaunch2CurveSupply(
    Object? launch2MemeCompact,
    Object? launch2MemeCompact2,
  ) {
    return '已售 $launch2MemeCompact / $launch2MemeCompact2，卖满自动建官方池毕业';
  }

  @override
  String get launch2_launch2InstanceLaunch2EvidencePendingMessage =>
      '合约核对中，交易可能暂时不可用';

  @override
  String get launch2_launch2InstanceLaunch2InvalidRouteTitle => '无法打开这个项目';

  @override
  String get launch2_launch2InstanceLaunch2MineOnlyToggle => '我的外盘成交';

  @override
  String get launch2_launch2InstanceLaunch2MyPoolTradesEmptyMessage =>
      '成交还在同步，稍后刷新';

  @override
  String launch2_launch2InstanceLaunch2MyPoolTradesFailedMessage(
    Object? chainFailureReason,
  ) {
    return '我的外盘成交暂时读不到 · $chainFailureReason';
  }

  @override
  String get launch2_launch2InstanceLaunch2MyPoolTradesNoWalletMessage =>
      '激活钱包后可以只看自己的成交';

  @override
  String get launch2_launch2InstanceLaunch2MyPoolTradesNoneTitle => '你还没有外盘成交';

  @override
  String launch2_launch2InstanceLaunch2MyPoolTradesProvenanceDetail(
    Object? launch2MyPoolTradesShown,
  ) {
    return '只含经官方池路由成交的记录，最近 $launch2MyPoolTradesShown 笔；数量已扣 2% 外盘税。';
  }

  @override
  String get launch2_launch2InstanceLaunch2MyPoolTradesUnsupportedMessage =>
      '我的外盘成交暂时读不到';

  @override
  String launch2_launch2InstanceLaunch2NftEnd(Object? dateTimeLabel) {
    return '截止 $dateTimeLabel';
  }

  @override
  String get launch2_launch2InstanceLaunch2NftHeldLabel => '我的持有';

  @override
  String get launch2_launch2InstanceLaunch2NftInfo => '项目 NFT';

  @override
  String get launch2_launch2InstanceLaunch2NftInfoLabel => '关于项目 NFT';

  @override
  String get launch2_launch2InstanceLaunch2NftOpenLabel => '铸造页';

  @override
  String launch2_launch2InstanceLaunch2OpenedWithoutHoldersBody(
    Object? launch2OpenedWithoutHoldersText,
  ) {
    return '$launch2OpenedWithoutHoldersText，跳过提前购。';
  }

  @override
  String get launch2_launch2InstanceLaunch2PoolIdTitle =>
      '池 ID（Uniswap v4，没有池地址）';

  @override
  String get launch2_launch2InstanceLaunch2PoolInfo => '官方池';

  @override
  String get launch2_launch2InstanceLaunch2PoolInfoLabel => '关于官方池';

  @override
  String get launch2_launch2InstanceLaunch2PoolTaxBody =>
      '在官方池买卖都收取，由 Hook 计入回购托管，用来按规则回购。';

  @override
  String launch2_launch2InstanceLaunch2PoolTaxTitle(Object? launch2BpsLabel) {
    return '外盘税 $launch2BpsLabel';
  }

  @override
  String get launch2_launch2InstanceLaunch2PoolTradesEmptyTitle => '还没有外盘成交';

  @override
  String launch2_launch2InstanceLaunch2PoolTradesFailedMessage(Object? state) {
    return '外盘成交暂时读不到 · $state';
  }

  @override
  String launch2_launch2InstanceLaunch2PoolTradesProvenanceDetail(
    Object? launch2RecentPoolTradesLimit,
  ) {
    return '最近 $launch2RecentPoolTradesLimit 笔官方池成交，不含回购；卖出金额为扣税后实收。';
  }

  @override
  String get launch2_launch2InstanceLaunch2TemplateInfo => '发射规则';

  @override
  String get launch2_launch2InstanceLaunch2TemplateInfoLabel => '关于发射规则';

  @override
  String get launch2_launch2InstanceLaunch2TemplateRiskTitle => '风险';

  @override
  String get launch2_launch2InstanceLaunch2TradeSheetBarrierLabel => '关闭交易面板';

  @override
  String get launch2_launch2InstanceLaunch2TradesProvenanceDetail =>
      '最近 20 笔内盘成交，金额含 10% 税。';

  @override
  String get launch2_launch2InstanceLoopBadge => '你是项目方';

  @override
  String get launch2_launch2InstanceLoopLabel => '勋章铸造';

  @override
  String get launch2_launch2InstanceLoopLabel2 => '最新成交';

  @override
  String get launch2_launch2InstanceLoopProvenanceLine => 'LOOP 链上索引';

  @override
  String get launch2_launch2InstanceMessage => '已复制代币地址';

  @override
  String get launch2_launch2InstanceMessage2 =>
      '铸造期内没有人铸造。这个项目使用旧版合约，名单无法生成，提前购和公开内盘不会开始。';

  @override
  String launch2_launch2InstanceNftSale(Object? soldCount) {
    return '每地址 1 枚 · 已铸 $soldCount 枚';
  }

  @override
  String get launch2_launch2InstancePartsBuild => '当前价（USD1）';

  @override
  String get launch2_launch2InstancePartsBuild2 => '我的持仓';

  @override
  String launch2_launch2InstancePartsBuild3(
    Object? launch2PriceLabel,
    Object? launch2TradeTimeLabel,
  ) {
    return '$launch2TradeTimeLabel · 价格 $launch2PriceLabel';
  }

  @override
  String get launch2_launch2InstancePartsBuyback => '回购';

  @override
  String get launch2_launch2InstancePartsEmptyText => '暂无成交价';

  @override
  String get launch2_launch2InstancePartsInfo => '信息';

  @override
  String get launch2_launch2InstancePartsLabel => '估值';

  @override
  String get launch2_launch2InstancePartsLabel2 => '成本价';

  @override
  String get launch2_launch2InstancePartsLabel3 => '只看我的';

  @override
  String get launch2_launch2InstancePartsLaunch2CopyAddressLabel => '复制代币地址';

  @override
  String launch2_launch2InstancePartsLaunch2DynStripLineLabel(
    Object? line,
    Object? state,
  ) {
    return '本轮状态，$state，$line';
  }

  @override
  String get launch2_launch2InstancePartsLaunch2HoldingPartialNoteBody =>
      '部分持仓为链上转入，无成本记录；成本价与盈亏只按有成本记录的部分计算。';

  @override
  String get launch2_launch2InstancePartsLaunch2HoldingPartialNoteTitle =>
      '部分持仓无成本记录';

  @override
  String get launch2_launch2InstancePartsLaunch2HoldingPnlInfoLabel => '盈亏';

  @override
  String get launch2_launch2InstancePartsLaunch2HoldingPnlInfoTitle => '持仓盈亏';

  @override
  String get launch2_launch2InstancePartsLaunch2HoldingRealizedNoteTitle =>
      '已实现盈亏';

  @override
  String launch2_launch2InstancePartsPot(Object? launch2Usd1Label) {
    return '奖金池 $launch2Usd1Label';
  }

  @override
  String launch2_launch2InstancePartsS(Object? launch2BpsLabel) {
    return '跌幅 $launch2BpsLabel';
  }

  @override
  String get launch2_launch2InstancePartsText => '匿名';

  @override
  String get launch2_launch2InstancePartsTrades => '成交';

  @override
  String get launch2_launch2InstancePriority => '持有人优先';

  @override
  String get launch2_launch2InstanceRows => '铸造开始';

  @override
  String get launch2_launch2InstanceRows2 => '铸造价格';

  @override
  String get launch2_launch2InstanceRows3 => '铸造时长';

  @override
  String get launch2_launch2InstanceRows4 => '已铸';

  @override
  String launch2_launch2InstanceRows5(Object? soldCount) {
    return '$soldCount 枚';
  }

  @override
  String get launch2_launch2InstanceRows6 => '我的 NFT';

  @override
  String get launch2_launch2InstanceRows7 => '未激活钱包';

  @override
  String get launch2_launch2InstanceRows8 => '截止块';

  @override
  String get launch2_launch2InstanceRows9 => '关闭时间';

  @override
  String launch2_launch2InstanceS(Object? elapsed) {
    return '已过 $elapsed%';
  }

  @override
  String launch2_launch2InstanceSemanticLabel(Object? elapsedText) {
    return '铸造时间$elapsedText';
  }

  @override
  String launch2_launch2InstanceSemanticLabel2(Object? launch2BpsLabel) {
    return '内盘进度 $launch2BpsLabel';
  }

  @override
  String get launch2_launch2InstanceSwitch => '上一笔还在链上确认，确认后再交易';

  @override
  String launch2_launch2InstanceText(Object? noun) {
    return '$noun已在链上确认。';
  }

  @override
  String launch2_launch2InstanceText2(Object? noun) {
    return '你的外盘$noun已在链上确认。';
  }

  @override
  String launch2_launch2InstanceText3(Object? noun) {
    return '官方池已记录新成交，你的外盘$noun应已确认；数量以钱包余额为准。';
  }

  @override
  String launch2_launch2InstanceText4(Object? launch2IntentNoun) {
    return '已广播，但还没有读到确认。它可能仍在确认中，请稍后再查；不要重复$launch2IntentNoun。';
  }

  @override
  String get launch2_launch2InstanceText5 => '你看到的是用户看到的项目页';

  @override
  String get launch2_launch2InstanceTitle => '由平台模板固定';

  @override
  String get launch2_launch2InstanceTitle2 => '三段发射';

  @override
  String get launch2_launch2InstanceTitle3 => '全部外盘成交';

  @override
  String get launch2_launch2InstanceTitle4 => '费率';

  @override
  String get launch2_launch2InstanceTitle5 => '规则';

  @override
  String get launch2_launch2InstanceTitle6 => '收币地址';

  @override
  String launch2_launch2InstanceUpcoming(
    Object? launch2SaleDurationLabel,
    Object? launch2Usd1Label,
  ) {
    return '$launch2Usd1Label / 枚 · 铸造期 $launch2SaleDurationLabel';
  }

  @override
  String launch2_launch2InstanceValue(
    Object? launch2BpsLabel,
    Object? launch2CurveCapFigure,
  ) {
    return '$launch2CurveCapFigure 枚（$launch2BpsLabel）';
  }

  @override
  String launch2_launch2InstanceZero(Object? groupedFigure) {
    return '我的外盘成交 · 共 $groupedFigure 笔';
  }

  @override
  String get launch2_launch2Label => '去充值';

  @override
  String get launch2_launch2Label2 => '获取资金';

  @override
  String get launch2_launch2Launch2SnapshotExplorerLabel => '在 BscScan 查看发布交易';

  @override
  String get launch2_launch2Launch2SnapshotMembersLabel => '名单人数';

  @override
  String launch2_launch2Launch2SnapshotMembersValue(Object? members) {
    return '$members 人';
  }

  @override
  String get launch2_launch2Launch2SnapshotPublishedAtLabel => '发布时间';

  @override
  String get launch2_launch2Launch2SnapshotTxLabel => '发布交易';

  @override
  String get launch2_launch2Launch2SnapshotVerificationLabel => '核验';

  @override
  String get launch2_launch2LaunchpadBuild => '待定';

  @override
  String launch2_launch2LaunchpadBuyback(Object? ticker, Object? usd1) {
    return '平台回购 $ticker$usd1';
  }

  @override
  String get launch2_launch2LaunchpadClosed => '已暂停 / 无人铸造';

  @override
  String launch2_launch2LaunchpadCurveBuy(
    Object? ticker,
    Object? usd1,
    Object? who,
  ) {
    return '$who买入 $ticker$usd1';
  }

  @override
  String launch2_launch2LaunchpadCurveSell(
    Object? ticker,
    Object? usd1,
    Object? who,
  ) {
    return '$who卖出 $ticker$usd1';
  }

  @override
  String launch2_launch2LaunchpadGraduated(Object? ticker) {
    return '$ticker 毕业了';
  }

  @override
  String launch2_launch2LaunchpadLaunch2DeskKicker(
    Object? loopTestnetStampText,
  ) {
    return '发射台 · $loopTestnetStampText';
  }

  @override
  String launch2_launch2LaunchpadLaunch2RelativeTime(Object? inMinutes) {
    return '$inMinutes 分钟前';
  }

  @override
  String get launch2_launch2LaunchpadLaunch2TapeActor => '有人';

  @override
  String get launch2_launch2LaunchpadLaunch2TapeFaceName => '这位用户';

  @override
  String get launch2_launch2LaunchpadLoopLabel => '实时成交';

  @override
  String launch2_launch2LaunchpadNftMint(Object? ticker, Object? who) {
    return '$who铸造 $ticker 勋章';
  }

  @override
  String launch2_launch2LaunchpadRewardClaimed(
    Object? ticker,
    Object? usd1,
    Object? who,
  ) {
    return '$who领取 $ticker 奖励$usd1';
  }

  @override
  String launch2_launch2LaunchpadRoundActivated(Object? ticker) {
    return '$ticker 外盘新一轮激活';
  }

  @override
  String get launch2_launch2LaunchpadS => '发射台 · BSC';

  @override
  String get launch2_launch2LaunchpadSemantics => '活动';

  @override
  String get launch2_launch2LaunchpadTitle => '暂无进行中的发射';

  @override
  String get launch2_launch2LaunchpadUpcoming => '预告';

  @override
  String get launch2_launch2ListEmptyMessage => '还没有 v2 项目';

  @override
  String get launch2_launch2ListIf => '暂时连不上 LOOP';

  @override
  String get launch2_launch2ListLabel => '看正在发射的';

  @override
  String get launch2_launch2ListLabel2 => '看经典发射';

  @override
  String get launch2_launch2ListLaunch2LiveEmptyMessage => '现在没有铸造或内盘中的项目';

  @override
  String launch2_launch2ListMessage(Object? launch2CapabilityText) {
    return 'MEME v2 暂时不可用 · $launch2CapabilityText';
  }

  @override
  String get launch2_launch2ListS => 'MEME v2 状态还没有读到';

  @override
  String get launch2_launch2ListTitle => 'v2 发射';

  @override
  String get launch2_launch2ListTitle2 => '还没有毕业的 v2 项目';

  @override
  String get launch2_launch2NftBarrierLabel => '关闭选择 NFT';

  @override
  String get launch2_launch2NftButtonLabel => '开始后可铸造';

  @override
  String get launch2_launch2NftButtonLabel2 => '已持有 · 每地址 1 枚';

  @override
  String launch2_launch2NftButtonLabel3(Object? launch2Usd1Label) {
    return '铸造 1 枚 · $launch2Usd1Label';
  }

  @override
  String get launch2_launch2NftButtonLabel4 => '激活钱包后可铸造';

  @override
  String get launch2_launch2NftButtonLabel5 => '等待名单发布';

  @override
  String get launch2_launch2NftButtonLabel6 => '铸造已结束';

  @override
  String get launch2_launch2NftButtonLabel7 => '去项目页';

  @override
  String get launch2_launch2NftCardSemantics => '默认图';

  @override
  String get launch2_launch2NftEntry => '进快照名单';

  @override
  String get launch2_launch2NftEntry2 => '铸造结束时持有，进入快照名单；名单发布后有 1 小时提前购内盘';

  @override
  String get launch2_launch2NftEntry3 => '托管与回购';

  @override
  String launch2_launch2NftEntry4(Object? launch2Usd1Label) {
    return '铸造款进入本项目的托管合约，毕业后由平台按每笔 $launch2Usd1Label 回购 MEME';
  }

  @override
  String get launch2_launch2NftEntry5 => '每地址 1 枚';

  @override
  String launch2_launch2NftEntry6(Object? launch2Usd1Label) {
    return '每个地址终身只能铸 1 枚 · $launch2Usd1Label / 枚';
  }

  @override
  String launch2_launch2NftEntry7(Object? launch2SaleDurationLabel) {
    return '铸造期 $launch2SaleDurationLabel';
  }

  @override
  String launch2_launch2NftIf(Object? tokenId) {
    return '#$tokenId · 已在快照名单';
  }

  @override
  String launch2_launch2NftIf2(Object? tokenId) {
    return '#$tokenId · 已在候选名单';
  }

  @override
  String launch2_launch2NftLaunch2NftMedalPictureLabel(
    Object? bottomLabel,
    Object? ticker,
  ) {
    return '$ticker 共识勋章，$bottomLabel';
  }

  @override
  String get launch2_launch2NftLaunch2NftMintedToast => '已铸造 · 等待铸造结束进入名单';

  @override
  String get launch2_launch2NftLaunch2NftProvenanceDetail =>
      '阶段与倒计时由服务端按链上时间给出，到点后重新读取。';

  @override
  String get launch2_launch2NftLoopLabel => '这枚勋章能做什么';

  @override
  String get launch2_launch2NftLoopLabel2 => '我的勋章';

  @override
  String get launch2_launch2NftLoopLabel3 => '选择要发送的 NFT';

  @override
  String launch2_launch2NftMintConfirmLabel(Object? noun) {
    return '继续$noun';
  }

  @override
  String launch2_launch2NftMintHeading(Object? noun, Object? ticker) {
    return '$noun $ticker 共识勋章';
  }

  @override
  String get launch2_launch2NftMintLaunch2ActionFailure => '还没有可用的钱包，激活钱包后再铸造';

  @override
  String get launch2_launch2NftMintNoun => '铸造';

  @override
  String get launch2_launch2NftS => '共识勋章';

  @override
  String launch2_launch2NftSale(Object? left, Object? soldCount) {
    return '已铸 $soldCount$left';
  }

  @override
  String launch2_launch2NftStatus(Object? launch2SnapshotPendingTitle) {
    return '铸造已结束 · $launch2SnapshotPendingTitle';
  }

  @override
  String get launch2_launch2NftStatus2 => '铸造期内无人铸造，已直接进入公开轮';

  @override
  String get launch2_launch2NftStatus3 => '内盘已开放';

  @override
  String get launch2_launch2NftStatus4 => '铸造期内无人铸造，项目已关闭';

  @override
  String get launch2_launch2NftText => '已广播，但还没有读到确认。它可能仍在确认中，请稍后再查；不要重复铸造。';

  @override
  String get launch2_launch2NftToProject => '去项目页交易';

  @override
  String get launch2_launch2PoolTradePanelLaunch2DynPanelNote =>
      '用任何软件买入都计入奖励，记给收到 MEME 的地址';

  @override
  String get launch2_launch2PoolTradePanelLaunch2GoSwapLabel => '也可以在钱包兑换里交易';

  @override
  String get launch2_launch2PoolTradePanelLaunch2PoolMaxLabel => '填入全部可卖';

  @override
  String get launch2_launch2PoolTradePanelLaunch2PoolModeCaption => '输入方式';

  @override
  String get launch2_launch2PoolTradePanelLaunch2PoolSlippageCustomLabel =>
      '自定义';

  @override
  String get launch2_launch2PoolTradePanelLaunch2PoolTaxLabel => '外盘交易';

  @override
  String get launch2_launch2PoolTradePanelLoopProvenanceLine => '官方池路由';

  @override
  String launch2_launch2PoolViewModelBase(Object? launch2BpsLabel) {
    return '基础税 $launch2BpsLabel';
  }

  @override
  String get launch2_launch2PoolViewModelConfirmLabel => '上一笔确认中…';

  @override
  String get launch2_launch2PoolViewModelConfirmLabel2 => '确认买入';

  @override
  String get launch2_launch2PoolViewModelConfirmLabel3 => '确认卖出';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText => '支付（含税）';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText2 => '想买入';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText3 => '想到手';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText4 => '按支付';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText5 => '按买入数量';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText6 => '按卖出数量';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolFailureText7 => '按到手金额';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolLine => '预计支付';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolLine2 => '最多支付';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolLine3 => '成交均价';

  @override
  String launch2_launch2PoolViewModelLaunch2PoolLine4(
    Object? launch2BuyFeeSideText,
    Object? rate,
  ) {
    return '基础税 $rate（$launch2BuyFeeSideText）';
  }

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolLine5 => '本笔计入奖励权重';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolLine6 => '奖励权重';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolLine7 => '当前未激活，不计奖励';

  @override
  String launch2_launch2PoolViewModelLaunch2PoolLine8(
    Object? base,
    Object? launch2BpsLabel,
  ) {
    return '$base + 当前动态税 $launch2BpsLabel（扣 USD1）';
  }

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolLine9 => '其中动态税';

  @override
  String launch2_launch2PoolViewModelLaunch2PoolSlippageFromInput(
    Object? launch2MemeLabel,
    Object? usd1,
  ) {
    return '$launch2MemeLabel · 付 $usd1';
  }

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolTradeView =>
      '官方池信息还在同步，暂时不能交易';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolTradeView2 =>
      '外盘交易暂未开放（路由未配置）';

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolTradeView3 =>
      '还没有可用的钱包，激活钱包后可交易';

  @override
  String launch2_launch2PoolViewModelLaunch2PoolTradeView4(
    Object? launch2MemeLabel,
  ) {
    return '卖出数量超过可卖 $launch2MemeLabel';
  }

  @override
  String launch2_launch2PoolViewModelLaunch2PoolTradeView5(
    Object? usd1,
    Object? usd12,
  ) {
    return 'USD1 余额不足：最多需要 $usd1，钱包有 $usd12';
  }

  @override
  String get launch2_launch2PoolViewModelLaunch2PoolTradeView6 => '正在向官方池报价…';

  @override
  String launch2_launch2PoolViewModelLaunch2PoolTradeView7(
    Object? launch2MemeLabel,
  ) {
    return '持有 $launch2MemeLabel';
  }

  @override
  String launch2_launch2PoolViewModelNull(Object? launch2PoolFailureText) {
    return '没有取到报价 · $launch2PoolFailureText';
  }

  @override
  String launch2_launch2PoolViewModelProvenance(
    Object? quote,
    Object? quotedAtBlock,
  ) {
    return '按区块 $quotedAtBlock 的官方池计算，$quote；到期自动重新报价。';
  }

  @override
  String launch2_launch2PoolViewModelProvenance2(
    Object? launch2BpsLabel,
    Object? quotedAtBlock,
  ) {
    return '按区块 $quotedAtBlock 的官方池计算，已扣 $launch2BpsLabel 外盘税；到期自动重新报价。';
  }

  @override
  String get launch2_launch2PoolViewModelS => '外盘路由未配置，暂不可交易';

  @override
  String get launch2_launch2PoolViewModelS10 => '池子不支持这种交易方式';

  @override
  String get launch2_launch2PoolViewModelS11 => '池子正忙，请稍后重试';

  @override
  String get launch2_launch2PoolViewModelS12 => '本轮还没有结束，结束后才能领取';

  @override
  String get launch2_launch2PoolViewModelS13 => '本轮奖励已经领取过';

  @override
  String get launch2_launch2PoolViewModelS14 => '这次领取已经记录了另一笔交易';

  @override
  String get launch2_launch2PoolViewModelS15 => '找不到这次领取请求';

  @override
  String get launch2_launch2PoolViewModelS16 => '预计到手';

  @override
  String get launch2_launch2PoolViewModelS17 => '最少到手';

  @override
  String get launch2_launch2PoolViewModelS18 => '预计卖出';

  @override
  String get launch2_launch2PoolViewModelS19 => '最多卖出';

  @override
  String get launch2_launch2PoolViewModelS2 => '外盘路由校验未通过，暂不可交易';

  @override
  String launch2_launch2PoolViewModelS20(
    Object? launch2MemeLabel,
    Object? launch2MemeLabel2,
    Object? tickerLabel,
  ) {
    return '$tickerLabel 余额不足：最多需要 $launch2MemeLabel，钱包有 $launch2MemeLabel2';
  }

  @override
  String get launch2_launch2PoolViewModelS21 => '输入金额后显示报价';

  @override
  String launch2_launch2PoolViewModelS22(
    Object? launch2MemeLabel,
    Object? launch2MemeLabel2,
  ) {
    return '持有 $launch2MemeLabel · 可卖 $launch2MemeLabel2';
  }

  @override
  String launch2_launch2PoolViewModelS23(
    Object? launch2MemeLabel,
    Object? usd1,
  ) {
    return '$launch2MemeLabel · 得 $usd1';
  }

  @override
  String get launch2_launch2PoolViewModelS3 => '外盘路由与池子不匹配，暂不可交易';

  @override
  String get launch2_launch2PoolViewModelS4 => '外盘池子校验未通过，暂不可交易';

  @override
  String get launch2_launch2PoolViewModelS5 => '外盘池子尚未初始化';

  @override
  String get launch2_launch2PoolViewModelS6 => '该池子只支持按支付金额交易';

  @override
  String get launch2_launch2PoolViewModelS7 => '该项目的外盘没有奖励轮次';

  @override
  String get launch2_launch2PoolViewModelS8 => '轮次编号无效';

  @override
  String get launch2_launch2PoolViewModelS9 => '池子拒绝了这个交易入口';

  @override
  String get launch2_launch2PoolViewModelSwitch => '官方池试算没有通过，换个金额再试';

  @override
  String get launch2_launch2PoolViewModelSwitch2 => '项目还没有毕业，官方池尚未开放';

  @override
  String get launch2_launch2PoolViewModelSwitch3 => '官方池流动性不足，换个小一点的金额试试';

  @override
  String get launch2_launch2PoolViewModelSwitch4 => '这个金额太小，换算后为 0';

  @override
  String get launch2_launch2PoolViewModelSwitch5 => '外盘交易暂时关闭，平台正在核对官方池';

  @override
  String get launch2_launch2PoolViewModelSwitch6 => 'USD1 余额不足，没有发起任何交易';

  @override
  String get launch2_launch2PoolViewModelSwitch7 => '卖出数量超过持有，没有发起任何交易';

  @override
  String launch2_launch2PoolViewModelTaxLabel(Object? launch2BpsLabel) {
    return '外盘税 $launch2BpsLabel + 卖出动态税';
  }

  @override
  String get launch2_launch2PoolViewModelText => '钱包余额暂时读不到 · 报价后显示';

  @override
  String launch2_launch2PoolViewModelText2(Object? launch2MemeLabel) {
    return '内盘净买入 $launch2MemeLabel · 钱包余额报价后显示';
  }

  @override
  String launch2_launch2Public(
    Object? launch2BpsLabel,
    Object? launch2PriceLabel,
  ) {
    return '内盘进度 $launch2BpsLabel，当前价 $launch2PriceLabel';
  }

  @override
  String get launch2_launch2SigningActive => '请在钱包确认';

  @override
  String get launch2_launch2SigningConfirmLabel => '继续铸造';

  @override
  String launch2_launch2SigningCurve(Object? noun) {
    return '确认$noun';
  }

  @override
  String get launch2_launch2SigningFailed => '未完成';

  @override
  String launch2_launch2SigningHeading(Object? ticker) {
    return '铸造 $ticker 共识勋章';
  }

  @override
  String launch2_launch2SigningIf(
    Object? launch2BpsLabel,
    Object? launch2BpsLabel2,
  ) {
    return '基础税 $launch2BpsLabel + 动态税 $launch2BpsLabel2';
  }

  @override
  String launch2_launch2SigningIf2(
    Object? launch2BpsLabel,
    Object? launch2BuyFeeSideText,
  ) {
    return '基础税 $launch2BpsLabel（$launch2BuyFeeSideText）';
  }

  @override
  String launch2_launch2SigningIf3(Object? launch2ShortAddress, Object? noun) {
    return '授权已广播（$launch2ShortAddress），但$noun交易的钱包结果未知，已锁定。不要重复签名，稍后刷新查看。';
  }

  @override
  String launch2_launch2SigningIf4(Object? noun) {
    return '钱包的结果未知，这笔$noun已锁定。不要重复签名，稍后刷新查看。';
  }

  @override
  String launch2_launch2SigningIf5(Object? launch2ShortAddress) {
    return '已广播（$launch2ShortAddress）。广播不代表已成交，链上确认后这里会更新。';
  }

  @override
  String launch2_launch2SigningIntentField(Object? meme) {
    return '在官方池买入 $meme';
  }

  @override
  String launch2_launch2SigningIntentField2(Object? meme) {
    return '在官方池卖出 $meme';
  }

  @override
  String get launch2_launch2SigningIntentField3 => '授权前无法试算';

  @override
  String get launch2_launch2SigningLabel => '最多支付（含税）';

  @override
  String get launch2_launch2SigningLabel2 => '先授权';

  @override
  String get launch2_launch2SigningLabel3 => '价格';

  @override
  String launch2_launch2SigningLaunch2NftRisk(Object? launch2NftRiskSentence) {
    return '我已知晓：$launch2NftRiskSentence。';
  }

  @override
  String get launch2_launch2SigningLaunch2NftRiskSentence =>
      '不保证成交、不保证配售，公开内盘可能不发生';

  @override
  String launch2_launch2SigningLaunch2NftRiskTickLabel(
    Object? launch2NftRiskSentence,
  ) {
    return '我已知晓：$launch2NftRiskSentence';
  }

  @override
  String get launch2_launch2SigningLaunch2RefreshedText =>
      '已刷新报价：原报价即将到期，已按最新区块重新报价，金额在你确认的范围内';

  @override
  String get launch2_launch2SigningLoopDynamicRewards => '确认领取外盘奖励';

  @override
  String launch2_launch2SigningNftMint(Object? noun, Object? ticker) {
    return '$noun $ticker 共识勋章（每个地址 1 枚）';
  }

  @override
  String launch2_launch2SigningOfficialPool(Object? noun) {
    return '确认外盘$noun';
  }

  @override
  String get launch2_launch2SigningOfficialPool2 => '路由';

  @override
  String launch2_launch2SigningReason(Object? noun) {
    return '会依次打开两次钱包：先授权，再$noun。授权金额只够这一笔。';
  }

  @override
  String get launch2_launch2SigningRefreshing => '正在刷新报价';

  @override
  String get launch2_launch2SigningRewardClaim => '领取奖励';

  @override
  String launch2_launch2SigningRewardClaim2(Object? meme) {
    return '领取 $meme 外盘奖励';
  }

  @override
  String get launch2_launch2SigningS => '曲线合约';

  @override
  String launch2_launch2SigningS2(Object? launch2BpsLabel) {
    return '税 $launch2BpsLabel';
  }

  @override
  String launch2_launch2SigningS3(Object? meme) {
    return '买入 $meme';
  }

  @override
  String launch2_launch2SigningS4(Object? meme) {
    return '卖出 $meme';
  }

  @override
  String launch2_launch2SigningS5(Object? launch2PoolFailureText) {
    return '没有取到新报价（$launch2PoolFailureText）';
  }

  @override
  String launch2_launch2SigningSetState(Object? noun, Object? noun2) {
    return '授权已广播，$noun没有签名，没有提交$noun2交易。可以关闭后重新发起。';
  }

  @override
  String get launch2_launch2SigningShowLaunch2NftConfirmSheet =>
      '持有 NFT 的地址进入快照名单，可参加 1 小时提前购。';

  @override
  String get launch2_launch2SigningSwitch => '奖励合约';

  @override
  String get launch2_launch2SigningSwitch10 =>
      '服务端构造交易用的钱包与当前钱包不一致，已拒绝签名，没有提交任何交易。';

  @override
  String get launch2_launch2SigningSwitch11 => '这条链不允许签名，没有提交任何交易。';

  @override
  String get launch2_launch2SigningSwitch12 => '钱包暂时不能在这条链上签名，没有提交任何交易。';

  @override
  String get launch2_launch2SigningSwitch13 => '当前登录的钱包不是这笔交易的钱包，没有提交任何交易。';

  @override
  String get launch2_launch2SigningSwitch14 => '钱包没有完成签名，没有提交任何交易。';

  @override
  String get launch2_launch2SigningSwitch15 => '授权还在链上确认';

  @override
  String get launch2_launch2SigningSwitch16 => '最新报价超出了你确认的范围';

  @override
  String get launch2_launch2SigningSwitch17 => '没有取到新报价';

  @override
  String get launch2_launch2SigningSwitch18 => '新的交易内容没有通过核对';

  @override
  String launch2_launch2SigningSwitch19(
    Object? noun,
    Object? noun2,
    Object? why,
  ) {
    return '授权已广播。原报价即将到期，刷新时$why，$noun没有签名，没有提交$noun2交易。稍后重新发起，授权足够时只需签一次。';
  }

  @override
  String get launch2_launch2SigningSwitch2 => 'NFT 合约';

  @override
  String launch2_launch2SigningSwitch20(Object? noun) {
    return '授权已广播，$noun没有签名。可以重新发起。';
  }

  @override
  String launch2_launch2SigningSwitch3(Object? spenderNoun) {
    return '授权给$spenderNoun';
  }

  @override
  String get launch2_launch2SigningSwitch4 => '已取消，没有发生任何变化。';

  @override
  String get launch2_launch2SigningSwitch5 => '身份验证没有通过，没有发生任何变化。';

  @override
  String get launch2_launch2SigningSwitch6 => '这笔交易已过期，没有提交任何交易。请重新发起。';

  @override
  String get launch2_launch2SigningSwitch7 => '试算没有通过，这笔交易在链上会被拒绝。没有提交任何交易。';

  @override
  String get launch2_launch2SigningSwitch8 => '交易内容与确认内容不一致，已拒绝签名，没有提交任何交易。';

  @override
  String get launch2_launch2SigningSwitch9 => '钱包目录里找不到这笔交易的钱包，没有提交任何交易。';

  @override
  String get launch2_launch2SigningTitle => '授权';

  @override
  String get launch2_launch2SigningUnknown => '结果未知';

  @override
  String get launch2_launch2SigningValue => '每个地址终身 1 枚';

  @override
  String get launch2_launch2Switch => '后开始铸造';

  @override
  String get launch2_launch2TradePanelBuild => '提前购仅限名单内持有人，公开内盘开始后可买入';

  @override
  String get launch2_launch2TradePanelBuild2 => '累计额度';

  @override
  String launch2_launch2TradePanelIf(Object? launch2Usd1Label) {
    return '填入 $launch2Usd1Label';
  }

  @override
  String get launch2_launch2TradePanelLabel => '退回';

  @override
  String launch2_launch2TradePanelLaunch2CurveMinOutNote(
    Object? launch2BpsLabel,
  ) {
    return '按当前曲线价计算，已含 $launch2BpsLabel 滑点保护，成交以链上为准';
  }

  @override
  String get launch2_launch2TradePanelLaunch2EligibilityBadge => '名单内';

  @override
  String get launch2_launch2TradePanelLaunch2EligibilityBadge2 => '不在名单';

  @override
  String launch2_launch2TradePanelLaunch2TradeExceeds(
    Object? launch2LimitedByText,
    Object? side,
  ) {
    return '超出可$side上限（$launch2LimitedByText）';
  }

  @override
  String get launch2_launch2TradePanelLaunch2TradeMaxLabel => '填入最大可买';

  @override
  String get launch2_launch2TradePanelLaunch2TradeQuoteEmpty => '正在报价…';

  @override
  String launch2_launch2TradePanelLaunch2TradeQuoteFailedMessage(
    Object? failureText,
  ) {
    return '没有取到报价 · $failureText';
  }

  @override
  String launch2_launch2TradePanelLaunch2TradeQuoteProvenanceDetail(
    Object? basisBlockNumber,
    Object? launch2BpsLabel,
  ) {
    return '报价按区块 $basisBlockNumber 的曲线计算，含 10% 税；滑点 $launch2BpsLabel，到期自动重新报价。';
  }

  @override
  String launch2_launch2TradePanelLaunch2TradeTax(Object? launch2BpsLabel) {
    return '税率 $launch2BpsLabel';
  }

  @override
  String get launch2_launch2TradePanelLoopProvenanceLine => '链上曲线';

  @override
  String launch2_launch2TradePanelS(Object? launch2MemeLabel) {
    return '填入 $launch2MemeLabel';
  }

  @override
  String get launch2_launch2TradePanelSemanticLabel => '累计额度暂时读不到';

  @override
  String launch2_launch2TradePanelSemanticLabel2(
    Object? launch2CurveCapSentence,
    Object? launch2MemeFigure,
    Object? tickerLabel,
  ) {
    return '累计额度已用 $launch2MemeFigure $tickerLabel，$launch2CurveCapSentence';
  }

  @override
  String get launch2_launch2WalletRowsLaunch2WalletChainLabel => 'Launch 链';

  @override
  String get launch2_launch2WalletRowsLaunch2WalletUnavailableMessage =>
      'MEME v2 持仓暂时读不到';

  @override
  String launch2_launch2WalletRowsSubtitle(Object? launch2WalletChainLabel) {
    return '$launch2WalletChainLabel · 内盘持仓';
  }

  @override
  String get launch2_launchpadSomeoneWho => '有人';

  @override
  String launch2_nftRiskBody(Object? sentence) {
    return '$sentence。';
  }

  @override
  String launch2_nftSaleLeft(Object? left) {
    return '，剩余 $left';
  }

  @override
  String launch2_poolPanelTax(Object? bps) {
    return '外盘税 $bps';
  }

  @override
  String get launch2_poolTradesRateLimited => '请求太频繁，稍后再试';

  @override
  String launch2_provenanceBuyFeeFromUsd1(Object? bps) {
    return '已从付出的 USD1 扣 $bps 基础税';
  }

  @override
  String launch2_provenancePoolTax(Object? bps) {
    return '已扣 $bps 外盘税';
  }

  @override
  String get launch2_provenanceSellPostSwap => '已扣基础税与动态税（按成交后跌幅模拟）';

  @override
  String get launch2_provenanceSellPreSwap => '已扣基础税与动态税（按成交前跌幅模拟）';

  @override
  String get launch2_sideBuy => '买';

  @override
  String get launch2_sideSell => '卖';

  @override
  String get launch2_tickerSeparator => '；';

  @override
  String get notifications_applicationNoReason => '运维没有给出原因。修改社区资料后可以重新提交。';

  @override
  String notifications_applicationReason(Object? reason) {
    return '原因：$reason';
  }

  @override
  String notifications_applicationRejected(Object? subject) {
    return '$subject未通过审核';
  }

  @override
  String get notifications_applicationSubject => '你的社区';

  @override
  String notifications_applicationSubjectNamed(Object? communityName) {
    return '你的社区「$communityName」';
  }

  @override
  String notifications_applicationVerified(Object? subject) {
    return '$subject已通过审核';
  }

  @override
  String get notifications_applicationVerifiedBody => '已显示验证标记，挖矿权重与官方群已开放。';

  @override
  String get notifications_badgeMinted => '共识勋章铸造完成';

  @override
  String notifications_bellUnread(Object? label) {
    return '通知，未读 $label 条';
  }

  @override
  String get notifications_categoryAnnouncement => '公告';

  @override
  String get notifications_categoryCommunityAll => '全部消息';

  @override
  String get notifications_categoryCommunityAllDetail => '大群建议关闭';

  @override
  String get notifications_categoryGraduation => '毕业通知';

  @override
  String get notifications_categoryLaunchRound => '资格快照与开始提醒';

  @override
  String get notifications_categoryLaunchRoundDetail => '含共识勋章、发射审核结果与上链进度';

  @override
  String get notifications_categoryMention => '@我的消息';

  @override
  String get notifications_categoryPriceAlertDetail => '关闭后价格提醒仍会记录事件，但不会生成通知';

  @override
  String get notifications_categorySecurityDetail => '无法关闭';

  @override
  String get notifications_categorySettlement => '每日结算完成';

  @override
  String get notifications_categoryTradeResult => '成交结果';

  @override
  String get notifications_categoryWeight => '权重变化';

  @override
  String get notifications_categoryWeightDetail => '持有币的 Mining Weight 调整时';

  @override
  String get notifications_deployFailed => '部署失败';

  @override
  String get notifications_deviceSessionRevoked => '撤销了一个设备会话';

  @override
  String get notifications_earlier => '更早';

  @override
  String get notifications_emptyMessage => '代币毕业、勋章铸造、好友申请和安全提醒会出现在这里。';

  @override
  String get notifications_emptyTitle => '还没有通知';

  @override
  String get notifications_friendAccepted => '好友申请已通过';

  @override
  String notifications_friendAcceptedBody(Object? name) {
    return '你和 $name 已成为好友';
  }

  @override
  String get notifications_friendRequest => '新的好友申请';

  @override
  String notifications_friendRequestBody(Object? name) {
    return '$name 想加你为好友';
  }

  @override
  String get notifications_graduated => '你参与的项目已毕业';

  @override
  String notifications_graduatedNamed(Object? subject) {
    return '$subject 已毕业';
  }

  @override
  String get notifications_launchApprovedBody => '请完成签名，发射才会部署';

  @override
  String get notifications_launchDeployFailed => '发射部署失败';

  @override
  String get notifications_launchOnChain => '你的发射已上链';

  @override
  String get notifications_launchReviewApproved => '发射审核已通过';

  @override
  String get notifications_launchReviewRejected => '发射审核未通过';

  @override
  String notifications_launchSaleStart(Object? saleStartAt) {
    return '开售时间 $saleStartAt';
  }

  @override
  String get notifications_onChain => '已上链';

  @override
  String notifications_priceAlertBody(Object? observed, Object? threshold) {
    return '目标 $threshold · 观察值 $observed';
  }

  @override
  String get notifications_priceAlertTriggered => '价格提醒已触发';

  @override
  String notifications_priceAlertTriggeredNamed(Object? symbol) {
    return '$symbol 价格提醒已触发';
  }

  @override
  String get notifications_readAll => '全部已读';

  @override
  String get notifications_readAllDone => '已全部标为已读';

  @override
  String get notifications_readAllFailed => '没有标记成功，请稍后再试';

  @override
  String get notifications_reviewApproved => '审核已通过';

  @override
  String get notifications_reviewRejected => '审核未通过';

  @override
  String get notifications_securityEvent => '安全事件';

  @override
  String get notifications_settingsSubtitle => '选择想收到哪些通知';

  @override
  String notifications_source(Object? factSourceLabel) {
    return '来源 $factSourceLabel';
  }

  @override
  String notifications_unreadCount(Object? unreadCount) {
    return '未读 $unreadCount 条';
  }

  @override
  String get profileSettings_aboutAndLegal => '关于与法务';

  @override
  String get profileSettings_appLock => '应用锁';

  @override
  String get profileSettings_appLockCapabilityUnknown => '还没有读到这台设备的锁屏能力';

  @override
  String profileSettings_appLockNotPersisted(Object? appLockFactorText) {
    return '$appLockFactorText · 这次有效，重开 App 后不会记得';
  }

  @override
  String get profileSettings_appLockOff => '已关闭';

  @override
  String profileSettings_appLockSemantic(Object? appLockLabel) {
    return '应用锁，$appLockLabel，点按后验证身份可切换';
  }

  @override
  String profileSettings_appLockUnavailableSemantic(Object? appLockDetail) {
    return '应用锁，不可用：$appLockDetail';
  }

  @override
  String get profileSettings_capabilityBlocked => '账号设置当前不可用';

  @override
  String get profileSettings_currency => '货币单位';

  @override
  String get profileSettings_displaySavedLocally => '只保存在本机，不写入账号，也不调用后端';

  @override
  String get profileSettings_displaySaving => '已生效，正在保存到本机';

  @override
  String get profileSettings_displaySessionOnly => '本次运行内生效；本机保存当前不可用';

  @override
  String get profileSettings_empty => '还没有账号设置';

  @override
  String get profileSettings_fixedThemeNote => '主题在当前版本固定，不能更改。';

  @override
  String get profileSettings_fixedValuesNote => '货币单位与主题在当前版本固定，不能更改。';

  @override
  String get profileSettings_general => '通用';

  @override
  String get profileSettings_helpAndSupport => '帮助与客服';

  @override
  String get profileSettings_reduceMotion => '减少动效';

  @override
  String profileSettings_reduceMotionSemantic(Object? preferences) {
    return '减少动效，$preferences';
  }

  @override
  String get profileSettings_storageUnavailableBody =>
      '减少动效仍会在本次运行内生效。重试只会再读一次本机存储，不会使用账号或后端。';

  @override
  String get profileSettings_storageUnavailableTitle => '本机保存不可用';

  @override
  String get profileSettings_theme => '主题';

  @override
  String get profileSettings_themeDark => '深色';

  @override
  String profileSettings_updatedAt(Object? relativeTime) {
    return '更新于 $relativeTime';
  }

  @override
  String get profileSettings_usingDefaults => '当前使用默认设置';

  @override
  String get scan_cameraDeniedBody => '扫码功能不可用；可在 系统设置 → LOOP → 相机 中重新开启。';

  @override
  String get scan_cameraErrorReason => '相机没有打开。可以重试，或改用下方的「相册」。';

  @override
  String get scan_cameraNoAccess => '没有相机权限';

  @override
  String get scan_cameraOpening => '正在打开相机…';

  @override
  String get scan_cameraUnsupported => '这台设备没有可用的相机';

  @override
  String get scan_cameraUnsupportedDetail => '可以改用下方的「相册」识别二维码图片。';

  @override
  String get scan_contentCopied => '已复制二维码内容';

  @override
  String get scan_hint => '对准 LOOP 名片、邀请海报、社区二维码或钱包地址二维码。';

  @override
  String get scan_imageNoCode => '这张图片里没有识别到二维码';

  @override
  String get scan_imageNoPhotoAccess => '没有相册权限，去系统设置里允许 LOOP 访问照片后再试';

  @override
  String get scan_imageUnreadable => '图片没有读出来，请换一张再试';

  @override
  String get scan_keepScanning => '继续扫描';

  @override
  String get scan_pickImageLabel => '相册';

  @override
  String get scan_pickImageReading => '正在读取…';

  @override
  String get scan_pickImageSemantic => '从相册选图';

  @override
  String get scan_torch => '手电筒';

  @override
  String get scan_torchOff => '关闭手电筒';

  @override
  String get scan_unavailable => '扫码当前不可用';

  @override
  String get scan_unavailableDetail => '这个版本没有装配相机扫码，本页不会打开相机。';

  @override
  String get scan_unknownBody => 'LOOP 不会打开这段内容，只把它显示在下面。';

  @override
  String get scan_unknownTitle => '不是 LOOP 二维码';

  @override
  String get securityAppLock_controllerReason => '验证身份以开启应用锁';

  @override
  String get securityAppLock_controllerReason2 => '验证身份以关闭应用锁';

  @override
  String get securityAppLock_controllerReason3 => '验证身份以进入 LOOP';

  @override
  String get securityAppLock_gateBiometric => '用这台设备的生物识别解锁；识别不了时会退回设备密码';

  @override
  String get securityAppLock_gateCanceled => '你取消了这次验证。';

  @override
  String get securityAppLock_gateDeviceCredential => '用这台设备的锁屏密码解锁';

  @override
  String get securityAppLock_gateFailed => '没有通过验证，可以再试一次。';

  @override
  String get securityAppLock_gateLockedOut => '系统暂时停用了验证，等一会儿再试，或改用设备密码。';

  @override
  String get securityAppLock_gateLoopAppLockUnlockLabel => '正在验证…';

  @override
  String get securityAppLock_gateLoopAppLockUnlockLabel2 => '验证身份';

  @override
  String get securityAppLock_gateLoopAppLockUnlockSemanticLabel => 'LOOP 已锁定';

  @override
  String get securityAppLock_gateNoCredentialSet =>
      '这台设备还没有设置锁屏密码或生物识别，先在系统设置里加上';

  @override
  String securityAppLock_gateS(Object? systemMessage) {
    return '验证没有完成 · 系统提示：$systemMessage';
  }

  @override
  String get securityAppLock_gateSucceeded => '验证通过。';

  @override
  String get securityAppLock_gateSwitch => '验证没有完成。';

  @override
  String get securityAppLock_gateSwitch2 => '还没有读到这台设备的锁屏能力';

  @override
  String get securityAppLock_gateUnavailable => '这台设备现在没有可用的锁屏验证。';

  @override
  String get securityAppLock_gateUnsupportedPlatform => '这台设备不支持锁屏验证';

  @override
  String get securityAppLock_promptAppLockPromptEnableLabel => '开启';

  @override
  String get securityAppLock_promptAppLockPromptLaterLabel => '以后再说';

  @override
  String get securityAppLock_promptLoopAppLockPromptBody =>
      '切到后台 60 秒后回来需要 Face ID / 指纹，钱包和聊天更安全';

  @override
  String get securityAppLock_promptLoopSheetHeading => '开启应用锁';

  @override
  String get securityMfa_controllerConfirmOwnerPresent => '解绑 Passkey 前先验证一次身份';

  @override
  String get securityMfa_modelsSms => '短信';

  @override
  String get securityMfa_modelsTotp => '验证器 App';

  @override
  String get securityMfa_passkeySheetBuild =>
      'Passkey 由这台设备的系统保管，登录服务只记下它的公钥。换手机后，用同一个系统账号同步过去的 Passkey 就能再次进入。';

  @override
  String get securityMfa_passkeySheetCancelled => '这次没有完成';

  @override
  String get securityMfa_passkeySheetLoopLabel => '已绑定';

  @override
  String get securityMfa_passkeySheetPasskeySheetConfirmBody =>
      '解绑前设备会先验证一次身份。系统里的那份 Passkey 由系统管理，LOOP 删不掉它，只是登录服务不再认它。';

  @override
  String get securityMfa_passkeySheetPasskeySheetConfirmTitle => '解绑后这条路就没有了';

  @override
  String get securityMfa_passkeySheetPasskeySheetEmptyMessage =>
      '绑定后，这台设备的面容或指纹就是一条独立的回来路。';

  @override
  String get securityMfa_passkeySheetPasskeySheetEmptyTitle =>
      '这个账号还没有 Passkey';

  @override
  String get securityMfa_passkeySheetPasskeySheetLinkLabel => '绑定 Passkey';

  @override
  String get securityMfa_passkeySheetPasskeySheetLinkLabel2 => '再绑定一个 Passkey';

  @override
  String get securityMfa_passkeySheetPasskeySheetUnknownTitle => '还没有读到登录服务的回答';

  @override
  String get securityMfa_passkeySheetPasskeySheetUnlinkLabel => '正在解绑…';

  @override
  String get securityMfa_passkeySheetPasskeySheetUnlinkLabel2 => '确认解绑';

  @override
  String securityMfa_passkeySheetSemanticLabel(Object? passkey) {
    return '$passkey，已设置，点按后可以解绑';
  }

  @override
  String get securityMfa_passkeySheetSubtitle => '也用作二次验证';

  @override
  String get securityMfa_passkeySheetSubtitle2 => '用于登录与恢复';

  @override
  String get securityMfa_passkeySheetText => '这次运行还没有得到登录服务的回答。';

  @override
  String get securityMfa_passkeySheetTitle => '这个账号的 Passkey';

  @override
  String get securityMfa_passkeySheetTrailing => '已设置';

  @override
  String get securityMfa_sheetBuild => '两种方式都由登录服务保管，LOOP 不保存密钥，也不保存 Passkey。';

  @override
  String get securityMfa_sheetBuild2 => '关闭后，登录服务在要求二次验证时不会再问你验证码。';

  @override
  String get securityMfa_sheetCancelled => '系统的验证没有完成，这次什么都没有改变。';

  @override
  String get securityMfa_sheetDeviceUnsupported =>
      '这台设备没有可用的 Passkey，系统没有提供可以创建的地方。';

  @override
  String get securityMfa_sheetInvalidCode => '验证码不对或者已经过期，重新输入一次。';

  @override
  String get securityMfa_sheetLoopLabel => '手动输入的密钥';

  @override
  String get securityMfa_sheetLoopLabel2 => '验证器给出的 6 位码';

  @override
  String get securityMfa_sheetLoopPasskeyDomainPending =>
      '还要先给 LOOP 配好 Passkey 用的域名凭据，当前版本还没有';

  @override
  String get securityMfa_sheetMessage => '已复制密钥';

  @override
  String get securityMfa_sheetMfaSheetBeginLabel => '获取密钥';

  @override
  String get securityMfa_sheetMfaSheetFailureTitle => '登录服务尚未开启 MFA';

  @override
  String get securityMfa_sheetMfaSheetFailureTitle2 => '这一步没有完成';

  @override
  String get securityMfa_sheetMfaSheetPasskeyLabel => '正在等待系统验证…';

  @override
  String get securityMfa_sheetMfaSheetPasskeyLabel2 => '关闭 Passkey 验证';

  @override
  String get securityMfa_sheetMfaSheetPasskeyLabel3 => 'Passkey 开启二次验证';

  @override
  String get securityMfa_sheetMfaSheetPasskeyStatus =>
      '已开启 · Passkey。登录服务要求二次验证时，会让系统弹出 Passkey 验证。';

  @override
  String get securityMfa_sheetMfaSheetPasskeyStatus2 =>
      '这个账号已经有 Passkey，可以直接把它也用作二次验证。';

  @override
  String get securityMfa_sheetMfaSheetPasskeyStatus3 =>
      '用这台设备创建一个 Passkey，并把它作为二次验证方式。';

  @override
  String get securityMfa_sheetMfaSheetPasskeyUnavailableTitle => 'Passkey 暂不可用';

  @override
  String get securityMfa_sheetMfaSheetRemoveLabel => '正在关闭…';

  @override
  String get securityMfa_sheetMfaSheetRemoveLabel2 => '关闭 MFA';

  @override
  String get securityMfa_sheetMfaSheetSubmitLabel => '正在验证…';

  @override
  String get securityMfa_sheetMfaSheetSubmitLabel2 => '验证并开启';

  @override
  String get securityMfa_sheetMfaSheetTitle => '二次验证';

  @override
  String get securityMfa_sheetNotAuthenticated => '登录状态已经失效，重新登录后再试。';

  @override
  String get securityMfa_sheetNotEnabled =>
      '登录服务尚未开启 MFA。这不是这台设备的问题，也不是你账号的问题。';

  @override
  String get securityMfa_sheetPasskeyDomainUnconfigured =>
      '还要先给 LOOP 配好 Passkey 用的域名凭据，当前版本还没有。';

  @override
  String get securityMfa_sheetRejected => '这次没有完成。';

  @override
  String get securityMfa_sheetS =>
      '验证器 App 是手机上生成 6 位验证码的应用，例如 Google Authenticator、Microsoft Authenticator、1Password。用它扫码或输入密钥即可。密钥由登录服务签发，LOOP 不保存它。';

  @override
  String get securityMfa_sheetUnavailable => '暂时联系不上登录服务。';

  @override
  String get securityMfa_sheetUnknown => '没有完成，登录服务没有说明原因。';

  @override
  String get securityStepUp_controllerAsk => '验证身份以开启大额交易二次验证';

  @override
  String get securityStepUp_controllerAsk2 => '验证身份以提高大额交易的验证金额';

  @override
  String get securityStepUp_controllerAsk3 => '验证身份以签名这笔大额交易';

  @override
  String get securityStepUp_controllerAsk4 => '验证身份以签名这笔请求';

  @override
  String get securityStepUp_controllerS => '验证身份以关闭大额交易二次验证';

  @override
  String get securityStepUp_modelsIf => '金额需在 1 到 1,000,000 USD1 之间';

  @override
  String get securityStepUp_modelsLoopStepUpAfterApprovalText => '授权已发出，交易未发起。';

  @override
  String securityStepUp_modelsLoopStepUpSubtitle(Object? stepUpThresholdLabel) {
    return '达到 $stepUpThresholdLabel USD1 时再验一次身份';
  }

  @override
  String get securityStepUp_modelsLoopStepUpThresholdError => '请输入整数金额';

  @override
  String get securityStepUp_modelsSwitch => '已取消，没有发生任何变化。';

  @override
  String get securityStepUp_modelsSwitch2 => '身份验证没有通过，没有发生任何变化。';

  @override
  String get securityStepUp_widgetsActive => '请在钱包确认';

  @override
  String get securityStepUp_widgetsBuild => '这次有效，重开 App 后不会记得';

  @override
  String get securityStepUp_widgetsBuild2 => '签名的金额达到或超过这个数时，会先用这台设备验证身份。';

  @override
  String get securityStepUp_widgetsDone => '已验证';

  @override
  String get securityStepUp_widgetsError => '没有通过验证，金额没有改。';

  @override
  String get securityStepUp_widgetsFailed => '未完成';

  @override
  String get securityStepUp_widgetsHint => '例如 1000';

  @override
  String get securityStepUp_widgetsLabel => '验证身份';

  @override
  String get securityStepUp_widgetsLoopBadge => '读取中…';

  @override
  String get securityStepUp_widgetsLoopSheetHeading => '大额交易验证金额';

  @override
  String get securityStepUp_widgetsRefreshing => '验证中';

  @override
  String get securityStepUp_widgetsRefreshing2 => '正在刷新报价';

  @override
  String get securityStepUp_widgetsS => '正在签名并广播';

  @override
  String get securityStepUp_widgetsSX => '已关闭';

  @override
  String securityStepUp_widgetsSecurityStepUpInfoBodyBody(
    Object? stepUpSubtitle,
  ) {
    return '$stepUpSubtitle。点按这一行可以修改金额。';
  }

  @override
  String securityStepUp_widgetsSecurityStepUpSwitchSemanticLabel(
    Object? capability,
    Object? stepUpTitle,
  ) {
    return '$stepUpTitle，不可用：$capability';
  }

  @override
  String securityStepUp_widgetsSecurityStepUpSwitchSemanticLabel2(
    Object? base,
    Object? on,
    Object? stepUpTitle,
  ) {
    return '$stepUpTitle，$on，$base，点按修改金额';
  }

  @override
  String securityStepUp_widgetsSemanticLabel(Object? stepUpTitle) {
    return '$stepUpTitle，不可用：这次运行没有可用的设备验证';
  }

  @override
  String get securityStepUp_widgetsStepUpSigningTitle => '正在验证身份';

  @override
  String get securityStepUp_widgetsStepUpThresholdFieldFootnote =>
      '整数，1 到 1,000,000';

  @override
  String get securityStepUp_widgetsStepUpThresholdFieldLabel => '金额（USD1）';

  @override
  String get securityStepUp_widgetsStepUpTitle => '大额交易二次验证';

  @override
  String get securityStepUp_widgetsSubtitle => '这次运行没有可用的设备验证';

  @override
  String get securityStepUp_widgetsUnknown => '结果未知';

  @override
  String get securityStepUp_widgetsWaiting => '待验证';

  @override
  String get shell_payUnavailableHeadline => 'Pay 暂不可用';

  @override
  String get shell_payUnavailableMessage =>
      'Pay 尚未开放。此页面不会扫码、不会请求相机权限、不会收集支付信息，也不会提交任何交易。';

  @override
  String get shell_pendingBackToCommunity => '返回社区';

  @override
  String get shell_pendingHeadline => '该页面还没有开放';

  @override
  String shell_pendingMessage(Object? title) {
    return '「$title」还没有开放，这里暂时不显示任何内容，也不能执行任何操作。';
  }

  @override
  String shell_pendingSourceLine(Object? label) {
    return '所属模块：$label';
  }

  @override
  String get shell_tabChat => '聊天';

  @override
  String get shell_tabIntel => '情报';

  @override
  String get shell_tabMe => '我的';

  @override
  String shell_tabNewMessages(Object? label) {
    return '$label，有新消息';
  }

  @override
  String get shell_tabSquare => '广场';

  @override
  String get walletTestnetFaucet_sheetBarrierLabel => '关闭获取资金';

  @override
  String get walletTestnetFaucet_sheetBusy => '正在给别人发放，几秒后再试';

  @override
  String get walletTestnetFaucet_sheetChainReadFailed => '链上读数暂时取不到，稍后再试';

  @override
  String walletTestnetFaucet_sheetCooldown(Object? testnetFaucetClaimedText) {
    return '$testnetFaucetClaimedText，稍后再来';
  }

  @override
  String get walletTestnetFaucet_sheetDisabled => '领取已关闭';

  @override
  String walletTestnetFaucet_sheetIf(
    Object? again,
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
  ) {
    return '$loopLaunchNativeSymbolText 已发出但还没确认，$loopLaunchUsd1SymbolText 这次没发；$again';
  }

  @override
  String walletTestnetFaucet_sheetIf2(
    Object? again,
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
  ) {
    return '$loopLaunchNativeSymbolText 已发出，$loopLaunchUsd1SymbolText 这次没发；$again';
  }

  @override
  String walletTestnetFaucet_sheetIf3(
    Object? again,
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
  ) {
    return '$loopLaunchUsd1SymbolText 已到账，$loopLaunchNativeSymbolText 这次没成功，$again';
  }

  @override
  String walletTestnetFaucet_sheetIf4(Object? again) {
    return '这次只发出了一部分，$again';
  }

  @override
  String walletTestnetFaucet_sheetIf5(
    Object? again,
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
  ) {
    return '$loopLaunchNativeSymbolText 已到账，$loopLaunchUsd1SymbolText 这次没成功，$again';
  }

  @override
  String get walletTestnetFaucet_sheetIf6 => '正在读取领取状态…';

  @override
  String get walletTestnetFaucet_sheetLabel => '最近已领过';

  @override
  String walletTestnetFaucet_sheetLabel2(Object? testnetFaucetCooldownText) {
    return '$testnetFaucetCooldownText内已领过';
  }

  @override
  String walletTestnetFaucet_sheetLabel3(Object? testnetFaucetNextLabel) {
    return '下次可领 $testnetFaucetNextLabel';
  }

  @override
  String walletTestnetFaucet_sheetLabel4(Object? label) {
    return '复制 $label 交易哈希';
  }

  @override
  String walletTestnetFaucet_sheetLabel5(Object? label) {
    return '复制 $label 的 BscScan 链接';
  }

  @override
  String get walletTestnetFaucet_sheetMessage => '交易哈希已复制';

  @override
  String get walletTestnetFaucet_sheetMessage2 => 'BscScan 链接已复制';

  @override
  String get walletTestnetFaucet_sheetRuntimeUnavailable => '领取暂时不可用，稍后再试';

  @override
  String walletTestnetFaucet_sheetS(Object? testnetFaucetCooldownText) {
    return '$testnetFaucetCooldownText后可再领';
  }

  @override
  String walletTestnetFaucet_sheetS2(Object? testnetFaucetCooldownText) {
    return '这个钱包 $testnetFaucetCooldownText内已经领过';
  }

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetAddressLabel => '收币钱包';

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetBusyLabel => '正在发放…（约 30 秒）';

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetCooldownText => '24 小时';

  @override
  String walletTestnetFaucet_sheetTestnetFaucetCooldownText2(num seconds) {
    return '$seconds 天';
  }

  @override
  String walletTestnetFaucet_sheetTestnetFaucetCooldownText3(num seconds) {
    return '$seconds 小时';
  }

  @override
  String walletTestnetFaucet_sheetTestnetFaucetCooldownText4(num seconds) {
    return '$seconds 分钟';
  }

  @override
  String walletTestnetFaucet_sheetTestnetFaucetCooldownText5(num seconds) {
    return '$seconds 秒';
  }

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetCooldownText6 => '稍后可再领';

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetCooldownText7 =>
      '这个钱包最近已经领过';

  @override
  String walletTestnetFaucet_sheetTestnetFaucetGranted(
    Object? formatDecimal,
    Object? formatDecimal2,
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
  ) {
    return '已发出 $formatDecimal $loopLaunchNativeSymbolText 和 $formatDecimal2 $loopLaunchUsd1SymbolText，到账以链上确认为准，余额会自动刷新。';
  }

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetInFlightLaterText =>
      '结果稍后在这里查看';

  @override
  String walletTestnetFaucet_sheetTestnetFaucetIntro(
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
  ) {
    return '领取 $loopLaunchNativeSymbolText 与 $loopLaunchUsd1SymbolText 到当前钱包，用来支付手续费和买卖，每 24 小时一次。';
  }

  @override
  String walletTestnetFaucet_sheetTestnetFaucetIntro2(
    Object? formatDecimal,
    Object? formatDecimal2,
    Object? loopLaunchNativeSymbolText,
    Object? loopLaunchUsd1SymbolText,
    Object? testnetFaucetCooldownText,
  ) {
    return '这次会发 $formatDecimal $loopLaunchNativeSymbolText 和 $formatDecimal2 $loopLaunchUsd1SymbolText 到当前钱包，每 $testnetFaucetCooldownText可以领一次。';
  }

  @override
  String walletTestnetFaucet_sheetTestnetFaucetNextLabel(Object? time) {
    return '明天 $time';
  }

  @override
  String walletTestnetFaucet_sheetTestnetFaucetNextLabel2(
    Object? day,
    Object? month,
    Object? time,
  ) {
    return '$month月$day日 $time';
  }

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetNotOwnedText =>
      '只能给当前登录的内置钱包领取';

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetOperatorLowText =>
      '资金池暂时不足，请稍后再试';

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetTimedOutLaterText =>
      '发放还在进行，稍后再进来看';

  @override
  String get walletTestnetFaucet_sheetTestnetFaucetTitle => '获取资金';

  @override
  String walletTestnetFaucet_sheetText(
    Object? testnetFaucetClaimedText,
    Object? testnetFaucetNextLabel,
  ) {
    return '$testnetFaucetClaimedText，下次可领 $testnetFaucetNextLabel';
  }

  @override
  String get walletTestnetFaucet_sheetTitle => '领取状态暂时读不到';

  @override
  String get walletTestnetFaucet_sheetTransferFailed => '这次没有发出，可以重试';

  @override
  String walletTestnetFaucet_sheetUsd1Unavailable(
    Object? loopLaunchUsd1SymbolText,
  ) {
    return '$loopLaunchUsd1SymbolText 合约暂时不可用，稍后再试';
  }

  @override
  String get walletTestnetFaucet_sheetWrongChain => '当前网络不支持领取';

  @override
  String get wallet_activityExportDismissed => '已生成 CSV，但没有选择分享去处';

  @override
  String get wallet_activityExportEmpty => '这一段没有记录可以导出';

  @override
  String get wallet_activityExportFailed => '导出没有完成，没有任何内容离开这台设备';

  @override
  String get wallet_activityExportIncoming => '收到';

  @override
  String get wallet_activityExportOutgoing => '发出';

  @override
  String get wallet_activityExportSelf => '自转';

  @override
  String get wallet_activityExportShared => '记录已导出，请在分享面板中选择去处';

  @override
  String get wallet_activityExportSwitch => '时间(UTC)';

  @override
  String get wallet_activityExportSwitch2 => '方向';

  @override
  String get wallet_activityExportSwitch3 => '资产标识';

  @override
  String get wallet_activityExportSwitch4 => '最小单位数量';

  @override
  String get wallet_activityExportSwitch5 => '对方地址';

  @override
  String get wallet_activityExportSwitch6 => '日志序号';

  @override
  String get wallet_activityExportSwitch7 => '区块';

  @override
  String get wallet_activityExportSwitch8 => '状态';

  @override
  String get wallet_activityExportUnavailable => '本次运行没有装配系统分享，没有导出任何内容';

  @override
  String get wallet_approvalScreensApprovalActionLimitLabel => '改为限额授权';

  @override
  String get wallet_approvalScreensApprovalActionRevokeLabel =>
      '回收授权（approve 0）';

  @override
  String get wallet_approvalScreensApprovalDecodedUnavailableLabel => '调用无法解码';

  @override
  String get wallet_approvalScreensApprovalGuardCapabilityBlockTitle =>
      '授权当前不可用';

  @override
  String get wallet_approvalScreensApprovalGuardErrorTitle => '授权没有准备成功';

  @override
  String get wallet_approvalScreensApprovalGuardExactLabel => '按限额授权';

  @override
  String wallet_approvalScreensApprovalGuardExactLabel2(
    Object? symbol,
    Object? wire,
  ) {
    return '按 $wire $symbol 限额授权';
  }

  @override
  String get wallet_approvalScreensApprovalGuardFolioCaption =>
      '代币、Spender、额度与解码后的调用在签名前完整显示。';

  @override
  String wallet_approvalScreensApprovalGuardFolioHeading(Object? symbol) {
    return '$symbol 授权';
  }

  @override
  String wallet_approvalScreensApprovalGuardFolioHeading2(Object? symbol) {
    return '无限 $symbol 授权';
  }

  @override
  String wallet_approvalScreensApprovalGuardFolioHeading3(
    Object? display,
    Object? symbol,
  ) {
    return '$display $symbol 限额';
  }

  @override
  String get wallet_approvalScreensApprovalGuardFolioKicker => '授权请求';

  @override
  String get wallet_approvalScreensApprovalGuardFolioStamp => '受保护';

  @override
  String get wallet_approvalScreensApprovalGuardRestartLabel => '改回限额授权';

  @override
  String get wallet_approvalScreensApprovalGuardScreenTitle => '授权拦截';

  @override
  String get wallet_approvalScreensApprovalGuardSignLabel => '事实已过期 · 重新准备';

  @override
  String wallet_approvalScreensApprovalGuardSignLabel2(
    Object? moneyCountdownLabel,
  ) {
    return '确认授权（$moneyCountdownLabel）';
  }

  @override
  String get wallet_approvalScreensApprovalGuardUnlimitedConfirmedBody =>
      '你已二次确认。签名后该 Spender 可持续动用这个代币的全部余额，离开对方界面后权限依然有效，直到你在授权盘点里回收。';

  @override
  String get wallet_approvalScreensApprovalGuardUnlimitedConfirmedTitle =>
      '这是一次无限额度授权';

  @override
  String get wallet_approvalScreensApprovalGuardUnlimitedLabel => '仍要无限授权';

  @override
  String get wallet_approvalScreensApprovalGuardUnlimitedWarningBody =>
      '获得无限额度的合约可以在任何时间转走这个代币的全部余额，直到你主动回收。LOOP 的默认是只授权本次需要的额度。';

  @override
  String get wallet_approvalScreensApprovalGuardUnlimitedWarningTitle =>
      '无限授权意味着持续动用全部余额';

  @override
  String get wallet_approvalScreensApprovalUnlimitedAcceptLabel => '我了解，仍要无限授权';

  @override
  String get wallet_approvalScreensApprovalUnlimitedCancelLabel => '改用限额';

  @override
  String get wallet_approvalScreensApprovalsBatchActionLabel => '批量回收';

  @override
  String get wallet_approvalScreensApprovalsCapabilityBlockTitle => '授权盘点当前不可用';

  @override
  String wallet_approvalScreensApprovalsFreshnessText(
    Object? groupedFigure,
    Object? groupedFigure2,
    Object? groupedFigure3,
    Object? relativeTime,
  ) {
    return '授权记录自区块 $groupedFigure 起 · 索引高度 $groupedFigure2 / 链头 $groupedFigure3 · 观察于 $relativeTime';
  }

  @override
  String get wallet_approvalScreensApprovalsPageBlockMessage => '授权清单当前不可用';

  @override
  String get wallet_approvalScreensApprovalsRevokeErrorTitle => '回收没有准备成功';

  @override
  String get wallet_approvalScreensBuild => '授权检查';

  @override
  String get wallet_approvalScreensConfirmUnlimited =>
      '无限额度不会随时间或这笔交易结束而失效。该 Spender 之后可以在不再询问你的情况下转走这个代币的全部余额。只有你在授权盘点里发送一笔 approve(spender, 0) 才会收回。';

  @override
  String get wallet_approvalScreensEmptyMessage => '这个钱包没有有效授权';

  @override
  String get wallet_approvalScreensLabel => '函数';

  @override
  String get wallet_approvalScreensLabel2 => '无限授权';

  @override
  String get wallet_approvalScreensLabel3 => '限额授权';

  @override
  String wallet_approvalScreensLabelText(Object? symbol) {
    return '授权额度（$symbol）';
  }

  @override
  String get wallet_approvalScreensLoopBadge => '读不到';

  @override
  String get wallet_approvalScreensLoopBadge2 => '无限';

  @override
  String get wallet_approvalScreensLoopBadge3 => '限额';

  @override
  String get wallet_approvalScreensLoopLabel => '限额授权（默认）';

  @override
  String get wallet_approvalScreensLoopLabel2 => '解码后的调用';

  @override
  String get wallet_approvalScreensLoopLabel3 => '按额度排序';

  @override
  String get wallet_approvalScreensLoopSheetHeading => '确认无限授权';

  @override
  String get wallet_approvalScreensMessage => '批量回收还没有开放。每一笔回收都是一次单独的签名。';

  @override
  String get wallet_approvalScreensMoneyOfflinePause => '准备授权';

  @override
  String get wallet_approvalScreensMoneyOfflinePause2 => '回收授权';

  @override
  String get wallet_approvalScreensMoneyOfflinePause3 => '改额度';

  @override
  String wallet_approvalScreensS(Object? display) {
    return '额度 $display';
  }

  @override
  String wallet_approvalScreensSubtitle(
    Object? groupedFigure,
    Object? truncatedAddress,
    Object? unlimited,
  ) {
    return '$truncatedAddress · $unlimited · 区块 $groupedFigure';
  }

  @override
  String get wallet_approvalScreensText => '只授权本次交易需要的额度。';

  @override
  String get wallet_approvalScreensValue => '原生资产没有授权面';

  @override
  String get wallet_deferredScreensBlocked => '已阻止';

  @override
  String get wallet_deferredScreensBody => '识别结果不会直接发起签名；金额、网络与收款方会再次展示。';

  @override
  String get wallet_deferredScreensBody2 => '先选来源链、目标链与数量，再显示预计费用和到账时间。';

  @override
  String get wallet_deferredScreensBody3 => '源链确认、桥接中和目标链到账是三个独立状态。';

  @override
  String get wallet_deferredScreensBody4 =>
      '核对完全在本机完成：不会打开这个网址，不会跟随跳转，也不会连接钱包。';

  @override
  String get wallet_deferredScreensBridgeFolioHeading => '跨链尚未开放';

  @override
  String get wallet_deferredScreensBridgeFolioKicker => '跨链意图';

  @override
  String get wallet_deferredScreensBridgeFolioStamp => '核对';

  @override
  String get wallet_deferredScreensBridgeFromCaption => '从';

  @override
  String get wallet_deferredScreensBridgeOpenStatusLabel => '查看跨链进度';

  @override
  String get wallet_deferredScreensBridgeScopeNoticeBody =>
      '跨链费、到账数量与预计时间只能由真实路由给出。没有路由就没有这些数字，这一页不会用示例数据代替它们。';

  @override
  String get wallet_deferredScreensBridgeScopeNoticeTitle => '关于跨链';

  @override
  String get wallet_deferredScreensBridgeScopeNoticeTitle2 => '这里不会出现预估数字';

  @override
  String get wallet_deferredScreensBridgeStartLabel => '开始跨链';

  @override
  String get wallet_deferredScreensBridgeStatusBackToWalletLabel => '返回钱包';

  @override
  String get wallet_deferredScreensBridgeStatusFolioHeading => '跨链进度尚未开放';

  @override
  String get wallet_deferredScreensBridgeStatusLeaveNoticeBody =>
      '跨链开放后会在后台继续，完成后推送通知，也可以从交易历史查看。';

  @override
  String get wallet_deferredScreensBridgeStatusLeaveNoticeTitle => '关于跨链进度';

  @override
  String get wallet_deferredScreensBridgeStatusLeaveNoticeTitle2 => '可以离开此页';

  @override
  String get wallet_deferredScreensBridgeStatusPageBlockMessage => '还没有可跟踪的跨链';

  @override
  String get wallet_deferredScreensBridgeStatusScreenTitle => '跨链进度';

  @override
  String get wallet_deferredScreensBridgeToCaption => '到';

  @override
  String wallet_deferredScreensDappConfusableNoticeBody(
    Object? confusableReading,
  ) {
    return '它看起来像 $confusableReading，但其中有不是拉丁字母的同形字符。这是最常见的钓鱼手法，已阻止。';
  }

  @override
  String get wallet_deferredScreensDappConfusableNoticeTitle => '这个域名在冒充另一个域名';

  @override
  String get wallet_deferredScreensDappExecutionUnavailableLabel =>
      '连接钱包与签名尚未开放';

  @override
  String get wallet_deferredScreensDappFindingsEmptyMessage =>
      '这只说明地址本身规范；它不代表这个站点可信。';

  @override
  String get wallet_deferredScreensDappFindingsEmptyTitle => '没有发现问题';

  @override
  String get wallet_deferredScreensDappFolioKicker => 'DApp 检查 · 只读';

  @override
  String get wallet_deferredScreensDappNoFetchNoticeBody =>
      '核对是纯本地计算：没有请求、没有 DNS 解析，也不会跟随任何跳转，所以你看到的域名一定是你输入的那个。';

  @override
  String get wallet_deferredScreensDappNoFetchNoticeTitle => '这一页不会打开网址';

  @override
  String get wallet_deferredScreensDappOmniboxHintText =>
      '搜索资产 / 社区 / 用户 / Launch / DApp / 网址';

  @override
  String get wallet_deferredScreensDappReputationUnavailableLabel => '读不到域名信誉';

  @override
  String get wallet_deferredScreensDappReviewCanonicalSubtitle => '无法规范化，已阻止';

  @override
  String get wallet_deferredScreensDappReviewCanonicalTitle => '规范化结果';

  @override
  String get wallet_deferredScreensDappReviewEmptyMessage =>
      '输入网址后，这里会显示规范化结果与发现的问题。';

  @override
  String get wallet_deferredScreensDappReviewTypedTitle => '你输入的';

  @override
  String get wallet_deferredScreensDappScreenTitle => 'DApp 核对';

  @override
  String get wallet_deferredScreensFlagged => '核对来源';

  @override
  String get wallet_deferredScreensFlagged2 => '需注意';

  @override
  String get wallet_deferredScreensLoopFolioPrimary => '还没有可核对的网址';

  @override
  String get wallet_deferredScreensLoopLabel => '步骤';

  @override
  String get wallet_deferredScreensLoopLabel2 => '本地核对';

  @override
  String get wallet_deferredScreensLoopLabel3 => '发现';

  @override
  String get wallet_deferredScreensLoopLabel4 => '域名信誉';

  @override
  String get wallet_deferredScreensLoopLabel5 => '连接与签名';

  @override
  String get wallet_deferredScreensNormalized => '来源一致';

  @override
  String get wallet_deferredScreensNormalized2 => '规范化完成';

  @override
  String get wallet_deferredScreensNormalized3 => '可读';

  @override
  String get wallet_deferredScreensPayFolioHeading => '扫码支付';

  @override
  String get wallet_deferredScreensPayFolioStamp => '相机';

  @override
  String get wallet_deferredScreensPayWhyNoticeBody =>
      '支付涉及合规与支付商准入，需要独立评估。先把社区、挖矿与 Launch 的闭环跑通。';

  @override
  String get wallet_deferredScreensPayWhyNoticeTitle => '关于扫码支付';

  @override
  String get wallet_deferredScreensPayWhyNoticeTitle2 => '为什么现在不做';

  @override
  String get wallet_deferredScreensS => '这个网址不能使用';

  @override
  String wallet_deferredScreensSemanticsLabel(Object? title) {
    return '查看$title';
  }

  @override
  String get wallet_deferredScreensSubtitle => '阻止';

  @override
  String get wallet_deferredScreensSubtitle2 => '提示';

  @override
  String get wallet_homeBarrierLabel => '关闭总资产说明';

  @override
  String get wallet_homeBuild => '持仓分布';

  @override
  String get wallet_homeBuild2 => '管理';

  @override
  String wallet_homeIf(Object? hidden) {
    return '待确认 $hidden';
  }

  @override
  String get wallet_homeIf2 => '数据源尚未对齐';

  @override
  String wallet_homeLabel(Object? address) {
    return '$address，复制钱包地址';
  }

  @override
  String get wallet_homeLabel10 => '快照观察于';

  @override
  String get wallet_homeLabel11 => '手续费保留';

  @override
  String wallet_homeLabel12(Object? label) {
    return '$label，暂不可用';
  }

  @override
  String wallet_homeLabel13(Object? symbol) {
    return '$symbol，余额读不到';
  }

  @override
  String get wallet_homeLabel14 => '其它';

  @override
  String wallet_homeLabel15(
    Object? amount,
    Object? changeText,
    Object? subtitle,
    Object? symbol,
    Object? valueText,
  ) {
    return '$symbol，$subtitle，余额 $amount，估值 $valueText$changeText';
  }

  @override
  String get wallet_homeLabel16 => '钱包管理';

  @override
  String get wallet_homeLabel2 => '显示金额';

  @override
  String get wallet_homeLabel3 => '隐藏金额';

  @override
  String get wallet_homeLabel4 => '价格来源';

  @override
  String get wallet_homeLabel5 => '观察于';

  @override
  String get wallet_homeLabel6 => '未计入';

  @override
  String get wallet_homeLabel7 => '24h 变动';

  @override
  String get wallet_homeLabel8 => '余额区块';

  @override
  String get wallet_homeLabel9 => '净值快照来源';

  @override
  String get wallet_homeLoopBadge => '产生算力';

  @override
  String get wallet_homeLoopNetWorthChangeAvailable => '按同一次价格读取计算';

  @override
  String get wallet_homeLoopNetWorthChangeUnavailable => '部分资产没有 24h 价格变化，暂不显示';

  @override
  String get wallet_homeLoopSheetHeading => '关于总资产';

  @override
  String get wallet_homeLoopSheetHeading2 => '持仓产生算力';

  @override
  String get wallet_homeMessage => '钱包地址已复制';

  @override
  String wallet_homeMessage2(Object? reasonCodeText) {
    return '余额读不到 · $reasonCodeText';
  }

  @override
  String wallet_homeS(Object? valueText, Object? walletRowChangeText) {
    return '估值 $valueText，24h $walletRowChangeText';
  }

  @override
  String wallet_homeSX(Object? changeText) {
    return '，24 小时 $changeText';
  }

  @override
  String wallet_homeSemanticLabel(
    Object? amount,
    Object? symbol,
    Object? valueLabel,
  ) {
    return '$symbol，余额 $amount，$valueLabel';
  }

  @override
  String get wallet_homeShowWalletPowerSheet =>
      '钱包里已登记的资产会按各自的权重产生挖矿算力，算力决定每天能分到的 LOOP。社区币须加入已通过审核的绑定社区才计入。每个资产的权重与算力在挖矿页查看。';

  @override
  String get wallet_homeShowWalletTotalInfoSheet =>
      '总资产是按当前价格对已登记资产的估值，只用于展示，不是可用余额。能动用的数量以每个资产页的「可动用」为准。';

  @override
  String wallet_homeSwitch(Object? valueText) {
    return '估值 $valueText';
  }

  @override
  String get wallet_homeText => '总资产';

  @override
  String get wallet_homeUnreadText => '暂不可用';

  @override
  String wallet_homeValue(num unavailableCount) {
    return '$unavailableCount 项资产暂无价格';
  }

  @override
  String get wallet_homeValueText => '暂无估值';

  @override
  String wallet_homeWalletDistributionBarLabel(Object? label) {
    return '持仓分布，$label';
  }

  @override
  String get wallet_homeWalletPowerSheetBarrierLabel => '关闭算力说明';

  @override
  String get wallet_homeWalletPowerTagLabel => '持仓产生算力，查看说明';

  @override
  String wallet_homeWalletRowChangeUsd(num count) {
    return '$count 项资产暂无价格，未计入';
  }

  @override
  String get wallet_miningHooksFor => '无权重';

  @override
  String wallet_miningHooksLoopPowerHint(Object? power) {
    return '$power 算力';
  }

  @override
  String get wallet_miningHooksLoopPowerHint2 => '今日预估暂无';

  @override
  String wallet_miningHooksLoopPowerHint3(Object? powerFigure) {
    return '$powerFigure 算力';
  }

  @override
  String wallet_miningHooksLoopPowerHint4(Object? weight) {
    return '权重 $weight×';
  }

  @override
  String wallet_miningHooksS(Object? daily) {
    return '今日预估 $daily LOOP';
  }

  @override
  String get wallet_miningHooksWalletAssetPowerHintText => '这个资产的挖矿贡献';

  @override
  String wallet_miningHooksWalletAssetPowerText(Object? loopFigureDash) {
    return '算力 $loopFigureDash';
  }

  @override
  String wallet_miningHooksWalletAssetPowerText2(Object? powerFigure) {
    return '算力 $powerFigure';
  }

  @override
  String get wallet_miningHooksWalletPowerHintText => '钱包持仓正在产生算力';

  @override
  String get wallet_miningHooksWalletPowerHintText2 => '钱包持仓按权重产生算力';

  @override
  String get wallet_moneyActionNameApprove => '授权';

  @override
  String get wallet_moneyActionNameRevoke => '回收授权';

  @override
  String get wallet_moneyActionNameSend => '发送';

  @override
  String get wallet_moneyActionNameSendNft => '发送 NFT';

  @override
  String get wallet_moneyActionNameSwap => '兑换';

  @override
  String get wallet_moneyActionsAssetBlocked => '这个资产已被屏蔽，不能进行任何资金操作。';

  @override
  String get wallet_moneyActionsAssetNotInAllowlist =>
      '这个资产不在当前可操作的资产范围里，这笔操作没有通过。范围由 LOOP 维护，不能在应用里调整；请换一个在范围内的资产。';

  @override
  String wallet_moneyActionsBuild(Object? moneyActionTitle) {
    return '$moneyActionTitle · 最终确认';
  }

  @override
  String wallet_moneyActionsBuild2(Object? symbol) {
    return '无限 $symbol';
  }

  @override
  String get wallet_moneyActionsBuild3 => '本次没有可用的新鲜行情，因此不展示估值。';

  @override
  String wallet_moneyActionsCanaryCeilingExceeded(Object? figures) {
    return '$figures这笔操作超过了单笔金额上限，没有提交任何交易。上限由 LOOP 设定，请降低本次金额后再试。';
  }

  @override
  String wallet_moneyActionsCanaryDailyCeilingExceeded(
    Object? budget,
    Object? figures,
  ) {
    return '$figures$budget这笔操作会超过 24 小时内的累计金额上限，没有提交任何交易。上限由 LOOP 设定，请降低金额，或等累计额度滚过这 24 小时。';
  }

  @override
  String get wallet_moneyActionsCounterpartyNotInAllowlist =>
      '这个收款地址不在当前允许的收款名单里，这笔操作没有通过，也没有提交任何交易。名单由 LOOP 维护，不能在应用里调整；请换一个名单内的地址。';

  @override
  String get wallet_moneyActionsMoneyCapabilityCheckingLabel => '正在核对可用性';

  @override
  String wallet_moneyActionsMoneyFactsFooterText(
    Object? groupedFigure,
    Object? observed,
  ) {
    return '区块 $groupedFigure · $observed';
  }

  @override
  String wallet_moneyActionsMoneyPolicyRefusalText(
    Object? ceilingUsd,
    Object? exposureUsd,
  ) {
    return '本次 \$$exposureUsd · 上限 \$$ceilingUsd。';
  }

  @override
  String wallet_moneyActionsMoneyPolicyRefusalText2(
    Object? remainingUsd,
    Object? spentUsd,
  ) {
    return '24 小时内已用 \$$spentUsd · 还剩 \$$remainingUsd。';
  }

  @override
  String get wallet_moneyActionsNativeAssetNotApprovable =>
      '原生 BNB 没有授权面：它不是 ERC-20，没有 allowance 可以授权或回收。这一步不适用于原生资产。';

  @override
  String wallet_moneyActionsObserved(Object? relativeTime) {
    return '事实观察于 $relativeTime';
  }

  @override
  String get wallet_moneyActionsPriceImpactBlocked =>
      '这笔兑换的价格影响过大，已被阻止。请减小金额或稍后再试。';

  @override
  String get wallet_moneyActionsPurpose =>
      '这一步需要二次验证，二次验证还没有开放，没有签名、没有广播，也没有提交任何交易。请到安全中心查看当前可用的验证方式。';

  @override
  String get wallet_moneyActionsReason => '已提交，等待链上回执。成功提示不代表链上已完成。';

  @override
  String get wallet_moneyActionsReason2 => '这笔操作已提交且结果未知，已锁定。请在结果页查看，不要重复提交。';

  @override
  String wallet_moneyActionsS(Object? txHash) {
    return '钱包已经广播（$txHash），但这次上报没有被接受。这笔交易可能已经上链，请在结果页查看并稍后重新上报，不要重复签名。';
  }

  @override
  String wallet_moneyActionsS2(Object? formatUsd, Object? intent) {
    return '预估价值 $formatUsd · 来源 $intent';
  }

  @override
  String get wallet_moneyActionsSetState =>
      '钱包已经签名，但这次提交还没有记录到。请到结果页查看状态，不要重复签名。';

  @override
  String get wallet_moneyActionsSetState2 => '钱包没有完成签名，没有提交任何交易。';

  @override
  String get wallet_moneyActionsSigningApprove => '确认授权';

  @override
  String get wallet_moneyActionsSigningLabel => '收款方';

  @override
  String get wallet_moneyActionsSigningLabel2 => '额度';

  @override
  String get wallet_moneyActionsSigningLabel3 => '最高网络费';

  @override
  String get wallet_moneyActionsSigningRevoke => '确认回收授权';

  @override
  String get wallet_moneyActionsSigningSend => '确认发送';

  @override
  String get wallet_moneyActionsSigningSendNft => '确认发送 NFT';

  @override
  String get wallet_moneyActionsSigningSwap => '确认兑换';

  @override
  String get wallet_moneyActionsSigningValue => '无限额度';

  @override
  String get wallet_moneyActionsSwitch => '当前策略不允许这笔操作，没有提交任何交易。这里不猜是哪一条。';

  @override
  String get wallet_moneyActionsTitle => '这一步需要二次验证，没有提交任何交易';

  @override
  String get wallet_moneyActionsTitle2 => '当前地区不能执行此操作，没有提交任何交易';

  @override
  String get wallet_moneyActionsTitle3 => '原生资产不能授权';

  @override
  String get wallet_moneyActionsTitle4 => '被策略拒绝，没有提交任何交易';

  @override
  String get wallet_moneyActionsUnknown => '未知（已锁定）';

  @override
  String wallet_moneyActionsUnlimitedExposureExceedsCeiling(Object? figures) {
    return '$figures无限授权按当前余额计算敞口，已超过单笔上限。请改用限额授权，或先降低这个资产的余额。';
  }

  @override
  String get wallet_moneyActionsWalletMoneyActionsS2 => '未标注';

  @override
  String get wallet_moneyAssetPickerHintText => '搜索名称或代号';

  @override
  String wallet_moneyAssetPickerLoopBalanceAvailable(
    Object? formatDecimal,
    Object? name,
  ) {
    return '$name · 可动用 $formatDecimal';
  }

  @override
  String wallet_moneyAssetPickerSummary(Object? folded) {
    return '余额为 0 的资产 · $folded 个';
  }

  @override
  String get wallet_moneyAssetPickerTitle => '选择资产';

  @override
  String get wallet_moneyAssetPickerTitle2 => '这个钱包还没有可读资产';

  @override
  String get wallet_moneyAssetPickerTitle3 => '没有匹配的资产';

  @override
  String get wallet_moneyAssetPickerTitle4 => '没有可动用余额的资产';

  @override
  String get wallet_networthBuild => '收起净值走势';

  @override
  String get wallet_networthBuild2 => '今日盈亏';

  @override
  String get wallet_networthDetail => '走势是服务端每小时为这个钱包记下的 USD 估值，只用于展示，不是可用余额。';

  @override
  String wallet_networthIf(
    Object? observed,
    Object? published,
    Object? rate,
    Object? stale,
    Object? walletFxSourceLabel,
  ) {
    return '人民币按$walletFxSourceLabel 1 USD = $rate CNY（$published 发布，观察于 $observed）折算$stale';
  }

  @override
  String wallet_networthLabel(Object? action, Object? value) {
    return '今日盈亏 $value，$action';
  }

  @override
  String get wallet_networthS => '展开净值走势';

  @override
  String get wallet_networthSource => 'LOOP 净值快照';

  @override
  String get wallet_networthSwitch => '欧洲央行参考汇率';

  @override
  String get wallet_networthSwitch2 => '参考汇率';

  @override
  String get wallet_networthWalletNetworthChartEmptyMessage =>
      '这个区间还没有净值记录 · 每小时记一次，有资产后开始画线';

  @override
  String wallet_networthWalletNetworthChartLabel(
    Object? highText,
    Object? label,
    Object? lowText,
  ) {
    return '$label净值走势，最高 $highText，最低 $lowText';
  }

  @override
  String get wallet_networthWalletNetworthChartUnavailableMessage =>
      '净值走势暂时读不到';

  @override
  String get wallet_networthWalletNetworthChevronLabel => '收起';

  @override
  String get wallet_networthWalletNetworthChevronLabel2 => '净值走势';

  @override
  String get wallet_networthWalletNetworthRangesSemanticLabel => '净值走势区间';

  @override
  String get wallet_nftSendContractUnsupported => '暂不支持发送这个 NFT';

  @override
  String get wallet_nftSendIdempotencyConflict => '这笔发送已提交过，请查看最新状态';

  @override
  String wallet_nftSendInsufficientBalance(Object? loopLaunchNativeSymbolText) {
    return '$loopLaunchNativeSymbolText 手续费不足，充值后再试';
  }

  @override
  String get wallet_nftSendNftSendDisabledText => '暂不支持发送 NFT';

  @override
  String get wallet_nftSendNotOwned => '这枚 NFT 已不在钱包，请返回重新选择';

  @override
  String get wallet_nftSendRecipientRejects => '收款地址不接收这枚 NFT';

  @override
  String get wallet_nftSendRecipientSelf => '不能发送给自己';

  @override
  String get wallet_nftSendSimulationFailed => '这笔发送预执行没有通过，请稍后再试';

  @override
  String wallet_readBuild(Object? hidden) {
    return '可动用 $hidden';
  }

  @override
  String wallet_readBuyback(Object? ticker) {
    return '回购 · $ticker';
  }

  @override
  String get wallet_readCreating => '正在向 Privy 申请嵌入式钱包，完成后清单会自动刷新。';

  @override
  String wallet_readFailed(Object? provisioning) {
    return '上一次创建没有完成：$provisioning 登录状态没有变化，可以再试一次。';
  }

  @override
  String get wallet_readIf => '只是已估值资产的合计，不是总资产';

  @override
  String wallet_readIf2(Object? valuationCurrency) {
    return '净值（$valuationCurrency）';
  }

  @override
  String get wallet_readLabel => '创建中…';

  @override
  String get wallet_readLabel2 => '创建钱包';

  @override
  String get wallet_readLabel3 => '列表加载中';

  @override
  String get wallet_readLabel4 => '收款地址加载中';

  @override
  String wallet_readLoopBalanceAvailable(Object? formatDecimal) {
    return '可动用 $formatDecimal';
  }

  @override
  String wallet_readLoopBalanceAvailable2(Object? formatDecimal) {
    return '手续费保留 $formatDecimal';
  }

  @override
  String wallet_readLoopBalanceUnavailable(Object? reasonCodeText) {
    return '可动用 $reasonCodeText';
  }

  @override
  String wallet_readLoopBalanceUnavailable2(Object? reasonCodeText) {
    return '手续费保留 $reasonCodeText';
  }

  @override
  String get wallet_readMessage => '开发预览不会创建真实钱包，也不会调用 Privy。';

  @override
  String get wallet_readMessage2 => '当前会话未完成验证，暂时不能创建钱包。重新登录后可以再试。';

  @override
  String get wallet_readMessage3 => '钱包已创建';

  @override
  String get wallet_readModelsDay => '1 天';

  @override
  String get wallet_readModelsHalfYear => '180 天';

  @override
  String get wallet_readModelsMonth => '30 天';

  @override
  String get wallet_readModelsSwitch =>
      '只接收 BNB Smart Chain（BSC）网络的资产。把其他网络的资产发到这个地址可能永久丢失。';

  @override
  String get wallet_readModelsSwitch2 => '请先确认发送方使用的网络与这里显示的一致。';

  @override
  String get wallet_readModelsWeek => '7 天';

  @override
  String get wallet_readModelsYear => '360 天';

  @override
  String wallet_readNftMint(Object? ticker) {
    return '铸造勋章 · $ticker';
  }

  @override
  String wallet_readPoolBuy(Object? ticker) {
    return '买入 $ticker';
  }

  @override
  String wallet_readPoolSell(Object? ticker) {
    return '卖出 $ticker';
  }

  @override
  String wallet_readRewardClaim(Object? ticker) {
    return '领取奖励 · $ticker';
  }

  @override
  String wallet_readRowBalance(Object? amount) {
    return '余额 $amount';
  }

  @override
  String get wallet_readRowBalanceMissing => '余额读不到';

  @override
  String wallet_readS(Object? formatDecimal) {
    return '待确认 $formatDecimal';
  }

  @override
  String get wallet_readScreensBalancesFailureLine => '当前账号没有权限读取余额';

  @override
  String get wallet_readScreensBuild => '原生转账';

  @override
  String get wallet_readScreensBuild2 => '跨链 / 挖矿';

  @override
  String get wallet_readScreensCopy => '地址已复制';

  @override
  String get wallet_readScreensEmptyMessage => '钱包清单还没有读到';

  @override
  String get wallet_readScreensEmptyMessage2 => '这个钱包没有这一行';

  @override
  String get wallet_readScreensEmptyMessage3 => '这个资产还没有收发记录';

  @override
  String get wallet_readScreensEmptyMessage4 => '没有可用的接收地址';

  @override
  String get wallet_readScreensEmptyMessage5 => '没有嵌入式钱包';

  @override
  String get wallet_readScreensEmptyMessage6 => '没有已连接的外部钱包';

  @override
  String get wallet_readScreensEmptyMessage7 => '还没有链上活动';

  @override
  String get wallet_readScreensEmptyMessage8 => '没有可展示的网络';

  @override
  String get wallet_readScreensEmptyReason => '这不是“没有钱包”，只是这次没有读到清单。';

  @override
  String get wallet_readScreensEmptyReason2 => '索引器已经读到这个区间，但其中没有属于这个钱包的转账。';

  @override
  String get wallet_readScreensExternalWalletKind => '外部钱包';

  @override
  String wallet_readScreensFor(Object? best) {
    return '延迟 ${best}ms';
  }

  @override
  String get wallet_readScreensFor2 => '延迟未知';

  @override
  String wallet_readScreensIf(Object? ticker) {
    return '$ticker · 余额还没有读到';
  }

  @override
  String get wallet_readScreensIf2 => '名称与精度只来自链上调用';

  @override
  String wallet_readScreensIf3(Object? groupedFigure) {
    return '区块高度 $groupedFigure';
  }

  @override
  String wallet_readScreensIf4(Object? relativeTime) {
    return '校验于 $relativeTime';
  }

  @override
  String get wallet_readScreensLabel => '链上余额';

  @override
  String wallet_readScreensLabel10(Object? decimals) {
    return '最小单位余额（$decimals 位精度的整数）';
  }

  @override
  String get wallet_readScreensLabel11 => '登记状态';

  @override
  String get wallet_readScreensLabel12 => '合约地址';

  @override
  String wallet_readScreensLabel13(Object? name) {
    return '网络 $name';
  }

  @override
  String get wallet_readScreensLabel14 => '原生 BNB 转账不可用';

  @override
  String get wallet_readScreensLabel15 => '跨链与挖矿领取记录不可用';

  @override
  String get wallet_readScreensLabel16 => 'MEME 记录暂不可用';

  @override
  String get wallet_readScreensLabel2 => '可动用';

  @override
  String get wallet_readScreensLabel3 => '当前价';

  @override
  String get wallet_readScreensLabel4 => '估值';

  @override
  String get wallet_readScreensLabel5 => '可用';

  @override
  String get wallet_readScreensLabel6 => '可动用（扣除手续费保留）';

  @override
  String get wallet_readScreensLabel7 => '待确认入账（不计入可用）';

  @override
  String get wallet_readScreensLabel8 => '单价';

  @override
  String get wallet_readScreensLabel9 => '精度';

  @override
  String wallet_readScreensLaunchChainTitle(Object? name) {
    return '$name（Launch）';
  }

  @override
  String get wallet_readScreensLoopBadge => '数据可能过期';

  @override
  String get wallet_readScreensLoopBadge2 => '使用中';

  @override
  String get wallet_readScreensLoopBadge3 => '已归档';

  @override
  String get wallet_readScreensLoopBadge4 => '已关闭';

  @override
  String get wallet_readScreensLoopBadge5 => '运行中';

  @override
  String get wallet_readScreensLoopFolioPrimary => '余额还没有读到';

  @override
  String get wallet_readScreensLoopLabel => '挖矿贡献';

  @override
  String get wallet_readScreensLoopLabel2 => '链上分布';

  @override
  String get wallet_readScreensLoopLabel3 => '收发记录';

  @override
  String get wallet_readScreensLoopLabel4 => '嵌入式钱包';

  @override
  String get wallet_readScreensLoopLabel5 => '外部钱包';

  @override
  String get wallet_readScreensLoopLabel6 => '已启用';

  @override
  String get wallet_readScreensLoopLabel7 => 'RPC 端点';

  @override
  String get wallet_readScreensLoopLabel8 => '索引器';

  @override
  String get wallet_readScreensLoopOfflineState => '切换活跃钱包';

  @override
  String get wallet_readScreensLoopOfflineState2 => '继续加载';

  @override
  String get wallet_readScreensLoopProvenanceFooter =>
      '所有绑定钱包的持仓都计入算力，不用搬家。LOOP ID 是你的身份，钱包只是可更换的凭证，地址不是账号标识。';

  @override
  String wallet_readScreensLoopProvenanceFooter2(Object? groupedFigure) {
    return '索引高度 $groupedFigure';
  }

  @override
  String wallet_readScreensLoopProvenanceFooter3(Object? groupedFigure) {
    return '数据落后 $groupedFigure 块';
  }

  @override
  String get wallet_readScreensLoopProvenanceLine => 'LOOP 链上索引';

  @override
  String wallet_readScreensLoopRecordRow(Object? groupedFigure) {
    return '高度 $groupedFigure';
  }

  @override
  String wallet_readScreensLoopRecordRow2(Object? groupedFigure) {
    return '落后 $groupedFigure 块';
  }

  @override
  String wallet_readScreensLoopRecordRow3(num reorgCount) {
    return '重组 $reorgCount 次';
  }

  @override
  String wallet_readScreensLoopRecordRow4(Object? index) {
    return '端点 $index';
  }

  @override
  String wallet_readScreensLoopRecordRow5(Object? latencyMs) {
    return '延迟 ${latencyMs}ms';
  }

  @override
  String wallet_readScreensLoopRecordRow6(Object? label) {
    return '校验$label';
  }

  @override
  String wallet_readScreensLoopSheetHeading(Object? limit) {
    return '最多绑定 $limit 个外部钱包';
  }

  @override
  String get wallet_readScreensLoopSheetHeading2 => '连接外部钱包';

  @override
  String wallet_readScreensLoopSheetHeading3(Object? truncatedAddress) {
    return '外部钱包 $truncatedAddress';
  }

  @override
  String get wallet_readScreensLoopSheetHeading4 => '解绑外部钱包';

  @override
  String get wallet_readScreensLoopSheetHeading5 => '交易详情';

  @override
  String get wallet_readScreensMeTradesCapabilityBlockTitle => '钱包活动当前不可用';

  @override
  String get wallet_readScreensMessage => '这台设备打不开分享面板，请改用复制地址';

  @override
  String get wallet_readScreensMessage10 => '已解绑外部钱包';

  @override
  String get wallet_readScreensMessage11 => '已切换活跃钱包';

  @override
  String get wallet_readScreensMessage12 => '记录还没有读到，没有可以导出的内容。';

  @override
  String wallet_readScreensMessage13(Object? what) {
    return '$what已复制';
  }

  @override
  String get wallet_readScreensMessage2 => '钱包清单当前不可用，暂时不能连接外部钱包。';

  @override
  String get wallet_readScreensMessage3 => '钱包清单还没有读到，读到之后再连接外部钱包。';

  @override
  String get wallet_readScreensMessage4 => '钱包绑定没有完成，请重试。';

  @override
  String wallet_readScreensMessage5(Object? limit) {
    return '已达 $limit 个外部钱包上限，请先解绑一个';
  }

  @override
  String get wallet_readScreensMessage6 => '外部钱包已绑定，钱包清单稍后刷新';

  @override
  String get wallet_readScreensMessage7 => '外部钱包已绑定';

  @override
  String get wallet_readScreensMessage8 => '解绑没有完成，请稍后重试。';

  @override
  String get wallet_readScreensMessage9 => '已解绑外部钱包，钱包清单稍后刷新';

  @override
  String get wallet_readScreensNetworksCapabilityBlockTitle => '链上读取当前不可用';

  @override
  String get wallet_readScreensNetworksChainMismatchLabel =>
      '端点返回的不是 BNB Smart Chain';

  @override
  String wallet_readScreensNetworksChainParametersText(
    Object? chainId,
    Object? groupedFigure,
    Object? groupedFigure2,
    Object? status,
  ) {
    return '$status$chainId · $groupedFigure 确认 · 重组跟踪 $groupedFigure2 块';
  }

  @override
  String wallet_readScreensNetworksChainRowTrailing(
    Object? endpoints,
    Object? healthyCount,
  ) {
    return '$healthyCount / $endpoints 正常';
  }

  @override
  String get wallet_readScreensNetworksCustomRpcTitle => '自定义 RPC';

  @override
  String wallet_readScreensNetworksLaunchChainRowSubtitle(
    Object? chainId,
    Object? groupedFigure,
    Object? groupedFigure2,
  ) {
    return '$chainId · $groupedFigure 确认 · 重组跟踪 $groupedFigure2 块';
  }

  @override
  String wallet_readScreensNetworksLaunchChainUnavailableLabel(Object? name) {
    return '$name（Launch）未配置 RPC';
  }

  @override
  String get wallet_readScreensNetworksNoEndpointsLabel => '没有已配置的 RPC 端点';

  @override
  String get wallet_readScreensNetworksOperatorDisclosureSummary =>
      '端点、索引器与链参数';

  @override
  String wallet_readScreensNetworksRegistryText(
    Object? readableAssetCount,
    Object? registeredPoolCount,
  ) {
    return '可读资产 $readableAssetCount 个 · 已登记池 $registeredPoolCount 个';
  }

  @override
  String get wallet_readScreensNetworksScreenTitle => '网络与 RPC';

  @override
  String wallet_readScreensNetworksTestnetSubtitle(Object? name) {
    return '$name · 只有 Launch 使用';
  }

  @override
  String get wallet_readScreensOffline => '网络已断开，余额没有读到';

  @override
  String wallet_readScreensOpenExternalWallet(Object? truncatedAddress) {
    return '钱包 $truncatedAddress 会成为余额、活动与收款页的当前钱包。';
  }

  @override
  String get wallet_readScreensRateLimited => '请求过于频繁，稍后再试';

  @override
  String get wallet_readScreensReceiveCopyAddressLabel => '复制地址';

  @override
  String get wallet_readScreensReceiveNoNetworkDetail => '暂时读不到可接收的网络。';

  @override
  String get wallet_readScreensReceiveNoNetworkMessage => '没有可接收的网络';

  @override
  String wallet_readScreensReceiveQrLabel(Object? name) {
    return '$name 收款二维码';
  }

  @override
  String wallet_readScreensReceiveQrUnavailableMessage(Object? reasonCodeText) {
    return '二维码不可用 · $reasonCodeText';
  }

  @override
  String get wallet_readScreensReceiveWarningTitle => '只接收这一条网络的资产';

  @override
  String get wallet_readScreensS => '异常';

  @override
  String get wallet_readScreensS2 => '已发布';

  @override
  String wallet_readScreensS2X(Object? blockDelta) {
    return '（相差 $blockDelta 个区块）';
  }

  @override
  String get wallet_readScreensS3 => '未运行';

  @override
  String wallet_readScreensS3X(Object? groupedFigure) {
    return '区块 $groupedFigure · ';
  }

  @override
  String wallet_readScreensSX(Object? groupedFigure) {
    return 'Launch 链余额读自区块 $groupedFigure，不计入总资产。';
  }

  @override
  String wallet_readScreensSubject(Object? name) {
    return '$name 收款地址';
  }

  @override
  String get wallet_readScreensSwitch => '余额暂时读不到';

  @override
  String wallet_readScreensSwitch2(Object? factSourceLabel) {
    return '来源 $factSourceLabel';
  }

  @override
  String wallet_readScreensSwitch3(Object? relativeTime) {
    return '观察于 $relativeTime';
  }

  @override
  String wallet_readScreensSwitch4(Object? truncatedAssetId) {
    return '代理资产 $truncatedAssetId';
  }

  @override
  String get wallet_readScreensSwitch5 => '待校验';

  @override
  String wallet_readScreensText(Object? address, Object? name) {
    return '$name 收款地址\n$address';
  }

  @override
  String get wallet_readScreensTimedOut => '读取超时，余额没有读到';

  @override
  String get wallet_readScreensTitle => '这一页没有加载完';

  @override
  String get wallet_readScreensTitle2 => '这一段没有记录';

  @override
  String get wallet_readScreensTxEntrySheetCopyHashLabel => '复制哈希';

  @override
  String get wallet_readScreensTxEntrySheetCopyLinkLabel => '复制 BscScan 链接';

  @override
  String get wallet_readScreensTxEntrySheetExplorerNoticeBody =>
      'LOOP 目前不能直接唤起外部浏览器。复制链接后在浏览器里打开，看到的是链上的同一笔。';

  @override
  String get wallet_readScreensTxEntrySheetExplorerNoticeTitle =>
      '在浏览器里打开要自己粘贴';

  @override
  String get wallet_readScreensTxHistoryExportActionLabel => '导出中';

  @override
  String get wallet_readScreensTxHistoryExportActionLabel2 => '导出';

  @override
  String get wallet_readScreensUnavailable => '链上余额暂时读不到';

  @override
  String get wallet_readScreensUnreachable => '不可达';

  @override
  String get wallet_readScreensWalletAssetActivityEmptyMessage =>
      '索引器已经读到这个区间，但其中没有属于这个资产的转账。';

  @override
  String get wallet_readScreensWalletAssetBalanceMissingLabel => '链上余额读不到';

  @override
  String wallet_readScreensWalletAssetCrosscheckBody(Object? crossCheck) {
    return '链上读数与 Privy 报告的数值不一致$crossCheck。这里显示的始终是链上读数，交叉核对不会改变它。';
  }

  @override
  String get wallet_readScreensWalletAssetCrosscheckUnavailableLabel =>
      '与 Privy 的交叉核对不可用';

  @override
  String get wallet_readScreensWalletAssetFactsDisclosureSummary => '余额说明与资产事实';

  @override
  String get wallet_readScreensWalletAssetFolioKicker => '钱包资产';

  @override
  String get wallet_readScreensWalletAssetHistoryEntrySubtitle =>
      '这个钱包的全部 ERC-20 转账，来自链上索引';

  @override
  String get wallet_readScreensWalletAssetHistoryEntryTitle => '交易历史';

  @override
  String get wallet_readScreensWalletAssetInvalidIdentityMessage =>
      '本页只接受规范的 CAIP assetId，未请求任何余额。';

  @override
  String get wallet_readScreensWalletAssetInvalidIdentityTitle =>
      '路由中没有可用的资产标识';

  @override
  String get wallet_readScreensWalletAssetInvalidTitle => '无法打开这个资产';

  @override
  String wallet_readScreensWalletAssetMarketActionTitle(Object? asset) {
    return '钱包资产 · $asset';
  }

  @override
  String get wallet_readScreensWalletAssetMissingRowDetail => '只有已登记的资产才会显示余额。';

  @override
  String get wallet_readScreensWalletAssetMissingRowMessage => '这个资产不在可读清单里';

  @override
  String get wallet_readScreensWalletAssetPendingMissingLabel => '待确认金额不可用';

  @override
  String get wallet_readScreensWalletAssetProxied => '以 WBNB 计价';

  @override
  String get wallet_readScreensWalletAssetValuationUnavailableLabel => '估值不可用';

  @override
  String get wallet_readScreensWalletBalancesEmptyTitle => '还没有资产';

  @override
  String get wallet_readScreensWalletCapabilityBlockTitle => '钱包读取当前不可用';

  @override
  String get wallet_readScreensWalletDirectoryNoActiveTitle => '还没有选定当前钱包';

  @override
  String get wallet_readScreensWalletFolioUnreadText => '还没有钱包';

  @override
  String get wallet_readScreensWalletFolioUnreadText2 => '未选定钱包';

  @override
  String get wallet_readScreensWalletFolioUnreadText3 => '离线';

  @override
  String get wallet_readScreensWalletNftEmptyTitle => '还没有 NFT';

  @override
  String get wallet_readScreensWalletNftUnavailableMessage =>
      'MEME v2 暂未开放，项目 NFT 暂时读不到';

  @override
  String get wallet_readScreensWalletScreenTitle => '我的';

  @override
  String wallet_readScreensWalletSnapshotFooterDetail(
    Object? formatDecimal,
    Object? groupedFigure,
    Object? launchSnapshot,
  ) {
    return '每一行余额都读自同一个区块（$groupedFigure 确认）。原生 BNB 会保留 $formatDecimal BNB 作为手续费，不计入可动用。$launchSnapshot';
  }

  @override
  String wallet_readScreensWalletSnapshotFooterPrefix(Object? groupedFigure) {
    return '区块 $groupedFigure';
  }

  @override
  String get wallet_readScreensWalletsActivateConfirmLabel => '切换';

  @override
  String get wallet_readScreensWalletsAddActionLabel => '添加';

  @override
  String get wallet_readScreensWalletsAddSheetContinueLabel => '继续连接';

  @override
  String get wallet_readScreensWalletsAddSheetNetworkBody =>
      '大陆网络需要开 VPN 才能连接外部钱包。';

  @override
  String get wallet_readScreensWalletsAddSheetNetworkTitle => '大陆网络需要开 VPN';

  @override
  String get wallet_readScreensWalletsAddSheetReasonBody =>
      '外部钱包只用于计算算力，不能在 LOOP 内交易或领奖励；LOOP 不会获取你的私钥。';

  @override
  String get wallet_readScreensWalletsAddSheetReasonTitle => '外部钱包只用于计算算力';

  @override
  String get wallet_readScreensWalletsAddSheetScopeBody =>
      '已绑定钱包里的社区币都会计入算力，不用把资产搬到某一个钱包。';

  @override
  String get wallet_readScreensWalletsAddSheetScopeTitle => '所有绑定钱包的持仓都计入算力';

  @override
  String get wallet_readScreensWalletsCapabilityBlockTitle => '钱包清单当前不可用';

  @override
  String wallet_readScreensWalletsLimitSheetBody(Object? limit) {
    return '最多绑定 $limit 个外部钱包，请先解绑一个，再连接新的钱包。';
  }

  @override
  String get wallet_readScreensWalletsScreenTitle => '我的钱包';

  @override
  String wallet_readScreensWalletsSourceText(Object? relativeTime) {
    return '来源 Privy · 观察于 $relativeTime';
  }

  @override
  String get wallet_readScreensWalletsSourceTitle => '关于绑定钱包';

  @override
  String get wallet_readScreensWalletsSwitchErrorTitle => '活跃钱包没有切换';

  @override
  String get wallet_readScreensWalletsUnlinkActionLabel => '解绑这个钱包';

  @override
  String get wallet_readScreensWalletsUnlinkConfirmLabel => '解绑';

  @override
  String wallet_readScreensWalletsUnlinkSheetBody(Object? truncatedAddress) {
    return '解绑后这个钱包的持仓从下一小时起不再计入算力。钱包 $truncatedAddress 里的资产不受影响，之后也可以重新绑定。';
  }

  @override
  String get wallet_readScreensWhat => '浏览器链接';

  @override
  String wallet_readSemanticLabel(Object? symbol) {
    return '$symbol 的可动用、算力与手续费保留';
  }

  @override
  String wallet_readSwitch(Object? launch2Usd1Label) {
    return '花费 $launch2Usd1Label';
  }

  @override
  String get wallet_readSwitch2 =>
      'LOOP 会为这个账号创建一个 Privy 嵌入式钱包。地址是公开的链上事实，不是账号标识。';

  @override
  String get wallet_readTitle => '这个账号还没有钱包';

  @override
  String wallet_readTransferFrom(Object? address) {
    return '来自 $address';
  }

  @override
  String wallet_readTransferTo(Object? address) {
    return '发往 $address';
  }

  @override
  String get wallet_readWalletActivityDayLabel => '昨天';

  @override
  String wallet_readWalletActivityDayLabel2(Object? day, Object? month) {
    return '$month月$day日';
  }

  @override
  String wallet_readWalletActivityDayLabel3(
    Object? day,
    Object? month,
    Object? year,
  ) {
    return '$year年$month月$day日';
  }

  @override
  String get wallet_readWalletLaunch2ActivityRow => 'Launch 链';

  @override
  String get wallet_readWalletLaunch2ActivityRow2 => '确认中';

  @override
  String wallet_readWalletLaunchChainUnavailableLabel(Object? name) {
    return '$name余额不可用';
  }

  @override
  String get wallet_readWalletLaunchUsd1Failed => '读取失败';

  @override
  String get wallet_readWalletNetworthNotSpendable => '不是可用余额';

  @override
  String wallet_readWalletNetworthPartial(Object? unavailableCount) {
    return '部分估值 · $unavailableCount 项无价格';
  }

  @override
  String get wallet_readWalletNetworthUnavailableLabel => '净值不可用';

  @override
  String get wallet_readWalletReadFailed => '原因未知';

  @override
  String wallet_readWalletSnapshotFooterText(
    Object? groupedFigure,
    Object? groupedFigure2,
    Object? relativeTime,
  ) {
    return '区块 $groupedFigure · $groupedFigure2 确认 · 观察于 $relativeTime';
  }

  @override
  String wallet_sendScreensBody(
    Object? moneyActionTitle,
    Object? moneyIntentStateLabel,
  ) {
    return '$moneyActionTitle · $moneyIntentStateLabel。再准备一笔新的会让它失效；如果它已经签名并广播，请先上报或取消。';
  }

  @override
  String get wallet_sendScreensBuild => '首次向该地址转账';

  @override
  String get wallet_sendScreensBuild2 => '收款方是合约地址';

  @override
  String get wallet_sendScreensBuild3 => '恶意地址筛查不可用';

  @override
  String get wallet_sendScreensBuild4 => '还没有填写';

  @override
  String get wallet_sendScreensBuild5 => '还没有读到';

  @override
  String get wallet_sendScreensBuild6 =>
      '这两行是你在上一步填的内容，还不是服务端的事实。网络费、余额与试算会在准备好这一笔之后一起显示。';

  @override
  String get wallet_sendScreensBuild7 =>
      '没有到账时间的来源，这里不给一个编出来的秒数。提交之后在结果页按确认数跟踪，那是唯一的进度。';

  @override
  String get wallet_sendScreensEmptyMessage => '这个账号还没有可用于发送的钱包';

  @override
  String get wallet_sendScreensEmptyReason => '只有 Privy 嵌入式钱包可以从本机签名并广播。';

  @override
  String get wallet_sendScreensLabel => '收款地址';

  @override
  String get wallet_sendScreensLabel2 => '金额与资产';

  @override
  String get wallet_sendScreensLabel3 => '确认并签名';

  @override
  String wallet_sendScreensLoopBalanceAvailable(
    Object? formatDecimal,
    Object? symbol,
  ) {
    return '可动用 $formatDecimal $symbol（已扣除手续费保留）';
  }

  @override
  String get wallet_sendScreensMissing => '还差一步：等待地址校验。';

  @override
  String get wallet_sendScreensMoneyOfflinePause => '校验地址';

  @override
  String get wallet_sendScreensMoneyPendingCancelLabel => '取消并重新准备';

  @override
  String get wallet_sendScreensMoneyPendingOpenLabel => '查看那一笔';

  @override
  String wallet_sendScreensRecipientHint(Object? chainName) {
    return '0x…（$chainName）';
  }

  @override
  String get wallet_sendScreensRecipientStep => '正在校验地址…';

  @override
  String wallet_sendScreensRecipientStep2(Object? chainName) {
    return '地址已校验 · $chainName';
  }

  @override
  String get wallet_sendScreensRecipientStep3 => '地址格式不对：0x 开头，共 42 位';

  @override
  String get wallet_sendScreensSendAddressNextMissing =>
      '还差一步：填写完整的收款地址（0x 开头，42 位）。';

  @override
  String get wallet_sendScreensSendAddressScreenTitle => '发送 NFT';

  @override
  String get wallet_sendScreensSendAmountMaxErrorText => '超过可动用余额';

  @override
  String get wallet_sendScreensSendAmountMaxHintText => '输入数量';

  @override
  String get wallet_sendScreensSendAmountNextMissing => '还差一步：选择要发送的资产。';

  @override
  String get wallet_sendScreensSendAmountNextMissing2 => '还差一步：填写发送数量。';

  @override
  String get wallet_sendScreensSendAmountNextMissing3 => '发送数量超过了可动用余额，请改小。';

  @override
  String get wallet_sendScreensSendAmountRecipientSubtitle => '收款地址 · 已校验';

  @override
  String get wallet_sendScreensSendAmountRecipientTrailingCaption => '修改';

  @override
  String get wallet_sendScreensSendAmountTitle => '发送数量';

  @override
  String wallet_sendScreensSendAmountTitle2(Object? symbol) {
    return '发送数量（$symbol）';
  }

  @override
  String wallet_sendScreensSendAssetSelectorSubtitle(num candidates) {
    return '$candidates 个资产可发送';
  }

  @override
  String get wallet_sendScreensSendAssetsEmptyMessage =>
      '登记资产后，这里会为每一个资产恒定保留一行。';

  @override
  String get wallet_sendScreensSendAssetsEmptyTitle => '还没有可读取的资产';

  @override
  String get wallet_sendScreensSendCapabilityBlockTitle => '发送当前不可用';

  @override
  String get wallet_sendScreensSendConfirmDraftArrivalLabel => '预估到账';

  @override
  String get wallet_sendScreensSendConfirmDraftArrivalValue => '不预估';

  @override
  String get wallet_sendScreensSendConfirmDraftFeeLabel => '网络费';

  @override
  String get wallet_sendScreensSendConfirmExpiredBody => '请重新准备一次再签名。';

  @override
  String get wallet_sendScreensSendConfirmExpiredBody2 =>
      '余额、费用与试算结果都取自同一时刻。请重新准备一次再签名。';

  @override
  String get wallet_sendScreensSendConfirmExpiredTitle => '事实已过期';

  @override
  String get wallet_sendScreensSendConfirmPowerBody =>
      '转出后算力会随持仓下降。具体数值暂时读不到，这里不做估算。';

  @override
  String get wallet_sendScreensSendConfirmPowerTitle => '算力会随持仓下降';

  @override
  String wallet_sendScreensSendConfirmSignLabel(Object? moneyCountdownLabel) {
    return '确认发送（$moneyCountdownLabel）';
  }

  @override
  String get wallet_sendScreensSendConfirmSigningExitText =>
      '签名由 Privy 嵌入式钱包在本机执行；所有资金操作都汇聚到同一个签名弹层，这是全产品唯一的签名出口。';

  @override
  String get wallet_sendScreensSendConfirmSigningExitTitle => '统一签名出口';

  @override
  String get wallet_sendScreensSendConfirmSimulationFailedTitle =>
      '试算没有通过，不能签名';

  @override
  String get wallet_sendScreensSendPowerNoticeBody =>
      '转出有权重的社区币后，算力会随持仓下降。具体数值暂时读不到，这里不做估算。';

  @override
  String get wallet_sendScreensSendPowerNoticeTitle => '发送会降低算力';

  @override
  String get wallet_sendScreensSendRecipientBasisText =>
      '首次收款方的判断依据：你自己在 LOOP 已索引的 ERC-20 转账记录';

  @override
  String get wallet_sendScreensSendRecipientBasisTitle => '判断依据';

  @override
  String wallet_sendScreensSendRecipientChecksSummary(
    Object? first,
    Object? headlines,
  ) {
    return '地址核对 · $headlines 项待确认 · $first';
  }

  @override
  String get wallet_sendScreensSendRecipientContractBody =>
      '向合约地址直接转账可能永久失去这笔资产。请确认这个合约确实接受直接转账。';

  @override
  String get wallet_sendScreensSendRecipientFirstTimeBody =>
      '这个地址不在你自己的已索引转账历史中。请逐字核对完整地址后再继续。';

  @override
  String get wallet_sendScreensSendRecipientPasteLabel => '粘贴';

  @override
  String get wallet_sendScreensSendRecipientPrefill => '收款地址来自扫码，已自动校验';

  @override
  String get wallet_sendScreensSendRecipientPreflightErrorTitle => '地址没有校验成功';

  @override
  String get wallet_sendScreensSendRecipientScanLabel => '扫码';

  @override
  String wallet_sendScreensSendStepBarLabel(
    Object? label,
    Object? step,
    Object? total,
  ) {
    return '第 $step 步，共 $total 步，$label';
  }

  @override
  String get wallet_sendScreensTitle => '这个钱包还有一笔未完成的操作';

  @override
  String get wallet_swapScreensBalanceLineFor => '先选择要支付的资产，这里会显示它的可动用余额。';

  @override
  String get wallet_swapScreensBalanceLineFor2 => '余额还没有读到。';

  @override
  String get wallet_swapScreensBalanceLineFor3 => '这个钱包没有这一行，读不到它的余额。';

  @override
  String get wallet_swapScreensEmptyMessage => '这个账号还没有可兑换的钱包';

  @override
  String get wallet_swapScreensIf => '无法定价';

  @override
  String get wallet_swapScreensLabel => '价格影响';

  @override
  String get wallet_swapScreensLabel2 => '平台费';

  @override
  String get wallet_swapScreensLabel3 => '单笔上限';

  @override
  String get wallet_swapScreensLabel4 => '网络费估算';

  @override
  String get wallet_swapScreensLabel5 => 'LOOP 服务费';

  @override
  String get wallet_swapScreensLabel6 => '市场估值';

  @override
  String wallet_swapScreensLoopBalanceAvailable(
    Object? formatDecimal,
    Object? symbol,
  ) {
    return '可动用 $formatDecimal $symbol';
  }

  @override
  String get wallet_swapScreensLoopLabel => '费用构成';

  @override
  String get wallet_swapScreensLoopProvenanceFooter =>
      '只展示最终报价：只有报价方提供路径时才会显示逐跳明细，这次没有提供。';

  @override
  String get wallet_swapScreensMoneyOfflinePause => '报价';

  @override
  String get wallet_swapScreensS => '报价后显示';

  @override
  String get wallet_swapScreensSwapCapabilityBlockLabel => '兑换当前不可用';

  @override
  String get wallet_swapScreensSwapConfirmActionLabel => '报价已过期 · 重新报价';

  @override
  String get wallet_swapScreensSwapConfirmActionLabel2 => '兑换还在验证中';

  @override
  String wallet_swapScreensSwapConfirmActionLabel3(
    Object? moneyCountdownLabel,
  ) {
    return '兑换（$moneyCountdownLabel）';
  }

  @override
  String get wallet_swapScreensSwapDestinationBlockedCaption => '获得';

  @override
  String get wallet_swapScreensSwapFlipLabel => '互换支付与获得';

  @override
  String get wallet_swapScreensSwapImpactBlockedTitle => '价格影响超过硬阻断线';

  @override
  String get wallet_swapScreensSwapImpactConfirmBody =>
      '这笔兑换会明显推动价格。滑点与价格影响是两件事：滑点是你设定的上限，价格影响是这笔成交本身造成的偏移。';

  @override
  String get wallet_swapScreensSwapImpactConfirmTitle => '价格影响在 1%–5% 之间';

  @override
  String get wallet_swapScreensSwapInfoActionLabel => '关于兑换';

  @override
  String get wallet_swapScreensSwapPowerNoticeBody => '买入后的算力变化暂时读不到，这里不做估算。';

  @override
  String get wallet_swapScreensSwapPowerNoticeTitle => '算力影响不可用';

  @override
  String get wallet_swapScreensSwapQuoteActionLabel => '报价中…';

  @override
  String get wallet_swapScreensSwapQuoteActionLabel2 => '选择支付与获得的资产';

  @override
  String get wallet_swapScreensSwapQuoteActionLabel3 => '输入数量后自动报价';

  @override
  String get wallet_swapScreensSwapQuoteActionLabel4 => '重新报价';

  @override
  String get wallet_swapScreensSwapQuoteErrorTitle => '没有取到报价';

  @override
  String wallet_swapScreensSwapQuoteProvenanceText(
    Object? provider,
    Object? quote,
    Object? relativeTime,
  ) {
    return '报价方 $provider · 报价于 $relativeTime$quote';
  }

  @override
  String get wallet_swapScreensSwapRouteActionLabel => '报价与费用明细';

  @override
  String get wallet_swapScreensSwapRouteBackLabel => '返回兑换并确认';

  @override
  String get wallet_swapScreensSwapRouteEntryLabel => '报价明细与费用';

  @override
  String wallet_swapScreensSwapRouteProvenanceText(
    Object? priceImpact,
    Object? provider,
    Object? quoteTtlSeconds,
  ) {
    return '报价方 $provider · 定价出处 $priceImpact · 有效期 $quoteTtlSeconds 秒';
  }

  @override
  String get wallet_swapScreensSwapRouteScreenTitle => '报价与费用';

  @override
  String get wallet_swapScreensSwapRoutingNoticeBody =>
      'LOOP 不自建路由，也不做逐跳拆解。这里只展示 Privy 返回的最终报价；兑换所得资产直接进入本钱包。';

  @override
  String get wallet_swapScreensSwapRoutingNoticeTitle => '路由由供应商选择';

  @override
  String get wallet_swapScreensText => '我已知晓价格影响在 1%–5% 之间，仍要继续';

  @override
  String get wallet_swapScreensTitle => '选择支付资产';

  @override
  String get wallet_swapScreensTitle2 => '选择获得资产';

  @override
  String get wallet_swapScreensValue => '未设置';

  @override
  String wallet_swapScreensValue2(
    Object? display,
    Object? moneySlippageLabel,
    Object? symbol,
  ) {
    return '$display $symbol（滑点 $moneySlippageLabel）';
  }

  @override
  String get wallet_swapScreensWalletSwapScreensSwapQuoteProvenanceText =>
      ' · 待产品确认';

  @override
  String wallet_txResultCancelled(Object? action) {
    return '$action已取消';
  }

  @override
  String wallet_txResultConfirmed(Object? action) {
    return '$action已确认';
  }

  @override
  String get wallet_txResultEmptyMessage => '这笔操作没有可读状态';

  @override
  String wallet_txResultExpired(Object? action) {
    return '$action已过期';
  }

  @override
  String wallet_txResultFailed(Object? action) {
    return '$action失败';
  }

  @override
  String get wallet_txResultIf => '结果、交易哈希和下一步动作集中在这里，不会混入新的报价。';

  @override
  String wallet_txResultIf2(Object? groupedFigure, Object? receipt) {
    return '区块 $groupedFigure · $receipt';
  }

  @override
  String get wallet_txResultMessage => '交易已确认';

  @override
  String wallet_txResultReverted(Object? action) {
    return '$action已回滚';
  }

  @override
  String wallet_txResultS(Object? groupedFigure) {
    return '$groupedFigure 确认';
  }

  @override
  String wallet_txResultSwitch(Object? action) {
    return '$action进行中';
  }

  @override
  String get wallet_txResultSwitch2 => '等待中';

  @override
  String get wallet_txResultSwitch3 => '最新状态。';

  @override
  String get wallet_txResultTxResultActionIdLabel => '供应商动作';

  @override
  String get wallet_txResultTxResultCapabilityBlockTitle => '交易状态当前不可读';

  @override
  String get wallet_txResultTxResultConfirmationsLabel => '确认数';

  @override
  String get wallet_txResultTxResultConfirmationsValue => '还没有回执';

  @override
  String get wallet_txResultTxResultConfirmationsValue2 => '链头读不到';

  @override
  String get wallet_txResultTxResultEmptyMessage =>
      '从发送、授权或兑换的签名页进来时，这一页会显示那一笔的状态。';

  @override
  String get wallet_txResultTxResultEmptyTitle => '这里还没有要展示的操作';

  @override
  String get wallet_txResultTxResultFolioCaption => '结果页只展示一笔具体操作，需要指定是哪一笔。';

  @override
  String get wallet_txResultTxResultFolioCaption2 => '结果以链上核对为准，这一页不会自己判断成败。';

  @override
  String get wallet_txResultTxResultFolioHeading => '没有可展示的结果';

  @override
  String get wallet_txResultTxResultFolioHeading2 => '正在读取结果';

  @override
  String get wallet_txResultTxResultForwardLabel => '转发消息';

  @override
  String get wallet_txResultTxResultGasLabel => '实际用量';

  @override
  String get wallet_txResultTxResultHashLabel => '交易哈希';

  @override
  String get wallet_txResultTxResultHashValue => '尚未上报';

  @override
  String get wallet_txResultTxResultMergeLabel => '合并长图';

  @override
  String get wallet_txResultTxResultPendingBody => '提交成功不代表链上已完成，还需要 15 个区块确认。';

  @override
  String get wallet_txResultTxResultPendingTitle => '已提交，等待回执';

  @override
  String wallet_txResultTxResultPollingStoppedBody(
    Object? maximumPollFailures,
  ) {
    return '连续 $maximumPollFailures 次读取失败，本页不再自动重试，已停止自动重试。这笔操作的状态没有改变，请手动重试。';
  }

  @override
  String get wallet_txResultTxResultPollingStoppedTitle => '已停止自动查询';

  @override
  String get wallet_txResultTxResultScreenTitle => '交易结果';

  @override
  String wallet_txResultTxResultUnknownLockBody(Object? reasonCodeText) {
    return '$reasonCodeText 本页只会继续查询，不会重复提交；请勿再次签名。';
  }

  @override
  String get wallet_txResultTxResultUnknownLockTitle => '结果未知，已锁定';

  @override
  String get wallet_txResultTxResultUnreportedBody =>
      '如果钱包已经广播过这笔交易，它可能已经上链，只是上报没有成功。请稍后回到这里重试，在提交被接受之前不要重新签名。';

  @override
  String get wallet_txResultTxResultUnreportedTitle => '这次提交还没有记录到';

  @override
  String get wallet_txResultTxResultUpdatedLabel => '更新于';

  @override
  String wallet_txResultUnknown(Object? action) {
    return '$action结果未知';
  }

  @override
  String get wallet_txResultWalletMoneyActionsMoneyFactsFooterText => '确认数读不到';
}

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

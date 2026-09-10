// The official Stream UI ships English strings only, and the published
// `stream_chat_localizations` package is not in this project's lockfile.
// Adding it would be a dependency decision, so LOOP supplies its own
// `StreamChatLocalizations` implementation instead: the same interface, the
// same widgets, LOOP's Chinese copy. See decision 0065.
//
// Nothing here invents a provider fact. Every string restates what the
// official widget already renders; counts, names and timestamps stay the
// values Stream passes in.
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// The 24-hour clock LOOP uses everywhere a Stream widget prints a time.
///
/// Stream's own footer formats `3:39 PM` through Jiffy's locale, which the
/// SDK pins to the ambient `Localizations` locale. LOOP does not switch the
/// application locale (that would drop `MaterialLocalizations`), so the clock
/// is formatted here instead and stays `HH:mm` on every device.
String loopStreamClockLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// `今天` / `昨天` / `周三` / `9月10日` / `2025年9月10日`.
String loopStreamDayLabel(DateTime dateTime, {DateTime? now}) {
  final local = dateTime.toLocal();
  final today = now?.toLocal() ?? DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  final anchor = DateTime(today.year, today.month, today.day);
  final difference = anchor.difference(day).inDays;
  if (difference == 0) return '今天';
  if (difference == 1) return '昨天';
  if (difference > 1 && difference < 7) {
    const List<String> weekdays = <String>[
      '周一',
      '周二',
      '周三',
      '周四',
      '周五',
      '周六',
      '周日',
    ];
    return weekdays[day.weekday - 1];
  }
  if (day.year == anchor.year) return '${day.month}月${day.day}日';
  return '${day.year}年${day.month}月${day.day}日';
}

/// LOOP's Chinese accessibility labels for the official Stream widgets.
class LoopStreamChatAccessibilityTranslations
    extends DefaultAccessibilityTranslations {
  /// Creates the Chinese accessibility labels.
  const LoopStreamChatAccessibilityTranslations()
    : super(localeName: 'zh_Hans');

  @override
  String get sendMessageTooltip => '发送消息';

  @override
  String get saveEditTooltip => '保存修改';

  @override
  String get sendCommandTooltip => '发送指令';

  @override
  String slowModeTooltip({required int seconds}) => '慢速模式，还需等待 $seconds 秒';

  @override
  String get attachmentPickerTooltip => '附件';

  @override
  String get channelInfoLabel => '会话信息';

  @override
  String get messageActionsLabel => '消息操作';

  @override
  String get gifAttachmentLabel => 'GIF 附件';

  @override
  String imageAttachmentLabel({String? title}) =>
      title == null ? '图片附件' : '图片附件：$title';

  @override
  String videoAttachmentLabel({String? title}) =>
      title == null ? '视频附件' : '视频附件：$title';

  @override
  String get outgoingMessagePreviewLabel => '我发送的消息';

  @override
  String incomingMessagePreviewLabel({String? senderName}) =>
      senderName == null ? '收到的消息' : '来自 $senderName 的消息';

  @override
  String get messageSendingStatusLabel => '发送中';

  @override
  String get messageSentStatusLabel => '已发送';

  @override
  String get messageDeliveredStatusLabel => '已送达';

  @override
  String get messageReadStatusLabel => '已读';

  @override
  String unreadMessagesLabel({required int count}) => '$count 条未读';

  @override
  String get channelGroupLabel => '群聊';

  @override
  String get systemMessagePreviewLabel => '系统消息';

  @override
  String get channelMutedLabel => '已静音';

  @override
  String get channelPinnedLabel => '已置顶';

  @override
  String formatDateTime(DateTime dateTime) =>
      '${loopStreamDayLabel(dateTime)} ${loopStreamClockLabel(dateTime)}';

  @override
  String formatRecentDateTime(DateTime date) =>
      '${loopStreamDayLabel(date)} ${loopStreamClockLabel(date)}';
}

/// LOOP's Chinese copy for every string the official Stream widgets read.
class LoopStreamChatLocalizations implements StreamChatLocalizations {
  /// Creates the Chinese localization set.
  const LoopStreamChatLocalizations();

  @override
  AccessibilityTranslations get accessibility =>
      const LoopStreamChatAccessibilityTranslations();

  @override
  String get launchUrlError => '无法打开这个链接';

  @override
  String get loadingUsersError => '加载用户失败';

  @override
  String get noUsersLabel => '暂无用户';

  @override
  String get noPhotoOrVideoLabel => '没有图片或视频';

  @override
  String get retryLabel => '重试';

  @override
  String get userLastOnlineText => '最后在线';

  @override
  String get userOnlineText => '在线';

  @override
  String userTypingText(Iterable<User> users) {
    if (users.isEmpty) return '';
    final first = users.first;
    if (users.length == 1) return '${first.name} 正在输入';
    return '${first.name} 等 ${users.length} 人正在输入';
  }

  @override
  String get threadReplyLabel => '回复话题';

  @override
  String get threadLabel => '话题';

  @override
  String get onlyVisibleToYouText => '仅你可见';

  @override
  String threadReplyCountText(int count) => '$count 条回复';

  @override
  String attachmentsUploadProgressText({
    required int completed,
    required int total,
  }) => '已上传 $completed / $total …';

  @override
  String pinnedByUserText({required User pinnedBy, required User currentUser}) {
    if (currentUser.id == pinnedBy.id) return '由你置顶';
    return '由 ${pinnedBy.name} 置顶';
  }

  @override
  String get sendMessagePermissionError => '你没有在这个会话发消息的权限';

  @override
  String get emptyMessagesText => '还没有消息';

  @override
  String get genericErrorText => '出了点问题';

  @override
  String get loadingMessagesError => '加载消息失败';

  @override
  String resultCountText(int count) => '$count 条结果';

  @override
  String get messageDeletedText => '这条消息已删除。';

  @override
  String get messageDeletedLabel => '消息已删除';

  @override
  String get systemMessageLabel => '系统消息';

  @override
  String get editedMessageLabel => '已编辑';

  @override
  String get messageReactionsLabel => '消息表态';

  @override
  String get emptyChatMessagesText => '这里还没有会话…';

  @override
  String threadSeparatorText(int replyCount) => '$replyCount 条回复';

  @override
  String get connectedLabel => '已连接';

  @override
  String get disconnectedLabel => '已断开';

  @override
  String get reconnectingLabel => '正在重连…';

  @override
  String get alsoSendAsDirectMessageLabel => '同时发到频道';

  @override
  String get addACommentOrSendLabel => '添加说明或直接发送';

  @override
  String get searchGifLabel => '搜索 GIF';

  @override
  String get writeAMessageLabel => '发消息';

  @override
  String get instantCommandsLabel => '快捷指令';

  @override
  String get commandUnavailableWhileEditingError => '编辑时不可用';

  @override
  String get commandUnavailableWhileQuotingError => '回复时不可用';

  @override
  String get commandUnavailableError => '该指令不可用';

  @override
  String fileTooLargeAfterCompressionError(double limitInMB) =>
      '文件过大，无法上传。上限是 $limitInMB MB，压缩后仍然超出。';

  @override
  String fileTooLargeError(double limitInMB) => '文件过大，无法上传。上限是 $limitInMB MB。';

  @override
  String fileTypeNotSupportedError(String? extension) {
    if (extension != null) return '不支持上传 .$extension 文件。';
    return '不支持上传这种文件类型。';
  }

  @override
  String get couldNotReadBytesFromFileError => '无法读取该文件的内容。';

  @override
  String get addAFileLabel => '添加文件';

  @override
  String get photoFromCameraLabel => '拍照';

  @override
  String get uploadAFileLabel => '上传文件';

  @override
  String get uploadAPhotoLabel => '上传图片';

  @override
  String get uploadAVideoLabel => '上传视频';

  @override
  String get videoFromCameraLabel => '录像';

  @override
  String get okLabel => '好';

  @override
  String get somethingWentWrongError => '出了点问题';

  @override
  String get connectionErrorTitle => '设备当前离线';

  @override
  String get connectionErrorDescription => '请检查网络连接';

  @override
  String get slowConnectionErrorTitle => '网络较慢';

  @override
  String get slowConnectionErrorDescription => '当前网络连接似乎不稳定';

  @override
  String get genericErrorTitle => '出错了';

  @override
  String get genericErrorDescription => '出了点问题，请稍后再试';

  @override
  String get addMoreFilesLabel => '继续添加';

  @override
  String get enablePhotoAndVideoAccessMessage => '请允许访问相册\n才能把图片和视频分享给好友。';

  @override
  String get allowGalleryAccessMessage => '允许访问相册';

  @override
  String get flagMessageLabel => '举报消息';

  @override
  String get flagMessageQuestion => '要把这条消息的副本发送给管理员进一步核查吗？';

  @override
  String get flagLabel => '举报';

  @override
  String get cancelLabel => '取消';

  @override
  String get flagMessageSuccessfulLabel => '举报已提交';

  @override
  String get flagMessageSuccessfulText => '这条消息已提交给管理员。';

  @override
  String get deleteLabel => '删除';

  @override
  String get deleteMessageLabel => '删除消息';

  @override
  String get deleteMessageQuestion => '确定要永久删除这条消息吗？';

  @override
  String get operationCouldNotBeCompletedText => '这个操作没有完成。';

  @override
  String get replyLabel => '回复';

  @override
  String togglePinUnpinText({required bool pinned}) =>
      pinned ? '取消置顶' : '置顶到会话';

  @override
  String get markAsUnreadLabel => '标为未读';

  @override
  String unreadCountIndicatorLabel({required int unreadCount}) =>
      '$unreadCount 条未读';

  @override
  String toggleDeleteRetryDeleteMessageText({required bool isDeleteFailed}) =>
      isDeleteFailed ? '重试删除消息' : '删除消息';

  @override
  String get copyMessageLabel => '复制消息';

  @override
  String get editMessageLabel => '编辑消息';

  @override
  String toggleResendOrResendEditedMessage({required bool isUpdateFailed}) =>
      isUpdateFailed ? '重新发送已编辑的消息' : '重新发送';

  @override
  String get photosLabel => '图片';

  @override
  String get photosAndVideosLabel => '图片与视频';

  @override
  String sentAtText({required DateTime date, required DateTime time}) =>
      '${loopStreamDayLabel(date)} ${loopStreamClockLabel(time)} 发送';

  @override
  String get todayLabel => '今天';

  @override
  String get yesterdayLabel => '昨天';

  @override
  String get justNowLabel => '刚刚';

  @override
  String get channelIsMutedText => '这个会话已静音';

  @override
  String get noTitleText => '无标题';

  @override
  String get letsStartChattingLabel => '开始聊天吧';

  @override
  String get sendingFirstMessageLabel => '给好友发出第一条消息试试';

  @override
  String get startAChatLabel => '发起会话';

  @override
  String get loadingChannelsError => '加载会话失败';

  @override
  String get deleteConversationLabel => '删除会话';

  @override
  String get deleteConversationQuestion => '确定要删除这个会话吗？';

  @override
  String get streamChatLabel => 'Stream Chat';

  @override
  String get searchingForNetworkText => '正在寻找网络';

  @override
  String get offlineLabel => '离线…';

  @override
  String get tryAgainLabel => '重试';

  @override
  String membersCountText(int count) => '$count 位成员';

  @override
  String watchersCountText(int count) => '$count 人在线';

  @override
  String membersCountWithOnlineText({
    required int memberCount,
    required int onlineCount,
  }) {
    final members = membersCountText(memberCount);
    if (onlineCount <= 0) return members;
    return '$members · ${watchersCountText(onlineCount)}';
  }

  @override
  String get viewInfoLabel => '查看信息';

  @override
  String get leaveGroupLabel => '退出群聊';

  @override
  String get leaveLabel => '退出';

  @override
  String get leaveConversationLabel => '退出会话';

  @override
  String get leaveConversationQuestion => '确定要退出这个会话吗？';

  @override
  String get showInChatLabel => '在会话中查看';

  @override
  String get saveImageLabel => '保存图片';

  @override
  String get saveVideoLabel => '保存视频';

  @override
  String get uploadErrorLabel => '上传失败';

  @override
  String get giphyLabel => 'Giphy';

  @override
  String get shuffleLabel => '换一个';

  @override
  String get sendLabel => '发送';

  @override
  String get withText => '与';

  @override
  String get inText => '于';

  @override
  String get youText => '你';

  @override
  String galleryPaginationText({
    required int currentPage,
    required int totalPages,
  }) => '${currentPage + 1} / $totalPages';

  @override
  String get fileText => '文件';

  @override
  String get replyToMessageLabel => '回复这条消息';

  @override
  String replyToUserLabel(String userName) => '回复 $userName';

  @override
  String slowModeOnLabel(int cooldownTimeOut) => '慢速模式，请等待 $cooldownTimeOut 秒…';

  @override
  String get commandUsernameLabel => '@用户名';

  @override
  String get viewLibrary => '查看相册';

  @override
  String attachmentLimitExceedError(int limit) => '附件数量超出上限：最多只能添加 $limit 个附件';

  @override
  String get downloadLabel => '下载';

  @override
  String toggleMuteUnmuteUserText({required bool isMuted}) =>
      isMuted ? '取消静音该用户' : '静音该用户';

  @override
  String toggleBlockUnblockUserText({required bool isBlocked}) =>
      isBlocked ? '取消屏蔽该用户' : '屏蔽该用户';

  @override
  String toggleMuteUnmuteGroupQuestion({required bool isMuted}) =>
      isMuted ? '确定要取消这个群聊的静音吗？' : '确定要静音这个群聊吗？';

  @override
  String toggleMuteUnmuteUserQuestion({required bool isMuted}) =>
      isMuted ? '确定要取消这位用户的静音吗？' : '确定要静音这位用户吗？';

  @override
  String toggleMuteUnmuteAction({required bool isMuted}) =>
      isMuted ? '取消静音' : '静音';

  @override
  String toggleMuteUnmuteGroupText({required bool isMuted}) =>
      isMuted ? '取消静音群聊' : '静音群聊';

  @override
  String get linkDisabledDetails => '这个会话不允许发送链接。';

  @override
  String get linkDisabledError => '链接已被禁用';

  @override
  String unreadMessagesSeparatorText() => '新消息';

  @override
  String get enableFileAccessMessage => '请允许访问文件\n才能把文件分享给好友。';

  @override
  String get allowFileAccessMessage => '允许访问文件';

  @override
  String get markUnreadError => '标为未读失败。无法标记比最近 100 条更早的消息。';

  @override
  String createPollLabel({bool isNew = false}) => isNew ? '创建新投票' : '创建投票';

  @override
  String questionLabel({bool isPlural = false}) => '问题';

  @override
  String get askAQuestionLabel => '提一个问题';

  @override
  String? pollQuestionValidationError(int length, Range<int> range) {
    final (:min, :max) = range;
    if (min != null && length < min) return '问题至少需要 $min 个字符';
    if (max != null && length > max) return '问题最多 $max 个字符';
    return null;
  }

  @override
  String optionLabel({bool isPlural = false}) => '选项';

  @override
  String get pollOptionEmptyError => '选项不能为空';

  @override
  String get pollOptionDuplicateError => '这个选项已经存在';

  @override
  String get addAnOptionLabel => '添加选项';

  @override
  String get multipleAnswersLabel => '多选';

  @override
  String get multipleAnswersDescription => '允许选择多个选项';

  @override
  String get maximumVotesPerPersonLabel => '每人最多可投票数';

  @override
  String maximumVotesPerPersonDescription([Range<int>? range]) {
    final (:min, :max) = range ?? (min: 2, max: 10);
    return '可选择 $min–$max 个选项';
  }

  @override
  String? maxVotesPerPersonValidationError(int votes, Range<int> range) {
    final (:min, :max) = range;
    if (min != null && votes < min) return '票数至少为 $min';
    if (max != null && votes > max) return '票数最多为 $max';
    return null;
  }

  @override
  String get anonymousPollLabel => '匿名投票';

  @override
  String get anonymousPollDescription => '隐藏投票人';

  @override
  String get pollOptionsLabel => '投票选项';

  @override
  String get suggestAnOptionLabel => '建议一个选项';

  @override
  String get suggestAnOptionDescription => '允许其他人添加选项';

  @override
  String get enterANewOptionLabel => '输入新的选项';

  @override
  String get addACommentLabel => '添加评论';

  @override
  String get addACommentDescription => '允许其他人评论';

  @override
  String get pollCommentsLabel => '投票评论';

  @override
  String get updateYourCommentLabel => '更新你的评论';

  @override
  String get enterYourCommentLabel => '输入你的评论';

  @override
  String get endVoteConfirmationTitle => '结束这个投票？';

  @override
  String get endVoteConfirmationMessage => '现在结束这个投票吗？结束后所有人都无法再投票。';

  @override
  String get deletePollOptionLabel => '删除选项';

  @override
  String get deletePollOptionQuestion => '确定要删除这个选项吗？';

  @override
  String get createLabel => '创建';

  @override
  String get endLabel => '结束';

  @override
  String pollVotingModeLabel(PollVotingMode votingMode) => votingMode.when(
    disabled: () => '投票已结束',
    unique: () => '单选',
    limited: (count) => '最多选 $count 项',
    all: () => '可多选',
  );

  @override
  String seeAllOptionsLabel({int? count}) =>
      count == null ? '查看全部选项' : '查看全部 $count 个选项';

  @override
  String get viewCommentsLabel => '查看评论';

  @override
  String get viewResultsLabel => '查看结果';

  @override
  String get endVoteLabel => '结束投票';

  @override
  String get pollResultsLabel => '投票结果';

  @override
  String get pollVotesLabel => '票';

  @override
  String showAllVotesLabel({int? count}) =>
      count == null ? '查看全部投票' : '查看全部 $count 票';

  @override
  String get viewAllLabel => '查看全部';

  @override
  String voteCountLabel({int? count}) => '${count ?? 0} 票';

  @override
  String totalVoteCountLabel({int? count}) => '共 ${count ?? 0} 票';

  @override
  String get noPollVotesLabel => '当前还没有投票';

  @override
  String get loadingPollVotesError => '加载投票失败';

  @override
  String get repliedToLabel => '回复了：';

  @override
  String newThreadsLabel({required int count}) => '$count 个新话题';

  @override
  String get loadingLabel => '加载中…';

  @override
  String get slideToCancelLabel => '滑动取消';

  @override
  String get holdToRecordLabel => '按住录音，松开保存。';

  @override
  String get sendAnywayLabel => '仍然发送';

  @override
  String get moderatedMessageBlockedText => '这条消息被内容审核拦截';

  @override
  String get moderationReviewModalTitle => '确定要发送吗？';

  @override
  String get moderationReviewModalDescription => '请考虑这条内容会给他人带来的感受，并遵守社区规范。';

  @override
  String get emptyMessagePreviewText => '';

  @override
  String get voiceRecordingText => '语音';

  @override
  String get audioAttachmentText => '音频';

  @override
  String get imageAttachmentText => '图片';

  @override
  String get videoAttachmentText => '视频';

  @override
  String get fileAttachmentText => '文件';

  @override
  String get linkAttachmentText => '链接';

  @override
  String filesAttachmentCountText(int count) => '$count 个文件';

  @override
  String photosAttachmentCountText(int count) => '$count 张图片';

  @override
  String videosAttachmentCountText(int count) => '$count 个视频';

  @override
  String get pollYouVotedText => '你投了票';

  @override
  String pollSomeoneVotedText(String username) => '$username 投了票';

  @override
  String get pollYouCreatedText => '你创建了投票';

  @override
  String pollSomeoneCreatedText(String username) => '$username 创建了投票';

  @override
  String get draftLabel => '草稿';

  @override
  String locationLabel({bool isLive = false}) => isLive ? '实时位置' : '位置';

  @override
  String get noConversationsYetText => '还没有会话';

  @override
  String get replyToStartThreadText => '回复一条消息即可开启话题';

  @override
  String get sendMessageToStartConversationText => '发条消息，开始这段对话';

  @override
  String get savedForLaterLabel => '稍后查看';

  @override
  String get repliedToThreadAnnotationLabel => '回复了话题';

  @override
  String get alsoSentInChannelAnnotationLabel => '同时发到了频道';

  @override
  String get viewLabel => '查看';

  @override
  String get reminderSetLabel => '已设置提醒';

  @override
  String reminderAtText(String time) => '今天 $time';

  @override
  String get createPollPromptLabel => '发起一个投票，让大家一起选';

  @override
  String get takePhotoAndShareLabel => '拍照并分享';

  @override
  String get takeVideoAndShareLabel => '录像并分享';

  @override
  String get openCameraLabel => '打开相机';

  @override
  String get selectFilesToShareLabel => '选择要分享的文件';

  @override
  String get openFilesLabel => '打开文件';

  @override
  String get unsupportedAttachmentLabel => '不支持的附件';

  @override
  String get confirmLabel => '确认';

  @override
  String get emptyReactionsText => '还没有表态';

  @override
  String get loadingReactionsError => '加载表态失败';

  @override
  String get tapToRemoveReactionLabel => '点按可取消';

  @override
  String reactionsCountText(int count) => '$count 个表态';

  @override
  String get notifyChannelText => '提醒这个频道的所有人';

  @override
  String get notifyHereText => '提醒这个频道所有在线成员';

  @override
  String notifyRoleText(String role) => '提醒所有 $role 成员';
}

/// Installs [LoopStreamChatLocalizations] for every locale.
///
/// LOOP ships one language. The delegate answers for any locale so the
/// official widgets stay Chinese even though the application locale — and
/// therefore `MaterialLocalizations` — remains the framework default.
class LoopStreamChatLocalizationsDelegate
    extends LocalizationsDelegate<StreamChatLocalizations> {
  /// Creates the delegate.
  const LoopStreamChatLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<StreamChatLocalizations> load(Locale locale) =>
      SynchronousFuture<StreamChatLocalizations>(
        const LoopStreamChatLocalizations(),
      );

  @override
  bool shouldReload(LoopStreamChatLocalizationsDelegate old) => false;
}

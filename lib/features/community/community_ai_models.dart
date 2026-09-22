import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/community/community_contract.dart';

/// The Community AI view models (loop-api decision 0066).
///
/// Everything here is the server's own answer, restated in the shapes the
/// page renders. Nothing is derived: the eight abilities arrive already
/// filtered by permission, the knowledge snapshot counts live sources rather
/// than documents (LOOP ingests none), and an answer may name only the
/// sources the same response carried.

/// One of the prototype's eight abilities.
///
/// The list is the server's: `communityAnalytics` is simply absent from a
/// member's response, and the client never adds it back.
enum CommunityAiAbility {
  projectKnowledge('projectKnowledge'),
  communitySupport('communitySupport'),
  newcomerEducation('newcomerEducation'),
  projectUpdates('projectUpdates'),
  assetInformation('assetInformation'),
  communityGuidance('communityGuidance'),
  aiPatrol('aiPatrol'),
  communityAnalytics('communityAnalytics');

  const CommunityAiAbility(this.wireName);

  final String wireName;

  /// The sprite glyph the prototype draws beside this row. It is presentation
  /// only: the row's words are the server's.
  String get icon => switch (this) {
    CommunityAiAbility.projectKnowledge => 'book',
    CommunityAiAbility.communitySupport => 'chat',
    CommunityAiAbility.newcomerEducation => 'graduate',
    CommunityAiAbility.projectUpdates => 'news',
    CommunityAiAbility.assetInformation => 'chart',
    CommunityAiAbility.communityGuidance => 'compass',
    CommunityAiAbility.aiPatrol => 'shield',
    CommunityAiAbility.communityAnalytics => 'smart',
  };

  static CommunityAiAbility? tryParse(String value) {
    for (final ability in values) {
      if (ability.wireName == value) return ability;
    }
    return null;
  }
}

/// One ability row: what it is, and whether anything backs it yet.
@immutable
final class CommunityAiCapability {
  const CommunityAiCapability({
    required this.ability,
    required this.title,
    required this.summary,
    required this.available,
    required this.reasonCode,
    required this.adminOnly,
  });

  final CommunityAiAbility ability;

  /// The server's own words for the row. The client prints them verbatim.
  final String title;
  final String summary;
  final bool available;

  /// Why nothing backs it, when nothing does. It never reaches a screen as
  /// itself: [communityAiReason] turns it into a sentence.
  final String? reasonCode;

  /// Whether this row is an owner/admin ability. It decides nothing on the
  /// client: the server already removed the rows this account may not see.
  final bool adminOnly;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityAiCapability &&
          other.ability == ability &&
          other.title == title &&
          other.summary == summary &&
          other.available == available &&
          other.reasonCode == reasonCode &&
          other.adminOnly == adminOnly;

  @override
  int get hashCode =>
      Object.hash(ability, title, summary, available, reasonCode, adminOnly);
}

/// What an assembled knowledge source is.
enum CommunityAiSourceKind {
  communityProfile('communityProfile'),
  assetFacts('assetFacts'),
  communityMining('communityMining'),
  voiceRoom('voiceRoom'),
  communityChat('communityChat'),

  /// Never assembled: it exists so an omission can name it.
  announcements('announcements');

  const CommunityAiSourceKind(this.wireName);

  final String wireName;

  /// Whether a *published* source may carry this kind. Announcements are only
  /// ever an omission (there is no announcement projection to read).
  bool get isAssemblable => this != CommunityAiSourceKind.announcements;

  static CommunityAiSourceKind? tryParse(String value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

/// One source this answer (or this overview) was assembled from.
///
/// `sourceId` is a handle that is stable only inside the one response it
/// arrived in, which is why nothing on the client ever caches or cross-maps
/// it.
@immutable
final class CommunityAiSource {
  const CommunityAiSource({
    required this.sourceId,
    required this.kind,
    required this.label,
    required this.observedAt,
  });

  final String sourceId;
  final CommunityAiSourceKind kind;

  /// The server's own label, e.g. 「社区档案：PEPE」.
  final String label;
  final DateTime observedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityAiSource &&
          other.sourceId == sourceId &&
          other.kind == kind &&
          other.label == label &&
          other.observedAt == observedAt;

  @override
  int get hashCode => Object.hash(sourceId, kind, label, observedAt);
}

/// A source that was not used this time, and why.
@immutable
final class CommunityAiOmittedSource {
  const CommunityAiOmittedSource({
    required this.kind,
    required this.reasonCode,
  });

  final CommunityAiSourceKind kind;
  final String reasonCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityAiOmittedSource &&
          other.kind == kind &&
          other.reasonCode == reasonCode;

  @override
  int get hashCode => Object.hash(kind, reasonCode);
}

/// The knowledge snapshot the top bar states.
///
/// It counts *live sources*, never documents: `documents` is permanently
/// unavailable because LOOP has no document corpus, and the prototype's
/// 「知识库 14 篇文档」 has nothing behind it.
@immutable
final class CommunityAiKnowledge {
  const CommunityAiKnowledge({
    required this.sourceCount,
    required this.updatedAt,
    required this.sources,
    required this.omittedSources,
    required this.documentsReasonCode,
  });

  final int sourceCount;

  /// When the newest source was observed, or null when there is none.
  final DateTime? updatedAt;
  final List<CommunityAiSource> sources;
  final List<CommunityAiOmittedSource> omittedSources;

  /// Why there is no document count. It is a reason, not a figure.
  final String documentsReasonCode;
}

/// Today's discussion summary, or the server's reason for not having one.
@immutable
sealed class CommunityAiBrief {
  const CommunityAiBrief();
}

@immutable
final class CommunityAiBriefUnavailable extends CommunityAiBrief {
  const CommunityAiBriefUnavailable(this.reasonCode);

  final String reasonCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityAiBriefUnavailable && other.reasonCode == reasonCode;

  @override
  int get hashCode => reasonCode.hashCode;
}

@immutable
final class CommunityAiBriefAvailable extends CommunityAiBrief {
  const CommunityAiBriefAvailable({
    required this.messageCount,
    required this.bounded,
    required this.windowHours,
    required this.summary,
    required this.model,
    required this.generatedAt,
  });

  final int messageCount;

  /// True when the count is a floor: a full page of messages was still inside
  /// the window, so the page says 「至少 N 条」 rather than 「N 条」.
  final bool bounded;
  final int windowHours;

  /// Written by the model, so it always carries the AI mark beside it.
  final String summary;
  final String model;
  final DateTime generatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityAiBriefAvailable &&
          other.messageCount == messageCount &&
          other.bounded == bounded &&
          other.windowHours == windowHours &&
          other.summary == summary &&
          other.model == model &&
          other.generatedAt == generatedAt;

  @override
  int get hashCode => Object.hash(
    messageCount,
    bounded,
    windowHours,
    summary,
    model,
    generatedAt,
  );
}

/// `GET …/ai/overview`: the whole first screen.
@immutable
final class CommunityAiOverview {
  const CommunityAiOverview({
    required this.capabilities,
    required this.knowledge,
    required this.exampleQuestions,
    required this.brief,
    required this.disclaimer,
  });

  final List<CommunityAiCapability> capabilities;
  final CommunityAiKnowledge knowledge;
  final List<String> exampleQuestions;
  final CommunityAiBrief brief;

  /// The fixed sentence that stays at the foot of the conversation.
  final String disclaimer;
}

/// `POST …/ai/ask`: one answer, with everything needed to judge it.
@immutable
final class CommunityAiAnswer {
  const CommunityAiAnswer({
    required this.answerId,
    required this.answer,
    required this.refusal,
    required this.citations,
    required this.sources,
    required this.omittedSources,
    required this.model,
    required this.generatedAt,
    required this.disclaimer,
  });

  final String answerId;

  /// The model's text. Empty only when [refusal] says why it declined.
  final String answer;

  /// The model's own refusal sentence. It is shown as the reply; the client
  /// never rephrases the question and asks again.
  final String? refusal;

  /// The sources the answer names, already intersected with [sources] by the
  /// server. A handle the model invented never arrives here.
  final List<CommunityAiSource> citations;
  final List<CommunityAiSource> sources;
  final List<CommunityAiOmittedSource> omittedSources;
  final String model;
  final DateTime generatedAt;
  final String disclaimer;

  /// What the bubble prints: the refusal when there is one, else the answer.
  String get spoken => refusal ?? answer;
}

/// Why a reader is reporting an answer.
enum CommunityAiReportReason {
  inaccurate('inaccurate', '内容不准确'),
  harmful('harmful', '有害或危险'),
  offTopic('offTopic', '答非所问'),
  privacy('privacy', '涉及个人隐私'),
  other('other', '其他问题');

  const CommunityAiReportReason(this.wireName, this.label);

  final String wireName;

  /// What the reader chooses. It is product copy, not the wire value.
  final String label;

  static CommunityAiReportReason? tryParse(String value) {
    for (final reason in values) {
      if (reason.wireName == value) return reason;
    }
    return null;
  }
}

/// `POST …/ai/answers/{answerId}/report`: the stored report.
@immutable
final class CommunityAiReportReceipt {
  const CommunityAiReportReceipt({
    required this.answerId,
    required this.reportId,
    required this.reason,
    required this.createdAt,
  });

  final String answerId;
  final String reportId;
  final CommunityAiReportReason reason;
  final DateTime createdAt;
}

// ---------------------------------------------------------------------------
// Answer text
// ---------------------------------------------------------------------------

/// One run of an answer: either words, or a citation handle the reader can
/// open.
@immutable
sealed class CommunityAiAnswerRun {
  const CommunityAiAnswerRun();
}

@immutable
final class CommunityAiAnswerText extends CommunityAiAnswerRun {
  const CommunityAiAnswerText(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityAiAnswerText && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

@immutable
final class CommunityAiAnswerCitation extends CommunityAiAnswerRun {
  const CommunityAiAnswerCitation(this.source);

  /// The cited source itself, so the tap needs no second lookup.
  final CommunityAiSource source;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityAiAnswerCitation && other.source == source;

  @override
  int get hashCode => source.hashCode;
}

/// `[s2]` inside an answer. The server's `sourceId` shape, in brackets.
final RegExp _citationMarker = RegExp(r'\[(s[1-9][0-9]{0,2})\]');

/// Splits [answer] into words and citation handles.
///
/// A handle the response did not cite stays plain text: it is not a control,
/// because there is nothing to open behind it. Only a handle present in
/// [citations] becomes one, so a number the model invented can never turn into
/// a tappable claim of provenance.
List<CommunityAiAnswerRun> communityAiAnswerRuns(
  String answer,
  List<CommunityAiSource> citations,
) {
  final runs = <CommunityAiAnswerRun>[];
  var index = 0;
  void addText(String text) {
    if (text.isEmpty) return;
    final last = runs.isEmpty ? null : runs.last;
    if (last is CommunityAiAnswerText) {
      runs[runs.length - 1] = CommunityAiAnswerText('${last.text}$text');
    } else {
      runs.add(CommunityAiAnswerText(text));
    }
  }

  for (final match in _citationMarker.allMatches(answer)) {
    addText(answer.substring(index, match.start));
    index = match.end;
    final handle = match.group(1)!;
    CommunityAiSource? cited;
    for (final citation in citations) {
      if (citation.sourceId == handle) {
        cited = citation;
        break;
      }
    }
    if (cited == null) {
      addText(match.group(0)!);
    } else {
      runs.add(CommunityAiAnswerCitation(cited));
    }
  }
  addText(answer.substring(index));
  return List<CommunityAiAnswerRun>.unmodifiable(runs);
}

// ---------------------------------------------------------------------------
// Copy
// ---------------------------------------------------------------------------

/// zh-CN sentence for one Community AI `reasonCode`.
///
/// The code itself never reaches a screen; an unknown code keeps a neutral
/// sentence instead of inventing a cause.
String communityAiReason(String? reasonCode) => switch (reasonCode) {
  // The five abilities nothing backs yet.
  'KNOWLEDGE_DOCUMENTS_NOT_INGESTED' => '还没有收录项目文档，这一项暂时答不了。',
  'EDUCATION_CONTENT_NOT_INGESTED' => '还没有收录新手教程，这一项暂时答不了。',
  'ANNOUNCEMENT_SOURCE_UNAVAILABLE' => '还没有接入公告和官方动态，这一项暂时答不了。',
  'AI_WRITE_LANE_NOT_DELIVERED' => 'AI 巡查还没有开放。',
  'COMMUNITY_ANALYTICS_NOT_DELIVERED' => '社区分析还没有开放。',
  // Why today's summary is missing.
  'COMMUNITY_AI_MEMBERSHIP_REQUIRED' => '先加入这个社区，才能读到社区里的讨论。',
  'COMMUNITY_CHAT_NOT_CONNECTED' => '这个社区还没有开通官方群，没有可以总结的讨论。',
  'COMMUNITY_CHAT_NOT_OBSERVED' => '这次没能读到官方群的讨论。',
  // What the model did, or did not do.
  'COMMUNITY_AI_PROVIDER_UNAVAILABLE' => 'AI 这次没有答上来，稍后可以再试。',
  'COMMUNITY_AI_PROVIDER_REJECTED' => 'AI 拒绝了这次请求，再试也不会有结果。',
  'COMMUNITY_AI_PROVIDER_MALFORMED' => 'AI 返回的内容不完整，这次没有采用。',
  'COMMUNITY_AI_NO_KNOWLEDGE_SOURCE' => '这个社区现在没有任何可用来源，暂时问不了。',
  'COMMUNITY_AI_RUNTIME_DEFERRED' => 'AI 助理还没有接入。',
  _ => '这一项暂时读不到。',
};

/// The top bar's second line: how many live sources, and when the newest was
/// observed. Never a document count.
String communityAiKnowledgeLine(CommunityAiKnowledge knowledge) {
  final updatedAt = knowledge.updatedAt;
  if (updatedAt == null || knowledge.sourceCount == 0) return '暂无可用来源';
  return '知识源 ${knowledge.sourceCount} 项 · 更新于 '
      '${communityAiTimestamp(updatedAt)}';
}

/// The hero's heading: how much was said in the window behind the summary.
String communityAiBriefHeading(CommunityAiBriefAvailable brief) => brief.bounded
    ? '今日至少 ${brief.messageCount} 条讨论'
    : '今日 ${brief.messageCount} 条讨论';

/// The AI mark every model-written block carries: which model wrote it, and
/// when.
String communityAiGeneratedLabel({
  required String model,
  required DateTime generatedAt,
}) => 'AI 生成 · $model · ${communityAiTimestamp(generatedAt)}';

/// A server timestamp in UTC. The client never restates it as a local wall
/// clock or as a relative 「刚刚」.
String communityAiTimestamp(DateTime value) {
  final utc = value.toUtc();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
      '${two(utc.hour)}:${two(utc.minute)} UTC';
}

/// What a rate limit means to the reader.
///
/// The two scopes are two different waits: the per-account minute is over in a
/// minute, the community's daily budget is not.
String communityAiRateLimitReason(String? scope) => switch (scope) {
  'community' => '这个社区今天的提问额度用完了，明天再来。',
  _ => '提问太频繁了，等一分钟再问。',
};

/// zh-CN sentence for a refused question.
///
/// A quota refusal names which budget ran out, a capability refusal carries
/// the server's own reason, and everything else falls back to the shared S3
/// sentence for its class. No branch here prints a code.
String communityAiFailureReason({
  required CommunityFailureKind? kind,
  String? reasonCode,
  String? scope,
}) {
  if (kind == CommunityFailureKind.rateLimited) {
    return communityAiRateLimitReason(scope);
  }
  if (reasonCode != null &&
      (kind == CommunityFailureKind.unavailable ||
          kind == CommunityFailureKind.permissionDenied)) {
    return communityAiReason(reasonCode);
  }
  return communityFailureReason(kind);
}

import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

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

/// The summary for today is being written right now.
///
/// The server answers the overview read immediately and generates the brief
/// behind it (loop-api S76b), because a summary that took twelve seconds to
/// write was holding the whole page — and the socket closed before it
/// arrived, so the reader was told a submission had gone unconfirmed over a
/// page they had only opened.
const communityAiBriefPendingReasonCode = 'COMMUNITY_AI_BRIEF_PENDING';

/// The community's summary budget for today is spent.
///
/// Like the pending one it is a state rather than a failure — the rest of the
/// overview is complete — but nothing the reader or the page can do brings it
/// back before tomorrow, so it earns no re-read.
const communityAiBriefQuotaExhaustedReasonCode = 'COMMUNITY_AI_QUOTA_EXHAUSTED';

@immutable
final class CommunityAiBriefUnavailable extends CommunityAiBrief {
  const CommunityAiBriefUnavailable(this.reasonCode);

  final String reasonCode;

  /// Whether the summary is on its way rather than missing. It is the one
  /// reason worth reading again without the reader asking.
  bool get isGenerating => reasonCode == communityAiBriefPendingReasonCode;

  /// Whether the absence is a state rather than something that went wrong.
  ///
  /// Two of the eight reasons are: the summary is being written, and today's
  /// budget is spent. Neither is a failure of this read, so neither is said
  /// in the failing voice.
  bool get isNeutral =>
      isGenerating || reasonCode == communityAiBriefQuotaExhaustedReasonCode;

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
  inaccurate('inaccurate'),
  harmful('harmful'),
  offTopic('offTopic'),
  privacy('privacy'),
  other('other');

  const CommunityAiReportReason(this.wireName);

  final String wireName;

  /// What the reader chooses. It is product copy, not the wire value.
  String get label => switch (this) {
    CommunityAiReportReason.inaccurate =>
      LoopL10n.current.community_aiModelsInaccurate,
    CommunityAiReportReason.harmful =>
      LoopL10n.current.community_aiModelsHarmful,
    CommunityAiReportReason.offTopic =>
      LoopL10n.current.community_aiModelsOffTopic,
    CommunityAiReportReason.privacy =>
      LoopL10n.current.community_aiModelsPrivacy,
    CommunityAiReportReason.other => LoopL10n.current.community_aiModelsOther,
  };

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
  'KNOWLEDGE_DOCUMENTS_NOT_INGESTED' =>
    LoopL10n.current.community_aiModelsSwitch,
  'EDUCATION_CONTENT_NOT_INGESTED' =>
    LoopL10n.current.community_aiModelsSwitch2,
  'ANNOUNCEMENT_SOURCE_UNAVAILABLE' =>
    LoopL10n.current.community_aiModelsSwitch3,
  'AI_WRITE_LANE_NOT_DELIVERED' => LoopL10n.current.community_aiModelsSwitch4,
  'COMMUNITY_ANALYTICS_NOT_DELIVERED' =>
    LoopL10n.current.community_aiModelsSwitch5,
  // Why today's summary is missing. The eight codes are a closed set; an
  // unknown one still keeps a neutral sentence rather than a code.
  communityAiBriefPendingReasonCode =>
    LoopL10n.current.community_aiModelsSwitch6,
  communityAiBriefQuotaExhaustedReasonCode =>
    LoopL10n.current.community_aiModelsSwitch7,
  'COMMUNITY_AI_MEMBERSHIP_REQUIRED' =>
    LoopL10n.current.community_aiModelsSwitch8,
  'COMMUNITY_CHAT_NOT_CONNECTED' => LoopL10n.current.community_aiModelsSwitch9,
  'COMMUNITY_CHAT_NOT_OBSERVED' => LoopL10n.current.community_aiModelsSwitch10,
  // What the model did, or did not do.
  'COMMUNITY_AI_PROVIDER_UNAVAILABLE' =>
    LoopL10n.current.community_aiModelsSwitch11,
  'COMMUNITY_AI_PROVIDER_REJECTED' =>
    LoopL10n.current.community_aiModelsSwitch12,
  'COMMUNITY_AI_PROVIDER_MALFORMED' =>
    LoopL10n.current.community_aiModelsSwitch13,
  'COMMUNITY_AI_NO_KNOWLEDGE_SOURCE' =>
    LoopL10n.current.community_aiModelsSwitch14,
  'COMMUNITY_AI_RUNTIME_DEFERRED' =>
    LoopL10n.current.community_aiModelsSwitch15,
  _ => LoopL10n.current.common_itemUnavailable,
};

/// The top bar's second line: how many live sources, and when the newest was
/// observed. Never a document count.
String communityAiKnowledgeLine(CommunityAiKnowledge knowledge) {
  final updatedAt = knowledge.updatedAt;
  if (updatedAt == null || knowledge.sourceCount == 0) {
    return LoopL10n.current.community_aiModelsCommunityAiKnowledgeLine;
  }
  return LoopL10n.current.community_aiModelsCommunityAiKnowledgeLine2(
    communityAiTimestamp(updatedAt),
    knowledge.sourceCount,
  );
}

/// The hero's two lines when there is no summary: what the state is, and what
/// it means for the reader.
///
/// A summary that is being written and a budget that is spent are states, so
/// they are headed as themselves; every other reason is this read failing to
/// produce one, and says 「今日讨论读不到」 over the server's own sentence.
({String heading, String caption}) communityAiBriefAbsence(
  CommunityAiBriefUnavailable brief,
) => switch (brief.reasonCode) {
  communityAiBriefPendingReasonCode => (
    heading: communityAiBriefPendingHeading,
    caption: LoopL10n.current.community_aiModelsCaption,
  ),
  communityAiBriefQuotaExhaustedReasonCode => (
    heading: communityAiBriefQuotaHeading,
    caption: LoopL10n.current.community_aiModelsCaption2,
  ),
  _ => (
    heading: LoopL10n.current.community_aiModelsHeading,
    caption: communityAiReason(brief.reasonCode),
  ),
};

/// The hero's heading while the summary is being written. It is a state, not
/// a failure, so it neither says 「读不到」 nor offers a 重试.
String get communityAiBriefPendingHeading =>
    LoopL10n.current.community_aiModelsCommunityAiBriefPendingHeading;

/// The hero's heading once today's summary budget is spent.
String get communityAiBriefQuotaHeading =>
    LoopL10n.current.community_aiModelsCommunityAiBriefQuotaHeading;

/// The hero's heading: how much was said in the window behind the summary.
String communityAiBriefHeading(CommunityAiBriefAvailable brief) => brief.bounded
    ? LoopL10n.current.community_aiModelsSwitch16(brief.messageCount)
    : LoopL10n.current.community_aiModelsS(brief.messageCount);

/// The AI mark every model-written block carries: which model wrote it, and
/// when.
String communityAiGeneratedLabel({
  required String model,
  required DateTime generatedAt,
}) => LoopL10n.current.community_aiModelsCommunityAiGeneratedLabel(
  communityAiTimestamp(generatedAt),
  model,
);

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
  'community' => LoopL10n.current.community_aiModelsSwitch17,
  _ => LoopL10n.current.community_aiModelsSwitch18,
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

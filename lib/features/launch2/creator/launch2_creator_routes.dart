import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_create_screen.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_deployment_screen.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_project_screen.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_projects_screen.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_sign_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';

/// The five project-side routes of MEME v2 (S135, decision 0138; manifest
/// 105 → 110).
///
/// A project is addressed by the server's opaque `projectId` and a job by its
/// `jobId`, both in the query; a missing or malformed one fails closed on the
/// page. The manifest forbids `:` in a path, so `/launch2/projects/:id` of
/// the design note is `/launch2/project?id=`.
abstract final class Launch2CreatorRoute {
  static const String createPath = '/launch2/create';
  static const String minePath = '/launch2/projects/mine';
  static const String projectPath = '/launch2/project';
  static const String signPath = '/launch2/project/sign';
  static const String deploymentPath = '/launch2/project/deployment';

  static final RegExp _idPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  static bool isId(String? value) =>
      value != null && _idPattern.hasMatch(value);

  static String? idOf(Uri uri, {String key = 'id'}) {
    final value = uri.queryParameters[key];
    return isId(value) ? value : null;
  }

  static String _with(String path, Map<String, String> query) =>
      Uri(path: path, queryParameters: query).toString();

  /// The edit form for a draft, returned or rejected project, or a rejected
  /// launch configuration (decision 0144).
  static String edit(String projectId) =>
      _with(createPath, <String, String>{'project': projectId});

  static String project(String projectId) =>
      _with(projectPath, <String, String>{'id': projectId});

  static String sign(String projectId) =>
      _with(signPath, <String, String>{'id': projectId});

  static String deployment(String projectId, String jobId) =>
      _with(deploymentPath, <String, String>{'id': projectId, 'job': jobId});

  /// Where 我的项目 sends the owner for [resume] (decision 0142).
  static String resume(String projectId, Launch2CreatorResume resume) =>
      switch (resume.target) {
        Launch2ResumeTarget.edit => edit(projectId),
        Launch2ResumeTarget.status => project(projectId),
        Launch2ResumeTarget.sign => sign(projectId),
        Launch2ResumeTarget.deployment => deployment(projectId, resume.jobId!),
        Launch2ResumeTarget.instance => Launch2Route.instance(
          resume.instanceId!,
        ),
      };
}

/// S326 · decision 0256 (UX-005): opens [location] from inside the launch
/// flow without stacking the same page twice.
///
/// The create page's 「我的项目」 and 我的项目's rows (and a project page's
/// 「修改资料」) could reach a page already open lower in the stack, and every
/// visit pushed another copy, so back had to be pressed once per lap. When a
/// page with the same location is already on the stack, this pops back to it
/// instead; on the top of the stack it does nothing; otherwise it pushes.
void launch2PushOnce(BuildContext context, String location) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return;
  final target = Uri.parse(location);
  final pushed = <ImperativeRouteMatch>[
    for (final match in router.routerDelegate.currentConfiguration.matches)
      if (match is ImperativeRouteMatch) match,
  ];
  for (var index = pushed.length - 1; index >= 0; index--) {
    if (!launch2SameLocation(pushed[index].matches.uri, target)) continue;
    if (index == pushed.length - 1) return;
    final key = pushed[index].pageKey;
    final navigator = router.routerDelegate.navigatorKey.currentState;
    if (navigator == null) break;
    navigator.popUntil(
      (route) => route.settings is Page && (route.settings as Page).key == key,
    );
    return;
  }
  unawaited(router.push<Object?>(location));
}

/// Whether two locations name the same page: the same path and the same
/// query, in any order.
bool launch2SameLocation(Uri a, Uri b) {
  if (a.path != b.path) return false;
  final left = a.queryParameters;
  final right = b.queryParameters;
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

/// The route table `lib/app.dart` mounts. [popOrHome] is the App's own back.
/// [openInstance] opens the user-side page of an activated instance; until
/// S136 mounts it the App sends the owner to the MEME tab.
List<RouteBase> launch2CreatorRoutes({
  required void Function(BuildContext context) popOrHome,
  required void Function(BuildContext context, String instanceId) openInstance,
}) => <RouteBase>[
  GoRoute(
    path: Launch2CreatorRoute.createPath,
    builder: (context, state) => Launch2CreateScreen(
      key: ValueKey<String>('launch2-create-${state.uri.query}'),
      projectId: Launch2CreatorRoute.idOf(state.uri, key: 'project'),
      onBack: () => popOrHome(context),
      onSubmitted: (projectId) =>
          context.pushReplacement(Launch2CreatorRoute.project(projectId)),
      onOpenMyProjects: () =>
          launch2PushOnce(context, Launch2CreatorRoute.minePath),
    ),
  ),
  GoRoute(
    path: Launch2CreatorRoute.minePath,
    builder: (context, state) => Launch2ProjectsScreen(
      onBack: () => popOrHome(context),
      onNavigate: (location) => launch2PushOnce(context, location),
    ),
  ),
  GoRoute(
    path: Launch2CreatorRoute.projectPath,
    builder: (context, state) => Launch2ProjectScreen(
      key: ValueKey<String>('launch2-project-${state.uri.query}'),
      projectId: Launch2CreatorRoute.idOf(state.uri),
      onBack: () => popOrHome(context),
      onNavigate: (location) => launch2PushOnce(context, location),
      onOpenInstance: (instanceId) => openInstance(context, instanceId),
    ),
  ),
  GoRoute(
    path: Launch2CreatorRoute.signPath,
    builder: (context, state) => Launch2SignScreen(
      key: ValueKey<String>('launch2-sign-${state.uri.query}'),
      projectId: Launch2CreatorRoute.idOf(state.uri),
      onBack: () => popOrHome(context),
      onSubmitted: (projectId, jobId) => context.pushReplacement(
        Launch2CreatorRoute.deployment(projectId, jobId),
      ),
      onEdit: (projectId) =>
          context.pushReplacement(Launch2CreatorRoute.edit(projectId)),
    ),
  ),
  GoRoute(
    path: Launch2CreatorRoute.deploymentPath,
    builder: (context, state) => Launch2DeploymentScreen(
      key: ValueKey<String>('launch2-deployment-${state.uri.query}'),
      projectId: Launch2CreatorRoute.idOf(state.uri),
      jobId: Launch2CreatorRoute.idOf(state.uri, key: 'job'),
      onBack: () => popOrHome(context),
      onResign: (projectId) =>
          context.pushReplacement(Launch2CreatorRoute.sign(projectId)),
      onEdit: (projectId) =>
          context.pushReplacement(Launch2CreatorRoute.edit(projectId)),
      onOpenInstance: (instanceId) => openInstance(context, instanceId),
    ),
  ),
];

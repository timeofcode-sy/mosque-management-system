import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../../../widgets/behavior_section.dart';
import '../di/app_scope.dart';

/// سلوكي: ما كتبه أساتذتي عنّي في التفقّد، وصفاتي، ونقاطُ سلوكي — بالشكل الذي يراه وليُّ أمري.
class BehaviorScreen extends StatelessWidget {
  const BehaviorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).repository;

    return Scaffold(
      appBar: AppBar(title: const Text('سلوكي')),
      body: SnapshotView<StudentBehavior>(
        load: () async => (await repository.behavior()).ui,
        errorMessageBuilder: messageFor,
        builder: (context, behavior) => BehaviorSection(behavior: behavior),
      ),
    );
  }
}

import 'package:collection/collection.dart';

enum MissionStatus {
  open('Aberta'),
  inProgress('Em andamento'),
  completed('Concluída');

  const MissionStatus(this.label);
  final String label;
}

class MissionStep {
  MissionStep.fromJson(Map<String, dynamic> data)
    : _data = Map.unmodifiable(data);

  final Map<String, dynamic> _data;

  String get title => _data['title'] as String;
  String get details => _data['details'] as String;
  bool get completed => _data['completed'] as bool;

  MissionStep copyWith({String? title, String? details, bool? completed}) =>
      MissionStep.fromJson({
        ..._data,
        'title': title ?? this.title,
        'details': details ?? this.details,
        'completed': completed ?? this.completed,
      });

  Map<String, dynamic> toJson() => _data;
}

class MissionPlan {
  const MissionPlan({
    this.priority = 'Normal',
    this.started = false,
    this.completed = false,
    this.steps = const [],
  });

  factory MissionPlan.fromJson(Map<String, dynamic> data) => MissionPlan(
    priority: data['priority'] as String? ?? 'Normal',
    started: data['started'] == true,
    completed: data['completed'] == true,
    steps: List.unmodifiable([
      if (data['steps'] case final List steps)
        for (final step in steps)
          if (step is Map<String, dynamic> &&
              step['title'] is String &&
              step['details'] is String &&
              step['completed'] is bool)
            MissionStep.fromJson(step),
    ]),
  );

  final String priority;
  final bool started;
  final bool completed;
  final List<MissionStep> steps;

  MissionStatus get status => completed
      ? MissionStatus.completed
      : started
      ? MissionStatus.inProgress
      : MissionStatus.open;

  int get completedSteps => steps.where((step) => step.completed).length;

  MissionPlan copyWith({
    String? priority,
    MissionStatus? status,
    List<MissionStep>? steps,
  }) => MissionPlan(
    priority: priority ?? this.priority,
    started: status == null ? started : status != MissionStatus.open,
    completed: status == null ? completed : status == MissionStatus.completed,
    steps: steps == null ? this.steps : List.unmodifiable(steps),
  );

  Map<String, Object> toJson() => {
    'priority': priority,
    'started': started,
    'completed': completed,
    'steps': steps.map((step) => step.toJson()).toList(growable: false),
  };

  bool sameSteps(MissionPlan other) => const DeepCollectionEquality().equals(
    steps.map((step) => step.toJson()).toList(),
    other.steps.map((step) => step.toJson()).toList(),
  );

  bool sameStatus(MissionPlan other) =>
      started == other.started && completed == other.completed;

  MissionPlan rebase(MissionPlan original, MissionPlan remote) {
    final state = sameStatus(original) ? remote : this;
    return MissionPlan(
      priority: priority == original.priority ? remote.priority : priority,
      started: state.started,
      completed: state.completed,
      steps: sameSteps(original) ? remote.steps : steps,
    );
  }
}

import 'package:equatable/equatable.dart';

class SchedulerSweepResultModel extends Equatable {
  final int scannedProjects;
  final int pendingTasksFound;
  final int emailsDispatched;
  final String? executedAt;

  const SchedulerSweepResultModel({
    required this.scannedProjects,
    required this.pendingTasksFound,
    required this.emailsDispatched,
    this.executedAt,
  });

  factory SchedulerSweepResultModel.fromJson(Map<String, dynamic> json) {
    return SchedulerSweepResultModel(
      scannedProjects: json['scannedProjects'] as int? ?? 0,
      pendingTasksFound: json['pendingTasksFound'] as int? ?? 0,
      emailsDispatched: json['emailsDispatched'] as int? ?? 0,
      executedAt: DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scannedProjects': scannedProjects,
      'pendingTasksFound': pendingTasksFound,
      'emailsDispatched': emailsDispatched,
      'executedAt': executedAt,
    };
  }

  @override
  List<Object?> get props => [scannedProjects, pendingTasksFound, emailsDispatched, executedAt];
}

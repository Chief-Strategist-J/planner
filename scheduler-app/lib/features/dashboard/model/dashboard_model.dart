import 'package:equatable/equatable.dart';

class DashboardSummaryModel extends Equatable {
  final bool isHealthy;
  final String serviceStatus;
  final int totalProjects;
  final int totalTasks;
  final int pendingTasks;
  final int completedTasks;
  final String region;
  final String storageBucket;

  const DashboardSummaryModel({
    required this.isHealthy,
    required this.serviceStatus,
    required this.totalProjects,
    required this.totalTasks,
    required this.pendingTasks,
    required this.completedTasks,
    required this.region,
    required this.storageBucket,
  });

  @override
  List<Object?> get props => [
        isHealthy,
        serviceStatus,
        totalProjects,
        totalTasks,
        pendingTasks,
        completedTasks,
        region,
        storageBucket,
      ];
}

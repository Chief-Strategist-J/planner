import 'package:equatable/equatable.dart';

enum TaskStatusEnum {
  pending('PENDING'),
  inProgress('IN_PROGRESS'),
  completed('COMPLETED'),
  cancelled('CANCELLED');

  final String value;
  const TaskStatusEnum(this.value);

  static TaskStatusEnum fromString(String val) {
    return TaskStatusEnum.values.firstWhere(
      (e) => e.value.toUpperCase() == val.toUpperCase(),
      orElse: () => TaskStatusEnum.pending,
    );
  }
}

enum TaskPriorityEnum {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH'),
  critical('CRITICAL');

  final String value;
  const TaskPriorityEnum(this.value);

  static TaskPriorityEnum fromString(String val) {
    return TaskPriorityEnum.values.firstWhere(
      (e) => e.value.toUpperCase() == val.toUpperCase(),
      orElse: () => TaskPriorityEnum.medium,
    );
  }
}

class TaskModel extends Equatable {
  final String taskId;
  final String projectId;
  final String title;
  final String description;
  final TaskStatusEnum status;
  final TaskPriorityEnum priority;
  final String assignedToEmail;
  final String dueDate;
  final String? createdAt;
  final String? updatedAt;

  const TaskModel({
    required this.taskId,
    required this.projectId,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.assignedToEmail,
    required this.dueDate,
    this.createdAt,
    this.updatedAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      taskId: json['taskId'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: TaskStatusEnum.fromString(json['status'] as String? ?? 'PENDING'),
      priority: TaskPriorityEnum.fromString(json['priority'] as String? ?? 'MEDIUM'),
      assignedToEmail: json['assignedToEmail'] as String? ?? '',
      dueDate: json['dueDate'] as String? ?? '',
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'title': title,
      'description': description,
      'status': status.value,
      'priority': priority.value,
      'assignedToEmail': assignedToEmail,
      'dueDate': dueDate,
    };
  }

  TaskModel copyWith({
    String? taskId,
    String? projectId,
    String? title,
    String? description,
    TaskStatusEnum? status,
    TaskPriorityEnum? priority,
    String? assignedToEmail,
    String? dueDate,
    String? createdAt,
    String? updatedAt,
  }) {
    return TaskModel(
      taskId: taskId ?? this.taskId,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedToEmail: assignedToEmail ?? this.assignedToEmail,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        taskId,
        projectId,
        title,
        description,
        status,
        priority,
        assignedToEmail,
        dueDate,
        createdAt,
        updatedAt,
      ];
}

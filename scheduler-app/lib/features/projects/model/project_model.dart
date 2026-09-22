import 'package:equatable/equatable.dart';

enum ProjectStatusEnum {
  active('ACTIVE'),
  onHold('ON_HOLD'),
  completed('COMPLETED'),
  archived('ARCHIVED');

  final String value;
  const ProjectStatusEnum(this.value);

  static ProjectStatusEnum fromString(String val) {
    return ProjectStatusEnum.values.firstWhere(
      (e) => e.value.toUpperCase() == val.toUpperCase(),
      orElse: () => ProjectStatusEnum.active,
    );
  }
}

class ProjectModel extends Equatable {
  final String projectId;
  final String name;
  final String description;
  final String ownerEmail;
  final ProjectStatusEnum status;
  final String? createdAt;
  final String? updatedAt;

  const ProjectModel({
    required this.projectId,
    required this.name,
    required this.description,
    required this.ownerEmail,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      projectId: json['projectId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      ownerEmail: json['ownerEmail'] as String? ?? '',
      status: ProjectStatusEnum.fromString(json['status'] as String? ?? 'ACTIVE'),
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'projectId': projectId,
      'name': name,
      'description': description,
      'ownerEmail': ownerEmail,
      'status': status.value,
    };
  }

  ProjectModel copyWith({
    String? projectId,
    String? name,
    String? description,
    String? ownerEmail,
    ProjectStatusEnum? status,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProjectModel(
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [projectId, name, description, ownerEmail, status, createdAt, updatedAt];
}

class AppEndpoints {
  static const String baseUrl = 'https://planner-service-715525810343.asia-south1.run.app';
  static const String apiVersion = 'v1';
  
  static const String health = '/health';
  static const String root = '/';
  
  static const String projects = '/api/$apiVersion/projects';
  static String projectById(String projectId) => '/api/$apiVersion/projects/$projectId';
  
  static String projectTasks(String projectId) => '/api/$apiVersion/projects/$projectId/tasks';
  static String taskById(String projectId, String taskId) => '/api/$apiVersion/projects/$projectId/tasks/$taskId';
  static String taskStatus(String projectId, String taskId) => '/api/$apiVersion/projects/$projectId/tasks/$taskId/status';
  
  static const String schedulerTrigger = '/api/$apiVersion/scheduler/trigger';
}

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_endpoints.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final Uuid _uuid = const Uuid();

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['x-request-id'] = 'req-flutter-${_uuid.v4()}';
          return handler.next(options);
        },
      ),
    );
  }
}

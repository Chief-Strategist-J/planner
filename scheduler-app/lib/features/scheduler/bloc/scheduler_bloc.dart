import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../model/scheduler_model.dart';
import '../state/scheduler_state.dart';

class SchedulerBloc extends Bloc<SchedulerEvent, SchedulerState> {
  final ApiClient _apiClient = ApiClient();

  SchedulerBloc() : super(const SchedulerInitialState()) {
    on<TriggerSchedulerSweepEvent>(_onTriggerSweep);
  }

  Future<void> _onTriggerSweep(
    TriggerSchedulerSweepEvent event,
    Emitter<SchedulerState> emit,
  ) async {
    emit(const SchedulerRunningState());
    try {
      final response = await _apiClient.dio.post(AppEndpoints.schedulerTrigger);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as Map<String, dynamic>? ?? {};
        final result = SchedulerSweepResultModel.fromJson(data);
        emit(SchedulerSuccessState(result));
      } else {
        emit(const SchedulerErrorState('Failed to execute scheduler sweep'));
      }
    } on DioException catch (e) {
      final message = e.response?.data?['error']?['message'] ?? e.message ?? 'Scheduler trigger failed';
      emit(SchedulerErrorState(message.toString()));
    } catch (e) {
      emit(SchedulerErrorState(e.toString()));
    }
  }
}

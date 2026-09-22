import 'package:equatable/equatable.dart';
import '../model/scheduler_model.dart';

abstract class SchedulerEvent extends Equatable {
  const SchedulerEvent();

  @override
  List<Object?> get props => [];
}

class TriggerSchedulerSweepEvent extends SchedulerEvent {
  const TriggerSchedulerSweepEvent();
}

abstract class SchedulerState extends Equatable {
  const SchedulerState();

  @override
  List<Object?> get props => [];
}

class SchedulerInitialState extends SchedulerState {
  const SchedulerInitialState();
}

class SchedulerRunningState extends SchedulerState {
  const SchedulerRunningState();
}

class SchedulerSuccessState extends SchedulerState {
  final SchedulerSweepResultModel result;

  const SchedulerSuccessState(this.result);

  @override
  List<Object?> get props => [result];
}

class SchedulerErrorState extends SchedulerState {
  final String errorMessage;

  const SchedulerErrorState(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

import 'package:equatable/equatable.dart';
import '../model/dashboard_model.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

class FetchDashboardDataEvent extends DashboardEvent {
  const FetchDashboardDataEvent();
}

abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitialState extends DashboardState {
  const DashboardInitialState();
}

class DashboardLoadingState extends DashboardState {
  const DashboardLoadingState();
}

class DashboardLoadedState extends DashboardState {
  final DashboardSummaryModel summary;

  const DashboardLoadedState(this.summary);

  @override
  List<Object?> get props => [summary];
}

class DashboardErrorState extends DashboardState {
  final String errorMessage;

  const DashboardErrorState(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

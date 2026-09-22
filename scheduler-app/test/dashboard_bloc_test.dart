import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:scheduler_app/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:scheduler_app/features/dashboard/state/dashboard_state.dart';

void main() {
  group('DashboardBloc Real Endpoint Tests', () {
    late DashboardBloc dashboardBloc;

    setUp(() {
      dashboardBloc = DashboardBloc();
    });

    tearDown(() {
      dashboardBloc.close();
    });

    test('initial state is DashboardInitialState', () {
      expect(dashboardBloc.state, equals(const DashboardInitialState()));
    });

    blocTest<DashboardBloc, DashboardState>(
      'fetches real health and metric data from live Cloud Run backend',
      build: () => DashboardBloc(),
      act: (bloc) => bloc.add(const FetchDashboardDataEvent()),
      wait: const Duration(seconds: 5),
      expect: () => [
        const DashboardLoadingState(),
        isA<DashboardLoadedState>().having(
          (state) => state.summary.isHealthy,
          'isHealthy',
          isTrue,
        ).having(
          (state) => state.summary.serviceStatus,
          'serviceStatus',
          equals('healthy'),
        ).having(
          (state) => state.summary.region,
          'region',
          contains('asia-south1'),
        ),
      ],
    );
  });
}

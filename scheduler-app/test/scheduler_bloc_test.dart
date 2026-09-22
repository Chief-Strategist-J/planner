import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:scheduler_app/features/scheduler/bloc/scheduler_bloc.dart';
import 'package:scheduler_app/features/scheduler/state/scheduler_state.dart';

void main() {
  group('SchedulerBloc Real Endpoint Tests', () {
    late SchedulerBloc schedulerBloc;

    setUp(() {
      schedulerBloc = SchedulerBloc();
    });

    tearDown(() {
      schedulerBloc.close();
    });

    test('initial state is SchedulerInitialState', () {
      expect(schedulerBloc.state, equals(const SchedulerInitialState()));
    });

    blocTest<SchedulerBloc, SchedulerState>(
      'triggers real scheduler sweep on live Cloud Run backend',
      build: () => SchedulerBloc(),
      act: (bloc) => bloc.add(const TriggerSchedulerSweepEvent()),
      wait: const Duration(seconds: 6),
      expect: () => [
        const SchedulerRunningState(),
        isA<SchedulerSuccessState>().having(
          (state) => state.result.scannedProjects,
          'scannedProjects',
          greaterThanOrEqualTo(0),
        ).having(
          (state) => state.result.executedAt,
          'executedAt',
          isNotNull,
        ),
      ],
    );
  });
}

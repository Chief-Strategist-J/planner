import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/constants/app_colors.dart';
import 'features/dashboard/bloc/dashboard_bloc.dart';
import 'features/dashboard/screen/dashboard_screen.dart';
import 'features/dashboard/state/dashboard_state.dart';
import 'features/projects/bloc/projects_bloc.dart';
import 'features/projects/state/projects_state.dart';
import 'features/scheduler/bloc/scheduler_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PlannerApp());
}

class PlannerApp extends StatelessWidget {
  const PlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DashboardBloc>(
          create: (_) => DashboardBloc()..add(const FetchDashboardDataEvent()),
        ),
        BlocProvider<ProjectsBloc>(
          create: (_) => ProjectsBloc()..add(const FetchProjectsEvent()),
        ),
        BlocProvider<SchedulerBloc>(
          create: (_) => SchedulerBloc(),
        ),
      ],
      child: MaterialApp(
        title: 'Cloud Planner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.background,
          primaryColor: AppColors.primary,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            secondary: AppColors.accent,
            surface: AppColors.surface,
            error: AppColors.error,
          ),
          cardTheme: CardThemeData(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.surface,
            elevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: AppColors.textPrimary),
            bodyMedium: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}

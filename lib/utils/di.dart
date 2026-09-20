import 'package:el_race/ui/presentation/Email%20Approval/bloc/approval_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/landing_screen/bloc/checkin_in_bloc/check_in_bloc.dart';
import 'package:el_race/ui/presentation/landing_screen/bloc/checkin_out_bloc/check_out_bloc.dart';
import 'package:el_race/ui/presentation/my_notes/bloc/notes_bloc.dart';
import 'package:el_race/ui/presentation/my_notes/repository/firebase_notes_repository.dart';
import 'package:el_race/ui/presentation/my_notes/repository/i_notes_repository.dart';
import 'package:el_race/ui/presentation/media/bloc/media_bloc.dart';
import 'package:el_race/ui/presentation/media/repository/i_media_repository.dart';
import 'package:el_race/ui/presentation/media/repository/media_repository.dart';
import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/repositories/project_repository_impl.dart';
import 'package:el_race/ui/presentation/my_projects/domain/repositories/project_repository.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_filters_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_partner_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_bloc.dart';
import 'package:el_race/ui/presentation/my_request/bloc/requests_bloc.dart';
import 'package:el_race/ui/presentation/signin/bloc/sign_in_bloc.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:el_race/ui/presentation/signin/data/repository.dart';
import 'package:el_race/config/uaepass_config.dart';
import 'package:el_race/services/api_client.dart';
import 'package:el_race/services/uaepass_auth_service.dart';
import 'package:el_race/auth/uaepass_auth_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:el_race/ui/presentation/Attendace_list/bloc/attendance_bloc.dart';
import 'package:el_race/ui/presentation/Attendace_list/repository/attendance_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../ui/presentation/call_screen/bloc/contact_bloc.dart';
import '../ui/presentation/call_screen/data/repository.dart';

final sl = GetIt.instance;

/// Flag to track if DI has been initialized
bool _diInitialized = false;

/// Helper to safely register a singleton only if not already registered
void _registerSingletonIfNeeded<T extends Object>(T instance) {
  if (!sl.isRegistered<T>()) {
    sl.registerSingleton<T>(instance);
  }
}

/// Helper to safely register a lazy singleton only if not already registered
void _registerLazySingletonIfNeeded<T extends Object>(T Function() factory) {
  if (!sl.isRegistered<T>()) {
    sl.registerLazySingleton<T>(factory);
  }
}

Future<void> initDI() async {
  // Prevent double initialization
  if (_diInitialized && sl.isRegistered<HomeBloc>()) {
    print('ℹ️ DI already initialized, skipping...');
    return;
  }

  try {
    print('🔧 Initializing Dependency Injection...');

    // Register Repositories
    _registerSingletonIfNeeded<UserRepo>(UserRepo());
    _registerSingletonIfNeeded<ContactRepo>(ContactRepo());
    _registerSingletonIfNeeded<AttendanceRepo>(AttendanceRepo());
    _registerSingletonIfNeeded<LoginResponseModel>(LoginResponseModel());

    _registerSingletonIfNeeded<UaepassConfig>(UaepassConfig.forCurrentEnvironment());
    _registerSingletonIfNeeded<FlutterSecureStorage>(
      const FlutterSecureStorage(),
    );
    _registerSingletonIfNeeded<ApiClient>(
      ApiClient(baseUrl: sl<UaepassConfig>().baseApiUrl),
    );
    _registerSingletonIfNeeded<UaepassAuthService>(
      UaepassAuthService(
        config: sl<UaepassConfig>(),
        apiClient: sl<ApiClient>(),
        secureStorage: sl<FlutterSecureStorage>(),
      ),
    );

    _registerLazySingletonIfNeeded<INotesRepository>(
      () => FirebaseNotesRepository(),
    );
    _registerLazySingletonIfNeeded<IMediaRepository>(() => MediaRepository());

    // Projects: one remote datasource per session (preserves v2 hub probe).
    _registerLazySingletonIfNeeded<ProjectRemoteDataSource>(
      ProjectRemoteDataSource.new,
    );
    _registerLazySingletonIfNeeded<ProjectRepository>(
      () => ProjectRepositoryImpl(sl()),
    );
    _registerLazySingletonIfNeeded(
      () => GetProjectsUseCase(repository: sl()),
    );
    _registerLazySingletonIfNeeded(
      () => GetProjectAttachmentsUseCase(repository: sl()),
    );
    _registerLazySingletonIfNeeded(
      () => GetProjectsByPartnerUseCase(repository: sl()),
    );
    _registerLazySingletonIfNeeded(
      () => GetProjectsByFiltersUseCase(repository: sl()),
    );
    if (!sl.isRegistered<ProjectListBloc>()) {
      sl.registerFactory(
        () => ProjectListBloc(
          getProjectsUseCase: sl(),
          getProjectAttachmentsUseCase: sl(),
          getProjectsByPartnerUseCase: sl(),
          getProjectsByFiltersUseCase: sl(),
        ),
      );
    }

    // Register Blocs as LAZY singletons – they are only created when first
    // accessed (e.g. when their screen opens), not during splash.
    _registerLazySingletonIfNeeded<SignInBloc>(() => SignInBloc());
    _registerLazySingletonIfNeeded<ContactBloc>(() => ContactBloc());
    _registerLazySingletonIfNeeded<CheckInBloc>(() => CheckInBloc());
    _registerLazySingletonIfNeeded<CheckOutBloc>(() => CheckOutBloc());
    _registerLazySingletonIfNeeded<AttendanceBloc>(() => AttendanceBloc());
    _registerLazySingletonIfNeeded<HomeBloc>(() => HomeBloc());
    _registerLazySingletonIfNeeded<RequestsBloc>(() => RequestsBloc());
    _registerLazySingletonIfNeeded<ApprovalBloc>(() => ApprovalBloc());
    _registerLazySingletonIfNeeded<UaepassAuthCubit>(
      () => UaepassAuthCubit(
        authService: sl<UaepassAuthService>(),
        config: sl<UaepassConfig>(),
      ),
    );
    _registerLazySingletonIfNeeded<NotesBloc>(
      () => NotesBloc(notesRepository: sl()),
    );
    _registerLazySingletonIfNeeded<MediaBloc>(
      () => MediaBloc(mediaRepository: sl()),
    );

    _diInitialized = true;
    print('✅ DI initialization complete');
  } catch (e) {
    print('❌ Error in DI setup: $e');
    // Continue with basic setup
  }
}

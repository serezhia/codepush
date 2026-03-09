import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';
import 'package:shorebird_console/data/api_client.dart';

// ─── Events ──────────────────────────────────────────────────

sealed class AppsEvent {}

final class AppsLoadRequested extends AppsEvent {}

final class AppCreateRequested extends AppsEvent {
  AppCreateRequested({required this.displayName, required this.organizationId});
  final String displayName;
  final int organizationId;
}

final class AppDeleteRequested extends AppsEvent {
  AppDeleteRequested(this.appId);
  final String appId;
}

// ─── States ──────────────────────────────────────────────────

sealed class AppsState {}

final class AppsInitial extends AppsState {}

final class AppsLoading extends AppsState {}

final class AppsLoaded extends AppsState {
  AppsLoaded(this.apps);
  final List<AppMetadata> apps;
}

final class AppsError extends AppsState {
  AppsError(this.message);
  final String message;
}

// ─── Bloc ────────────────────────────────────────────────────

class AppsBloc extends Bloc<AppsEvent, AppsState> {
  AppsBloc({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(AppsInitial()) {
    on<AppsLoadRequested>(_onLoad);
    on<AppCreateRequested>(_onCreate);
    on<AppDeleteRequested>(_onDelete);
  }

  final ApiClient _apiClient;

  Future<void> _onLoad(
    AppsLoadRequested event,
    Emitter<AppsState> emit,
  ) async {
    emit(AppsLoading());
    try {
      final apps = await _apiClient.getApps();
      emit(AppsLoaded(apps));
    } catch (e) {
      emit(AppsError(e.toString()));
    }
  }

  Future<void> _onCreate(
    AppCreateRequested event,
    Emitter<AppsState> emit,
  ) async {
    try {
      await _apiClient.createApp(
        displayName: event.displayName,
        organizationId: event.organizationId,
      );
      add(AppsLoadRequested());
    } catch (e) {
      emit(AppsError(e.toString()));
    }
  }

  Future<void> _onDelete(
    AppDeleteRequested event,
    Emitter<AppsState> emit,
  ) async {
    try {
      await _apiClient.deleteApp(event.appId);
      add(AppsLoadRequested());
    } catch (e) {
      emit(AppsError(e.toString()));
    }
  }
}

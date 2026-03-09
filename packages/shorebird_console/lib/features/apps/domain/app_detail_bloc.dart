import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';
import 'package:shorebird_console/data/api_client.dart';
import 'package:shorebird_console/data/dto/dto.dart';

// ─── Events ──────────────────────────────────────────────────

sealed class AppDetailEvent {}

final class AppDetailLoadRequested extends AppDetailEvent {
  AppDetailLoadRequested(this.appId);
  final String appId;
}

final class AppCollaboratorAddRequested extends AppDetailEvent {
  AppCollaboratorAddRequested({required this.appId, required this.email});
  final String appId;
  final String email;
}

final class AppCollaboratorRoleUpdated extends AppDetailEvent {
  AppCollaboratorRoleUpdated({
    required this.appId,
    required this.userId,
    required this.role,
  });
  final String appId;
  final int userId;
  final AppCollaboratorRole role;
}

final class AppCollaboratorRemoved extends AppDetailEvent {
  AppCollaboratorRemoved({required this.appId, required this.userId});
  final String appId;
  final int userId;
}

// ─── States ──────────────────────────────────────────────────

sealed class AppDetailState {}

final class AppDetailInitial extends AppDetailState {}

final class AppDetailLoading extends AppDetailState {}

final class AppDetailLoaded extends AppDetailState {
  AppDetailLoaded({
    required this.releases,
    required this.channels,
    required this.collaborators,
  });
  final List<Release> releases;
  final List<Channel> channels;
  final List<AppCollaborator> collaborators;
}

final class AppDetailError extends AppDetailState {
  AppDetailError(this.message);
  final String message;
}

// ─── Bloc ────────────────────────────────────────────────────

class AppDetailBloc extends Bloc<AppDetailEvent, AppDetailState> {
  AppDetailBloc({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(AppDetailInitial()) {
    on<AppDetailLoadRequested>(_onLoad);
    on<AppCollaboratorAddRequested>(_onAddCollaborator);
    on<AppCollaboratorRoleUpdated>(_onUpdateRole);
    on<AppCollaboratorRemoved>(_onRemoveCollaborator);
  }

  final ApiClient _apiClient;

  Future<void> _onLoad(
    AppDetailLoadRequested event,
    Emitter<AppDetailState> emit,
  ) async {
    emit(AppDetailLoading());
    try {
      final results = await Future.wait([
        _apiClient.getReleases(event.appId),
        _apiClient.getChannels(event.appId),
        _apiClient.getCollaborators(event.appId),
      ]);

      emit(
        AppDetailLoaded(
          releases: results[0] as List<Release>,
          channels: results[1] as List<Channel>,
          collaborators: results[2] as List<AppCollaborator>,
        ),
      );
    } catch (e) {
      emit(AppDetailError(e.toString()));
    }
  }

  Future<void> _onAddCollaborator(
    AppCollaboratorAddRequested event,
    Emitter<AppDetailState> emit,
  ) async {
    try {
      await _apiClient.addCollaborator(
        appId: event.appId,
        email: event.email,
      );
      add(AppDetailLoadRequested(event.appId));
    } catch (e) {
      emit(AppDetailError(e.toString()));
    }
  }

  Future<void> _onUpdateRole(
    AppCollaboratorRoleUpdated event,
    Emitter<AppDetailState> emit,
  ) async {
    try {
      await _apiClient.updateCollaboratorRole(
        appId: event.appId,
        userId: event.userId,
        role: event.role,
      );
      add(AppDetailLoadRequested(event.appId));
    } catch (e) {
      emit(AppDetailError(e.toString()));
    }
  }

  Future<void> _onRemoveCollaborator(
    AppCollaboratorRemoved event,
    Emitter<AppDetailState> emit,
  ) async {
    try {
      await _apiClient.removeCollaborator(
        appId: event.appId,
        userId: event.userId,
      );
      add(AppDetailLoadRequested(event.appId));
    } catch (e) {
      emit(AppDetailError(e.toString()));
    }
  }
}

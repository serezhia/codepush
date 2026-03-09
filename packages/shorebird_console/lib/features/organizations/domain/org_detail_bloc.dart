import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';
import 'package:shorebird_console/data/api_client.dart';

// ─── Events ──────────────────────────────────────────────────

sealed class OrgDetailEvent {}

final class OrgDetailLoadRequested extends OrgDetailEvent {
  OrgDetailLoadRequested(this.orgId);
  final int orgId;
}

final class OrgMemberAddRequested extends OrgDetailEvent {
  OrgMemberAddRequested({
    required this.orgId,
    required this.email,
    required this.role,
  });
  final int orgId;
  final String email;
  final Role role;
}

final class OrgMemberRoleUpdated extends OrgDetailEvent {
  OrgMemberRoleUpdated({
    required this.orgId,
    required this.userId,
    required this.role,
  });
  final int orgId;
  final int userId;
  final Role role;
}

final class OrgMemberRemoved extends OrgDetailEvent {
  OrgMemberRemoved({required this.orgId, required this.userId});
  final int orgId;
  final int userId;
}

// ─── States ──────────────────────────────────────────────────

sealed class OrgDetailState {}

final class OrgDetailInitial extends OrgDetailState {}

final class OrgDetailLoading extends OrgDetailState {}

final class OrgDetailLoaded extends OrgDetailState {
  OrgDetailLoaded({required this.users, required this.apps});
  final List<OrganizationUser> users;
  final List<AppMetadata> apps;
}

final class OrgDetailError extends OrgDetailState {
  OrgDetailError(this.message);
  final String message;
}

// ─── Bloc ────────────────────────────────────────────────────

class OrgDetailBloc extends Bloc<OrgDetailEvent, OrgDetailState> {
  OrgDetailBloc({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(OrgDetailInitial()) {
    on<OrgDetailLoadRequested>(_onLoad);
    on<OrgMemberAddRequested>(_onAddMember);
    on<OrgMemberRoleUpdated>(_onUpdateRole);
    on<OrgMemberRemoved>(_onRemoveMember);
  }

  final ApiClient _apiClient;

  Future<void> _onLoad(
    OrgDetailLoadRequested event,
    Emitter<OrgDetailState> emit,
  ) async {
    emit(OrgDetailLoading());
    try {
      final results = await Future.wait([
        _apiClient.getOrganizationUsers(event.orgId),
        _apiClient.getOrganizationApps(event.orgId),
      ]);

      emit(
        OrgDetailLoaded(
          users: results[0] as List<OrganizationUser>,
          apps: results[1] as List<AppMetadata>,
        ),
      );
    } catch (e) {
      emit(OrgDetailError(e.toString()));
    }
  }

  Future<void> _onAddMember(
    OrgMemberAddRequested event,
    Emitter<OrgDetailState> emit,
  ) async {
    try {
      await _apiClient.addOrganizationMember(
        orgId: event.orgId,
        email: event.email,
        role: event.role,
      );
      add(OrgDetailLoadRequested(event.orgId));
    } catch (e) {
      emit(OrgDetailError(e.toString()));
    }
  }

  Future<void> _onUpdateRole(
    OrgMemberRoleUpdated event,
    Emitter<OrgDetailState> emit,
  ) async {
    try {
      await _apiClient.updateOrganizationMemberRole(
        orgId: event.orgId,
        userId: event.userId,
        role: event.role,
      );
      add(OrgDetailLoadRequested(event.orgId));
    } catch (e) {
      emit(OrgDetailError(e.toString()));
    }
  }

  Future<void> _onRemoveMember(
    OrgMemberRemoved event,
    Emitter<OrgDetailState> emit,
  ) async {
    try {
      await _apiClient.removeOrganizationMember(
        orgId: event.orgId,
        userId: event.userId,
      );
      add(OrgDetailLoadRequested(event.orgId));
    } catch (e) {
      emit(OrgDetailError(e.toString()));
    }
  }
}

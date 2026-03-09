import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';
import 'package:shorebird_console/data/api_client.dart';

// ─── Events ──────────────────────────────────────────────────

sealed class OrganizationsEvent {}

final class OrganizationsLoadRequested extends OrganizationsEvent {}

// ─── States ──────────────────────────────────────────────────

sealed class OrganizationsState {}

final class OrganizationsInitial extends OrganizationsState {}

final class OrganizationsLoading extends OrganizationsState {}

final class OrganizationsLoaded extends OrganizationsState {
  OrganizationsLoaded(this.memberships);
  final List<OrganizationMembership> memberships;
}

final class OrganizationsError extends OrganizationsState {
  OrganizationsError(this.message);
  final String message;
}

// ─── Bloc ────────────────────────────────────────────────────

class OrganizationsBloc extends Bloc<OrganizationsEvent, OrganizationsState> {
  OrganizationsBloc({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(OrganizationsInitial()) {
    on<OrganizationsLoadRequested>(_onLoad);
  }

  final ApiClient _apiClient;

  Future<void> _onLoad(
    OrganizationsLoadRequested event,
    Emitter<OrganizationsState> emit,
  ) async {
    emit(OrganizationsLoading());
    try {
      final memberships = await _apiClient.getOrganizations();
      emit(OrganizationsLoaded(memberships));
    } catch (e) {
      emit(OrganizationsError(e.toString()));
    }
  }
}

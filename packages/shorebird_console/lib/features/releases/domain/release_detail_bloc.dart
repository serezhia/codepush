import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';
import 'package:shorebird_console/data/api_client.dart';

// ─── Events ──────────────────────────────────────────────────

sealed class ReleaseDetailEvent {}

final class ReleaseDetailLoadRequested extends ReleaseDetailEvent {
  ReleaseDetailLoadRequested({required this.appId, required this.releaseId});
  final String appId;
  final int releaseId;
}

final class ReleaseStatusUpdated extends ReleaseDetailEvent {
  ReleaseStatusUpdated({
    required this.appId,
    required this.releaseId,
    required this.platform,
    required this.status,
  });
  final String appId;
  final int releaseId;
  final ReleasePlatform platform;
  final ReleaseStatus status;
}

final class PatchRollbackRequested extends ReleaseDetailEvent {
  PatchRollbackRequested({
    required this.appId,
    required this.releaseId,
    required this.patchId,
  });
  final String appId;
  final int releaseId;
  final int patchId;
}

final class PatchPromoteRequested extends ReleaseDetailEvent {
  PatchPromoteRequested({
    required this.appId,
    required this.releaseId,
    required this.patchId,
    required this.channelId,
  });
  final String appId;
  final int releaseId;
  final int patchId;
  final int channelId;
}

// ─── States ──────────────────────────────────────────────────

sealed class ReleaseDetailState {}

final class ReleaseDetailInitial extends ReleaseDetailState {}

final class ReleaseDetailLoading extends ReleaseDetailState {}

final class ReleaseDetailLoaded extends ReleaseDetailState {
  ReleaseDetailLoaded({
    required this.release,
    required this.patches,
    required this.artifacts,
    required this.channels,
  });
  final Release release;
  final List<ReleasePatch> patches;
  final List<ReleaseArtifact> artifacts;
  final List<Channel> channels;
}

final class ReleaseDetailError extends ReleaseDetailState {
  ReleaseDetailError(this.message);
  final String message;
}

// ─── Bloc ────────────────────────────────────────────────────

class ReleaseDetailBloc extends Bloc<ReleaseDetailEvent, ReleaseDetailState> {
  ReleaseDetailBloc({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(ReleaseDetailInitial()) {
    on<ReleaseDetailLoadRequested>(_onLoad);
    on<ReleaseStatusUpdated>(_onStatusUpdate);
    on<PatchRollbackRequested>(_onRollback);
    on<PatchPromoteRequested>(_onPromote);
  }

  final ApiClient _apiClient;

  Future<void> _onLoad(
    ReleaseDetailLoadRequested event,
    Emitter<ReleaseDetailState> emit,
  ) async {
    emit(ReleaseDetailLoading());
    try {
      final results = await Future.wait([
        _apiClient.getRelease(
          appId: event.appId,
          releaseId: event.releaseId,
        ),
        _apiClient.getPatches(
          appId: event.appId,
          releaseId: event.releaseId,
        ),
        _apiClient.getReleaseArtifacts(
          appId: event.appId,
          releaseId: event.releaseId,
        ),
        _apiClient.getChannels(event.appId),
      ]);

      emit(
        ReleaseDetailLoaded(
          release: results[0] as Release,
          patches: results[1] as List<ReleasePatch>,
          artifacts: results[2] as List<ReleaseArtifact>,
          channels: results[3] as List<Channel>,
        ),
      );
    } catch (e) {
      emit(ReleaseDetailError(e.toString()));
    }
  }

  Future<void> _onStatusUpdate(
    ReleaseStatusUpdated event,
    Emitter<ReleaseDetailState> emit,
  ) async {
    try {
      await _apiClient.updateRelease(
        appId: event.appId,
        releaseId: event.releaseId,
        status: event.status,
        platform: event.platform,
      );
      add(
        ReleaseDetailLoadRequested(
          appId: event.appId,
          releaseId: event.releaseId,
        ),
      );
    } catch (e) {
      emit(ReleaseDetailError(e.toString()));
    }
  }

  Future<void> _onRollback(
    PatchRollbackRequested event,
    Emitter<ReleaseDetailState> emit,
  ) async {
    try {
      await _apiClient.rollbackPatch(event.patchId);
      add(
        ReleaseDetailLoadRequested(
          appId: event.appId,
          releaseId: event.releaseId,
        ),
      );
    } catch (e) {
      emit(ReleaseDetailError(e.toString()));
    }
  }

  Future<void> _onPromote(
    PatchPromoteRequested event,
    Emitter<ReleaseDetailState> emit,
  ) async {
    try {
      await _apiClient.promotePatch(
        patchId: event.patchId,
        channelId: event.channelId,
      );
      add(
        ReleaseDetailLoadRequested(
          appId: event.appId,
          releaseId: event.releaseId,
        ),
      );
    } catch (e) {
      emit(ReleaseDetailError(e.toString()));
    }
  }
}

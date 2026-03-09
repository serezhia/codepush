import 'package:self_hosted_server/src/config/server_config.dart';
import 'package:self_hosted_server/src/db/database.dart';
import 'package:self_hosted_server/src/repositories/app_repository.dart';
import 'package:self_hosted_server/src/repositories/artifact_repository.dart';
import 'package:self_hosted_server/src/repositories/channel_repository.dart';
import 'package:self_hosted_server/src/repositories/organization_repository.dart';
import 'package:self_hosted_server/src/repositories/patch_repository.dart';
import 'package:self_hosted_server/src/repositories/release_repository.dart';
import 'package:self_hosted_server/src/repositories/user_repository.dart';
import 'package:self_hosted_server/src/services/auth_service.dart';
import 'package:self_hosted_server/src/services/storage_service.dart';

/// Dependency container that wires together all services and repositories.
class Dependencies {
  Dependencies._({
    required this.database,
    required this.config,
    required this.userRepository,
    required this.organizationRepository,
    required this.appRepository,
    required this.releaseRepository,
    required this.patchRepository,
    required this.channelRepository,
    required this.artifactRepository,
    required this.authService,
    required this.storageService,
  });

  /// Creates and initializes all dependencies from config.
  static Future<Dependencies> initialize(ServerConfig config) async {
    final database = Database(connectionString: config.databaseUrl);
    await database.open();
    await database.migrate();

    final pool = database.pool;

    final userRepo = UserRepository(pool);
    final orgRepo = OrganizationRepository(pool);
    final appRepo = AppRepository(pool);
    final releaseRepo = ReleaseRepository(pool);
    final patchRepo = PatchRepository(pool);
    final channelRepo = ChannelRepository(pool);
    final artifactRepo = ArtifactRepository(pool);

    final authService = AuthService(
      userRepository: userRepo,
      pool: pool,
      jwtSecret: config.jwtSecret,
      serverUrl: config.authIssuer ?? config.serverUrl,
    );

    final storageService = StorageService(
      endpoint: config.minioEndpoint,
      accessKey: config.minioAccessKey,
      secretKey: config.minioSecretKey,
      bucket: config.minioBucket,
      publicEndpoint: config.minioPublicEndpoint,
    );

    await storageService.ensureBucket();

    return Dependencies._(
      database: database,
      config: config,
      userRepository: userRepo,
      organizationRepository: orgRepo,
      appRepository: appRepo,
      releaseRepository: releaseRepo,
      patchRepository: patchRepo,
      channelRepository: channelRepo,
      artifactRepository: artifactRepo,
      authService: authService,
      storageService: storageService,
    );
  }

  final Database database;
  final ServerConfig config;
  final UserRepository userRepository;
  final OrganizationRepository organizationRepository;
  final AppRepository appRepository;
  final ReleaseRepository releaseRepository;
  final PatchRepository patchRepository;
  final ChannelRepository channelRepository;
  final ArtifactRepository artifactRepository;
  final AuthService authService;
  final StorageService storageService;

  /// Closes all connections.
  Future<void> close() async {
    await database.close();
  }
}

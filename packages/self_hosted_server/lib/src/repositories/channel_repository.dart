import 'package:postgres/postgres.dart';
import 'package:self_hosted_server/src/repositories/pg_helpers.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// Data access layer for channels.
class ChannelRepository {
  const ChannelRepository(this._pool);

  final Pool _pool;

  /// Creates a new channel.
  Future<Channel> create({
    required String appId,
    required String name,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        '''INSERT INTO channels (app_id, name) VALUES (@appId, @name)
           RETURNING id''',
      ),
      parameters: {'appId': appId, 'name': name},
    );
    return Channel(
      id: result.first[0]! as int,
      appId: appId,
      name: name,
    );
  }

  /// Returns all channels for an app.
  Future<List<Channel>> getByAppId(String appId) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT id, app_id, name FROM channels '
        'WHERE app_id = @appId ORDER BY name',
      ),
      parameters: {'appId': appId},
    );
    return result.map((row) {
      final cols = row.toColumnMap();
      return Channel(
        id: cols['id']! as int,
        appId: decodeColumn(cols['app_id']),
        name: cols['name']! as String,
      );
    }).toList();
  }

  /// Finds a channel by id.
  Future<Channel?> findById(int channelId) async {
    final result = await _pool.execute(
      Sql.named('SELECT id, app_id, name FROM channels WHERE id = @id'),
      parameters: {'id': channelId},
    );
    if (result.isEmpty) return null;
    final cols = result.first.toColumnMap();
    return Channel(
      id: cols['id']! as int,
      appId: decodeColumn(cols['app_id']),
      name: cols['name']! as String,
    );
  }

  /// Promotes a patch to a channel.
  Future<void> promotePatch({
    required int patchId,
    required int channelId,
  }) async {
    await _pool.execute(
      Sql.named(
        '''INSERT INTO patch_channels (patch_id, channel_id)
           VALUES (@patchId, @channelId)
           ON CONFLICT (patch_id, channel_id) DO NOTHING''',
      ),
      parameters: {'patchId': patchId, 'channelId': channelId},
    );
  }
}

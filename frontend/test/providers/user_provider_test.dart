import 'package:clausulazos/models/user.dart';
import 'package:clausulazos/providers/user_provider.dart';
import 'package:clausulazos/repositories/user_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _stats = UserStats(
  performed: SlotStats(active: 0, limit: 2, available: 2),
  received: SlotStats(active: 0, limit: 2, available: 2),
);

/// `fail` makes every call throw the way Dio does when the backend doesn't answer in time.
class _FakeUserRepository implements UserRepository {
  bool fail = false;
  UserStats stats = _stats;

  Never _timeout(String path) => throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.connectionTimeout,
      );

  @override
  Future<AppUser> fetchMe() async => fail
      ? _timeout('/users/me')
      : const AppUser(id: 'me', name: 'Martin', email: 'm@test.local');

  @override
  Future<UserStats> fetchMyStats() async =>
      fail ? _timeout('/users/me/stats') : stats;

  @override
  Future<List<AppUser>> fetchOtherPlayers() async =>
      fail ? _timeout('/users') : const [];

  @override
  Future<void> approveUser(String id) async => _timeout('/users/$id/approve');

  @override
  Future<void> rejectUser(String id) async => _timeout('/users/$id/reject');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a timed-out refresh shows a readable message, not the raw exception',
      () async {
    final repo = _FakeUserRepository()..fail = true;
    final provider = UserProvider(userRepository: repo);

    await provider.refreshAll();

    expect(provider.errorMessage, 'No se ha podido conectar con el servidor.');
    expect(provider.errorMessage, isNot(contains('DioException')));
  });

  test('the error clears as soon as a refresh succeeds', () async {
    final repo = _FakeUserRepository()..fail = true;
    final provider = UserProvider(userRepository: repo);

    await provider.refreshAll();
    repo.fail = false;
    await provider.refreshAll();

    expect(provider.errorMessage, isNull);
    expect(provider.myStats, isNotNull);
  });

  test('a failed admin approve/reject does not set the Inicio error', () async {
    final provider = UserProvider(userRepository: _FakeUserRepository());

    expect(await provider.approveUser('u1'), isFalse);
    expect(await provider.rejectUser('u1'), isFalse);

    expect(provider.errorMessage, isNull);
    expect(provider.actionErrorMessage,
        'No se ha podido conectar con el servidor.');
  });

  test('refreshStatsOnly brings the new counts after a clause changes state',
      () async {
    final repo = _FakeUserRepository();
    final provider = UserProvider(userRepository: repo);
    await provider.refreshAll();
    expect(provider.myStats?.performed.active, 0);

    // A PENDING movement is confirmed as CLAUSE: the backend now counts it.
    repo.stats = const UserStats(
      performed: SlotStats(active: 1, limit: 2, available: 1),
      received: SlotStats(active: 0, limit: 2, available: 2),
    );
    await provider.refreshStatsOnly();

    expect(provider.myStats?.performed.active, 1);
    expect(provider.myStats?.received.active, 0);
  });
}

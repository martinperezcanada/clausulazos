import 'package:clausulazos/models/fantasy_sync_status.dart';
import 'package:clausulazos/providers/fantasy_sync_provider.dart';
import 'package:clausulazos/repositories/fantasy_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns the queued statuses in order; `triggerSync` just counts calls.
class _FakeFantasyRepository implements FantasyRepository {
  final List<FantasySyncStatus> statuses = [];
  int syncCalls = 0;

  @override
  Future<FantasySyncStatus> fetchSyncStatus() async => statuses.removeAt(0);

  @override
  Future<void> triggerSync() async => syncCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FantasySyncStatus _status(DateTime at, int changes) => FantasySyncStatus(
      lastSuccessfulSyncAt: at,
      lastStatus: 'SUCCESS',
      lastChangeCount: changes,
    );

void main() {
  final t0 = DateTime(2026, 9, 28, 10);
  final t1 = t0.add(const Duration(minutes: 10));
  final t2 = t1.add(const Duration(minutes: 10));

  test('the first load never asks for a clause reload', () async {
    final repo = _FakeFantasyRepository()..statuses.add(_status(t0, 3));
    final provider = FantasySyncProvider(fantasyRepository: repo);

    await provider.load();

    expect(provider.clauseChangesRevision, 0);
  });

  test('a newer sync that changed clauses bumps the revision exactly once',
      () async {
    final repo = _FakeFantasyRepository()
      ..statuses.addAll([
        _status(t0, 0),
        _status(t1, 1), // new sync with a created/reconciled movement
        _status(t1, 1), // same sync seen again by the next periodic check
        _status(t1, 1),
      ]);
    final provider = FantasySyncProvider(fantasyRepository: repo);

    await provider.load();
    await provider.load();
    expect(provider.clauseChangesRevision, 1);

    await provider.load();
    await provider.load();
    expect(provider.clauseChangesRevision, 1);
  });

  test('a newer sync that changed nothing does not bump the revision',
      () async {
    final repo = _FakeFantasyRepository()
      ..statuses.addAll([_status(t0, 0), _status(t1, 0)]);
    final provider = FantasySyncProvider(fantasyRepository: repo);

    await provider.load();
    await provider.load();

    expect(provider.clauseChangesRevision, 0);
  });

  test('forceSync calls /fantasy/sync once and reports its changes', () async {
    final repo = _FakeFantasyRepository()
      ..statuses.addAll([_status(t0, 0), _status(t2, 1)]);
    final provider = FantasySyncProvider(fantasyRepository: repo);

    await provider.load();
    final ok = await provider.forceSync();

    expect(ok, isTrue);
    expect(repo.syncCalls, 1);
    expect(provider.clauseChangesRevision, 1);
  });

  test('parses lastChangeCount, defaulting to 0 for older backends', () {
    final withCount = FantasySyncStatus.fromJson({
      'lastSuccessfulSyncAt': '2026-09-28T10:00:00.000Z',
      'lastChangeCount': 2,
    });
    final withoutCount = FantasySyncStatus.fromJson({
      'lastSuccessfulSyncAt': '2026-09-28T10:00:00.000Z',
    });

    expect(withCount.lastChangeCount, 2);
    expect(withoutCount.lastChangeCount, 0);
  });
}

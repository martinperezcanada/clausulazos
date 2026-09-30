import 'package:clausulazos/models/clause.dart';
import 'package:clausulazos/models/user.dart';
import 'package:clausulazos/providers/clause_provider.dart';
import 'package:clausulazos/repositories/clause_repository.dart';
import 'package:flutter_test/flutter_test.dart';

SlotStats _slots(int active) =>
    SlotStats(active: active, limit: 2, available: (2 - active).clamp(0, 2));

UserStats _stats({required int performed, required int received}) =>
    UserStats(performed: _slots(performed), received: _slots(received));

/// A LALIGA-detected movement nobody has voted on yet.
Clause _pending(String id, {required String from, required String to}) {
  final now = DateTime.now();
  return Clause(
    id: id,
    fromUserId: from,
    toUserId: to,
    createdAt: now.subtract(const Duration(hours: 1)),
    expiresAt: now.add(const Duration(days: 6)),
    status: ClauseStatus.active,
    classification: ClauseClassification.pending,
  );
}

/// Records every vote sent to the backend and answers the way it does for a single vote: the voter's
/// confirmation is stored and the movement stays pending (or becomes a clause on a CLAUSE vote).
class _FakeClauseRepository implements ClauseRepository {
  _FakeClauseRepository(this.clauses, {required this.me});

  final List<Clause> clauses;
  final String me;
  final List<(String, String)> votes = [];

  @override
  Future<List<Clause>> fetchAll() async => clauses;

  @override
  Future<Clause> confirmClassification(
      String clauseId, String classification) async {
    votes.add((clauseId, classification));
    final clause = clauses.firstWhere((c) => c.id == clauseId);
    final vote = classification == 'CLAUSE'
        ? ClauseClassification.clause
        : ClauseClassification.agreed;
    return Clause(
      id: clause.id,
      fromUserId: clause.fromUserId,
      toUserId: clause.toUserId,
      createdAt: clause.createdAt,
      expiresAt: clause.expiresAt,
      status: clause.status,
      classification: classification == 'CLAUSE'
          ? ClauseClassification.clause
          : ClauseClassification.pending,
      fromConfirmation:
          clause.fromUserId == me ? vote : clause.fromConfirmation,
      toConfirmation: clause.toUserId == me ? vote : clause.toConfirmation,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(ClauseProvider, _FakeClauseRepository)> _loaded(
    List<Clause> clauses) async {
  final repo = _FakeClauseRepository(clauses, me: 'me');
  final provider = ClauseProvider(clauseRepository: repo);
  await provider.loadHistory();
  return (provider, repo);
}

void main() {
  group('mustBeAgreed', () {
    final made = _pending('made', from: 'me', to: 'rival');
    final received = _pending('received', from: 'rival', to: 'me');

    test('with free slots (0/2, 1/2) the user still chooses', () {
      for (final taken in [0, 1]) {
        final stats = _stats(performed: taken, received: taken);
        expect(ClauseProvider.mustBeAgreed(made, 'me', stats), isFalse);
        expect(ClauseProvider.mustBeAgreed(received, 'me', stats), isFalse);
      }
    });

    test('2/2 performed only settles the movements the user made', () {
      final stats = _stats(performed: 2, received: 0);
      expect(ClauseProvider.mustBeAgreed(made, 'me', stats), isTrue);
      expect(ClauseProvider.mustBeAgreed(received, 'me', stats), isFalse);
    });

    test('2/2 received only settles the movements made on the user', () {
      final stats = _stats(performed: 1, received: 2);
      expect(ClauseProvider.mustBeAgreed(made, 'me', stats), isFalse);
      expect(ClauseProvider.mustBeAgreed(received, 'me', stats), isTrue);
    });

    test('over the limit counts as full too', () {
      final stats = _stats(performed: 3, received: 0);
      expect(ClauseProvider.mustBeAgreed(made, 'me', stats), isTrue);
    });
  });

  group('agreeMovementsAtLimit', () {
    test('at 2/2 the waiting movement is voted AGREED, never CLAUSE', () async {
      final (provider, repo) =
          await _loaded([_pending('made', from: 'me', to: 'rival')]);

      await provider.agreeMovementsAtLimit(
          'me', _stats(performed: 2, received: 0));

      expect(repo.votes, [('made', 'AGREED')]);
      expect(provider.history.single.needsConfirmationFrom('me'), isFalse);
      expect(provider.history.single.fromConfirmation,
          ClauseClassification.agreed);
    });

    test('below the limit nothing is voted for the user', () async {
      final (provider, repo) = await _loaded([
        _pending('made', from: 'me', to: 'rival'),
        _pending('received', from: 'rival', to: 'me'),
      ]);

      await provider.agreeMovementsAtLimit(
          'me', _stats(performed: 1, received: 1));

      expect(repo.votes, isEmpty);
      expect(
          provider.history.every((c) => c.needsConfirmationFrom('me')), isTrue);
    });

    test('only the side that is full is settled', () async {
      final (provider, repo) = await _loaded([
        _pending('made', from: 'me', to: 'rival'),
        _pending('received', from: 'rival', to: 'me'),
      ]);

      await provider.agreeMovementsAtLimit(
          'me', _stats(performed: 0, received: 2));

      expect(repo.votes, [('received', 'AGREED')]);
    });

    test('running it again does not vote twice', () async {
      final (provider, repo) =
          await _loaded([_pending('made', from: 'me', to: 'rival')]);
      final stats = _stats(performed: 2, received: 2);

      await provider.agreeMovementsAtLimit('me', stats);
      await provider.agreeMovementsAtLimit('me', stats);

      expect(repo.votes, hasLength(1));
    });

    test('movements between other managers are left alone', () async {
      final (provider, repo) =
          await _loaded([_pending('other', from: 'a', to: 'b')]);

      await provider.agreeMovementsAtLimit(
          'me', _stats(performed: 2, received: 2));

      expect(repo.votes, isEmpty);
    });
  });
}

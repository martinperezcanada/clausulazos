import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clausulazos/models/clause.dart';
import 'package:clausulazos/models/user.dart';
import 'package:clausulazos/widgets/dashboard/occupied_clause_slot.dart';
import 'package:clausulazos/widgets/player_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

// A real 1x1 transparent PNG.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

const _pedri =
    'https://assets-fantasy.llt-services.com/players/t1/p55/256x256/p55.png';
const _gavi =
    'https://assets-fantasy.llt-services.com/players/t1/p56/256x256/p56.png';
const _broken =
    'https://assets-fantasy.llt-services.com/players/t1/p99/256x256/p99.png';

/// Serves `_png` for the known picture URLs and 404 for anything else, so no test touches the network.
class _FakeHttpOverrides extends HttpOverrides {
  final requested = <Uri>[];

  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeClient(this);
}

class _FakeClient implements HttpClient {
  _FakeClient(this.overrides);
  final _FakeHttpOverrides overrides;

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    overrides.requested.add(url);
    return _FakeRequest(url);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.url);
  final Uri url;

  @override
  final HttpHeaders headers = _FakeHeaders();

  @override
  Future<HttpClientResponse> close() async => _FakeResponse(
      '$url' == _pedri || '$url' == _gavi ? 200 : 404,
      '$url' == _pedri || '$url' == _gavi ? _png : const <int>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(this.statusCode, this._body);

  final List<int> _body;

  @override
  final int statusCode;

  @override
  int get contentLength => _body.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.fromIterable([_body]).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Clause _clause(String id, String player, String? imageUrl) {
  final now = DateTime.now();
  return Clause(
    id: id,
    fromUserId: 'a',
    toUserId: 'b',
    createdAt: now.subtract(const Duration(days: 1)),
    expiresAt: now.add(const Duration(days: 6)),
    status: ClauseStatus.active,
    fromUser: const AppUser(id: 'a', name: 'Alex', email: 'a@test.local'),
    toUser: const AppUser(id: 'b', name: 'Bea', email: 'b@test.local'),
    playerName: player,
    playerImageUrl: imageUrl,
  );
}

Widget _app(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

/// Pumps until pending image loads have finished (they complete outside the fake clock).
Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

Finder get _ball => find.byIcon(Icons.sports_soccer_rounded);

RawImage? _shownImage(WidgetTester tester, Finder within) {
  final raw = find.descendant(of: within, matching: find.byType(RawImage));
  return raw.evaluate().isEmpty ? null : tester.widget<RawImage>(raw.first);
}

/// Loads `url` into Flutter's image cache (or lets it fail) outside the widget tree, so a widget built
/// afterwards gets it straight from the cache. Used where the tree also has Google Fonts text, whose
/// font download must not get a chance to run in tests.
Future<void> _preload(WidgetTester tester, String url) => tester.runAsync(() {
      final done = Completer<void>();
      NetworkImage(url).resolve(ImageConfiguration.empty).addListener(
          ImageStreamListener((_, __) => done.complete(),
              onError: (_, __) => done.complete()));
      return done.future;
    });

void main() {
  // One instance for the whole file: NetworkImage keeps a single shared HttpClient.
  final http = _FakeHttpOverrides();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    HttpOverrides.global = http;
  });
  setUp(() {
    http.requested.clear();
    imageCache.clear();
    imageCache.clearLiveImages();
  });
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('with a picture URL it loads and shows the picture',
      (tester) async {
    await tester.pumpWidget(
        _app(const PlayerAvatar(imageUrl: _pedri, size: 40, iconSize: 18)));
    // Placeholder while it loads: never an empty square.
    expect(_ball, findsOneWidget);

    await _settleImages(tester);

    expect(http.requested.map((u) => '$u'), contains(_pedri));
    expect(_ball, findsNothing);
    expect(_shownImage(tester, find.byType(PlayerAvatar))?.image, isNotNull);
  });

  testWidgets('without a picture it shows the football', (tester) async {
    for (final url in [null, '', '   ', 'not a url', 'ftp://x/y.png']) {
      await tester.pumpWidget(
          _app(PlayerAvatar(imageUrl: url, size: 40, iconSize: 18)));
      expect(_ball, findsOneWidget, reason: 'url: $url');
      expect(find.byType(Image), findsNothing, reason: 'url: $url');
    }
    expect(http.requested, isEmpty);
  });

  testWidgets('a picture that fails to load falls back to the football',
      (tester) async {
    await tester.pumpWidget(
        _app(const PlayerAvatar(imageUrl: _broken, size: 40, iconSize: 18)));
    await _settleImages(tester);

    expect(http.requested.map((u) => '$u'), contains(_broken));
    expect(_ball, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the picture does not change the slot size or layout',
      (tester) async {
    // Before anything with text is on screen (see `_preload`).
    await _preload(tester, _pedri);
    await _preload(tester, _broken);

    Future<(Size, Size, Offset)> measure(String? url) async {
      await tester.pumpWidget(_app(SizedBox(
        width: 360,
        child: OccupiedClauseSlot(
          clause: _clause('c1', 'Pedri', url),
          counterpartLabel: 'A Alex',
        ),
      )));
      await tester.pump();
      return (
        tester.getSize(find.byType(OccupiedClauseSlot)),
        tester.getSize(find.byType(PlayerAvatar)),
        tester.getTopLeft(find.text('Pedri')),
      );
    }

    final withBall = await measure(null);
    final withPicture = await measure(_pedri);
    final withBroken = await measure(_broken);

    expect(withBall.$2, const Size(40, 40));
    expect(withPicture, withBall);
    expect(withBroken, withBall);
  });

  testWidgets('two players show their own pictures', (tester) async {
    await _preload(tester, _pedri);
    await _preload(tester, _gavi);
    await tester.pumpWidget(_app(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
            width: 360,
            child: OccupiedClauseSlot(
                clause: _clause('c1', 'Pedri', _pedri),
                counterpartLabel: 'A Alex')),
        SizedBox(
            width: 360,
            child: OccupiedClauseSlot(
                clause: _clause('c2', 'Gavi', _gavi),
                counterpartLabel: 'A Bea')),
      ],
    )));
    await tester.pump();

    final urls = tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => (i.image as NetworkImage).url)
        .toList();
    expect(urls, [_pedri, _gavi]);
    expect(http.requested.map((u) => '$u').toSet(), {_pedri, _gavi});
    expect(_ball, findsNothing);
  });

  testWidgets('the same picture is downloaded once and then cached',
      (tester) async {
    await tester.pumpWidget(
        _app(const Column(mainAxisSize: MainAxisSize.min, children: [
      PlayerAvatar(imageUrl: _pedri, size: 40, iconSize: 18),
      PlayerAvatar(imageUrl: _pedri, size: 40, iconSize: 18),
    ])));
    await _settleImages(tester);
    await tester.pumpWidget(
        _app(const PlayerAvatar(imageUrl: _pedri, size: 40, iconSize: 18)));
    await _settleImages(tester);

    expect(http.requested.where((u) => '$u' == _pedri), hasLength(1));
  });

  test('Clause reads playerImageUrl from the API payload', () {
    final clause = Clause.fromJson({
      'id': 'c1',
      'fromUserId': 'a',
      'toUserId': 'b',
      'createdAt': '2026-09-29T10:00:00.000Z',
      'expiresAt': '2026-10-06T10:00:00.000Z',
      'status': 'ACTIVE',
      'classification': 'CLAUSE',
      'playerName': 'Pedri',
      'playerImageUrl': _pedri,
    });
    expect(clause.playerImageUrl, _pedri);
  });
}

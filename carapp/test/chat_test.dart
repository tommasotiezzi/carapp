import 'dart:async';

import 'package:carapp/core/config/app_config.dart';
import 'package:carapp/core/supabase/supabase_client.dart';
import 'package:carapp/core/utils/formatters.dart';
import 'package:carapp/features/chat/data/chat_models.dart';
import 'package:carapp/features/chat/data/chat_repository.dart';
import 'package:carapp/features/chat/state/chat_controller.dart';
import 'package:carapp/features/chat/state/inbox_controller.dart';
import 'package:carapp/features/chat/ui/chat_screen.dart';
import 'package:carapp/features/chat/ui/contact_actions.dart';
import 'package:carapp/features/chat/ui/inbox_screen.dart';
import 'package:carapp/features/listing/data/listing_detail.dart';
import 'package:carapp/features/listing/state/listing_providers.dart';
import 'package:carapp/features/listing/ui/listing_screen.dart';
import 'package:carapp/l10n/gen/app_localizations.dart';
import 'package:carapp/features/onboarding/state/onboarding_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _me = 'me';
const _seller = 'seller';

ConversationSummary _summary(
  String id, {
  bool isBuyer = true,
  bool unread = false,
  DateTime? at,
  String? last,
  bool mine = false,
  String listingId = 'l1',
  String status = 'active',
}) =>
    ConversationSummary(
      id: id,
      listingId: listingId,
      isBuyer: isBuyer,
      buyerId: isBuyer ? _me : 'buyer',
      otherName: isBuyer ? 'Auto Bianchi' : null,
      otherIsDealer: isBuyer,
      listingTitle: 'Volkswagen Golf',
      listingPriceCents: 1490000,
      listingStatus: status,
      lastMessageBody: last,
      lastMessageMine: mine,
      lastMessageAt: at,
      activityAt: at ?? DateTime(2026, 10, 4, 10),
      unread: unread,
    );

ChatMessage _msg(String id, String sender, String body, DateTime at) =>
    ChatMessage(id: id, senderId: sender, body: body, createdAt: at);

/// In-memory stand-in for the database and Realtime.
class FakeChatRepository implements ChatRepository {
  final inboxRows = <ConversationSummary>[];
  final rows = <String, ConversationSummary>{};
  final messagesOf = <String, List<ChatMessage>>{}; // newest first
  final messageStreams = <String, StreamController<ChatMessage?>>{};
  final conversationStream = StreamController<String?>.broadcast();
  final messageQueries = <({DateTime? before, DateTime? after})>[];
  final readCalls = <String>[];
  final started = <({String listingId, String body})>[];
  Completer<ChatMessage>? sendGate;
  bool failSend = false;
  String? whatsapp;
  var _sent = 0;

  @override
  Future<List<ConversationSummary>> inbox({DateTime? before}) async =>
      inboxRows.where((r) => before == null || r.activityAt.isBefore(before)).toList();

  @override
  Future<ConversationSummary?> conversation(String id) async => rows[id];

  @override
  Future<String?> conversationIdForListing(String listingId) async =>
      rows.values.where((r) => r.listingId == listingId && r.isBuyer).firstOrNull?.id;

  @override
  Future<List<ChatMessage>> messages(String conversationId, {DateTime? before, DateTime? after}) async {
    messageQueries.add((before: before, after: after));
    return (messagesOf[conversationId] ?? const [])
        .where((m) => before == null || m.createdAt.isBefore(before))
        .where((m) => after == null || m.createdAt.isAfter(after))
        .toList();
  }

  @override
  Future<ChatMessage> send(String conversationId, String body) async {
    if (sendGate != null) return sendGate!.future;
    if (failSend) throw Exception('offline');
    return _msg('s${_sent++}', _me, body, DateTime(2026, 10, 4, 12, _sent));
  }

  @override
  Future<String> startConversation({required String listingId, required String body}) async {
    started.add((listingId: listingId, body: body));
    rows['c-new'] = _summary('c-new', listingId: listingId);
    messagesOf['c-new'] = [_msg('m-first', _me, body, DateTime(2026, 10, 4, 12))];
    return 'c-new';
  }

  @override
  Future<void> markRead(String conversationId) async => readCalls.add(conversationId);

  @override
  Future<String?> sellerWhatsapp(String listingId) async => whatsapp;

  /// Emits null at once, like the "subscribed" status.
  @override
  Stream<ChatMessage?> watchMessages(String conversationId) {
    final c = messageStreams[conversationId] = StreamController<ChatMessage?>();
    c.onListen = () => c.add(null);
    return c.stream;
  }

  @override
  Stream<String?> watchConversations() {
    scheduleMicrotask(() => conversationStream.add(null));
    return conversationStream.stream;
  }
}

ProviderContainer _container(FakeChatRepository repo, {String? userId = _me}) {
  final container = ProviderContainer(overrides: [
    chatRepositoryProvider.overrideWithValue(repo),
    currentUserIdProvider.overrideWithValue(userId),
  ]);
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  setUpAll(() => initializeDateFormatting('it'));

  group('whatsappDigits', () {
    test('international, 00 prefix and Italian numbers without prefix', () {
      expect(whatsappDigits('+39 333 123 4567'), '393331234567');
      expect(whatsappDigits('0039 333 1234567'), '393331234567');
      expect(whatsappDigits('333 1234567'), '393331234567');
      expect(whatsappDigits('02 1234567'), '39021234567');
      expect(whatsappDigits('+44 7700 900123'), '447700900123');
      expect(whatsappDigits('123'), isNull);
      expect(whatsappDigits(''), isNull);
    });
  });

  test('chatListTime: time today, Ieri, weekday, then date', () {
    final now = DateTime(2026, 10, 4, 18);
    String f(DateTime d) => Formatters.chatListTime(d, yesterday: 'Ieri', now: now);
    expect(f(DateTime(2026, 10, 4, 9, 5)), '09:05');
    expect(f(DateTime(2026, 10, 3, 23)), 'Ieri');
    expect(f(DateTime(2026, 10, 1, 12)), 'gio');
    expect(f(DateTime(2026, 9, 1, 12)), '01/09/26');
  });

  group('ChatState.merge', () {
    final state = ChatState(
      conversation: _summary('c1'),
      userId: _me,
      messages: [
        ChatMessage(
          id: 'local-1',
          senderId: _me,
          body: 'Ciao',
          createdAt: DateTime(2026, 10, 4, 12),
          status: MessageStatus.sending,
        ),
        _msg('m1', _seller, 'Buongiorno', DateTime(2026, 10, 4, 11)),
      ],
    );

    test('a duplicate is ignored', () {
      final merged = state.merge([_msg('m1', _seller, 'Buongiorno', DateTime(2026, 10, 4, 11))]);
      expect(merged.messages.map((m) => m.id), ['local-1', 'm1']);
    });

    test('the server copy replaces the bubble still sending', () {
      final merged = state.merge([_msg('m2', _me, 'Ciao', DateTime(2026, 10, 4, 12, 1))]);
      expect(merged.messages.map((m) => m.id), ['m2', 'm1']);
    });

    test('seller side: a colleague of the dealer counts as "mine"', () {
      final seller = ChatState(conversation: _summary('c1', isBuyer: false), userId: _me);
      expect(seller.isMine(_msg('x', 'colleague', 'Sì', DateTime(2026))), isTrue);
      expect(seller.isMine(_msg('y', 'buyer', 'Ciao', DateTime(2026))), isFalse);
    });
  });

  group('ChatController', () {
    late FakeChatRepository repo;

    setUp(() {
      repo = FakeChatRepository()
        ..rows['c1'] = _summary('c1')
        ..messagesOf['c1'] = [
          _msg('m2', _seller, 'Sì, è disponibile', DateTime(2026, 10, 4, 11)),
          _msg('m1', _me, 'È ancora disponibile?', DateTime(2026, 10, 4, 10)),
        ];
    });

    test('loads the latest messages and marks the chat read', () async {
      final c = _container(repo);
      final state = await c.read(chatControllerProvider('c1').future);
      expect(state!.messages.map((m) => m.id), ['m2', 'm1']);
      expect(repo.readCalls, ['c1']);
    });

    test('unknown chat = null', () async {
      final c = _container(repo);
      expect(await c.read(chatControllerProvider('nope').future), isNull);
    });

    test('a message from the other side arrives through Realtime', () async {
      final c = _container(repo);
      final sub = c.listen(chatControllerProvider('c1'), (_, _) {});
      addTearDown(sub.close);
      await c.read(chatControllerProvider('c1').future);
      repo.messageStreams['c1']!.add(_msg('m3', _seller, 'Passa quando vuoi', DateTime(2026, 10, 4, 12)));
      await _settle();
      expect(c.read(chatControllerProvider('c1')).value!.messages.first.id, 'm3');
    });

    test('sending is optimistic; Realtime echo first does not duplicate', () async {
      final c = _container(repo);
      final sub = c.listen(chatControllerProvider('c1'), (_, _) {});
      addTearDown(sub.close);
      await c.read(chatControllerProvider('c1').future);
      final notifier = c.read(chatControllerProvider('c1').notifier);

      repo.sendGate = Completer();
      final sending = notifier.send('  Posso passare sabato?  ');
      var messages = c.read(chatControllerProvider('c1')).value!.messages;
      expect(messages.first.status, MessageStatus.sending);
      expect(messages.first.body, 'Posso passare sabato?');

      final server = _msg('m9', _me, 'Posso passare sabato?', DateTime(2026, 10, 4, 12));
      repo.messageStreams['c1']!.add(server); // Realtime before the insert answer
      await _settle();
      repo.sendGate!.complete(server);
      await sending;

      messages = c.read(chatControllerProvider('c1')).value!.messages;
      expect(messages.map((m) => m.id), ['m9', 'm2', 'm1']);
    });

    test('a failed send can be retried or discarded', () async {
      final c = _container(repo);
      final sub = c.listen(chatControllerProvider('c1'), (_, _) {});
      addTearDown(sub.close);
      await c.read(chatControllerProvider('c1').future);
      final notifier = c.read(chatControllerProvider('c1').notifier);

      repo.failSend = true;
      await notifier.send('Ciao');
      final failed = c.read(chatControllerProvider('c1')).value!.messages.first;
      expect(failed.status, MessageStatus.failed);

      repo.failSend = false;
      await notifier.retry(failed.id);
      final first = c.read(chatControllerProvider('c1')).value!.messages.first;
      expect(first.status, MessageStatus.sent);
      expect(first.body, 'Ciao');

      repo.failSend = true;
      await notifier.send('Altro');
      final again = c.read(chatControllerProvider('c1')).value!.messages.first;
      notifier.discard(again.id);
      expect(c.read(chatControllerProvider('c1')).value!.messages.any((m) => m.body == 'Altro'), isFalse);
    });

    test('after a reconnect it fetches only what arrived meanwhile', () async {
      final c = _container(repo);
      final sub = c.listen(chatControllerProvider('c1'), (_, _) {});
      addTearDown(sub.close);
      await c.read(chatControllerProvider('c1').future);

      repo.messagesOf['c1'] = [
        _msg('m3', _seller, 'Ci sei?', DateTime(2026, 10, 4, 13)),
        ...repo.messagesOf['c1']!,
      ];
      repo.messageStreams['c1']!.add(null); // re-subscribed
      await _settle();

      expect(repo.messageQueries.last.after, DateTime(2026, 10, 4, 11));
      expect(c.read(chatControllerProvider('c1')).value!.messages.map((m) => m.id), ['m3', 'm2', 'm1']);
    });
  });

  group('InboxController', () {
    test('guests have an empty Inbox and no request', () async {
      final repo = FakeChatRepository()..inboxRows.add(_summary('c1'));
      final c = _container(repo, userId: null);
      expect((await c.read(inboxProvider.future)).items, isEmpty);
    });

    test('a changed chat is fetched alone and moves to the top', () async {
      final repo = FakeChatRepository()
        ..inboxRows.addAll([
          _summary('c1', at: DateTime(2026, 10, 4, 12)),
          _summary('c2', at: DateTime(2026, 10, 4, 11), listingId: 'l2'),
        ]);
      final c = _container(repo);
      final sub = c.listen(inboxProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(inboxProvider.future);
      expect(c.read(unreadChatsProvider), 0);

      repo.rows['c2'] = _summary('c2',
          at: DateTime(2026, 10, 4, 13), unread: true, last: 'Nuovo messaggio', listingId: 'l2');
      repo.conversationStream
        ..add('c2')
        ..add('c2'); // message + read marker: one fetch
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final state = c.read(inboxProvider).value!;
      expect(state.items.map((i) => i.id), ['c2', 'c1']);
      expect(c.read(unreadChatsProvider), 1);
      expect(state.forListing('l2')?.id, 'c2');

      c.read(inboxProvider.notifier).markedRead('c2');
      expect(c.read(unreadChatsProvider), 0);
    });
  });

  group('screens', () {
    Widget app(FakeChatRepository repo, Widget home, {String? userId = _me, List<Override> more = const []}) =>
        ProviderScope(
          overrides: [
            homeProvinceProvider.overrideWithValue(null),
        supabaseProvider.overrideWithValue(SupabaseClient(
              'https://test.supabase.co',
              'anon',
              authOptions: const AuthClientOptions(autoRefreshToken: false),
            )),
            chatRepositoryProvider.overrideWithValue(repo),
            currentUserIdProvider.overrideWithValue(userId),
            currentUserProvider.overrideWithValue(null),
            ...more,
          ],
          child: MaterialApp(
            locale: const Locale('it'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: home,
          ),
        );

    testWidgets('Inbox: guests are asked to sign in', (tester) async {
      await tester.pumpWidget(app(FakeChatRepository(), const InboxScreen(), userId: null));
      await tester.pumpAndSettle();
      expect(find.text('I tuoi messaggi'), findsOneWidget);
      expect(find.text('Accedi o registrati'), findsOneWidget);
    });

    testWidgets('Inbox: rows with name, listing, preview and unread dot', (tester) async {
      final repo = FakeChatRepository()
        ..inboxRows.addAll([
          _summary('c1', unread: true, last: 'Sì, è disponibile', at: DateTime.now()),
          _summary('c2',
              isBuyer: false, last: 'Grazie', mine: true, status: 'sold', at: DateTime(2026, 9, 1)),
        ]);
      await tester.pumpWidget(app(repo, const InboxScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Auto Bianchi'), findsOneWidget);
      expect(find.text('Acquirente'), findsOneWidget); // buyer without a name
      expect(find.text('Sì, è disponibile'), findsOneWidget);
      expect(find.text('Tu: Grazie'), findsOneWidget);
      expect(find.text('Il tuo annuncio'), findsOneWidget);
      expect(find.text('Venduto'), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-dot')), findsOneWidget);
    });

    testWidgets('Inbox: empty state', (tester) async {
      await tester.pumpWidget(app(FakeChatRepository(), const InboxScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Nessun messaggio'), findsOneWidget);
    });

    testWidgets('new chat: quick reply, first message creates the chat', (tester) async {
      final repo = FakeChatRepository();
      final listing = ListingDetail.fromRow({
        'id': 'l1',
        'seller_type': 'dealer',
        'owner_id': _seller,
        'category_id': 'car',
        'price_cents': 1490000,
        'make': {'name': 'Volkswagen'},
        'model': {'name': 'Golf'},
        'dealer': {'id': 'd1', 'display_name': 'Auto Bianchi'},
      });
      await tester.pumpWidget(app(
        repo,
        const ChatScreen(listingId: 'l1'),
        more: [listingDetailProvider('l1').overrideWith((ref) async => listing)],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Scrivi a Auto Bianchi'), findsOneWidget);
      expect(find.textContaining('anticipi o caparre'), findsOneWidget);

      await tester.tap(find.text('È ancora disponibile?'));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'È ancora disponibile?'), findsOneWidget);

      await tester.tap(find.byTooltip('Invia'));
      await tester.pumpAndSettle();

      expect(repo.started.single, (listingId: 'l1', body: 'È ancora disponibile?'));
      expect(find.text('Scrivi a Auto Bianchi'), findsNothing);
      expect(find.text('È ancora disponibile?'), findsOneWidget); // the bubble
      expect(repo.readCalls, ['c-new']);

      await tester.pumpWidget(const SizedBox()); // closes the chat: timers stop
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('listing: WhatsApp next to Contatta when on; not for the seller', (tester) async {
      // New key each time: a fresh ProviderScope with these overrides.
      Widget listingApp({required bool whatsapp, String? userId}) => KeyedSubtree(
          key: UniqueKey(),
          child: app(
            FakeChatRepository(),
            const ListingScreen(id: 'l1'),
            userId: userId,
            more: [
              appConfigProvider.overrideWith((ref) async => const AppConfig(version: 1, values: {
                    'feature_flags': {'whatsapp_contact_enabled': true},
                  })),
              listingDetailProvider('l1').overrideWith((ref) async => ListingDetail.fromRow({
                    'id': 'l1',
                    'seller_type': 'private',
                    'owner_id': _seller,
                    'category_id': 'car',
                    'price_cents': 900000,
                    'whatsapp_enabled': whatsapp,
                    'make': {'name': 'Fiat'},
                    'model': {'name': 'Panda'},
                  })),
              listingQuestionsProvider('l1').overrideWith((ref) async => const []),
            ],
          ));

      await tester.pumpWidget(listingApp(whatsapp: true));
      await tester.pumpAndSettle();
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Contatta'), findsOneWidget);

      await tester.pumpWidget(listingApp(whatsapp: false));
      await tester.pumpAndSettle();
      expect(find.text('WhatsApp'), findsNothing);

      await tester.pumpWidget(listingApp(whatsapp: true, userId: _seller));
      await tester.pumpAndSettle();
      expect(find.text('Contatta'), findsNothing);
      expect(find.text('Il tuo annuncio'), findsOneWidget);
    });
  });
}

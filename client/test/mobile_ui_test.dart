import 'package:chengliao/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _mobileSurface = Size(390, 844);
const _transitionDuration = Duration(milliseconds: 500);

Future<void> _pumpMobileApp(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _mobileSurface;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(const ChatApp(enableNetworking: false));
  await tester.pump(_transitionDuration);
}

Future<void> _finishTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_transitionDuration);
}

Future<void> _openConversation(WidgetTester tester) async {
  expect(find.byKey(const Key('mobileInboxPage')), findsOneWidget);

  await tester.tap(find.byKey(const Key('conversation-u-deer')));
  await _finishTransition(tester);

  expect(find.byKey(const Key('mobileChatPage')), findsOneWidget);
  expect(find.byKey(const Key('mobileInboxPage')), findsNothing);
}

void main() {
  testWidgets('Android back returns from a conversation to the inbox',
      (tester) async {
    await _pumpMobileApp(tester);
    await _openConversation(tester);

    final handled = await tester.binding.handlePopRoute();
    await _finishTransition(tester);

    expect(handled, isTrue);
    expect(find.byKey(const Key('mobileChatPage')), findsNothing);
    expect(find.byKey(const Key('mobileInboxPage')), findsOneWidget);
  });

  testWidgets('Android back closes tools before leaving the conversation',
      (tester) async {
    await _pumpMobileApp(tester);
    await _openConversation(tester);

    await tester.tap(find.byKey(const Key('mobileMoreToggle')));
    await _finishTransition(tester);
    expect(find.byKey(const Key('mobileToolsPanel')), findsOneWidget);

    final closedPanel = await tester.binding.handlePopRoute();
    await _finishTransition(tester);

    expect(closedPanel, isTrue);
    expect(find.byKey(const Key('mobileToolsPanel')), findsNothing);
    expect(find.byKey(const Key('mobileChatPage')), findsOneWidget);
    expect(find.byKey(const Key('mobileInboxPage')), findsNothing);

    final returnedToInbox = await tester.binding.handlePopRoute();
    await _finishTransition(tester);

    expect(returnedToInbox, isTrue);
    expect(find.byKey(const Key('mobileChatPage')), findsNothing);
    expect(find.byKey(const Key('mobileInboxPage')), findsOneWidget);
  });

  testWidgets('voice and tools panels are mutually exclusive', (tester) async {
    await _pumpMobileApp(tester);
    await _openConversation(tester);

    await tester.tap(find.byKey(const Key('mobileVoiceToggle')));
    await _finishTransition(tester);
    expect(find.byKey(const Key('mobileVoicePanel')), findsOneWidget);
    expect(find.byKey(const Key('mobileToolsPanel')), findsNothing);

    await tester.tap(find.byKey(const Key('mobileMoreToggle')));
    await _finishTransition(tester);
    expect(find.byKey(const Key('mobileVoicePanel')), findsNothing);
    expect(find.byKey(const Key('mobileToolsPanel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobileVoiceToggle')));
    await _finishTransition(tester);
    expect(find.byKey(const Key('mobileVoicePanel')), findsOneWidget);
    expect(find.byKey(const Key('mobileToolsPanel')), findsNothing);
  });
}

// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:chengliao/main.dart';

void main() {
  testWidgets('shows the desktop chat inbox', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ChatApp(enableNetworking: false));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('澄聊'), findsOneWidget);
    expect(find.text('小鹿'), findsWidgets);
    expect(find.byKey(const Key('sendMessageButton')), findsOneWidget);
  });

  testWidgets('keeps exactly one stable light-gray conversation selection',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ChatApp(enableNetworking: false));
    await tester.pump();

    Color tileColor(String id) {
      final tile =
          tester.widget<AnimatedContainer>(find.byKey(Key('conversation-$id')));
      return (tile.decoration! as BoxDecoration).color!;
    }

    expect(tileColor('u-deer'), const Color(0xffe5e5e5));
    expect(tileColor('u-nana'), Colors.transparent);

    await tester.tap(find.byKey(const Key('conversation-u-nana')));
    await tester.pump();

    expect(tileColor('u-deer'), Colors.transparent);
    expect(tileColor('u-nana'), const Color(0xffe5e5e5));
  });

  testWidgets('clears a conversation unread badge when it is opened',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ChatApp(enableNetworking: false));
    await tester.pump();

    expect(find.byKey(const Key('unread-u-deer')), findsNothing);
    expect(find.byKey(const Key('unread-group-product')), findsOneWidget);

    await tester.tap(find.byKey(const Key('conversation-group-product')));
    await tester.pump();

    expect(find.byKey(const Key('unread-group-product')), findsNothing);
  });

  testWidgets('moves a conversation to the top after sending a message',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ChatApp(enableNetworking: false));
    await tester.pump();
    await tester.tap(find.byKey(const Key('conversation-u-nana')));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('messageInput')), '最新沟通置顶测试');
    await tester.tap(find.byKey(const Key('sendMessageButton')));
    await tester.pump(const Duration(milliseconds: 220));

    expect(
      tester.getTopLeft(find.byKey(const Key('conversation-u-nana'))).dy,
      lessThan(
          tester.getTopLeft(find.byKey(const Key('conversation-u-deer'))).dy),
    );
  });
}

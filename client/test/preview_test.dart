import 'package:chengliao/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the QQ-style desktop chat shell', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ChatApp(enableNetworking: false));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('澄聊'), findsOneWidget);
    expect(find.text('小鹿'), findsWidgets);
    expect(find.byKey(const Key('signatureEntry')), findsOneWidget);
    expect(find.byKey(const Key('friendsRailButton')), findsOneWidget);
    expect(find.byKey(const Key('sendMessageButton')), findsOneWidget);
  });

  testWidgets(
      'sends text with Enter and keeps the send button available offline',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ChatApp(enableNetworking: false));
    await tester.pump(const Duration(milliseconds: 120));

    final input = find.byKey(const Key('messageInput'));
    await tester.enterText(input, 'Enter 发送测试');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.text('Enter 发送测试'), findsNWidgets(2));
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);

    await tester.enterText(input, '按钮发送测试');
    await tester.tap(find.byKey(const Key('sendMessageButton')));
    await tester.pump();
    expect(find.text('按钮发送测试'), findsNWidgets(2));
  });

  testWidgets('inserts a line break with Shift+Enter', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ChatApp(enableNetworking: false));
    await tester.pump(const Duration(milliseconds: 120));

    final input = find.byKey(const Key('messageInput'));
    await tester.enterText(input, '第一行');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(tester.widget<TextField>(input).controller!.text, '第一行\n');
  });

  testWidgets('shows added friends and lets the user edit a signature',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ChatApp(enableNetworking: false));
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tap(find.byKey(const Key('friendsRailButton')));
    await tester.pump();
    expect(find.text('已添加好友'), findsOneWidget);
    expect(find.byKey(const Key('friend-u-deer')), findsOneWidget);

    await tester.tap(find.byKey(const Key('signatureEntry')));
    await tester.pump();
    expect(find.text('设置个性签名'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('signatureField')), '今天也要元气满满');
    await tester.tap(find.byKey(const Key('saveSignatureButton')));
    await tester.pump();
    expect(find.text('今天也要元气满满'), findsOneWidget);
  });

  testWidgets('shows an avatar replacement action in the profile card',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ChatApp(enableNetworking: false));
    await tester.pump();
    await tester.tap(find.byKey(const Key('profileEntry')));
    await tester.pump();

    expect(find.byKey(const Key('changeAvatarButton')), findsOneWidget);
  });
}

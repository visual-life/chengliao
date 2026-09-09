import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:universal_io/io.dart';

const _configuredApiBase = String.fromEnvironment('API_BASE_URL');
final apiBase = _configuredApiBase.isNotEmpty
    ? _configuredApiBase
    : (Platform.isAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080');
const currentUserId = 'u-me';
final api = Dio(BaseOptions(baseUrl: apiBase));

const _qqBlue = Color(0xff0aa8f7);
const _qqBlueSoft = Color(0xffd7f1ff);
const _qqInk = Color(0xff191919);
const _qqMuted = Color(0xff939393);
const _qqPanel = Color(0xfff5f5f5);

void main() => runApp(const ChatApp());

class ChatApp extends StatelessWidget {
  const ChatApp({super.key, this.enableNetworking = true});

  /// Tests can render the complete UI without opening HTTP or WebSocket clients.
  final bool enableNetworking;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '澄聊',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _qqBlue),
        fontFamily: 'Microsoft YaHei',
        scaffoldBackgroundColor: Colors.white,
      ),
      home: Shell(enableNetworking: enableNetworking),
    );
  }
}

class AppProfile {
  const AppProfile({
    required this.userId,
    required this.displayName,
    required this.signature,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String signature;
  final String? avatarUrl;

  AppProfile copyWith(
          {String? displayName, String? signature, String? avatarUrl}) =>
      AppProfile(
        userId: userId,
        displayName: displayName ?? this.displayName,
        signature: signature ?? this.signature,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );

  factory AppProfile.fromJson(Map<String, dynamic> json) => AppProfile(
        userId: json['userId'] as String? ?? currentUserId,
        displayName: json['displayName'] as String? ?? '晨曦',
        signature: json['signature'] as String? ?? '保持热爱，奔赴山海。',
        avatarUrl: json['avatarUrl'] as String?,
      );
}

class ChatPeer {
  const ChatPeer({
    required this.id,
    required this.name,
    required this.preview,
    required this.time,
    required this.signature,
    required this.avatarColor,
    this.online = true,
    this.unread = 0,
    this.isGroup = false,
  });

  final String id;
  final String name;
  final String preview;
  final String time;
  final String signature;
  final Color avatarColor;
  final bool online;
  final int unread;
  final bool isGroup;

  ChatPeer copyWith({
    String? preview,
    String? time,
    int? unread,
  }) =>
      ChatPeer(
        id: id,
        name: name,
        preview: preview ?? this.preview,
        time: time ?? this.time,
        signature: signature,
        avatarColor: avatarColor,
        online: online,
        unread: unread ?? this.unread,
        isGroup: isGroup,
      );

  factory ChatPeer.fromFriendJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final name = json['displayName'] as String? ?? '未命名好友';
    const avatarColors = <Color>[
      Color(0xffffae73),
      Color(0xffec93b5),
      Color(0xff6ca9d5),
      Color(0xff88bd9a),
      Color(0xffa78bdf),
    ];
    return ChatPeer(
      id: id,
      name: name,
      preview: '',
      time: '',
      signature: json['signature'] as String? ?? '这个人很低调，什么也没有留下。',
      avatarColor: avatarColors[id.hashCode.abs() % avatarColors.length],
      online: json['online'] as bool? ?? true,
    );
  }
}

const _initialConversations = <ChatPeer>[
  ChatPeer(
    id: 'u-deer',
    name: '小鹿',
    preview: '在做项目啦，晚些时候给你看～',
    time: '10:24',
    signature: '在做一个会让人开心的项目',
    avatarColor: Color(0xffffae73),
    unread: 2,
  ),
  ChatPeer(
    id: 'group-product',
    name: '产品讨论组',
    preview: '张三：新的设计稿已上传',
    time: '09:18',
    signature: '8 位成员',
    avatarColor: Color(0xff7776e8),
    unread: 6,
    isGroup: true,
  ),
  ChatPeer(
    id: 'file',
    name: '文件传输助手',
    preview: '[图片]',
    time: '昨天',
    signature: '在设备之间安全传文件',
    avatarColor: Color(0xff59b8de),
    online: false,
  ),
  ChatPeer(
    id: 'u-nana',
    name: '娜娜',
    preview: '哈哈哈，太棒了！',
    time: '昨天',
    signature: '把生活调成喜欢的频道',
    avatarColor: Color(0xffec93b5),
    online: true,
  ),
  ChatPeer(
    id: 'u-ice',
    name: 'ICEY文希',
    preview: '旅行计划发你啦',
    time: '星期六',
    signature: '世界很大，慢慢见面',
    avatarColor: Color(0xff6ca9d5),
    online: false,
  ),
];

final _fallbackFriends = <ChatPeer>[
  _initialConversations[0],
  _initialConversations[3],
  _initialConversations[4],
  const ChatPeer(
    id: 'u-chen',
    name: '陈默',
    preview: '',
    time: '',
    signature: '今天也要好好生活。',
    avatarColor: Color(0xff88bd9a),
    online: true,
  ),
];

enum RailSection { messages, contacts }

class Shell extends StatefulWidget {
  const Shell({super.key, this.enableNetworking = true});

  final bool enableNetworking;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  RailSection _section = RailSection.messages;
  List<ChatPeer> _conversations = List<ChatPeer>.of(_initialConversations);
  ChatPeer _selectedPeer = _initialConversations.first;
  List<ChatPeer> _friends = List<ChatPeer>.of(_fallbackFriends);
  AppProfile _profile = const AppProfile(
    userId: currentUserId,
    displayName: '晨曦',
    signature: '保持热爱，奔赴山海。',
  );
  final Set<String> _readConversationIds = <String>{
    _initialConversations.first.id
  };
  bool _showMobileChat = false;

  @override
  void initState() {
    super.initState();
    if (widget.enableNetworking) {
      unawaited(_loadProfile());
      unawaited(_loadFriends());
    }
  }

  Future<void> _loadProfile() async {
    try {
      final response = await api.get('/api/users/$currentUserId/profile');
      if (response.data is Map<String, dynamic> && mounted) {
        setState(() => _profile = AppProfile.fromJson(response.data));
      } else if (response.data is Map && mounted) {
        setState(() => _profile = AppProfile.fromJson(
              Map<String, dynamic>.from(response.data as Map),
            ));
      }
    } catch (_) {
      // The offline preview remains usable before the Java service starts.
    }
  }

  Future<void> _saveProfile(AppProfile nextProfile) async {
    setState(() => _profile = nextProfile);
    if (!widget.enableNetworking) return;
    try {
      final response = await api.put(
        '/api/users/$currentUserId/profile',
        data: <String, dynamic>{
          'signature': nextProfile.signature,
          'avatarUrl': nextProfile.avatarUrl,
        },
      );
      if (response.data is Map && mounted) {
        setState(() => _profile = AppProfile.fromJson(
              Map<String, dynamic>.from(response.data as Map),
            ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('签名已在本次预览中更新；后端启动后会自动同步。'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _saveSignature(String signature) async {
    final normalized = signature.trim();
    if (normalized.isEmpty) return;
    await _saveProfile(_profile.copyWith(signature: normalized));
  }

  Future<void> _changeAvatar() async {
    if (!widget.enableNetworking) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('请先启动后端服务，再更换头像。'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final selection = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    if (selection == null || selection.files.isEmpty) return;
    final file = selection.files.single;
    final bytes = file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('无法读取所选图片，请重新选择。'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    try {
      final form = FormData.fromMap(<String, dynamic>{
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
      });
      final response = await api.post('/api/media', data: form);
      final data = response.data;
      final avatarUrl = data is Map ? data['url'] as String? : null;
      if (avatarUrl == null || avatarUrl.isEmpty || !mounted) return;
      await _saveProfile(_profile.copyWith(avatarUrl: avatarUrl));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('头像上传失败，请稍后重试。'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _loadFriends() async {
    try {
      final response = await api.get('/api/users/$currentUserId/friends');
      if (response.data is! List || !mounted) return;
      final friends = (response.data as List)
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .where(
              (raw) => (raw['status'] as String? ?? 'ACCEPTED') == 'ACCEPTED')
          .map(ChatPeer.fromFriendJson)
          .where((peer) => peer.id.isNotEmpty)
          .toList(growable: false);
      if (friends.isNotEmpty) setState(() => _friends = friends);
    } catch (_) {
      // The built-in sample list is displayed until the friends service is ready.
    }
  }

  Future<void> _editSignature() async {
    final next = await showDialog<String>(
      context: context,
      builder: (context) => _SignatureDialog(initialValue: _profile.signature),
    );
    if (next != null) await _saveSignature(next);
  }

  void _openPeer(ChatPeer peer) {
    setState(() {
      _readConversationIds.add(peer.id);
      _selectedPeer = peer;
      _section = RailSection.messages;
      _showMobileChat = true;
    });
  }

  void _recordConversationActivity(ChatPeer peer, LocalMessage message) {
    final current = _conversations.firstWhere(
      (item) => item.id == peer.id,
      orElse: () => peer,
    );
    final updated = current.copyWith(
      preview: _conversationPreview(message),
      time: _currentConversationTime(),
      unread: 0,
    );
    setState(() {
      _readConversationIds.add(peer.id);
      _conversations = <ChatPeer>[
        updated,
        ..._conversations.where((item) => item.id != peer.id),
      ];
      if (_selectedPeer.id == peer.id) _selectedPeer = updated;
    });
  }

  void _openProfile() {
    showDialog<void>(
      context: context,
      builder: (context) => _ProfileDialog(
        profile: _profile,
        onEditSignature: _editSignature,
        onChangeAvatar: _changeAvatar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 760;
    if (!desktop) {
      return _MobileShell(
        section: _section,
        profile: _profile,
        selectedPeer: _selectedPeer,
        conversations: _conversations,
        friends: _friends,
        readConversationIds: _readConversationIds,
        enableNetworking: widget.enableNetworking,
        showChat: _showMobileChat,
        onBack: () => setState(() => _showMobileChat = false),
        onSectionChanged: (value) => setState(() {
          _section = value;
          _showMobileChat = false;
        }),
        onOpenPeer: _openPeer,
        onConversationActivity: _recordConversationActivity,
        onEditSignature: _editSignature,
        onOpenProfile: _openProfile,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _DesktopHeader(
              profile: _profile,
              onEditSignature: _editSignature,
              onChangeAvatar: _changeAvatar,
              onOpenProfile: _openProfile,
            ),
            const Divider(height: 1, color: Color(0xffe9e9e9)),
            Expanded(
              child: Row(
                children: [
                  _QqRail(
                    section: _section,
                    onSectionChanged: (value) =>
                        setState(() => _section = value),
                    onOpenProfile: _openProfile,
                  ),
                  const VerticalDivider(width: 1, color: Color(0xffe6e6e6)),
                  SizedBox(
                    width: 264,
                    child: _ListPanel(
                      section: _section,
                      selectedPeer: _selectedPeer,
                      conversations: _conversations,
                      readConversationIds: _readConversationIds,
                      friends: _friends,
                      onOpenPeer: _openPeer,
                    ),
                  ),
                  const VerticalDivider(width: 1, color: Color(0xffe7e7e7)),
                  Expanded(
                    child: ChatPage(
                      key: ValueKey<String>(_selectedPeer.id),
                      peer: _selectedPeer,
                      enableNetworking: widget.enableNetworking,
                      onConversationActivity: _recordConversationActivity,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({
    required this.profile,
    required this.onEditSignature,
    required this.onChangeAvatar,
    required this.onOpenProfile,
  });

  final AppProfile profile;
  final VoidCallback onEditSignature;
  final VoidCallback onChangeAvatar;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: const Color(0xfff3f4f6),
      padding: const EdgeInsets.only(left: 10, right: 12),
      child: Row(
        children: [
          const Icon(Icons.flutter_dash, size: 18, color: _qqInk),
          const SizedBox(width: 4),
          const Text('澄聊', style: TextStyle(fontSize: 13, color: _qqInk)),
          const SizedBox(width: 18),
          InkWell(
            key: const Key('changeAvatarEntry'),
            onTap: onChangeAvatar,
            borderRadius: BorderRadius.circular(16),
            child: _Avatar(
              label: profile.displayName,
              color: const Color(0xffffb768),
              imageUrl: profile.avatarUrl,
              radius: 13,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            key: const Key('profileEntry'),
            onTap: onOpenProfile,
            borderRadius: BorderRadius.circular(5),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(profile.displayName,
                  style: const TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Tooltip(
              message: '点击修改个性签名',
              child: InkWell(
                key: const Key('signatureEntry'),
                onTap: onEditSignature,
                borderRadius: BorderRadius.circular(5),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          profile.signature,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xff666666), fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_outlined,
                          size: 14, color: Color(0xff969696)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Icon(Icons.wb_sunny_outlined,
              color: Color(0xff777777), size: 20),
          const SizedBox(width: 5),
          const Text('晴',
              style: TextStyle(color: Color(0xff777777), fontSize: 13)),
          const SizedBox(width: 20),
          const Icon(Icons.more_horiz, color: Color(0xff555555)),
        ],
      ),
    );
  }
}

class _QqRail extends StatelessWidget {
  const _QqRail({
    required this.section,
    required this.onSectionChanged,
    required this.onOpenProfile,
  });

  final RailSection section;
  final ValueChanged<RailSection> onSectionChanged;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      color: _qqPanel,
      child: Column(
        children: [
          const SizedBox(height: 12),
          _RailButton(
            icon: Icons.chat_bubble_rounded,
            selected: section == RailSection.messages,
            selectedColor: _qqBlue,
            tooltip: '消息',
            onTap: () => onSectionChanged(RailSection.messages),
          ),
          const SizedBox(height: 9),
          _RailButton(
            key: const Key('friendsRailButton'),
            icon: Icons.person_outline_rounded,
            selected: section == RailSection.contacts,
            selectedColor: const Color(0xffffaa37),
            tooltip: '已添加好友',
            onTap: () => onSectionChanged(RailSection.contacts),
          ),
          const SizedBox(height: 9),
          _RailButton(
              icon: Icons.star_border_rounded, tooltip: '收藏', onTap: () {}),
          const SizedBox(height: 9),
          _RailButton(icon: Icons.tag_rounded, tooltip: '频道', onTap: () {}),
          const SizedBox(height: 9),
          _RailButton(
              icon: Icons.sports_esports_outlined, tooltip: '应用', onTap: () {}),
          const SizedBox(height: 9),
          _RailButton(icon: Icons.link_rounded, tooltip: '小程序', onTap: () {}),
          const Spacer(),
          _RailButton(
              icon: Icons.mail_outline_rounded, tooltip: '通知', onTap: () {}),
          const SizedBox(height: 9),
          _RailButton(
              icon: Icons.phone_android_outlined, tooltip: '手机', onTap: () {}),
          const SizedBox(height: 9),
          _RailButton(
              icon: Icons.menu_rounded, tooltip: '菜单', onTap: onOpenProfile),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
    this.selectedColor = _qqBlue,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool selected;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 38,
          height: 34,
          decoration: BoxDecoration(
            color: selected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 21, color: selected ? Colors.white : _qqInk),
        ),
      ),
    );
  }
}

class _ListPanel extends StatefulWidget {
  const _ListPanel({
    required this.section,
    required this.selectedPeer,
    required this.conversations,
    required this.friends,
    required this.readConversationIds,
    required this.onOpenPeer,
  });

  final RailSection section;
  final ChatPeer selectedPeer;
  final List<ChatPeer> conversations;
  final List<ChatPeer> friends;
  final Set<String> readConversationIds;
  final ValueChanged<ChatPeer> onOpenPeer;

  @override
  State<_ListPanel> createState() => _ListPanelState();
}

class _ListPanelState extends State<_ListPanel> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final items = widget.section == RailSection.messages
        ? widget.conversations
        : widget.friends;
    final lowered = _filter.trim().toLowerCase();
    final filtered = items.where((peer) {
      return lowered.isEmpty ||
          peer.name.toLowerCase().contains(lowered) ||
          peer.signature.toLowerCase().contains(lowered);
    }).toList(growable: false);
    final friends = widget.section == RailSection.contacts;

    return Container(
      color: _qqPanel,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: TextField(
                      key: const Key('chatSearch'),
                      onChanged: (value) => setState(() => _filter = value),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: friends ? '搜索好友' : '搜索',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Color(0xff9e9e9e)),
                        prefixIcon: const Icon(Icons.search,
                            size: 18, color: Color(0xff999999)),
                        filled: true,
                        fillColor: const Color(0xffebebeb),
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xffebebeb),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: IconButton(
                    tooltip: friends ? '添加好友' : '发起聊天',
                    icon: Icon(friends ? Icons.person_add_alt_1 : Icons.add,
                        size: 18),
                    onPressed: () => _showComingSoon(context),
                  ),
                ),
              ],
            ),
          ),
          if (friends) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 9),
              child: Row(
                children: [
                  const Text('已添加好友',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Text('(${widget.friends.length})',
                      style: const TextStyle(color: _qqMuted, fontSize: 12)),
                  const Spacer(),
                  const Text('在线',
                      style: TextStyle(color: _qqMuted, fontSize: 12)),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xffe6e6e6)),
          ],
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 3, bottom: 8),
              itemCount: filtered.length + (friends ? 1 : 0),
              itemBuilder: (context, index) {
                if (friends && index == 0) {
                  return _NewFriendsTile(onTap: () => _showComingSoon(context));
                }
                final peer = filtered[index - (friends ? 1 : 0)];
                if (friends) {
                  return _FriendTile(
                      peer: peer, onTap: () => widget.onOpenPeer(peer));
                }
                return _ConversationTile(
                  peer: peer,
                  selected: peer.id == widget.selectedPeer.id,
                  unread: widget.readConversationIds.contains(peer.id)
                      ? 0
                      : peer.unread,
                  onTap: () => widget.onOpenPeer(peer),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

void _showComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content: Text('该入口已预留，后续可接入好友申请和会话创建服务。'),
    behavior: SnackBarBehavior.floating,
  ));
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.peer,
    required this.selected,
    required this.unread,
    required this.onTap,
  });

  final ChatPeer peer;
  final bool selected;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      overlayColor: WidgetStateProperty.all<Color>(Colors.transparent),
      child: AnimatedContainer(
        key: Key('conversation-${peer.id}'),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 68,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xffe5e5e5) : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            _Avatar(label: peer.name, color: peer.avatarColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          peer.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, color: _qqInk),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(peer.time,
                          style:
                              const TextStyle(fontSize: 11, color: _qqMuted)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          peer.preview,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _qqMuted),
                        ),
                      ),
                      if (unread > 0)
                        _UnreadBadge(
                          key: Key('unread-${peer.id}'),
                          value: unread,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewFriendsTile extends StatelessWidget {
  const _NewFriendsTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 9),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: const Color(0xffffb238),
                  borderRadius: BorderRadius.circular(7)),
              child: const Icon(Icons.person_add_alt_1,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('新的朋友', style: TextStyle(fontSize: 14))),
            const Icon(Icons.chevron_right, size: 18, color: _qqMuted),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.peer, required this.onTap});

  final ChatPeer peer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('friend-${peer.id}'),
      onTap: onTap,
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Row(
          children: [
            _Avatar(label: peer.name, color: peer.avatarColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(peer.name,
                              style: const TextStyle(fontSize: 14))),
                      if (peer.online)
                        const Text('在线',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xff28ae60))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    peer.signature,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _qqMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({super.key, required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 17),
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: const Color(0xffff6262),
          borderRadius: BorderRadius.circular(9)),
      child: Text('$value',
          style: const TextStyle(color: Colors.white, fontSize: 10)),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.label,
    required this.color,
    this.imageUrl,
    this.radius = 21,
  });

  final String label;
  final Color color;
  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final letter = label.isEmpty ? '?' : label.substring(0, 1);
    final source = imageUrl?.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: source == null || source.isEmpty
          ? _AvatarLetter(letter: letter, radius: radius)
          : ClipOval(
              child: Image.network(
                source.startsWith('http') ? source : '$apiBase$source',
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _AvatarLetter(letter: letter, radius: radius),
              ),
            ),
    );
  }
}

class _AvatarLetter extends StatelessWidget {
  const _AvatarLetter({required this.letter, required this.radius});

  final String letter;
  final double radius;

  @override
  Widget build(BuildContext context) => Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * .85,
          fontWeight: FontWeight.w700,
        ),
      );
}

class RealtimeChannel {
  RealtimeChannel(this.conversationId, this.onMessage) {
    final socketUrl = '${apiBase.replaceFirst(RegExp(r'^http'), 'ws')}/ws';
    _client = StompClient(
      config: StompConfig(
        url: socketUrl,
        onConnect: (_) => _client.subscribe(
          destination: '/topic/conversations/$conversationId',
          callback: (frame) {
            if (frame.body != null) {
              onMessage(Map<String, dynamic>.from(jsonDecode(frame.body!)));
            }
          },
        ),
      ),
    );
  }

  final String conversationId;
  final void Function(Map<String, dynamic>) onMessage;
  late final StompClient _client;

  void connect() => _client.activate();
  void close() => _client.deactivate();
}

enum _MobileComposerPanel { none, voice, tools }

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.peer,
    this.enableNetworking = true,
    this.onConversationActivity,
    this.onMobileBack,
  });

  final ChatPeer peer;
  final bool enableNetworking;
  final void Function(ChatPeer peer, LocalMessage message)?
      onConversationActivity;
  final VoidCallback? onMobileBack;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final input = TextEditingController();
  final recorder = AudioRecorder();
  final messageScrollController = ScrollController();
  final mobileInputFocus = FocusNode(debugLabel: 'mobileMessageInput');
  final List<LocalMessage> messages = [
    LocalMessage('你好呀，今天的进度怎么样？', false),
    LocalMessage('在做项目啦，晚些时候给你看～', true),
  ];
  bool recording = false;
  _MobileComposerPanel mobilePanel = _MobileComposerPanel.none;
  RealtimeChannel? channel;

  @override
  void initState() {
    super.initState();
    if (widget.enableNetworking) {
      channel = RealtimeChannel(widget.peer.id, _onRealtimeMessage);
      channel!.connect();
      unawaited(_loadHistory());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
  }

  Future<void> _loadHistory() async {
    try {
      final response = await api
          .get('/api/conversations/${widget.peer.id}/messages?limit=50');
      if (response.data is! List || !mounted) return;
      final loaded = (response.data as List)
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .map(LocalMessage.fromJson)
          .toList(growable: false);
      if (loaded.isNotEmpty) {
        setState(() {
          messages
            ..clear()
            ..addAll(loaded);
        });
        _scrollToLatest(immediate: true);
      }
    } catch (_) {
      // Sample messages make the first-run desktop preview feel alive offline.
    }
  }

  void _onRealtimeMessage(Map<String, dynamic> data) {
    final message = LocalMessage.fromJson(data);
    final duplicate = message.mine &&
        messages.isNotEmpty &&
        messages.last.mine &&
        messages.last.text == message.text &&
        messages.last.type == message.type;
    if (!duplicate && mounted) {
      setState(() => messages.add(message));
      _scrollToLatest();
      widget.onConversationActivity?.call(widget.peer, message);
    }
  }

  void _scrollToLatest({bool immediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !messageScrollController.hasClients) return;
      final target = messageScrollController.position.maxScrollExtent;
      if (immediate) {
        messageScrollController.jumpTo(target);
      } else {
        messageScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    channel?.close();
    input.dispose();
    mobileInputFocus.dispose();
    messageScrollController.dispose();
    recorder.dispose();
    super.dispose();
  }

  Future<void> send({String? type, String? url, int? duration}) async {
    final text = input.text.trim();
    if (text.isEmpty && url == null) return;
    input.clear();
    final message = LocalMessage(text, true,
        type: type ?? 'text', url: url, duration: duration);
    setState(() => messages.add(message));
    _scrollToLatest();
    widget.onConversationActivity?.call(widget.peer, message);
    if (!widget.enableNetworking) return;
    try {
      await api.post(
        '/api/conversations/${widget.peer.id}/messages',
        data: <String, dynamic>{
          'senderId': currentUserId,
          'type': message.type,
          'content': text,
          'mediaUrl': url,
          'durationMs': duration,
        },
      );
    } catch (_) {
      // The local bubble is intentionally retained when the service is offline.
    }
  }

  Future<void> pickImage() async {
    final selection = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    if (selection == null || selection.files.isEmpty) return;
    final url = await upload(selection.files.single);
    if (url != null) await send(type: 'image', url: url);
  }

  Future<String?> upload(PlatformFile file) async {
    if (!widget.enableNetworking) return null;
    try {
      final bytes = file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) return null;
      final form = FormData.fromMap(<String, dynamic>{
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
      });
      final response = await api.post('/api/media', data: form);
      return response.data['url'] as String?;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('上传失败：请确认后端已经启动。'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return null;
    }
  }

  Future<void> toggleRecord() async {
    if (!recording) {
      if (!await Permission.microphone.request().isGranted) return;
      final path =
          '${Directory.systemTemp.path}${Platform.pathSeparator}voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path);
      if (mounted) setState(() => recording = true);
      return;
    }

    final path = await recorder.stop();
    if (mounted) setState(() => recording = false);
    if (path == null) return;
    final data = await File(path).readAsBytes();
    final url = await upload(
        PlatformFile(name: 'voice.m4a', size: data.length, bytes: data));
    if (url != null) await send(type: 'audio', url: url, duration: 0);
  }

  void _setMobilePanel(_MobileComposerPanel next) {
    if (next == mobilePanel) {
      _closeMobilePanel();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => mobilePanel = next);
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _scrollToLatest();
    });
  }

  void _closeMobilePanel() {
    if (mobilePanel == _MobileComposerPanel.none && !recording) return;
    final cancelRecording = recording;
    setState(() {
      mobilePanel = _MobileComposerPanel.none;
      if (cancelRecording) recording = false;
    });
    if (cancelRecording) unawaited(recorder.cancel());
  }

  void _focusMobileInput() {
    if (mobilePanel != _MobileComposerPanel.none) _closeMobilePanel();
  }

  void _showMobileFeaturePreview(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$label入口已预留'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1400),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    final chat = Container(
      key: mobile ? const Key('mobileChatPage') : null,
      color: mobile ? const Color(0xfff5f6f8) : const Color(0xfffafafa),
      child: Column(
        children: [
          if (!mobile) ...[
            _ChatHeader(peer: widget.peer, onCall: startCall),
            const Divider(height: 1, color: Color(0xffececec)),
          ],
          Expanded(
            child: ListView.builder(
              key: const Key('messageList'),
              controller: messageScrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: mobile
                  ? const EdgeInsets.fromLTRB(14, 18, 14, 12)
                  : const EdgeInsets.fromLTRB(24, 18, 24, 10),
              itemCount: messages.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return const _ChatTimestamp('今天 10:58');
                final message = messages[index - 1];
                return _MessageEntrance(
                  key: ObjectKey(message),
                  mine: message.mine,
                  child: _Bubble(message: message, peer: widget.peer),
                );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xffededed)),
          if (mobile)
            _MobileMessageComposer(
              input: input,
              inputFocus: mobileInputFocus,
              panel: mobilePanel,
              recording: recording,
              onSend: send,
              onPickImage: pickImage,
              onToggleRecord: toggleRecord,
              onPanelSelected: _setMobilePanel,
              onInputTap: _focusMobileInput,
              onStartCall: startCall,
              onUnavailable: _showMobileFeaturePreview,
            )
          else
            _MessageComposer(
              input: input,
              recording: recording,
              onSend: send,
              onPickImage: pickImage,
              onToggleRecord: toggleRecord,
            ),
        ],
      ),
    );

    if (!mobile || widget.onMobileBack == null) return chat;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (mobilePanel != _MobileComposerPanel.none || recording) {
          _closeMobilePanel();
        } else {
          widget.onMobileBack!();
        }
      },
      child: chat,
    );
  }

  void startCall(bool video) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CallPage(peer: widget.peer, video: video),
    ));
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.peer, required this.onCall});

  final ChatPeer peer;
  final void Function(bool video) onCall;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 23),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      peer.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _qqInk),
                    ),
                  ),
                  if (peer.online) ...[
                    const SizedBox(width: 7),
                    const Icon(Icons.circle, size: 8, color: Color(0xff38b86b)),
                  ],
                ],
              ),
            ),
            _HeaderAction(
                icon: Icons.call_outlined,
                tooltip: '语音通话',
                onTap: () => onCall(false)),
            _HeaderAction(
                icon: Icons.videocam_outlined,
                tooltip: '视频通话',
                onTap: () => onCall(true)),
            _HeaderAction(
                icon: Icons.present_to_all_outlined,
                tooltip: '屏幕共享',
                onTap: () {}),
            _HeaderAction(
                icon: Icons.devices_other_outlined,
                tooltip: '设备',
                onTap: () {}),
            _HeaderAction(
                icon: Icons.add_circle_outline, tooltip: '添加', onTap: () {}),
            _HeaderAction(icon: Icons.more_horiz, tooltip: '更多', onTap: () {}),
          ],
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction(
      {required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: _qqInk, size: 21),
      splashRadius: 19,
      onPressed: onTap,
    );
  }
}

class LocalMessage {
  LocalMessage(this.text, this.mine,
      {this.type = 'text', this.url, this.duration});

  factory LocalMessage.fromJson(Map<String, dynamic> json) => LocalMessage(
        json['content'] as String? ?? '',
        json['senderId'] == currentUserId,
        type: json['type'] as String? ?? 'text',
        url: json['mediaUrl'] as String?,
        duration: (json['durationMs'] as num?)?.toInt(),
      );

  final String text;
  final bool mine;
  final String type;
  final String? url;
  final int? duration;
}

String _conversationPreview(LocalMessage message) {
  switch (message.type) {
    case 'image':
      return '[图片]';
    case 'audio':
      return '[语音]';
    default:
      return message.text.replaceAll('\n', ' ');
  }
}

String _currentConversationTime() {
  final now = DateTime.now();
  return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
}

class _ChatTimestamp extends StatelessWidget {
  const _ChatTimestamp(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Text(value,
            style: const TextStyle(fontSize: 12, color: Color(0xffb5b5b5))),
      ),
    );
  }
}

class _MessageEntrance extends StatefulWidget {
  const _MessageEntrance({
    super.key,
    required this.mine,
    required this.child,
  });

  final bool mine;
  final Widget child;

  @override
  State<_MessageEntrance> createState() => _MessageEntranceState();
}

class _MessageEntranceState extends State<_MessageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);
    _slide = Tween<Offset>(
      begin: Offset(widget.mine ? .08 : -.08, .025),
      end: Offset.zero,
    ).animate(curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.peer});

  final LocalMessage message;
  final ChatPeer peer;

  @override
  Widget build(BuildContext context) {
    final mineMessage = message.mine;
    final mobile = MediaQuery.sizeOf(context).width < 760;
    final foreground = mobile && mineMessage ? Colors.white : _qqInk;
    Widget content;
    if (message.type == 'image' && message.url != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          '$apiBase${message.url}',
          width: 200,
          height: 135,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox(
            width: 160,
            height: 100,
            child: Icon(Icons.broken_image_outlined),
          ),
        ),
      );
    } else if (message.type == 'audio') {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_fill_rounded, size: 19, color: foreground),
          const SizedBox(width: 8),
          Icon(Icons.graphic_eq_rounded, size: 28, color: foreground),
          const SizedBox(width: 8),
          Text(
              message.duration == null || message.duration == 0
                  ? '语音'
                  : '${(message.duration! / 1000).ceil()}″',
              style: TextStyle(color: foreground)),
        ],
      );
    } else {
      content = Text(message.text,
          style: TextStyle(fontSize: 14, height: 1.45, color: foreground));
    }

    final avatar = _Avatar(
      label: mineMessage ? '晨曦' : peer.name,
      color: mineMessage ? const Color(0xff6aaee5) : peer.avatarColor,
      radius: mobile ? 17 : 18,
    );
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: mobile ? MediaQuery.sizeOf(context).width * .68 : 390,
      ),
      margin: EdgeInsets.symmetric(horizontal: mobile ? 7 : 9),
      padding: message.type == 'image'
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(
              horizontal: mobile ? 13 : 12,
              vertical: mobile ? 10 : 9,
            ),
      decoration: BoxDecoration(
        color: mineMessage
            ? (mobile ? const Color(0xff18a8f5) : _qqBlueSoft)
            : Colors.white,
        borderRadius: BorderRadius.circular(mobile ? 14 : 9),
        boxShadow: [
          BoxShadow(
              color: const Color(0xff000000)
                  .withValues(alpha: mobile ? .055 : .03),
              blurRadius: mobile ? 10 : 2,
              offset: Offset(0, mobile ? 3 : 1))
        ],
      ),
      child: content,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Align(
        alignment: mineMessage ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: mineMessage ? [bubble, avatar] : [avatar, bubble],
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.input,
    required this.recording,
    required this.onSend,
    required this.onPickImage,
    required this.onToggleRecord,
  });

  final TextEditingController input;
  final bool recording;
  final Future<void> Function({String? type, String? url, int? duration})
      onSend;
  final Future<void> Function() onPickImage;
  final Future<void> Function() onToggleRecord;

  void _insertLineBreak() {
    final value = input.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final text = value.text.replaceRange(start, end, '\n');
    input.value = value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: start + 1),
      composing: TextRange.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 164,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Column(
        children: [
          Row(
            children: [
              _ComposerTool(
                  icon: Icons.sentiment_satisfied_alt_outlined,
                  tooltip: '表情',
                  onTap: () {}),
              _ComposerTool(
                  icon: Icons.content_cut_rounded, tooltip: '截图', onTap: () {}),
              _ComposerTool(
                  icon: Icons.folder_open_outlined,
                  tooltip: '文件',
                  onTap: () {}),
              _ComposerTool(
                  icon: Icons.image_outlined,
                  tooltip: '图片',
                  onTap: onPickImage),
              _ComposerTool(
                  icon: Icons.view_sidebar_outlined,
                  tooltip: '聊天记录',
                  onTap: () {}),
              _ComposerTool(
                  icon: Icons.inventory_2_outlined,
                  tooltip: '应用',
                  onTap: () {}),
              _ComposerTool(
                icon: recording
                    ? Icons.stop_circle_outlined
                    : Icons.mic_none_rounded,
                tooltip: recording ? '停止录音' : '发送语音',
                color: recording ? Colors.red : _qqInk,
                onTap: onToggleRecord,
              ),
              const Spacer(),
              const Icon(Icons.schedule_outlined, size: 19, color: _qqInk),
            ],
          ),
          Expanded(
            child: Focus(
              onKeyEvent: (_, event) {
                final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter;
                if (event is KeyDownEvent && isEnter) {
                  if (HardwareKeyboard.instance.isShiftPressed) {
                    _insertLineBreak();
                  } else {
                    unawaited(onSend());
                  }
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                key: const Key('messageInput'),
                controller: input,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: '输入消息…',
                  hintStyle: TextStyle(color: Color(0xffc0c0c0)),
                  contentPadding: EdgeInsets.fromLTRB(2, 2, 2, 2),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 96,
              height: 32,
              child: FilledButton(
                key: const Key('sendMessageButton'),
                style: FilledButton.styleFrom(
                  backgroundColor: _qqBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7)),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => onSend(),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('发送'),
                    SizedBox(width: 8),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 17)
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileMessageComposer extends StatelessWidget {
  const _MobileMessageComposer({
    required this.input,
    required this.inputFocus,
    required this.panel,
    required this.recording,
    required this.onSend,
    required this.onPickImage,
    required this.onToggleRecord,
    required this.onPanelSelected,
    required this.onInputTap,
    required this.onStartCall,
    required this.onUnavailable,
  });

  final TextEditingController input;
  final FocusNode inputFocus;
  final _MobileComposerPanel panel;
  final bool recording;
  final Future<void> Function({String? type, String? url, int? duration})
      onSend;
  final Future<void> Function() onPickImage;
  final Future<void> Function() onToggleRecord;
  final ValueChanged<_MobileComposerPanel> onPanelSelected;
  final VoidCallback onInputTap;
  final void Function(bool video) onStartCall;
  final ValueChanged<String> onUnavailable;

  @override
  Widget build(BuildContext context) {
    final panelChild = switch (panel) {
      _MobileComposerPanel.voice => _MobileVoicePanel(
          key: const ValueKey<String>('voicePanel'),
          recording: recording,
          onToggleRecord: onToggleRecord,
        ),
      _MobileComposerPanel.tools => _MobileToolsPanel(
          key: const ValueKey<String>('toolsPanel'),
          onVoiceCall: () {
            onInputTap();
            onStartCall(false);
          },
          onVideoCall: () {
            onInputTap();
            onStartCall(true);
          },
          onUnavailable: onUnavailable,
        ),
      _MobileComposerPanel.none =>
        const SizedBox(key: ValueKey<String>('noPanel')),
    };

    return Material(
      color: const Color(0xfff8f9fb),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: panel == _MobileComposerPanel.none ? .045 : .075,
                    ),
                    blurRadius: panel == _MobileComposerPanel.none ? 8 : 14,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          constraints: const BoxConstraints(minHeight: 44),
                          decoration: BoxDecoration(
                            color: const Color(0xfff3f5f7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            key: const Key('messageInput'),
                            controller: input,
                            focusNode: inputFocus,
                            onTap: onInputTap,
                            keyboardType: TextInputType.multiline,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.newline,
                            style: const TextStyle(fontSize: 15, height: 1.35),
                            decoration: const InputDecoration(
                              hintText: '输入消息…',
                              hintStyle: TextStyle(color: Color(0xffb1b5ba)),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 11),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: input,
                        builder: (context, value, _) {
                          final enabled = value.text.trim().isNotEmpty;
                          return AnimatedContainer(
                            key: const Key('sendMessageButton'),
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            width: 68,
                            height: 44,
                            decoration: BoxDecoration(
                              color:
                                  enabled ? _qqBlue : const Color(0xffb9e3fa),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: enabled
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x3310a9f5),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(15),
                                onTap:
                                    enabled ? () => unawaited(onSend()) : null,
                                child: Center(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 180),
                                    style: TextStyle(
                                      color: enabled
                                          ? Colors.white
                                          : const Color(0xfff4fbff),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    child: const Text('发送'),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: _MobileComposerAction(
                          key: const Key('mobileVoiceToggle'),
                          icon: Icons.mic_none_rounded,
                          selectedIcon: Icons.keyboard_voice_rounded,
                          label: '语音',
                          selected: panel == _MobileComposerPanel.voice,
                          onTap: () =>
                              onPanelSelected(_MobileComposerPanel.voice),
                        ),
                      ),
                      Expanded(
                        child: _MobileComposerAction(
                          icon: Icons.image_outlined,
                          label: '图片',
                          onTap: () {
                            onInputTap();
                            unawaited(onPickImage());
                          },
                        ),
                      ),
                      Expanded(
                        child: _MobileComposerAction(
                          icon: Icons.photo_camera_outlined,
                          label: '拍照',
                          onTap: () => onUnavailable('拍照'),
                        ),
                      ),
                      Expanded(
                        child: _MobileComposerAction(
                          icon: Icons.folder_open_outlined,
                          label: '文件',
                          onTap: () => onUnavailable('文件'),
                        ),
                      ),
                      Expanded(
                        child: _MobileComposerAction(
                          icon: Icons.sentiment_satisfied_alt_outlined,
                          label: '表情',
                          onTap: () => onUnavailable('表情'),
                        ),
                      ),
                      Expanded(
                        child: _MobileComposerAction(
                          key: const Key('mobileMoreToggle'),
                          icon: Icons.add_rounded,
                          selectedIcon: Icons.close_rounded,
                          label: '更多',
                          selected: panel == _MobileComposerPanel.tools,
                          rotateWhenSelected: true,
                          onTap: () =>
                              onPanelSelected(_MobileComposerPanel.tools),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ClipRect(
              child: AnimatedSize(
                key: const Key('mobileComposerAnimatedRegion'),
                duration: const Duration(milliseconds: 280),
                reverseDuration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  reverseDuration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, .08),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: panelChild,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileComposerAction extends StatelessWidget {
  const _MobileComposerAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selectedIcon,
    this.selected = false,
    this.rotateWhenSelected = false,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool rotateWhenSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: 25,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: selected ? const Color(0xffe2f4fe) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: AnimatedRotation(
              turns: selected && rotateWhenSelected ? .125 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  selected ? (selectedIcon ?? icon) : icon,
                  key: ValueKey<bool>(selected),
                  color: selected ? _qqBlue : const Color(0xff2f353b),
                  size: 25,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileVoicePanel extends StatefulWidget {
  const _MobileVoicePanel({
    super.key,
    required this.recording,
    required this.onToggleRecord,
  });

  final bool recording;
  final Future<void> Function() onToggleRecord;

  @override
  State<_MobileVoicePanel> createState() => _MobileVoicePanelState();
}

class _MobileVoicePanelState extends State<_MobileVoicePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.recording) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _MobileVoicePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recording == widget.recording) return;
    if (widget.recording) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.animateBack(0, duration: const Duration(milliseconds: 180));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('mobileVoicePanel'),
      height: 248,
      child: Column(
        children: [
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              widget.recording ? '录音中 · 点击发送' : '点击麦克风开始录音',
              key: ValueKey<bool>(widget.recording),
              style: TextStyle(
                color: widget.recording
                    ? const Color(0xfff04f59)
                    : const Color(0xff7f858c),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 25),
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Transform.scale(
              scale: 1 + _pulse.value * .065,
              child: child,
            ),
            child: Semantics(
              button: true,
              label: widget.recording ? '停止并发送录音' : '开始录音',
              child: GestureDetector(
                key: const Key('mobileRecordButton'),
                onTap: () => unawaited(widget.onToggleRecord()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.recording
                          ? const [Color(0xffff7a83), Color(0xffef4050)]
                          : const [Color(0xff35c5ff), Color(0xff079cf0)],
                    ),
                    border: Border.all(color: Colors.white, width: 5),
                    boxShadow: [
                      BoxShadow(
                        color: (widget.recording
                                ? const Color(0xffef4050)
                                : _qqBlue)
                            .withValues(alpha: .28),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                    child: Icon(
                      widget.recording ? Icons.stop_rounded : Icons.mic_rounded,
                      key: ValueKey<bool>(widget.recording),
                      color: Colors.white,
                      size: 54,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          Text(
            widget.recording ? '再次点击即可结束并发送' : '录音将在本机完成后上传',
            style: const TextStyle(color: Color(0xffa0a5aa), fontSize: 12),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _MobileToolsPanel extends StatefulWidget {
  const _MobileToolsPanel({
    super.key,
    required this.onVoiceCall,
    required this.onVideoCall,
    required this.onUnavailable,
  });

  final VoidCallback onVoiceCall;
  final VoidCallback onVideoCall;
  final ValueChanged<String> onUnavailable;

  @override
  State<_MobileToolsPanel> createState() => _MobileToolsPanelState();
}

class _MobileToolsPanelState extends State<_MobileToolsPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions =
        <({String id, IconData icon, String label, VoidCallback tap})>[
      (
        id: 'voiceCall',
        icon: Icons.call_rounded,
        label: '语音通话',
        tap: widget.onVoiceCall,
      ),
      (
        id: 'videoCall',
        icon: Icons.videocam_rounded,
        label: '视频通话',
        tap: widget.onVideoCall,
      ),
      (
        id: 'location',
        icon: Icons.location_on_rounded,
        label: '位置',
        tap: () => widget.onUnavailable('位置'),
      ),
      (
        id: 'file',
        icon: Icons.folder_rounded,
        label: '文件',
        tap: () => widget.onUnavailable('文件'),
      ),
      (
        id: 'favorite',
        icon: Icons.bookmark_rounded,
        label: '收藏',
        tap: () => widget.onUnavailable('收藏'),
      ),
      (
        id: 'payment',
        icon: Icons.account_balance_wallet_rounded,
        label: '转账',
        tap: () => widget.onUnavailable('转账'),
      ),
      (
        id: 'screenShare',
        icon: Icons.screen_share_rounded,
        label: '屏幕共享',
        tap: () => widget.onUnavailable('屏幕共享'),
      ),
      (
        id: 'contactCard',
        icon: Icons.badge_rounded,
        label: '名片',
        tap: () => widget.onUnavailable('名片'),
      ),
    ];

    return SizedBox(
      key: const Key('mobileToolsPanel'),
      height: 252,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          childAspectRatio: .88,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          final start = index * .045;
          final animation = CurvedAnimation(
            parent: _entrance,
            curve: Interval(start, (start + .58).clamp(0, 1),
                curve: Curves.easeOutCubic),
          );
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .14),
                end: Offset.zero,
              ).animate(animation),
              child: _MobileToolTile(
                key: Key('mobileTool-${action.id}'),
                icon: action.icon,
                label: action.label,
                onTap: action.tap,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MobileToolTile extends StatelessWidget {
  const _MobileToolTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0f000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 28, color: const Color(0xff555b61)),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xff646a70)),
          ),
        ],
      ),
    );
  }
}

class _ComposerTool extends StatelessWidget {
  const _ComposerTool({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = _qqInk,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: color, size: 20),
      splashRadius: 18,
      onPressed: onTap,
    );
  }
}

class _SignatureDialog extends StatefulWidget {
  const _SignatureDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置个性签名'),
      content: TextField(
        key: const Key('signatureField'),
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: '写下一句想让朋友看到的话',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          key: const Key('saveSignatureButton'),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _ProfileDialog extends StatelessWidget {
  const _ProfileDialog({
    required this.profile,
    required this.onEditSignature,
    required this.onChangeAvatar,
  });

  final AppProfile profile;
  final VoidCallback onEditSignature;
  final VoidCallback onChangeAvatar;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 340,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                key: const Key('changeAvatarEntry'),
                onTap: () {
                  Navigator.pop(context);
                  onChangeAvatar();
                },
                borderRadius: BorderRadius.circular(38),
                child: _Avatar(
                  label: profile.displayName,
                  color: const Color(0xff6aaee5),
                  imageUrl: profile.avatarUrl,
                  radius: 38,
                ),
              ),
              const SizedBox(height: 12),
              Text(profile.displayName,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              Text(profile.signature,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xff777777))),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                key: const Key('changeAvatarButton'),
                onPressed: () {
                  Navigator.pop(context);
                  onChangeAvatar();
                },
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('更换头像'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onEditSignature();
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('修改个性签名'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.section,
    required this.profile,
    required this.selectedPeer,
    required this.conversations,
    required this.friends,
    required this.readConversationIds,
    required this.enableNetworking,
    required this.showChat,
    required this.onBack,
    required this.onSectionChanged,
    required this.onOpenPeer,
    required this.onConversationActivity,
    required this.onEditSignature,
    required this.onOpenProfile,
  });

  final RailSection section;
  final AppProfile profile;
  final ChatPeer selectedPeer;
  final List<ChatPeer> conversations;
  final List<ChatPeer> friends;
  final Set<String> readConversationIds;
  final bool enableNetworking;
  final bool showChat;
  final VoidCallback onBack;
  final ValueChanged<RailSection> onSectionChanged;
  final ValueChanged<ChatPeer> onOpenPeer;
  final void Function(ChatPeer peer, LocalMessage message)
      onConversationActivity;
  final VoidCallback onEditSignature;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final page = showChat
        ? Scaffold(
            key: const ValueKey<String>('mobileChatScaffold'),
            backgroundColor: const Color(0xfff5f6f8),
            appBar: AppBar(
              toolbarHeight: 68,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: const Color(0xfff7f8fb),
              surfaceTintColor: Colors.transparent,
              leadingWidth: 54,
              leading: IconButton(
                key: const Key('mobileChatBackButton'),
                tooltip: '返回',
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                onPressed: onBack,
              ),
              titleSpacing: 0,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedPeer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _qqInk,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selectedPeer.online
                              ? const Color(0xff35bd72)
                              : const Color(0xffb9bdc2),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          selectedPeer.online ? '在线' : selectedPeer.signature,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xff8a9096),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  key: const Key('mobileChatMenu'),
                  tooltip: '聊天设置',
                  icon: const Icon(Icons.menu_rounded, size: 27),
                  onPressed: () => _showComingSoon(context),
                ),
                const SizedBox(width: 5),
              ],
            ),
            body: ChatPage(
              key: ValueKey<String>(selectedPeer.id),
              peer: selectedPeer,
              enableNetworking: enableNetworking,
              onConversationActivity: onConversationActivity,
              onMobileBack: onBack,
            ),
          )
        : Scaffold(
            key: const ValueKey<String>('mobileInboxPage'),
            appBar: AppBar(
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: const Color(0xfff7f8fb),
              surfaceTintColor: Colors.transparent,
              titleSpacing: 14,
              title: InkWell(
                onTap: onEditSignature,
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.displayName,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    Text(profile.signature,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xff747a80))),
                  ],
                ),
              ),
              actions: [
                IconButton(
                    icon: const Icon(Icons.person_outline),
                    onPressed: onOpenProfile)
              ],
            ),
            body: _ListPanel(
              section: section,
              selectedPeer: selectedPeer,
              conversations: conversations,
              friends: friends,
              readConversationIds: readConversationIds,
              onOpenPeer: onOpenPeer,
            ),
            bottomNavigationBar: NavigationBar(
              height: 70,
              elevation: 0,
              backgroundColor: const Color(0xfff3f6fa),
              indicatorColor: const Color(0xffdceeff),
              selectedIndex: section.index,
              onDestinationSelected: (index) =>
                  onSectionChanged(RailSection.values[index]),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.chat_bubble_outline),
                    selectedIcon: Icon(Icons.chat_bubble_rounded),
                    label: '消息'),
                NavigationDestination(
                    icon: Icon(Icons.people_outline),
                    selectedIcon: Icon(Icons.people_rounded),
                    label: '好友'),
              ],
            ),
          );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final isChat =
            child.key == const ValueKey<String>('mobileChatScaffold');
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(isChat ? .12 : -.055, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: page,
    );
  }
}

class CallPage extends StatefulWidget {
  const CallPage({super.key, required this.peer, required this.video});

  final ChatPeer peer;
  final bool video;

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  final local = RTCVideoRenderer();
  MediaStream? stream;
  bool muted = false;

  @override
  void initState() {
    super.initState();
    unawaited(open());
  }

  Future<void> open() async {
    await local.initialize();
    stream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
      'audio': true,
      'video': widget.video
          ? <String, dynamic>{
              'mandatory': <String, dynamic>{
                'minWidth': '1280',
                'minHeight': '720',
                'minFrameRate': '30'
              },
            }
          : false,
    });
    local.srcObject = stream;
    if (mounted) setState(() {});
  }

  void toggleMute() {
    setState(() => muted = !muted);
    for (final track in stream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }
  }

  void toggleCamera() {
    final tracks = stream?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (tracks.isNotEmpty) tracks.first.enabled = !tracks.first.enabled;
  }

  @override
  void dispose() {
    stream?.dispose();
    local.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff16233b),
      body: SafeArea(
        child: Stack(
          children: [
            if (widget.video)
              Positioned.fill(
                  child: RTCVideoView(local,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover))
            else
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xff253e70), Color(0xff101a2d)]),
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Avatar(
                      label: widget.peer.name,
                      color: widget.peer.avatarColor,
                      radius: 56),
                  const SizedBox(height: 18),
                  Text(widget.peer.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold)),
                  Text(widget.video ? '正在建立高清连接…' : '正在呼叫…',
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    onPressed: toggleMute,
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                    child: Icon(muted ? Icons.mic_off : Icons.mic),
                  ),
                  if (widget.video)
                    FloatingActionButton(
                      onPressed: toggleCamera,
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.videocam),
                    ),
                  FloatingActionButton(
                    onPressed: () => Navigator.pop(context),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.call_end),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

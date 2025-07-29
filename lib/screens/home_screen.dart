import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:icons_plus/icons_plus.dart';

import '../helpers/custom_route.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/firestore_service.dart'; // Keep for FutureBuilder
import 'chat_screen.dart';
import 'create_group_screen.dart';
import 'new_chat_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final currentUser = authProvider.user;

    if (currentUser == null) {
      // This should technically not be reached due to the consumer in main.dart
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enawera'),
        actions: [
          Semantics(
            label: 'Create new group chat',
            child: IconButton(
              icon: const Icon(EvaIcons.people_outline),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  CustomPageRoute(child: const CreateGroupScreen()),
                );
              },
              tooltip: 'Create Group',
            ),
          ),
          Semantics(
            label: 'More options menu',
            child: PopupMenuButton<String>(
              onSelected: (value) {
                HapticFeedback.lightImpact();
                if (value == 'profile') {
                  Navigator.of(context).push(
                    CustomPageRoute(child: const ProfileScreen()),
                  );
                } else if (value == 'logout') {
                  authProvider.signOut();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Text('Profile'),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Text('Logout'),
                ),
              ],
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<ChatModel>>(
        stream: chatProvider.getUserChatsStream(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            final textTheme = Theme.of(context).textTheme;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 200,
                    child: SvgPicture.asset(
                      'assets/images/empty_chat_illustration.svg',
                      semanticsLabel:
                          'An illustration of a person sitting peacefully in nature',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('No chats yet', style: textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the button below to start a conversation.',
                    style: textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final chats = snapshot.data!;
          _animationController.forward();

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final slideAnimation = Tween<Offset>(
                    begin: const Offset(0, 0.2),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: Interval(
                      0.1 * index,
                      0.8,
                      curve: Curves.easeOut,
                    ),
                  ));

                  final fadeAnimation = Tween<double>(
                    begin: 0.0,
                    end: 1.0,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: Interval(
                      0.1 * index,
                      0.8,
                      curve: Curves.easeOut,
                    ),
                  ));

                  return FadeTransition(
                    opacity: fadeAnimation,
                    child: SlideTransition(
                      position: slideAnimation,
                      child: child,
                    ),
                  );
                },
                child: _buildChatListItem(context, chat, currentUser.uid),
              );
            },
            separatorBuilder: (context, index) => Divider(
              indent: 80,
              height: 1,
              color: Colors.grey.shade300,
            ),
          );
        },
      ),

      // Floating action button for new chat
      floatingActionButton: Semantics(
        label: 'Start a new chat',
        child: FloatingActionButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.of(context).push(
              CustomPageRoute(child: const NewChatScreen()),
            );
          },
          child: const Icon(EvaIcons.message_square_outline),
        ),
      ),
    );
  }

  Widget _buildChatListItem(
      BuildContext context, ChatModel chat, String currentUserId) {
    final unreadCount = chat.unreadCounts[currentUserId] ?? 0;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    Widget buildTile(String title, String subtitle, String? photoUrl,
        Widget placeholderIcon) {
      return InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            CustomPageRoute(
              child: ChatScreen(chatId: chat.id, chatName: title),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                    ? NetworkImage(photoUrl)
                    : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? placeholderIcon
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleLarge
                          ?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chat.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                          color: unreadCount > 0 ? colorScheme.primary : null),
                    ),
                  ],
                ),
              ),
              if (unreadCount > 0)
                CircleAvatar(
                  radius: 12,
                  backgroundColor: colorScheme.primary,
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (chat.isGroup) {
      return Semantics(
        label:
            'Group chat: ${chat.groupName ?? 'Group Chat'}. Last message: ${chat.lastMessage}',
        child: buildTile(
          chat.groupName ?? 'Group Chat',
          chat.lastMessage,
          chat.groupPhotoUrl,
          const Icon(EvaIcons.people_outline),
        ),
      );
    } else {
      final otherMemberId = chat.members
          .firstWhere((id) => id != currentUserId, orElse: () => '');
      return FutureBuilder<UserModel?>(
        future: FirestoreService.getUser(otherMemberId),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const ListTile(
                title: Text('Loading...'), leading: CircleAvatar(radius: 30));
          }
          final otherUser = userSnapshot.data!;
          return Semantics(
            label:
                'Chat with ${otherUser.name}. Last message: ${chat.lastMessage}',
            child: buildTile(
              otherUser.name,
              chat.lastMessage,
              otherUser.photoUrl,
              Text(
                  otherUser.name.isNotEmpty
                      ? otherUser.name[0].toUpperCase()
                      : '',
                  style: textTheme.headlineSmall),
            ),
          );
        },
      );
    }
  }
}

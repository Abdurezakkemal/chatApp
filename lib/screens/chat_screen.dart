import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:icons_plus/icons_plus.dart';
import 'dart:async';

import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;

  const ChatScreen({Key? key, required this.chatId, required this.chatName})
      : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<MessageModel> _messages = [];
  late final TextEditingController _messageController = TextEditingController();
  Timer? _typingTimer;

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _typingTimer?.cancel();
    // Final check to ensure typing status is set to false when leaving the screen.
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentUser = authProvider.user;
    if (currentUser != null) {
      chatProvider.updateTypingStatus(
        chatId: widget.chatId,
        userId: currentUser.uid,
        isTyping: false,
      );
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);

    // It's often better to fetch data after the first frame is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      // Listen to the chat stream once to get member info for caching.
      chatProvider.getChatStream(widget.chatId).first.then((chat) {
        if (chat.isGroup) {
          Provider.of<UserProvider>(context, listen: false)
              .fetchAndCacheUsers(chat.members);
        }
      });
    });
  }

  void _onTextChanged() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentUser = authProvider.user;
    if (currentUser == null) return;

    if (_messageController.text.isNotEmpty) {
      chatProvider.updateTypingStatus(
        chatId: widget.chatId,
        userId: currentUser.uid,
        isTyping: true,
      );
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      chatProvider.updateTypingStatus(
        chatId: widget.chatId,
        userId: currentUser.uid,
        isTyping: false,
      );
    });
  }

  void _sendMessage() {
    HapticFeedback.mediumImpact();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentUser = authProvider.user;

    if (_messageController.text.trim().isNotEmpty && currentUser != null) {
      chatProvider.sendMessage(
        widget.chatId,
        currentUser.uid,
        _messageController.text.trim(),
      );
      _messageController.clear();
      _typingTimer?.cancel();
      chatProvider.updateTypingStatus(
        chatId: widget.chatId,
        userId: currentUser.uid,
        isTyping: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final currentUser = authProvider.user;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Not authenticated. Please log in again.')),
      );
    }

    return StreamBuilder<ChatModel>(
      stream: chatProvider.getChatStream(widget.chatId),
      builder: (context, chatSnapshot) {
        if (chatSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.chatName)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!chatSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.chatName)),
            body: const Center(child: Text('Chat not found.')),
          );
        }

        final chat = chatSnapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: _buildAppBarTitle(context, chat, currentUser.uid),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: chatProvider.getChatMessagesStream(widget.chatId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && _messages.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final newMessages = snapshot.data ?? [];

                    // Diffing logic to handle new messages
                    if (newMessages.length > _messages.length) {
                      final newCount = newMessages.length - _messages.length;
                      final newItems = newMessages.sublist(0, newCount);
                      for (var item in newItems) {
                        _messages.insert(0, item);
                        _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 400));
                      }
                    }

                    if (_messages.isEmpty) {
                      final textTheme = Theme.of(context).textTheme;
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 200,
                              child: SvgPicture.asset(
                                'assets/images/empty_chat_illustration.svg',
                                semanticsLabel: 'An illustration of a person sitting peacefully in nature',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text('Say hello!', style: textTheme.headlineSmall),
                            const SizedBox(height: 8),
                            Text(
                              'Messages you send will appear here.',
                              style: textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return AnimatedList(
                      key: _listKey,
                      reverse: true,
                      padding: const EdgeInsets.all(16.0),
                      initialItemCount: _messages.length,
                      itemBuilder: (context, index, animation) {
                        final message = _messages[index];
                        final isMe = message.senderId == currentUser.uid;
                        if (!isMe && !message.readBy.contains(currentUser.uid)) {
                          chatProvider.markMessageAsRead(
                            chatId: widget.chatId,
                            messageId: message.id,
                            userId: currentUser.uid,
                          );
                        }
                        final chat = chatSnapshot.data!;
                        return _buildAnimatedItem(message, isMe, animation, chat.isGroup);
                      },
                    );
                  },
                ),
              ),
              TypingIndicator(
                typingUserIds:
                    chat.typing.where((id) => id != currentUser.uid).toList(),
              ),
              _buildMessageComposer(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageComposer() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(30.0),
                ),
                child: Semantics(
                  label: 'Message input field',
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Type a message...',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            Semantics(
              label: 'Send message',
              child: IconButton(
                icon: const Icon(EvaIcons.paper_plane_outline),
                iconSize: 25.0,
                color: colorScheme.primary,
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedItem(MessageModel message, bool isMe, Animation<double> animation, bool isGroup) {
    // We pass isGroup down to the final message widget.
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: _buildMessage(context, message, isMe, isGroup),
      ),
    );
  }


  Widget _buildMessage(BuildContext context, MessageModel message, bool isMe, bool isGroup) {
    final bool isRead = message.readBy.length > 1;

    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (isGroup && !isMe) ...[
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
            child: Consumer<UserProvider>(
              builder: (context, userProvider, _) {
                final sender = userProvider.getUserFromCache(message.senderId);
                return Text(
                  sender?.name ?? '...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                );
              },
            ),
          ),
        ],
        GestureDetector(
          onLongPress: () {
            HapticFeedback.heavyImpact();
            _showReactionDialog(context, message);
          },
          child: Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 5.0),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                      child: Icon(
                        EvaIcons.done_all_outline,
                        size: 16.0,
                        color: isRead
                            ? Colors.lightBlueAccent
                            : Colors.white.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (message.reactions.isNotEmpty)
          _buildReactions(message.reactions, isMe),
      ],
    );
  }

  Widget _buildAppBarTitle(
      BuildContext context, ChatModel chat, String currentUserId) {
    if (chat.isGroup) {
      return Row(
        children: [
          CircleAvatar(
            backgroundImage:
                (chat.groupPhotoUrl != null && chat.groupPhotoUrl!.isNotEmpty)
                    ? NetworkImage(chat.groupPhotoUrl!)
                    : null,
            child: (chat.groupPhotoUrl == null || chat.groupPhotoUrl!.isEmpty)
                ? const Icon(EvaIcons.people_outline)
                : null,
          ),
          const SizedBox(width: 12),
          Text(chat.groupName ?? 'Group Chat'),
        ],
      );
    } else {
      final otherUserId = chat.members
          .firstWhere((id) => id != currentUserId, orElse: () => '');
      if (otherUserId.isEmpty) return Text(widget.chatName);

      return _PrivateChatAppBarTitle(
          otherUserId: otherUserId, fallbackName: widget.chatName);
    }
  }

  void _showReactionDialog(BuildContext context, MessageModel message) {
    const List<String> reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentUser = authProvider.user!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('React to message'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: reactionEmojis.map((emoji) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                chatProvider.toggleMessageReaction(
                  chatId: widget.chatId,
                  messageId: message.id,
                  userId: currentUser.uid,
                  reaction: emoji,
                );
                Navigator.of(context).pop();
              },
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildReactions(Map<String, String> reactions, bool isMe) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    final Map<String, int> reactionCounts = {};
    for (var reaction in reactions.values) {
      reactionCounts[reaction] = (reactionCounts[reaction] ?? 0) + 1;
    }

    return Padding(
      padding:
          EdgeInsets.only(left: isMe ? 0 : 40, right: isMe ? 40 : 0, bottom: 4),
      child: Wrap(
        spacing: 6.0,
        children: reactionCounts.entries.map((entry) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Text('${entry.key} ${entry.value}'),
          );
        }).toList(),
      ),
    );
  }
}

class _PrivateChatAppBarTitle extends StatefulWidget {
  final String otherUserId;
  final String fallbackName;

  const _PrivateChatAppBarTitle({
    Key? key,
    required this.otherUserId,
    required this.fallbackName,
  }) : super(key: key);

  @override
  __PrivateChatAppBarTitleState createState() =>
      __PrivateChatAppBarTitleState();
}

class __PrivateChatAppBarTitleState extends State<_PrivateChatAppBarTitle> {
  late final Future<List<UserModel>> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture =
        context.read<UserProvider>().getUsersFromIds([widget.otherUserId]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserModel>>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text(widget.fallbackName);
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Text(widget.fallbackName);
        }
        final otherUser = snapshot.data!.first;
        return Row(
          children: [
            CircleAvatar(
              backgroundImage: otherUser.photoUrl.isNotEmpty
                  ? NetworkImage(otherUser.photoUrl)
                  : null,
              child: otherUser.photoUrl.isEmpty
                  ? Text(otherUser.name.isNotEmpty
                      ? otherUser.name[0].toUpperCase()
                      : '?')
                  : null,
            ),
            const SizedBox(width: 12),
            Text(otherUser.name),
          ],
        );
      },
    );
  }
}

Widget _buildReactions(Map<String, String> reactions, bool isMe) {
  if (reactions.isEmpty) return const SizedBox.shrink();

  final Map<String, int> reactionCounts = {};
  for (var reaction in reactions.values) {
    reactionCounts[reaction] = (reactionCounts[reaction] ?? 0) + 1;
  }

  return Padding(
    padding:
        EdgeInsets.only(left: isMe ? 0 : 40, right: isMe ? 40 : 0, bottom: 4),
    child: Wrap(
      spacing: 6.0,
      children: reactionCounts.entries.map((entry) {
        return Chip(
          backgroundColor: Colors.grey.shade300,
          labelPadding:
              const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0),
          label: Text('${entry.key} ${entry.value}'),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/svg.dart';
import 'package:syphon_demo/domain/events/messages/model.dart';
import 'package:syphon_demo/domain/events/selectors.dart';
import 'package:syphon_demo/domain/index.dart';
import 'package:syphon_demo/domain/rooms/room/model.dart';
import 'package:syphon_demo/domain/rooms/selectors.dart';
import 'package:syphon_demo/domain/sync/selectors.dart';
import 'package:syphon_demo/global/assets.dart';
import 'package:syphon_demo/global/dimensions.dart';
import 'package:syphon_demo/global/libraries/redux/hooks.dart';
import 'package:syphon_demo/global/strings.dart';
import 'package:syphon_demo/views/home/HomeChatListItem.dart';

class HomeChatList extends HookWidget {
  const HomeChatList({
    super.key,
    this.searching = false,
    this.searchText = '',
    this.selectedChats = const [],
    this.onSelectChat,
    this.onToggleChatOptions,
  });

  final bool searching;
  final String searchText;
  final List<String> selectedChats;
  final Function? onSelectChat;
  final Function? onToggleChatOptions;

  @override
  Widget build(BuildContext context) {
    debugPrint('HomeChatList, build');
    final chats = useSelector<AppState, List<Chat>>(selectHomeChats, const []);
    final syncing = useSelector<AppState, bool>(selectSyncingStatus, false);
    final messagesAll = useSelector<AppState, Map<String, List<Message>>>(
      (state) => state.eventStore.messages,
      {},
    );
    final decryptedAll = useSelector<AppState, Map<String, List<Message>>>(
      (state) => state.eventStore.messagesDecrypted,
      {},
    );
    final searchMessages = useSelector<AppState, List<Message>>(
      (state) => state.searchStore.searchMessages,
      [],
    );
    final latestMessageAll = useMemoized<Map<String, Message?>>(() {
      return Map.fromIterable(
        chats,
        key: (chat) => chat.id,
        value: (chat) {
          final messages = messagesAll[chat.id] ?? const [];
          final decrypted = decryptedAll[chat.id] ?? const [];
          return latestMessage(messages, room: chat, decrypted: decrypted);
        },
      );
    }, [chats, messagesAll, decryptedAll]);
    final noChatsLabel =
        syncing ? Strings.labelSyncingChats : Strings.labelMessagesEmpty;
    final noSearchResults =
        searching && searchMessages.isEmpty && searchText.isNotEmpty;
    if (chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              constraints: const BoxConstraints(
                minWidth: Dimensions.mediaSizeMin,
                maxWidth: Dimensions.mediaSizeMax,
                maxHeight: Dimensions.mediaSizeMin,
              ),
              child: SvgPicture.asset(
                Assets.heroChatNotFound,
                semanticsLabel: Strings.semanticsHomeDefault,
              ),
            ),
            GestureDetector(
              child: Container(
                margin: const EdgeInsets.only(bottom: 48),
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  noChatsLabel,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ScrollConfiguration(
      behavior: NoGlowScrollBehavior(),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        scrollDirection: Axis.vertical,
        itemCount: noSearchResults ? 0 : chats.length,
        itemBuilder: (BuildContext context, int index) => HomeChatListItem(
          room: chats[index],
          messages: messagesAll[chats[index].id] ?? const [],
          messageLatest: latestMessageAll[chats[index].id],
          // roomTypeBadgesEnabled: roomTypeBadgesEnabled,
          onSelectChat: onSelectChat,
          onToggleChatOptions: onToggleChatOptions,
        ),
      ),
    );
  }
}

class NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildViewportChrome(
      BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }
}

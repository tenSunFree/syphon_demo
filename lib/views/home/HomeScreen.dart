import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:syphon_demo/domain/index.dart';
import 'package:syphon_demo/domain/rooms/room/model.dart';
import 'package:syphon_demo/domain/search/actions.dart';
import 'package:syphon_demo/domain/settings/storage.dart';
import 'package:syphon_demo/domain/settings/theme-settings/model.dart';
import 'package:syphon_demo/global/libraries/redux/hooks.dart';
import 'package:syphon_demo/views/home/HomeChatList.dart';
import 'package:syphon_demo/views/navigation.dart';
import 'package:syphon_demo/views/widgets/loader/index.dart';

import '../../domain/rooms/actions.dart';
import '../../global/assets.dart';

class HomeScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final dispatch = useDispatch<AppState>();
    final searchModeState = useState(false);
    final searchTextState = useState('');
    final selectedChatsState = useState<List<String>>([]);
    final searchMode = searchModeState.value;
    final searchText = searchTextState.value;
    final selectedChats = selectedChatsState.value;
    useEffect(() {
      dispatch(fetchRooms());
      return null;
    }, []);
    onToggleSearch() {
      searchModeState.value = !searchModeState.value;
      searchTextState.value = '';
    }
    onToggleChatOptions({required Room room}) {
      if (searchMode) {
        onToggleSearch();
      }
      if (!selectedChats.contains(room.id)) {
        selectedChatsState.value = List.from(selectedChats..addAll([room.id]));
      } else {
        selectedChatsState.value = List.from(selectedChats..remove(room.id));
      }
    }
    onDismissChatOptions() {
      selectedChatsState.value = [];
    }
    onSelectChat(Room room, String chatName) {
      if (selectedChats.isNotEmpty) {
        return onToggleChatOptions(room: room);
      }
    }
    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              child: const AspectRatio(
                aspectRatio: 1080 / 564,
                child: Image(
                  image: AssetImage(Assets.iconTopBar),
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: onDismissChatOptions,
                    child: HomeChatList(
                      searching: searchMode,
                      searchText: searchText,
                      selectedChats: selectedChats,
                      onSelectChat: onSelectChat,
                      onToggleChatOptions: onToggleChatOptions,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              child: const AspectRatio(
                aspectRatio: 1080 / 147,
                child: Image(
                  image: AssetImage(Assets.iconBottomBar),
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

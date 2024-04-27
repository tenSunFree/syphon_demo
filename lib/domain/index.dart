import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';
import 'package:redux_persist/redux_persist.dart';
import 'package:redux_thunk/redux_thunk.dart';
import 'package:sembast/sembast.dart';
import 'package:syphon_demo/domain/crypto/reducer.dart';
import 'package:syphon_demo/domain/crypto/state.dart';
import 'package:syphon_demo/domain/events/reducer.dart';
import 'package:syphon_demo/domain/events/state.dart';
import 'package:syphon_demo/domain/media/reducer.dart';
import 'package:syphon_demo/domain/search/middleware.dart';
import 'package:syphon_demo/domain/sync/reducer.dart';
import 'package:syphon_demo/domain/sync/state.dart';
import 'package:syphon_demo/domain/user/reducer.dart';
import 'package:syphon_demo/domain/user/state.dart';
import 'package:syphon_demo/global/libraries/cache/middleware.dart';
import 'package:syphon_demo/global/libraries/cache/serializer.dart';
import 'package:syphon_demo/global/libraries/cache/storage.dart';
import 'package:syphon_demo/global/libraries/storage/database.dart';
import 'package:syphon_demo/global/libraries/storage/index.dart';
import 'package:syphon_demo/global/libraries/storage/middleware/load-storage-middleware.dart';
import 'package:syphon_demo/global/libraries/storage/middleware/save-storage-middleware.dart';
import 'package:syphon_demo/global/print.dart';

import './auth/state.dart';
import './media/state.dart';
import './rooms/reducer.dart';
import './rooms/state.dart';
import './search/reducer.dart';
import './search/state.dart';
import './settings/reducer.dart';
import './settings/state.dart';

class SetGlobalLoading {
  bool loading;
  SetGlobalLoading({required this.loading});
}

// ignore: avoid_positional_boolean_parameters
bool loadingReducer([bool state = false, dynamic action]) {
  switch (action.runtimeType) {
    case SetGlobalLoading:
      return action.loading;
    default:
      return state;
  }
}

class AppState extends Equatable {
  final bool loading;
  final AuthStore authStore;
  // final AlertsStore alertsStore;
  final SearchStore searchStore;
  final MediaStore mediaStore;
  final SettingsStore settingsStore;
  final RoomStore roomStore;
  final EventStore eventStore;
  final UserStore userStore;
  final SyncStore syncStore;
  final CryptoStore cryptoStore;

  const AppState({
    this.loading = false,
    this.authStore = const AuthStore(),
    // this.alertsStore = const AlertsStore(),
    this.syncStore = const SyncStore(),
    this.roomStore = const RoomStore(),
    this.eventStore = const EventStore(),
    this.userStore = const UserStore(),
    this.mediaStore = const MediaStore(),
    this.searchStore = const SearchStore(),
    this.settingsStore = const SettingsStore(),
    this.cryptoStore = const CryptoStore(),
  });

  @override
  List<Object> get props => [
        loading,
        // alertsStore,
        authStore,
        syncStore,
        roomStore,
        userStore,
        mediaStore,
        eventStore,
        searchStore,
        settingsStore,
        cryptoStore,
      ];

  AppState copyWith({
    bool? loading,
    AuthStore? authStore,
    // AlertsStore? alertsStore,
    SearchStore? searchStore,
    SettingsStore? settingsStore,
    RoomStore? roomStore,
    EventStore? eventStore,
    UserStore? userStore,
    SyncStore? syncStore,
    CryptoStore? cryptoStore,
  }) =>
      AppState(
        loading: loading ?? this.loading,
        authStore: authStore ?? this.authStore,
       // alertsStore: alertsStore ?? this.alertsStore,
        searchStore: searchStore ?? this.searchStore,
        settingsStore: settingsStore ?? this.settingsStore,
        roomStore: roomStore ?? this.roomStore,
        eventStore: eventStore ?? this.eventStore,
        userStore: userStore ?? this.userStore,
        syncStore: syncStore ?? this.syncStore,
        cryptoStore: cryptoStore ?? this.cryptoStore,
      );
}

AppState appReducer(AppState state, action) => AppState(
      // authStore: authReducer(state.authStore, action),
      // alertsStore: alertsReducer(state.alertsStore, action),
      mediaStore: mediaReducer(state.mediaStore, action),
      roomStore: roomReducer(state.roomStore, action),
      // eventStore: eventReducer(state.eventStore, action),
      // syncStore: syncReducer(state.syncStore, action),
      userStore: userReducer(state.userStore, action),
      searchStore: searchReducer(state.searchStore, action),
      // settingsStore: settingsReducer(state.settingsStore, action),
      // cryptoStore: cryptoReducer(state.cryptoStore, action),
    );

///
/// Initialize Store
///
/// Hot cache for top level data
/// Cold storage all missing and full state data
///
/// existingState copies the login state between multiaccount swaps
///
Future<Store<AppState>> initStore(
  Database? cache,
  ColdStorageDatabase? storage, {
  AppState? existingState,
  bool existingUser = false,
}) async {
  AppState? initialState;
  Map<String, dynamic> preloaded = {};

  if (storage != null) {
    // synchronously load mandatory cold storage to rehydrate cache
    preloaded = await loadStorage(storage);
  }

  // Configure redux persist instance
  final persistor = Persistor<AppState>(
    storage: CacheStorage(cache: cache),
    serializer: CacheSerializer(cache: cache, preloaded: preloaded),
    // shouldSave: cacheMiddleware,
    throttleDuration: const Duration(milliseconds: 500),
  );

  // Finally load persisted store
  try {
    // TODO: this is pretty hacky - merges availableUsers across stores
    if (existingUser) {
      initialState = await persistor.load();
      initialState = initialState?.copyWith(
        authStore: initialState.authStore.copyWith(
          availableUsers: existingState?.authStore.availableUsers,
        ),
      );
    } else {
      initialState = existingState ?? await persistor.load();
    }
  } catch (error) {
    console.error('[persistor.load] $error');
  }

  final store = Store<AppState>(
    appReducer,
    initialState: initialState ?? const AppState(),
    middleware: [
      // (){},
      // (Store<State> store, action, NextDispatcher next) {
      //   // 这里可以根据action的类型或其他属性来编写自定义逻辑
      //   // 比如打印动作:
      //   print('Dispatching action: $action');
      //   // 确保继续传递动作
      //   next(action);
      // },
      thunkMiddleware,
      // authMiddleware,
      persistor.createMiddleware(),
      // saveStorageMiddleware(storage),
      loadStorageMiddleware(storage),
      searchMiddleware(storage),
      // alertMiddleware,
    ],
  );

  if (storage != null) {
    // async load additional cold storage to rehydrate cache
    loadStorageAsync(storage, store);
  }

  return store;
}

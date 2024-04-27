import 'dart:async';
import 'package:easy_localization/easy_localization.dart' as localization;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:sembast/sembast.dart';
import 'package:syphon_demo/context/auth.dart';
import 'package:syphon_demo/context/storage.dart';
import 'package:syphon_demo/context/types.dart';
import 'package:syphon_demo/domain/index.dart';
import 'package:syphon_demo/domain/settings/theme-settings/model.dart';
import 'package:syphon_demo/domain/sync/actions.dart';
import 'package:syphon_demo/domain/sync/service/storage.dart';
import 'package:syphon_demo/domain/user/model.dart';
import 'package:syphon_demo/global/connectivity.dart';
import 'package:syphon_demo/global/formatters.dart';
import 'package:syphon_demo/global/libraries/cache/index.dart';
import 'package:syphon_demo/global/libraries/storage/database.dart';
import 'package:syphon_demo/global/libraries/storage/index.dart';
import 'package:syphon_demo/global/notifications.dart';
import 'package:syphon_demo/global/print.dart';
import 'package:syphon_demo/global/themes.dart';
import 'package:syphon_demo/global/values.dart';
import 'package:syphon_demo/views/home/HomeScreen.dart';
import 'package:syphon_demo/views/navigation.dart';

class Syphon extends StatefulWidget {
  final Database? cache;
  final Store<AppState> store;
  final ColdStorageDatabase? storage;

  const Syphon(
    this.cache,
    this.store,
    this.storage,
  );

  static Future setAppContext(
      BuildContext buildContext, AppContext appContext) {
    return buildContext
        .findAncestorStateOfType<SyphonState>()!
        .onContextSet(appContext);
  }

  static AppContext getAppContext(BuildContext buildContext) {
    return buildContext.findAncestorStateOfType<SyphonState>()!.appContext ??
        const AppContext();
  }

  static Future reloadCurrentContext(BuildContext buildContext) {
    return buildContext
        .findAncestorStateOfType<SyphonState>()!
        .reloadCurrentContext();
  }

  @override
  SyphonState createState() => SyphonState();
}

class SyphonState extends State<Syphon> with WidgetsBindingObserver {
  late Store<AppState> store;
  Database? cache;
  ColdStorageDatabase? storage;
  AppContext? appContext;
  final globalScaffold = GlobalKey<ScaffoldMessengerState>();
  Widget defaultHome = HomeScreen();

  SyphonState();

  @override
  void initState() {
    cache = widget.cache;
    store = widget.store;
    storage = widget.storage;
    WidgetsBinding.instance.addObserver(this);
    onInitListeners();
    super.initState();
  }

  Future<void> reloadCurrentContext() async {
    final currentContext = await loadContextCurrent();
    appContext = currentContext;
  }

  onInitListeners() async {
    await onDispatchListeners();
    await onStartListeners();
    final currentContext = await loadContextCurrent();
    appContext = currentContext;
    final currentUser = store.state.authStore.user;
    if (currentUser.accessToken == null &&
        currentContext.id != AppContext.DEFAULT) {
      return onResetContext();
    }
    store.state.authStore.authObserver?.add(
      currentUser,
    );
  }

  onDispatchListeners() async {
    await Future.wait([
      // store.dispatch(initDeepLinks()) as Future,
      // store.dispatch(startAuthObserver()) as Future,
      // store.dispatch(startAlertsObserver()) as Future,
      // store.dispatch(startContextObserver()) as Future,
    ]);
  }

  onStartListeners() async {
    await ConnectionService.startListener();
    store.state.authStore.onAuthStateChanged.listen(onAuthStateChanged);
    store.state.authStore.onContextChanged.listen(onContextChanged);
    // store.state.alertsStore.onAlertsChanged.listen(onAlertsChanged);
  }

  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) async {
  //   switch (state) {
  //     // case AppLifecycleState.resumed:
  //     //   setupTheme(store.state.settingsStore.themeSettings);
  //     //   dismissAllNotifications(
  //     //     pluginInstance: globalNotificationPluginInstance,
  //     //   );
  //     //   saveNotificationsUnchecked(const {});
  //     // case AppLifecycleState.paused:
  //     //   store.dispatch(updateLatestLastSince());
  //     //   store.dispatch(setBackgrounded(backgrounded: true));
  //     // case AppLifecycleState.detached:
  //     //   store.dispatch(updateLatestLastSince());
  //     //   store.dispatch(setBackgrounded(backgrounded: true));
  //     case AppLifecycleState.inactive:
  //       break;
  //     case AppLifecycleState.hidden:
  //     // TODO: Handle this case.
  //   }
  // }

  Future<void> onContextSet(AppContext appContext) async {
    await saveContextCurrent(appContext);
  }

  onContextChanged(User? user) async {
    store.dispatch(SetGlobalLoading(loading: true));
    await onDestroyListeners();
    // await store.dispatch(stopSyncObserver());
    await closeCache(cache);
    await closeStorage(storage);
    final contextOld = await loadContextCurrent();
    AppContext? contextNew;
    if (user != null) {
      final contextId = generateContextId_DEPRECATED(id: user.userId!);
      contextNew = await findContext(contextId);
      if (contextNew.id.isEmpty) {
        contextNew = AppContext(id: contextId);
      }
      await saveContext(contextNew);
    } else {
      await deleteContext(contextOld);
      contextNew = await loadContextNext();
    }
    final cacheNew = await initCache(context: contextNew);
    final storageNew = await initStorage(context: contextNew);
    appContext = contextNew;
    final storeExisting = AppState(
      authStore: store.state.authStore.copyWith(user: user),
      settingsStore: store.state.settingsStore.copyWith(),
    );
    var existingUser = false;
    if (user != null && user.accessToken != null) {
      if (user.accessToken!.isEmpty) {
        existingUser = true;
      }
    }
    if (user == null) {
      existingUser = true;
    }
    final storeNew = await initStore(
      cacheNew,
      storageNew,
      existingUser: existingUser,
      existingState: storeExisting,
    );
    setState(() {
      cache = cacheNew;
      store = storeNew;
      storage = storageNew;
    });
    await onDispatchListeners();
    await onStartListeners();
    final userNew = storeNew.state.authStore.user;
    final authObserverNew = storeNew.state.authStore.authObserver;
    if (user == null &&
        userNew.accessToken != null &&
        contextNew.id.isNotEmpty) {
      authObserverNew?.add(userNew);
    } else {
      authObserverNew?.add(user);
    }
    if (user != null) {
      onDeleteContextStorage(const AppContext(id: AppContext.DEFAULT));
    } else {
      onDeleteContextStorage(contextOld);
    }
    storeNew.dispatch(SetGlobalLoading(loading: false));
  }

  onDeleteContextStorage(AppContext context) async {
    if (context.id.isEmpty) {
      console.info('[onContextChanged] DELETING DEFAULT CONTEXT');
    } else {
      console.info('[onDeleteContext] DELETING CONTEXT DATA ${context.id}');
    }
    await deleteCache(context: context);
    await deleteStorage(context: context);
    await deleteContext(context);
  }

  onResetContext() async {
    console.error(
        '[onResetContext] WARNING - RESETTING CONTEXT - HIT UNRECOVERABLE STATE');
    resetContextsAll();
    store.state.authStore.contextObserver?.add(null);
  }

  onAuthStateChanged(User? user) async {
    debugPrint('SyphonState, onAuthStateChanged: $user');
    if (true) {
      debugPrint('SyphonState, onAuthStateChanged2');
      defaultHome = HomeScreen();
      return NavigationService.clearTo(Routes.home, context);
    }
  }

  // onAlertsChanged(Alert alert) {
  //   Color? color;
//
  //   String? alertOverride;
//
  //   switch (alert.type) {
  //     case 'error':
  //       if (!ConnectionService.isConnected() && !alert.offline) {
  //         alertOverride = Strings.alertOffline;
  //       }
  //       color = Colors.red;
  //     case 'warning':
  //       if (!ConnectionService.isConnected() && !alert.offline) {
  //         alertOverride = Strings.alertOffline;
  //       }
  //       color = Colors.red;
  //     case 'success':
  //       color = Colors.green;
  //     case 'info':
  //     default:
  //       color = Colors.grey;
  //   }
//
  //   final alertMessage =
  //       alertOverride ?? alert.message ?? alert.error ?? Strings.alertUnknown;
//
  //   globalScaffold.currentState?.showSnackBar(
  //     SnackBar(
  //       backgroundColor: color,
  //       content: Text(
  //         alertMessage,
  //         style: Theme.of(context)
  //             .textTheme
  //             .titleMedium
  //             ?.copyWith(color: Colors.white),
  //       ),
  //       duration: alert.duration,
  //       action: SnackBarAction(
  //         label: alert.action ?? Strings.buttonDismiss,
  //         textColor: Colors.white,
  //         onPressed: () {
  //           alert.onAction?.call();
  //           globalScaffold.currentState?.removeCurrentSnackBar();
  //         },
  //       ),
  //     ),
  //   );
  // }

  onDestroyListeners() async {
    await ConnectionService.stopListener();
    // await store.dispatch(stopContextObserver());
    // await store.dispatch(stopAlertsObserver());
    // await store.dispatch(stopAuthObserver());
    // await store.dispatch(disposeDeepLinks());
  }

  @override
  void dispose() {
    onDestroyListeners();
    closeCache(cache);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StoreProvider<AppState>(
        store: store,
        child: localization.EasyLocalization(
          path: 'assets/translations',
          useOnlyLangCode: true,
          startLocale: Locale(
              findLocale(store.state.settingsStore.language, context: context)),
          fallbackLocale: const Locale(SupportedLanguages.defaultLang),
          useFallbackTranslations: true,
          supportedLocales: SupportedLanguages.list,
          child: StoreConnector<AppState, ThemeSettings>(
            distinct: true,
            converter: (store) => store.state.settingsStore.themeSettings,
            builder: (context, themeSettings) {
              return MaterialApp(
                  scaffoldMessengerKey: globalScaffold,
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  debugShowCheckedModeBanner: false,
                  theme: setupTheme(themeSettings, generateThemeData: true),
                  navigatorKey: NavigationService.navigatorKey,
                  routes: NavigationProvider.getRoutes(),
                  home: defaultHome,
                  builder: (context, child) {
                    SystemChrome.setSystemUIOverlayStyle(
                        SystemUiOverlayStyle.dark.copyWith(
                      systemNavigationBarColor: Colors.black, // 将导航栏背景设为黑色
                      systemNavigationBarIconBrightness:
                          Brightness.light, // 将导航栏图标设为浅色
                    ));
                    return Directionality(
                      textDirection: SupportedLanguages.rtl
                              .contains(store.state.settingsStore.language)
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      child: child!,
                    );
                  });
            },
          ),
        ),
      );
}

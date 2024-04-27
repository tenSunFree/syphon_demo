import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:sembast/sembast.dart';
import 'package:syphon_demo/context/storage.dart';
import 'package:syphon_demo/context/types.dart';
import 'package:syphon_demo/domain/index.dart';
import 'package:syphon_demo/global/https.dart';
import 'package:syphon_demo/global/libraries/cache/index.dart';
import 'package:syphon_demo/global/libraries/storage/database.dart';
import 'package:syphon_demo/global/libraries/storage/index.dart';
import 'package:syphon_demo/global/print.dart';
import 'package:syphon_demo/global/values.dart';
import 'package:syphon_demo/views/intro/lock-screen.dart';
import 'package:syphon_demo/views/intro/signup/LoadingScreen.dart';
import 'package:syphon_demo/views/navigation.dart';
import 'package:syphon_demo/views/syphon.dart';
import 'package:syphon_demo/views/widgets/lifecycle.dart';

class PrelockRoutes {
  static const root = '/';
  static const locked = '/locked';
  static const unlocked = '/unlocked';
  static const loading = '/loading-screen';
}

///
/// Prelock
///
/// Locks the app by removing the storage
/// references of the widget and potentially
/// freeing what is in RAM. None of the storage
/// references should be available when locked
///
class Prelock extends StatefulWidget {
  final bool enabled;
  final AppContext appContext;
  final Duration backgroundLockLatency;

  const Prelock({
    required this.enabled,
    required this.appContext,
    this.backgroundLockLatency = Duration.zero,
  });

  static restart(BuildContext context) {
    context.findAncestorStateOfType<_PrelockState>()!.restart();
  }

  static Future? toggleLocked(BuildContext context, String pin, {bool? override}) {
    return context.findAncestorStateOfType<_PrelockState>()!.toggleLocked(pin: pin, override: override);
  }

  @override
  _PrelockState createState() => _PrelockState();
}

class _PrelockState extends State<Prelock> with WidgetsBindingObserver, Lifecycle<Prelock> {
  static final GlobalKey<NavigatorState> _navigatorKey = GlobalKey();

  Key key = UniqueKey();
  bool locked = false;
  bool enabled = false;
  bool _didUnlockForAppLaunch = false;
  Timer? backgroundLockLatencyTimer;

  Database? cache;
  ColdStorageDatabase? storage;
  Store<AppState>? store;
  AppContext? appContext;

  @override
  void initState() {
    debugPrint('_PrelockState initState');
    WidgetsBinding.instance.addObserver(this);

    locked = widget.enabled;
    enabled = widget.enabled;
    _didUnlockForAppLaunch = !widget.enabled;

    super.initState();
  }

  @override
  onMounted() async {
    if (!locked) {
      await _onLoadStorage();

      console.info('[Prelock] onMounted LOADED STORAGE ${widget.appContext.id}');

      _navigatorKey.currentState?.pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => buildSyphon(),
          transitionDuration: const Duration(seconds: 200),
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!enabled) {
      return;
    }

    if (state == AppLifecycleState.paused && (!locked && _didUnlockForAppLaunch)) {
      backgroundLockLatencyTimer = Timer(widget.backgroundLockLatency, () => showLockScreen());
    }

    if (state == AppLifecycleState.resumed) {
      backgroundLockLatencyTimer?.cancel();
    }

    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    backgroundLockLatencyTimer?.cancel();

    super.dispose();
  }

  _onLoadStorage({String pin = Values.empty}) async {
    final context = appContext ?? widget.appContext;

    // init hot caches
    final cachePreload = await initCache(context: context);

    // init cold storage
    final storagePreload = await initStorage(context: context, pin: pin);

    // init redux store
    final storePreload = await initStore(cachePreload, storagePreload);

    // init http client
    httpClient = createClient(proxySettings: storePreload.state.settingsStore.proxySettings);

    setState(() {
      cache = cachePreload;
      storage = storagePreload;
      store = storePreload;
    });
  }

  showLockScreen() async {
    locked = true;

    if (_navigatorKey.currentState == null) return;

    _navigatorKey.currentState?.pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => buildLockScreen(),
        transitionDuration: const Duration(seconds: 200),
      ),
    );
  }

  restart() async {
    final appContextNew = await loadContextCurrent();

    final isLocked = appContextNew.id.isNotEmpty && appContextNew.pinHash.isNotEmpty;

    await _navigatorKey.currentState?.pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => buildLoadingScreen(),
        transitionDuration: const Duration(seconds: 200),
      ),
      ModalRoute.withName(PrelockRoutes.root),
    );

    setState(() {
      key = UniqueKey();
      locked = isLocked;
      enabled = isLocked;
      appContext = appContextNew;
      _didUnlockForAppLaunch = !enabled;
    });

    if (isLocked) {
      await showLockScreen();
    } else {
      await _onLoadStorage();

      console.info('[Prelock] onMounted LOADED STORAGE ${widget.appContext.id}');

      _navigatorKey.currentState?.pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => buildSyphon(),
          transitionDuration: const Duration(seconds: 200),
        ),
        ModalRoute.withName(PrelockRoutes.root),
      );
    }
  }

  Widget buildLoadingScreen() => LoadingScreen(dark: Platform.isAndroid);

  Widget buildLockScreen() => LockScreen(
        appContext: appContext ?? widget.appContext,
      );

  Widget buildSyphon() => WillPopScope(
        onWillPop: () => NavigationService.goBack(),
        child: Syphon(
          cache,
          store!,
          storage,
        ),
      );

  Future<void> toggleLocked({required String pin, bool? override}) async {
    final lockedNew = override ?? !locked;

    if (!lockedNew) {
      await _onLoadStorage(pin: pin);

      setState(() {
        locked = false;
      });

      _navigatorKey.currentState?.pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => buildSyphon(),
          transitionDuration: const Duration(seconds: 200),
        ),
        ModalRoute.withName(PrelockRoutes.root),
      );
    } else {
      final appContextCurrent = await loadContextCurrent();
      setState(() {
        locked = true;
        appContext = appContextCurrent;
      });

      await showLockScreen();

      setState(() {
        store = null;
        cache = null;
        storage = null;
      });
    }
  }

  Widget buildHome() {
    if (enabled) {
      return buildLockScreen();
    }

    return LoadingScreen(dark: Platform.isAndroid);
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: buildHome(),
          navigatorKey: _navigatorKey,
          routes: {
            PrelockRoutes.unlocked: (context) => buildSyphon(),
            PrelockRoutes.locked: (context) => buildLockScreen(),
            PrelockRoutes.loading: (context) => buildLoadingScreen(),
          },
        ),
      );
}

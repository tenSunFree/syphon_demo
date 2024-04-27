import 'dart:convert';

import 'package:syphon_demo/context/types.dart';
import 'package:syphon_demo/global/libraries/cache/index.dart';
import 'package:syphon_demo/global/libraries/secure-storage/secure-storage.dart';
import 'package:syphon_demo/global/libraries/storage/index.dart';
import 'package:syphon_demo/global/print.dart';
import 'package:syphon_demo/global/values.dart';

const ALL_APP_CONTEXT_KEY = '${Values.appLabel}@app-context-all';
const CURRENT_APP_CONTEXT_KEY = '${Values.appLabel}@app-context-current';

Future<AppContext> findContext(String contextId) async {
  final all = await loadContextsAll();

  return all.firstWhere((e) => e.id == contextId, orElse: () => const AppContext());
}

Future saveContextCurrent(AppContext? current) async {
  if (current == null) return;

  SecureStorage().write(key: CURRENT_APP_CONTEXT_KEY, value: json.encode(current));
}

Future saveContextsAll(List<AppContext>? all) async {
  if (all == null) return;

  await SecureStorage().write(key: ALL_APP_CONTEXT_KEY, value: json.encode(all));
}

Future saveContext(AppContext? current) async {
  if (current == null) return;

  final allContexts = await loadContextsAll();
  final position = allContexts.indexWhere((c) => c.id == current.id);

  // both saves new or effectively updates existing
  if (position == -1) {
    allContexts.add(current);
  } else {
    allContexts.removeAt(position);
    allContexts.insert(0, current);
  }

  // TODO: handle setting current context external to saveContext
  await saveContextCurrent(current);

  return saveContextsAll(allContexts);
}

Future<AppContext> loadContextCurrent() async {
  try {
    final contextJson = await SecureStorage().read(key: CURRENT_APP_CONTEXT_KEY);
    final currentContext = AppContext.fromJson(await json.decode(contextJson!));

    return currentContext;
  } catch (error) {
    console.error('[loadCurrentContext] ERROR LOADING CURRENT CONTEXT $error');

    try {
      final fallback = await loadContextNext();

      saveContextCurrent(fallback);

      return fallback;
    } catch (error) {
      console.error('[loadNextContext] ERROR LOADING NEXT CONTEXT - RESETTING CONTEXT');
      resetContextsAll();
      return const AppContext();
    }
  }
}

Future<AppContext> loadContextNext() async {
  try {
    final allContexts = await loadContextsAll();
    return allContexts.isNotEmpty ? allContexts[0] : const AppContext();
  } catch (error) {
    console.error('[loadNextContext] ERROR LOADING NEXT CONTEXT $error');

    return const AppContext();
  }
}

Future<List<AppContext>> loadContextsAll() async {
  try {
    final contextJson = await SecureStorage().read(key: ALL_APP_CONTEXT_KEY) ?? '[]';
    return List.from(await json.decode(contextJson)).map((c) => AppContext.fromJson(c)).toList();
  } catch (error) {
    console.error('[loadAllContexts] ERROR LOADING ALL CONTEXTS $error');

    resetContextsAll();

    return [const AppContext()];
  }
}

Future deleteContext(AppContext? current) async {
  if (current == null) return;

  final allContexts = await loadContextsAll();

  final updatedContexts = allContexts.where((e) => e.id != current.id).toList();

  if (allContexts.isNotEmpty) {
    saveContextCurrent(allContexts.first);
  } else {
    saveContextCurrent(const AppContext());
  }

  return saveContextsAll(updatedContexts);
}

resetContextsAll() async {
  try {
    final allContexts = await loadContextsAll();

    await Future.forEach(
      allContexts,
      (AppContext context) async {
        await deleteCache(context: context);
        await deleteStorage(context: context);
      },
    );

    await SecureStorage().write(key: ALL_APP_CONTEXT_KEY, value: json.encode([]));
    await SecureStorage().write(key: CURRENT_APP_CONTEXT_KEY, value: json.encode(const AppContext()));
  } catch (error) {
    console.error('[resetAllContexts] ERROR RESETTING CONTEXT STORAGE $error');
  }
}

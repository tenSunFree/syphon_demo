import 'package:redux/redux.dart';
import 'package:redux_thunk/redux_thunk.dart';
import 'package:syphon_demo/domain/index.dart';

class SetLastBackupMillis {
  final String timestamp;

  SetLastBackupMillis({
    required this.timestamp,
  });
}

class SetKeyBackupInterval {
  final Duration duration;

  SetKeyBackupInterval({
    required this.duration,
  });
}

class SetKeyBackupPassword {
  final String password;

  SetKeyBackupPassword({
    required this.password,
  });
}

ThunkAction<AppState> setKeyBackupInterval(Duration duration) {
  return (Store<AppState> store) async {
    store.dispatch(SetKeyBackupInterval(duration: duration));
  };
}

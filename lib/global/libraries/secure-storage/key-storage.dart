import 'package:encrypt/encrypt.dart';
import 'package:syphon_demo/global/libraries/secure-storage/secure-storage.dart';
import 'package:syphon_demo/global/print.dart';

String generateKey() {
  return Key.fromSecureRandom(32).base64;
}

Future<bool> checkKey(String keyId) async {
  try {
    return await SecureStorage().check(key: keyId);
  } catch (error) {
    console.error('[checkKey] $error');
    return false;
  }
}

Future<void> overrideKey(String keyId, {String value = ''}) async {
  try {
    return await SecureStorage().write(key: keyId, value: value);
  } catch (error) {
    console.error('[checkKey] $error');
    return;
  }
}

Future<void> clearKey(String keyId) async {
  try {
    return await SecureStorage().write(key: keyId, value: '');
  } catch (error) {
    console.error('[checkKey] $error');
    return;
  }
}

Future<String> loadKey(String keyId) async {
  String? key;

  // try to read key
  try {
    key = await SecureStorage().read(key: keyId);
  } catch (error) {
    console.error('[loadKey] $error');
  }

  // generate a new one on failure
  if (key == null || key.isEmpty) {
    console.info('[loadKey] generating new key for $keyId');
    key = generateKey();
    await SecureStorage().write(key: keyId, value: key);
  }

  return key;
}

Future deleteKey(String keyId) async {
  // try to read key
  try {
    await SecureStorage().delete(key: keyId);
  } catch (error) {
    console.error('[deleteKey] $error');
  }
}

import 'package:drift/drift.dart';
import 'package:syphon_demo/global/libraries/storage/converters.dart';

///
/// Auths Model (Table)
///
/// Meant to store all of auth state in _cold storage_
///
class Auths extends Table {
  TextColumn get id => text().unique()();
  TextColumn get store => text().map(const MapToJsonConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

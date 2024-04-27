import 'dart:convert';

import 'package:drift/drift.dart';

class MapToJsonConverter extends NullAwareTypeConverter<Map<String, dynamic>?, String> {
  const MapToJsonConverter();

  @override
  Map<String, dynamic>? requireFromSql(String fromDb) {
    return json.decode(fromDb) as Map<String, dynamic>?;
  }

  @override
  String requireToSql(Map<String, dynamic>? value) {
    return json.encode(value);
  }
}

class ListToTextConverter extends TypeConverter<List<String>, String> {
  const ListToTextConverter();

  @override
  List<String> fromSql(String fromDb) {
    return List<String>.from(json.decode(fromDb) ?? const []);
  }

  @override
  String toSql(List<String> value) {
    try {
      return json.encode(value);
    } catch (error) {
      return '[]';
    }
  }
}

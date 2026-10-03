import 'dart:convert';
import 'dart:io';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/support/fixtures/$name.json').readAsStringSync())
        as Map<String, dynamic>;

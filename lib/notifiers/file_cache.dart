import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/shell.dart';
import 'package:process_run/which.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/foldersettings.dart';

class FileCache extends ChangeNotifier {
  static final FileCache _instance = FileCache._internal();

  late Database _fileCache;
  Map<String, List<String>> metadata = {};
  bool hasExiftool = false;

  static const String _files = '''
        create table if not exists files(
          id integer primary key,
          path text not null,
          unique (path) on conflict ignore);
          ''';
  static const String _tags = '''
        create table if not exists tags(
          id integer primary key,
          key text not null,
          value text not null,
          unique (name) on conflict ignore);
          ''';
  static const String _filetags = '''
        create table if not exists file_tags(
          fileId integer not null, 
          tagId integer not null, 
          foreign key(fileId) references files(id),
          foreign key(tagId) references tags(id));
          ''';
  static const String _settings = '''
        create table if not exists files(
          id integer primary key,
          path text not null,
          width int not null,
          unique (path) on conflict ignore);
          ''';
  static const String _indexFiles = 'create index files_idx on files(path);';
  static const String _indexSettings = 'create index settings_idx on settings(path);';

  factory FileCache() {
    return _instance;
  }

  FileCache._internal() {
    _openDatabase();
    _checkDependencies();
  }

  void _checkDependencies() async {
    hasExiftool = whichSync('exiftool') != null ? true : false;
  }

  void _createTables(Database db, int oldVersion, int newVersion) {
    _enableForeignKeys(db);
    if (oldVersion < 1) {
      db.execute(_files);
      db.execute(_tags);
      db.execute(_filetags);
      db.execute(_settings);

      db.execute(_indexFiles);
      db.execute(_indexSettings);
    }
    return;
  }

  Future _enableForeignKeys(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<String> _getDatabasePath() async {
    String database = "";
    if (!kIsWeb) {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      database = documentsDirectory.path;
    }
    database += '/db/fscache.db';

    return database;
  }

  void _openDatabase() async {
    sqfliteFfiInit();

    _fileCache = await databaseFactoryFfi.openDatabase(await _getDatabasePath(),
        options: OpenDatabaseOptions(
            version: 1,
            onConfigure: (db) {
              _enableForeignKeys(db);
            },
            onCreate: (db, version) {
              _createTables(db, 0, version);
            },
            onOpen: (db) {

            },
            onUpgrade: (db, oldVersion, newVersion) {
              _createTables(db, oldVersion, newVersion);
            }));
  }

  Future<void> loadMetadata(FileSystemEntity entity) async {
    if (!metadata.containsKey(entity.path)) {
      ProcessResult output = await runExecutableArguments('exiftool', ['-s', '-s', '-s', '-subject', entity.path]);
      metadata[entity.path] = output.stdout.split(',');

      notifyListeners();
    }
  }

  void saveFolderSettings(FolderSettings settings) {
    _fileCache.insert('settings', settings.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
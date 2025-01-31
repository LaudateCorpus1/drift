@Tags(['analyzer'])
import 'package:build/build.dart';
import 'package:drift_dev/src/analyzer/runner/file_graph.dart';
import 'package:drift_dev/src/analyzer/runner/results.dart';
import 'package:drift_dev/src/analyzer/session.dart';
import 'package:test/test.dart';

import '../utils/test_backend.dart';

void main() {
  late TestBackend backend;
  late MoorSession session;

  setUpAll(() {
    backend = TestBackend({
      AssetId.parse('test_lib|lib/entry.dart'): r'''
import 'package:drift/drift.dart';

class Foos extends Table {
  IntColumn get id => integer().autoIncrement()();
}

@DriftDatabase(include: {'db.moor'}, tables: [Foos])
class Database {}
     ''',
      AssetId.parse('test_lib|lib/db.moor'): r'''
import 'entry.dart';

CREATE TABLE bars (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
);
      ''',
    });
    session = MoorSession(backend);
  });

  tearDownAll(() {
    backend.finish();
  });

  test('handles cyclic imports', () async {
    final backendTask =
        backend.startTask(Uri.parse('package:test_lib/entry.dart'));
    final task = session.startTask(backendTask);
    await task.runTask();

    final file = session.registerFile(Uri.parse('package:test_lib/entry.dart'));

    expect(file.state, FileState.analyzed);
    expect(file.errors.errors, isEmpty);

    final result = file.currentResult as ParsedDartFile;
    final database = result.declaredDatabases.single;

    expect(
        database.tables.map((t) => t.sqlName), containsAll(['foos', 'bars']));
  });
}

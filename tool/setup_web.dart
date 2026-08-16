// Regenerates the web/ assets that `sqflite_common_ffi_web` needs at
// runtime: the shared-worker JS bundle and the sqlite3 WASM binary.
//
// Why this exists instead of just running
// `dart run sqflite_common_ffi_web:setup`: that command downloads a
// *hardcoded* sqlite3.wasm release — it doesn't look at what version of
// the `sqlite3` package pub actually resolved for this project. When the
// two drift apart, the worker fails to open the database and silently
// replies `null`, with no error surfaced anywhere (see git history on
// `lib/main.dart` around the web sqflite setup for how that manifested).
//
// This script re-derives the wasm version from pubspec.lock every time,
// so it can't go stale the way a hand-picked binary can. Run it after
// any `pub upgrade`/`pub get` that changes the resolved `sqlite3`
// version, or whenever web/sqlite3.wasm and web/sqflite_sw.js are
// missing (they're gitignored — generated, not checked in).
//
//   dart run tool/setup_web.dart
//
// Running the test suite against this target: use `flutter test -d chrome`,
// not `flutter test --platform chrome`. The latter is deprecated and hangs
// forever on Windows (CanvasKit 404s from its dev server, upstream bug —
// see `.superpowers/todo.md` item 51 for the full trace and confirmation).
import 'dart:io';
import 'dart:typed_data';

Future<void> main() async {
  final lockFile = File('pubspec.lock');
  if (!lockFile.existsSync()) {
    stderr.writeln('pubspec.lock not found — run `flutter pub get` first.');
    exit(1);
  }

  final version = _resolvedSqlite3Version(lockFile.readAsStringSync());
  if (version == null) {
    stderr.writeln(
      'Could not find a resolved `sqlite3` version in pubspec.lock.',
    );
    exit(1);
  }
  stdout.writeln('Resolved sqlite3 package version: $version');

  stdout.writeln('Running `dart run sqflite_common_ffi_web:setup`...');
  final setupResult = await Process.run('dart', [
    'run',
    'sqflite_common_ffi_web:setup',
    '--force',
  ]);
  stdout.write(setupResult.stdout);
  stderr.write(setupResult.stderr);
  if (setupResult.exitCode != 0) {
    stderr.writeln('sqflite_common_ffi_web:setup failed.');
    exit(setupResult.exitCode);
  }

  final wasmUri = Uri.parse(
    'https://github.com/simolus3/sqlite3.dart/releases/download/'
    'sqlite3-$version/sqlite3.wasm',
  );
  stdout.writeln('Fetching version-matched binary from $wasmUri ...');
  final client = HttpClient();
  try {
    final request = await client.getUrl(wasmUri);
    final response = await request.close();
    if (response.statusCode != 200) {
      stderr.writeln(
        'Failed to download sqlite3.wasm for sqlite3 $version '
        '(HTTP ${response.statusCode}). Check '
        'https://github.com/simolus3/sqlite3.dart/releases for a matching '
        'tag — it may not exist for every sqlite3 package version.',
      );
      exit(1);
    }
    final bytes = await response.fold<BytesBuilder>(
      BytesBuilder(),
      (b, d) => b..add(d),
    );
    File('web/sqlite3.wasm').writeAsBytesSync(bytes.takeBytes());
  } finally {
    client.close();
  }

  stdout.writeln('web/sqlite3.wasm and web/sqflite_sw.js are up to date.');
}

/// Pulls the `version:` line out of the `sqlite3:` package block in a
/// `pubspec.lock` file's YAML. Deliberately avoids a real YAML parser —
/// this is a narrow, stable pattern and it keeps this script dependency
/// free.
String? _resolvedSqlite3Version(String lockFileContents) {
  final match = RegExp(
    r'^  sqlite3:\n(?:.*\n)*?    version: "([^"]+)"',
    multiLine: true,
  ).firstMatch(lockFileContents);
  return match?.group(1);
}

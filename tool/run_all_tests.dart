// Runs the same four checks CI runs: `flutter analyze`, the Python import
// harness, the Dart suite, and the integration suite. `flutter test` alone
// is NOT the suite: it does not run integration_test/ (those need a
// device), and CI additionally gates on `flutter analyze`. Before this
// script existed there was no single command meaning "everything CI checks"
// -- see .superpowers/todo.md item 6.
//
// The order below is deliberately NOT CI's order. CI's `tests` job runs the
// Python step, then `flutter analyze`, then `flutter test` -- an artifact of
// installing Python tooling before Flutter tooling in that job -- and runs
// integration as a separate job entirely. This script runs Analyze first:
// CI fails fast, so its order decides which failure masks the others, but
// this script runs every step regardless of earlier failures, so order only
// affects when output appears, never what gets reported. Analyze takes ~3s
// and catches lint before a five-minute integration build, so it goes first
// here.
//
// Every step runs even after one fails, then the summary prints. Stopping at
// the first failure would hide exactly the question this script exists to
// answer: which suites actually ran?
import 'dart:io';

/// One command, with a human-readable label for the summary table.
class _Step {
  final String label;
  final String executable;
  final List<String> arguments;

  const _Step(this.label, this.executable, this.arguments);
}

/// The integration suite needs a real device, and the device name is
/// platform-specific. `windows` is the only configuration this suite has ever
/// run in; Linux desktop support exists in the repo but has never been
/// exercised (see the comment on the `integration` job in tests.yml).
String _integrationDevice() {
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  throw UnsupportedError(
    'No integration device known for ${Platform.operatingSystem}. Add one '
    'here, and expect to exercise it on a branch before trusting it.',
  );
}

List<_Step> _steps() => [
      // CI fails the build on any analyzer error OR warning, so a runner that
      // skipped this could go green where CI would not.
      const _Step('Analyze', 'flutter', ['analyze']),
      // `uv run --no-project` is this machine's convention for a repo with no
      // pyproject.toml. CI uses bare `python` under actions/setup-python; the
      // unittest arguments are identical to CI's on purpose.
      const _Step('Import harness (Python)', 'uv', [
        'run',
        '--no-project',
        'python',
        '-m',
        'unittest',
        'discover',
        '-s',
        'scripts/spell_import/tests',
        '-t',
        '.',
      ]),
      const _Step('Dart suite', 'flutter', ['test']),
      _Step('Integration suite', 'flutter', [
        'test',
        'integration_test',
        '-d',
        _integrationDevice(),
      ]),
    ];

Future<void> main() async {
  final results = <String, bool>{};

  for (final step in _steps()) {
    stdout.writeln('');
    stdout.writeln('=== ${step.label} ===');
    stdout.writeln('\$ ${step.executable} ${step.arguments.join(' ')}');

    int exitCode;
    try {
      final process = await Process.start(
        step.executable,
        step.arguments,
        mode: ProcessStartMode.inheritStdio,
        runInShell: true,
      );
      exitCode = await process.exitCode;
    } on ProcessException catch (error) {
      // runInShell: true is required -- `flutter` is a .bat on Windows and
      // can't be exec'd directly -- which means a missing executable does
      // NOT throw here: the shell starts fine, prints its own "not
      // recognized" message via inherited stdio, and exits non-zero, which
      // is reported as an ordinary FAIL below. This catch is cheap insurance
      // for the cases where Process.start genuinely fails to start the
      // process at all.
      stdout.writeln('Could not run ${step.executable}: ${error.message}');
      exitCode = 127;
    }

    results[step.label] = exitCode == 0;
  }

  stdout.writeln('');
  stdout.writeln('=== Summary ===');
  results.forEach((label, passed) {
    stdout.writeln('${passed ? 'PASS' : 'FAIL'}  $label');
  });

  final failed = results.values.where((passed) => !passed).length;
  if (failed > 0) {
    stdout.writeln('');
    stdout.writeln('$failed of ${results.length} steps failed.');
    exit(1);
  }
  stdout.writeln('');
  stdout.writeln('All ${results.length} steps passed.');
}

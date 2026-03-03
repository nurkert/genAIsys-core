import 'dart:io';

/// Runs a `dart` command while holding an inter-process file lock.
///
/// Why?
/// - On macOS, `dart run` may bundle/codesign native assets into `.dart_tool/`.
/// - The Flutter/Dart test runner can execute multiple test files in parallel
///   isolates, which means multiple `dart run` processes can contend on the
///   same output files and intermittently fail (codesign / native assets).
/// - Serializing `dart` invocations keeps the suite deterministic.
ProcessResult runLockedDartSync(
  List<String> arguments, {
  required String workingDirectory,
  Map<String, String>? environment,
}) {
  final lockPath =
      '${Directory.systemTemp.path}${Platform.pathSeparator}genaisys_dart_run.lock';
  final lockFile = File(lockPath);
  lockFile.parent.createSync(recursive: true);

  final raf = lockFile.openSync(mode: FileMode.write);
  try {
    _lockExclusiveWithRetry(raf);
    return Process.runSync(
      'dart',
      arguments,
      workingDirectory: workingDirectory,
      runInShell: false,
      environment: environment,
    );
  } finally {
    try {
      raf.unlockSync();
    } catch (_) {}
    try {
      raf.closeSync();
    } catch (_) {}
  }
}

void _lockExclusiveWithRetry(
  RandomAccessFile raf, {
  Duration timeout = const Duration(minutes: 2),
}) {
  final deadline = DateTime.now().add(timeout);
  var delayMs = 10;

  while (true) {
    try {
      raf.lockSync(FileLock.exclusive);
      return;
    } on FileSystemException catch (e) {
      final code = e.osError?.errorCode;
      // macOS: EAGAIN(35), Linux: EAGAIN(11) when the lock is busy.
      final isBusy = code == 35 || code == 11;
      if (!isBusy) {
        rethrow;
      }

      if (DateTime.now().isAfter(deadline)) {
        throw FileSystemException(
          'Timed out waiting for dart-run lock.',
          raf.path,
          e.osError,
        );
      }

      sleep(Duration(milliseconds: delayMs));
      if (delayMs < 200) {
        delayMs = delayMs * 2;
        if (delayMs > 200) {
          delayMs = 200;
        }
      }
    }
  }
}

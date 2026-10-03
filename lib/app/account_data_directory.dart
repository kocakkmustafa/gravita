import 'dart:io';

import 'course_progress_io.dart';

final RegExp _canonicalAccountUuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Keeps user-owned data separate from the pre-account local files and from
/// every other Motion identity. Legacy data is not silently claimed by the
/// first person who signs in.
Directory accountDataDirectory(Directory root, String? accountUserId) {
  if (accountUserId == null) return root;
  final valid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  if (!valid.hasMatch(accountUserId)) {
    throw ArgumentError.value(accountUserId, 'accountUserId', 'Expected UUID');
  }
  return Directory('${root.path}/accounts/${accountUserId.toLowerCase()}');
}

/// Lists only canonical account directories created by this app. Links and
/// unrelated files are never offered to the shared deletion-receipt check.
Future<List<String>> localAccountIds(Directory root) async {
  final accounts = Directory('${root.path}/accounts');
  if (await FileSystemEntity.type(accounts.path, followLinks: false) !=
      FileSystemEntityType.directory) {
    return <String>[];
  }
  final ids = <String>[];
  await for (final entry in accounts.list(followLinks: false)) {
    if (entry is! Directory) continue;
    final name = entry.path.substring(accounts.path.length + 1);
    if (_canonicalAccountUuid.hasMatch(name)) ids.add(name);
  }
  return ids..sort();
}

/// Called after verified common-account deletion with an ID captured before
/// remote sign-out. Sign-out/switch retire store admission but preserve files.
Future<void> deleteAccountData(Directory root, String accountUserId) async {
  final directory = accountDataDirectory(root, accountUserId);
  Future<void> checkBoundary() async {
    for (final path in ['${root.path}/accounts', directory.path]) {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type != FileSystemEntityType.directory &&
          type != FileSystemEntityType.notFound) {
        throw FileSystemException(
          'Account deletion requires a directory',
          path,
        );
      }
    }
  }

  // The verified receipt closes admission before the first filesystem await.
  final drain = invalidateCourseProgressDirectory(directory);
  await checkBoundary();
  await drain;
  // An outstanding writer may have yielded while the boundary changed.
  await checkBoundary();
  if (await directory.exists()) await directory.delete(recursive: true);
}

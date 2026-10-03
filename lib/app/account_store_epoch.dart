import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:motion_core/motion_core.dart' show SessionStoreWriteLease;

final RegExp _accountUuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

String? _normalizedUserId(String? userId) {
  if (userId == null) return null;
  if (!_accountUuid.hasMatch(userId)) {
    throw ArgumentError.value(userId, 'accountUserId', 'Expected UUID');
  }
  return userId.toLowerCase();
}

String normalizedAccountStorePath(String path) =>
    Uri.file(File(path).absolute.path).normalizePath().toFilePath();

final class _FileOwner {
  _FileOwner(File file) {
    final path = normalizedAccountStorePath(file.path);
    final parts = path.split('/');
    for (int index = parts.length - 3; index >= 0; index--) {
      if (parts[index] == 'accounts' &&
          _accountUuid.hasMatch(parts[index + 1])) {
        accountUserId = parts[index + 1].toLowerCase();
        directoryPath = parts.take(index + 2).join('/');
        return;
      }
    }
    accountUserId = null;
    directoryPath = normalizedAccountStorePath(file.parent.path);
  }

  late final String? accountUserId;
  late final String directoryPath;
}

/// One verified account (or explicitly admitted guest) lifetime. A fresh
/// lifetime can reuse files, but can never reactivate an old store handle.
final class AccountStoreEpoch {
  AccountStoreEpoch._(this.accountUserId, {Future<void>? readiness})
    : _readiness = readiness {
    if (readiness != null) {
      unawaited(
        readiness.then<void>((_) {
          if (identical(_readiness, readiness)) _readiness = null;
        }),
      );
    }
  }

  final String? accountUserId;
  final SessionStoreWriteLease writeLease = SessionStoreWriteLease();
  Future<void>? _readiness;
  final Set<Future<void>> _pending = <Future<void>>{};
  bool _active = true;
  Future<void>? _retirement;
  bool _retirementSettled = false;

  bool get isActive => _active && writeLease.isActive;

  /// Fresh idle Futures are created in the caller's zone. Only an unfinished
  /// predecessor drain is retained, never its completed Future.
  Future<void> get ready => runHostIo(() async {});

  void checkCurrent() {
    if (!isActive ||
        AccountStoreEpochRegistry.isAccountErasureBlocked(accountUserId)) {
      throw StateError('Local account store lifetime was retired');
    }
  }

  /// Register host IO before invoking its callback, including queued writers.
  /// New same-UUID IO waits for the previous epoch's admitted IO to drain.
  Future<T> runHostIo<T>(Future<T> Function() action) async {
    checkCurrent();
    final settled = Completer<void>();
    _pending.add(settled.future);
    try {
      final readiness = _readiness;
      if (readiness != null) await readiness;
      checkCurrent();
      final result = await action();
      checkCurrent();
      return result;
    } finally {
      _pending.remove(settled.future);
      settled.complete();
    }
  }

  /// Admission closes synchronously; no file is deleted by retirement.
  Future<void> retireAndDrain() {
    _active = false;
    if (_retirementSettled) return Future<void>.value();
    final journalDrain = writeLease.retireAndDrain();
    final readiness = _readiness;
    return _retirement ??=
        Future.wait<void>([
          if (readiness != null) readiness,
          journalDrain,
          ..._pending,
        ]).then<void>((_) {
          _retirementSettled = true;
        });
  }
}

enum _AccountErasureState { pending, failed, erased }

final class _AccountErasureTicket {
  _AccountErasureState state = _AccountErasureState.pending;
  Future<void>? pending;
  Object? error;
}

final class _AccountAdmissionChanges extends ChangeNotifier {
  void changed() => notifyListeners();
}

/// The production bootstrap enables managed admission once, before runtime
/// initialization. Legacy direct-file tests remain scoped to their own path.
/// This coordinates one Dart isolate; it does not resolve symlink aliases.
final class AccountStoreEpochRegistry {
  AccountStoreEpochRegistry._();

  static final _AccountAdmissionChanges _admissionChanges =
      _AccountAdmissionChanges();
  static ChangeNotifier get admissionChanges => _admissionChanges;
  static final Map<String, _AccountErasureTicket> _erasures =
      <String, _AccountErasureTicket>{};
  static int _erasureGeneration = 0;

  static bool isAccountErasureBlocked(String? accountUserId) {
    final userId = _normalizedUserId(accountUserId);
    return userId != null && _erasures.containsKey(userId);
  }

  static bool isAccountErasurePending(String? accountUserId) {
    final userId = _normalizedUserId(accountUserId);
    return userId != null && _erasures[userId]?.pending != null;
  }

  static Object? erasureError(String? accountUserId) {
    final userId = _normalizedUserId(accountUserId);
    return userId == null ? null : _erasures[userId]?.error;
  }

  static void _checkErasureAdmission(String? accountUserId) {
    if (isAccountErasureBlocked(accountUserId)) {
      throw StateError('Confirmed account erasure blocks local admission');
    }
  }

  /// Call only for the UUID verified by Core's server deletion receipt. The
  /// supplied closure captures its own UUID/paths; it must not look up a later
  /// current owner. Admission closes before any directory lookup or await.
  static Future<void> beginConfirmedAccountErasure(
    String accountUserId,
    Future<void> Function() erase,
  ) {
    final userId = _normalizedUserId(accountUserId)!;
    final existing = _erasures[userId];
    final pending = existing?.pending;
    if (pending != null) return pending;
    if (existing?.state == _AccountErasureState.erased) {
      // Do not retain a settled Future from another caller/test zone.
      return Future<void>.value();
    }

    final ticket = existing ?? _AccountErasureTicket();
    final completer = Completer<void>();
    final result = completer.future;
    ticket.state = _AccountErasureState.pending;
    ticket.pending = result;
    ticket.error = null;
    _erasures[userId] = ticket;
    final generation = _erasureGeneration;

    // Include captured opens that have not registered a directory yet, as
    // well as every known journal/course/program/schedule lifetime for A.
    final epochs = <AccountStoreEpoch>{
      ..._epochs,
      ..._unmanagedCaptures.values,
      ..._unmanagedDirectories.values,
      if (_current case final current?) current,
    }.where((epoch) => epoch.accountUserId == userId).toList();
    if (_current?.accountUserId == userId) _current = null;
    _unmanagedCaptures.remove(userId);
    final drains = <Future<void>>[];
    for (final epoch in epochs) {
      final drain = epoch.retireAndDrain();
      drains.add(drain);
      unawaited(drain.then<void>((_) => _forgetDrainedEpoch(epoch)));
    }

    // Publish the shared Future before notifying reentrant shell listeners.
    _admissionChanges.changed();
    unawaited(() async {
      try {
        await Future.wait<void>(drains);
        await erase();
        if (generation == _erasureGeneration &&
            identical(_erasures[userId], ticket)) {
          ticket.pending = null;
          ticket.state = _AccountErasureState.erased;
          _admissionChanges.changed();
        }
        completer.complete();
      } on Object catch (error, stackTrace) {
        if (generation == _erasureGeneration &&
            identical(_erasures[userId], ticket)) {
          ticket.pending = null;
          ticket.state = _AccountErasureState.failed;
          ticket.error = error;
          _admissionChanges.changed();
        }
        completer.completeError(error, stackTrace);
      }
    }());
    return result;
  }

  static bool _managed = false;
  static AccountStoreEpoch? _current;
  static Future<void>? _barrier;
  static final Set<AccountStoreEpoch> _epochs = <AccountStoreEpoch>{};
  static final Map<String?, AccountStoreEpoch> _unmanagedCaptures =
      <String?, AccountStoreEpoch>{};
  static final Map<String, AccountStoreEpoch> _unmanagedDirectories =
      <String, AccountStoreEpoch>{};
  static final Map<String, Set<AccountStoreEpoch>> _directoryEpochs =
      <String, Set<AccountStoreEpoch>>{};

  static AccountStoreEpoch _newEpoch(
    String? accountUserId, {
    Future<void>? readiness,
  }) {
    final epoch = AccountStoreEpoch._(accountUserId, readiness: readiness);
    _epochs.add(epoch);
    return epoch;
  }

  static Future<void> enableManagedAdmission() {
    _managed = true;
    return retireAll();
  }

  /// Capture before the first async directory lookup. Recheck the same object
  /// afterward, so an old A lookup cannot acquire a later fresh A lifetime.
  static AccountStoreEpoch capture(String? accountUserId) {
    final userId = _normalizedUserId(accountUserId);
    _checkErasureAdmission(userId);
    if (_managed) {
      final epoch = _current;
      if (epoch == null || epoch.accountUserId != userId) {
        throw StateError('Local account store admission is closed');
      }
      epoch.checkCurrent();
      return epoch;
    }
    return _unmanagedCaptures.putIfAbsent(userId, () => _newEpoch(userId));
  }

  /// Caller supplies the currently authoritative verified identity. Null is
  /// an explicit guest activation, not a fallback from a closed account gate.
  static AccountStoreEpoch activate(String? accountUserId) {
    final userId = _normalizedUserId(accountUserId);
    _checkErasureAdmission(userId);
    if (!_managed) {
      throw StateError('Enable managed account admission before activation');
    }
    retireAll();
    final epoch = _newEpoch(userId, readiness: _barrier);
    _current = epoch;
    return epoch;
  }

  static Future<void> _combineDrains(Iterable<Future<void>> drains) {
    final previous = _barrier;
    late final Future<void> combined;
    combined = Future.wait<void>([if (previous != null) previous, ...drains])
        .then<void>((_) {
          if (identical(_barrier, combined)) _barrier = null;
        });
    _barrier = combined;
    return combined;
  }

  /// Used synchronously on logout, identity change, closed phase or recovery.
  /// Retiring is independent of any verified deletion receipt.
  static Future<void> retireAll() {
    _current = null;
    final epochs = _epochs.toList();
    final drains = <Future<void>>[];
    for (final epoch in epochs) {
      final drain = epoch.retireAndDrain();
      drains.add(drain);
      unawaited(
        drain.then<void>((_) {
          _forgetDrainedEpoch(epoch);
        }),
      );
    }
    _unmanagedCaptures.clear();
    return _combineDrains(drains);
  }

  static void _forgetDrainedEpoch(AccountStoreEpoch epoch) {
    _epochs.remove(epoch);
    final empty = <String>[];
    for (final entry in _directoryEpochs.entries) {
      entry.value.remove(epoch);
      if (entry.value.isEmpty) empty.add(entry.key);
    }
    for (final path in empty) {
      _directoryEpochs.remove(path);
    }
  }

  /// Bind direct-file handles and captured async opens to their account scope.
  /// In unmanaged tests the directory selects the shared epoch; in production
  /// every file must belong to the captured, still-current managed owner.
  static AccountStoreEpoch forFile(File file, {AccountStoreEpoch? captured}) {
    final owner = _FileOwner(file);
    _checkErasureAdmission(owner.accountUserId);
    captured?.checkCurrent();
    if (captured != null && captured.accountUserId != owner.accountUserId) {
      throw StateError('Account store path does not match captured identity');
    }
    final AccountStoreEpoch epoch;
    if (_managed) {
      epoch = captured ?? capture(owner.accountUserId);
      if (!identical(epoch, _current)) {
        throw StateError('Local account store lifetime was superseded');
      }
    } else {
      epoch = _unmanagedDirectories.putIfAbsent(
        owner.directoryPath,
        () => _newEpoch(owner.accountUserId),
      );
    }
    epoch.checkCurrent();
    _directoryEpochs
        .putIfAbsent(owner.directoryPath, () => <AccountStoreEpoch>{})
        .add(epoch);
    return epoch;
  }

  /// A confirmed deletion also retires an admitted owner whose async file
  /// lookup has not registered a directory yet. Other owners remain active.
  static Future<void> retireDirectory(Directory directory) {
    final path = normalizedAccountStorePath(directory.path);
    final owner = _FileOwner(File('$path/.account-epoch'));
    final epochs = <AccountStoreEpoch>{...?_directoryEpochs[path]};
    final current = _current;
    if (_managed &&
        current != null &&
        current.accountUserId == owner.accountUserId) {
      epochs.add(current);
      _current = null;
    }
    final drains = <Future<void>>[];
    for (final epoch in epochs) {
      final drain = epoch.retireAndDrain();
      drains.add(drain);
      unawaited(
        drain.then<void>((_) {
          _forgetDrainedEpoch(epoch);
        }),
      );
    }
    return _combineDrains(drains);
  }

  /// Tests must await the returned drain. Retained old handles stay retired;
  /// permanent directory deletion fences belong to course_progress_io.dart.
  static Future<void> resetForTest() {
    final erasures = <Future<void>>[
      for (final ticket in _erasures.values)
        if (ticket.pending case final pending?)
          pending.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
    ];
    final drain = retireAll();
    _managed = false;
    _unmanagedCaptures.clear();
    _unmanagedDirectories.clear();
    _directoryEpochs.clear();
    _erasureGeneration++;
    if (_erasures.isNotEmpty) {
      _erasures.clear();
      _admissionChanges.changed();
    }
    return Future.wait<void>([drain, ...erasures]).then<void>((_) {});
  }
}

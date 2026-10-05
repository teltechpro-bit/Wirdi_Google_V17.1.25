import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// One juz' claimed by a member of a group khatma.
class JuzClaim {
  final int juz;
  final String uid;
  final String name;
  final bool done;
  const JuzClaim({required this.juz, required this.uid, required this.name, required this.done});
}

/// A group (family / friends) khatma: 30 juz' that members claim and tick off.
class FamilyKhatma {
  final String code;
  final String name;
  final String ownerUid;
  final int rounds;
  final Map<String, String> members; // uid -> display name
  final Map<int, JuzClaim> claims;

  const FamilyKhatma({
    required this.code,
    required this.name,
    required this.ownerUid,
    required this.rounds,
    required this.members,
    required this.claims,
  });

  int get doneCount => claims.values.where((c) => c.done).length;

  factory FamilyKhatma.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final members = <String, String>{};
    final rawMembers = data['members'];
    if (rawMembers is Map) {
      rawMembers.forEach((k, v) => members[k.toString()] = v.toString());
    }
    final claims = <int, JuzClaim>{};
    final rawClaims = data['claims'];
    if (rawClaims is Map) {
      rawClaims.forEach((k, v) {
        final juz = int.tryParse(k.toString());
        if (juz == null || v is! Map) return;
        claims[juz] = JuzClaim(
          juz: juz,
          uid: (v['uid'] ?? '').toString(),
          name: (v['name'] ?? '').toString(),
          done: v['done'] == true,
        );
      });
    }
    return FamilyKhatma(
      code: doc.id,
      name: (data['name'] ?? '').toString(),
      ownerUid: (data['ownerUid'] ?? '').toString(),
      rounds: (data['rounds'] is int) ? data['rounds'] as int : 1,
      members: members,
      claims: claims,
    );
  }
}

class FamilyKhatmaException implements Exception {
  /// One of: notSignedIn, notFound, taken, notOwner, permission, failed
  final String kind;
  const FamilyKhatmaException(this.kind);
  @override
  String toString() => 'FamilyKhatmaException($kind)';
}

/// Firestore-backed group khatma. Collection: `family_khatmas/{code}`.
/// Security rules for it are documented in FIREBASE_SETUP.md and must be
/// published in the Firebase console for this feature to work.
class FamilyKhatmaService {
  FamilyKhatmaService._();
  static final FamilyKhatmaService instance = FamilyKhatmaService._();

  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('family_khatmas');

  User? get _user {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isSignedIn => _user != null;
  String? get uid => _user?.uid;

  String get _displayName {
    final u = _user;
    final dn = u?.displayName;
    if (dn != null && dn.trim().isNotEmpty) return dn.trim();
    final email = u?.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Member';
  }

  User _requireUser() {
    final u = _user;
    if (u == null) throw const FamilyKhatmaException('notSignedIn');
    return u;
  }

  Never _rethrow(Object e) {
    if (e is FamilyKhatmaException) throw e;
    if (e is FirebaseException && e.code == 'permission-denied') {
      throw const FamilyKhatmaException('permission');
    }
    throw const FamilyKhatmaException('failed');
  }

  String _newCode() {
    final rnd = Random.secure();
    return String.fromCharCodes(
      List<int>.generate(6, (_) => _alphabet.codeUnitAt(rnd.nextInt(_alphabet.length))),
    );
  }

  Stream<List<FamilyKhatma>> myGroups() {
    final user = _requireUser();
    return _col
        .where('memberUids', arrayContains: user.uid)
        .snapshots()
        .map((snap) => snap.docs.map(FamilyKhatma.fromDoc).toList());
  }

  Stream<FamilyKhatma?> watch(String code) {
    return _col.doc(code).snapshots().map((doc) => doc.exists ? FamilyKhatma.fromDoc(doc) : null);
  }

  Future<String> create(String name) async {
    final user = _requireUser();
    try {
      for (var attempt = 0; attempt < 5; attempt++) {
        final code = _newCode();
        final ref = _col.doc(code);
        final existing = await ref.get();
        if (existing.exists) continue;
        await ref.set(<String, dynamic>{
          'name': name.trim(),
          'ownerUid': user.uid,
          'memberUids': <String>[user.uid],
          'members': <String, String>{user.uid: _displayName},
          'claims': <String, dynamic>{},
          'rounds': 1,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return code;
      }
      throw const FamilyKhatmaException('failed');
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<void> join(String rawCode) async {
    final user = _requireUser();
    final code = rawCode.trim().toUpperCase();
    try {
      final ref = _col.doc(code);
      final doc = await ref.get();
      if (!doc.exists) throw const FamilyKhatmaException('notFound');
      await ref.update(<String, dynamic>{
        'memberUids': FieldValue.arrayUnion(<String>[user.uid]),
        'members.${user.uid}': _displayName,
      });
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<void> claim(String code, int juz) async {
    final user = _requireUser();
    final ref = _col.doc(code);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data() ?? <String, dynamic>{};
        final claims = data['claims'];
        if (claims is Map) {
          final existing = claims['$juz'];
          if (existing is Map && existing['uid'] != user.uid) {
            throw const FamilyKhatmaException('taken');
          }
        }
        tx.update(ref, <String, dynamic>{
          'claims.$juz': <String, dynamic>{'uid': user.uid, 'name': _displayName, 'done': false},
        });
      });
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<void> release(String code, int juz) async {
    final user = _requireUser();
    final ref = _col.doc(code);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final claims = (snap.data() ?? <String, dynamic>{})['claims'];
        if (claims is Map) {
          final existing = claims['$juz'];
          if (existing is Map && existing['uid'] == user.uid) {
            tx.update(ref, <String, dynamic>{'claims.$juz': FieldValue.delete()});
          }
        }
      });
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<void> setDone(String code, int juz, bool done) async {
    final user = _requireUser();
    final ref = _col.doc(code);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final claims = (snap.data() ?? <String, dynamic>{})['claims'];
        if (claims is Map) {
          final existing = claims['$juz'];
          if (existing is Map && existing['uid'] == user.uid) {
            tx.update(ref, <String, dynamic>{'claims.$juz.done': done});
          }
        }
      });
    } catch (e) {
      _rethrow(e);
    }
  }

  /// Owner only: clears all claims and starts the next round.
  Future<void> startNewRound(String code) async {
    final user = _requireUser();
    final ref = _col.doc(code);
    try {
      final snap = await ref.get();
      if ((snap.data() ?? <String, dynamic>{})['ownerUid'] != user.uid) {
        throw const FamilyKhatmaException('notOwner');
      }
      await ref.update(<String, dynamic>{
        'claims': <String, dynamic>{},
        'rounds': FieldValue.increment(1),
      });
    } catch (e) {
      _rethrow(e);
    }
  }

  /// Leaves the group (un-finished claims of this member are released first).
  /// If the owner leaves and nobody else is left, the group is deleted.
  Future<void> leave(String code) async {
    final user = _requireUser();
    final ref = _col.doc(code);
    try {
      final snap = await ref.get();
      final data = snap.data() ?? <String, dynamic>{};
      final claims = data['claims'];
      final updates = <String, dynamic>{};
      if (claims is Map) {
        claims.forEach((k, v) {
          if (v is Map && v['uid'] == user.uid && v['done'] != true) {
            updates['claims.$k'] = FieldValue.delete();
          }
        });
      }
      final memberUids = (data['memberUids'] is List) ? List<String>.from(data['memberUids'] as List) : <String>[];
      final remaining = memberUids.where((m) => m != user.uid).toList();
      if (remaining.isEmpty && data['ownerUid'] == user.uid) {
        await ref.delete();
        return;
      }
      if (updates.isNotEmpty) {
        // Claims first (rule: members may edit only claims/rounds in one write).
        await ref.update(updates);
      }
      await ref.update(<String, dynamic>{
        'memberUids': FieldValue.arrayRemove(<String>[user.uid]),
        'members.${user.uid}': FieldValue.delete(),
      });
    } catch (e) {
      _rethrow(e);
    }
  }
}

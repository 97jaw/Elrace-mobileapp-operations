import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_actions/data/stamp_authorized_emp_ids.dart';
import 'package:el_race/ui/presentation/my_actions/data/user_stamp_assets.dart';
import 'package:el_race/ui/presentation/todo_list/services/team_members_api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/models.dart';

/// Repository for user-related Firestore operations.
///
/// Handles:
/// - User profile upsert
/// - User search with keyword-based prefix matching
/// - FCM token management
class UserRepository {
  static UserRepository? _instance;
  static UserRepository get instance => _instance ??= UserRepository._();

  UserRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// In-memory user cache to avoid repeated Firestore reads
  final Map<String, ChatUser> _userCache = {};

  /// Cache expiry tracking (5 minutes)
  final Map<String, DateTime> _cacheTimestamps = {};
  static const _cacheDuration = Duration(minutes: 5);

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Upsert user profile in Firestore.
  /// Creates the document if it doesn't exist, updates if it does.
  Future<void> upsertUser(ChatUserSession session) async {
    final docRef = _usersCollection.doc(session.firebaseUid);
    final keywords = ChatUser.buildSearchKeywords(session.name, session.email);

    final data = <String, dynamic>{
      'odoo_user_id': session.odooUserId,
      'employee_id': session.employeeId,
      'name': session.name,
      'role_name': session.roleName,
      'role_id': session.roleId,
      'branch_id': session.branchId,
      'company_id': session.companyId,
      'last_login_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'search_keywords': keywords,
    };

    final safeAvatar = _normalizeNullableString(session.avatarUrl);
    if (safeAvatar != null) {
      data['avatar_url'] = safeAvatar;
    }

    final safeEmail = _normalizeNullableString(session.email);
    final safePhone = _normalizeNullableString(session.phoneNumber);
    final safeJobTitle = _normalizeNullableString(session.jobTitle);

    if (safeEmail != null) {
      data['email'] = safeEmail;
      data['work_email'] = safeEmail;
    }
    if (safePhone != null) {
      data['phone'] = safePhone;
      data['mobile_phone'] = safePhone;
    }
    if (safeJobTitle != null) {
      data['job_title'] = safeJobTitle;
    }

    // Stamp flag: promote to true when login/session says so. Never clobber an
    // existing true with false just because login omitted the field.
    final loginStamp = SharedPref.getLoginData().result?.data?.xStampUser;
    final stampNow = session.xStampUser ||
        loginStamp == true ||
        UserStampAssets.isStampUser;
    if (stampNow) {
      data['x_stamp_user'] = true;
    } else if (loginStamp == false) {
      data['x_stamp_user'] = false;
    }

    try {
      final doc = await docRef.get();
      if (doc.exists) {
        final existing = doc.data() ?? <String, dynamic>{};

        // Never overwrite existing non-empty contact fields with null/empty values.
        if (!data.containsKey('email')) {
          final existingEmail = _normalizeNullableString(
            existing['email']?.toString() ?? existing['work_email']?.toString(),
          );
          if (existingEmail != null) {
            data['email'] = existingEmail;
            data['work_email'] = existingEmail;
          }
        }

        if (!data.containsKey('phone')) {
          final existingPhone = _normalizeNullableString(
            existing['phone']?.toString() ??
                existing['mobile_phone']?.toString() ??
                existing['mobile']?.toString(),
          );
          if (existingPhone != null) {
            data['phone'] = existingPhone;
            data['mobile_phone'] = existingPhone;
          }
        }

        if (!data.containsKey('job_title')) {
          final existingJob = _normalizeNullableString(
            existing['job_title']?.toString() ??
                existing['job_position']?.toString() ??
                existing['designation']?.toString(),
          );
          if (existingJob != null) {
            data['job_title'] = existingJob;
          }
        }

        // Preserve existing avatar when session has none
        if (!data.containsKey('avatar_url')) {
          final existingAvatar =
              _normalizeNullableString(existing['avatar_url']?.toString());
          if (existingAvatar != null) {
            data['avatar_url'] = existingAvatar;
          }
        }

        await docRef.update(data);
        print('✅ UserRepository: Updated user ${session.firebaseUid}');
      } else {
        data['created_at'] = FieldValue.serverTimestamp();
        await docRef.set(data);
        print('✅ UserRepository: Created user ${session.firebaseUid}');
      }

      invalidateUserCache(session.firebaseUid);
      // Best-effort: keep peer DM list titles in sync with corrected person name.
      // ignore: unawaited_futures
      _healDmTitlesForUser(session.firebaseUid, session.name);
    } catch (e) {
      print('❌ UserRepository: Error upserting user: $e');
      rethrow;
    }
  }

  /// Drop cached profile so next [getUser] hits Firestore.
  void invalidateUserCache([String? uid]) {
    if (uid == null) {
      _userCache.clear();
      _cacheTimestamps.clear();
      return;
    }
    _userCache.remove(uid);
    _cacheTimestamps.remove(uid);
  }

  /// Update peers' `userChats` titles that point at [uid] so list/header
  /// snapshots show the corrected person name.
  Future<void> _healDmTitlesForUser(String uid, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    try {
      final ownChats = await _firestore
          .collection('userChats')
          .doc(uid)
          .collection('chats')
          .where('type', isEqualTo: 'dm')
          .get();
      for (final doc in ownChats.docs) {
        final peerUid = doc.data()['peer_uid']?.toString();
        if (peerUid == null || peerUid.isEmpty) continue;
        try {
          await _firestore
              .collection('userChats')
              .doc(peerUid)
              .collection('chats')
              .doc(doc.id)
              .set(
            {
              'title': trimmed,
              'peer_uid': uid,
              'type': 'dm',
            },
            SetOptions(merge: true),
          );
        } catch (e) {
          print('⚠️ UserRepository: heal DM title for $peerUid/$uid: $e');
        }
      }
    } catch (e) {
      print('⚠️ UserRepository: heal DM titles failed: $e');
    }
  }

  /// Resolve peer profile for UI: live Firestore + directory fallback for
  /// missing avatar / empty name.
  Future<ChatUser?> getUserWithDirectoryFallback(
    String uid, {
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) invalidateUserCache(uid);
    final user = await getUser(uid);
    if (user == null) return null;

    final needsAvatar = _normalizeNullableString(user.avatarUrl) == null;
    final nameLooksLikeTitle = user.name.trim().isNotEmpty &&
        ((user.roleName != null &&
                user.name.trim().toLowerCase() ==
                    user.roleName!.trim().toLowerCase()) ||
            (user.jobTitle != null &&
                user.name.trim().toLowerCase() ==
                    user.jobTitle!.trim().toLowerCase()));
    final needsName = user.name.trim().isEmpty || nameLooksLikeTitle;
    if (!needsAvatar && !needsName) return user;

    try {
      final members = await TeamMembersApiService.instance.getTeamMembers();
      final match = _findBestDirectoryMatch(user, members);
      if (match == null) {
        if (needsAvatar && user.employeeId != null && user.employeeId! > 0) {
          final url =
              'https://erp.elrace.com/public/employee/image/${user.employeeId}';
          final enriched = user.copyWith(avatarUrl: url);
          _userCache[uid] = enriched;
          return enriched;
        }
        return user;
      }

      String? avatar = user.avatarUrl;
      if (needsAvatar) {
        avatar = _httpAvatarFromDirectory(match.image) ??
            (match.employeeId != null && match.employeeId! > 0
                ? 'https://erp.elrace.com/public/employee/image/${match.employeeId}'
                : null);
      }
      final resolvedName = match.name.trim().isNotEmpty ? match.name.trim() : null;

      final enriched = user.copyWith(
        name: needsName ? resolvedName : null,
        avatarUrl: avatar,
      );
      _userCache[uid] = enriched;
      _cacheTimestamps[uid] = DateTime.now();
      return enriched;
    } catch (e) {
      print('⚠️ UserRepository: directory fallback failed for $uid: $e');
      return user;
    }
  }

  String? _httpAvatarFromDirectory(String? raw) {
    final text = _normalizeNullableString(raw);
    if (text == null) return null;
    if (text.startsWith('data:')) return null;
    if (text.startsWith('http://') || text.startsWith('https://')) return text;
    if (text.startsWith('/')) return 'https://erp.elrace.com$text';
    if (text.length > 500) return null;
    return null;
  }

  String? _normalizeNullableString(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    final lower = text.toLowerCase();
    if (lower == 'null' || lower == 'false' || lower == 'n/a' || lower == '-') {
      return null;
    }
    return text;
  }

  /// Get a user by UID (cached)
  Future<ChatUser?> getUser(String uid) async {
    // Check cache first
    final cached = _userCache[uid];
    final cachedAt = _cacheTimestamps[uid];
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheDuration) {
      return cached;
    }

    try {
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) return null;
      final user = ChatUser.fromFirestore(doc);
      _userCache[uid] = user;
      _cacheTimestamps[uid] = DateTime.now();
      return user;
    } catch (e) {
      print('❌ UserRepository: Error getting user: $e');
      return cached; // Return stale cache on error
    }
  }

  /// Get a user from cache only (sync, no Firestore call)
  ChatUser? getCachedUser(String uid) => _userCache[uid];

  /// Pre-warm user cache for multiple UIDs
  Future<void> prefetchUsers(List<String> uids) async {
    final uncached = uids.where((uid) {
      final cachedAt = _cacheTimestamps[uid];
      return cachedAt == null ||
          DateTime.now().difference(cachedAt) >= _cacheDuration;
    }).toList();
    if (uncached.isEmpty) return;
    final users = await getUsersByIds(uncached);
    for (final user in users) {
      _userCache[user.uid] = user;
      _cacheTimestamps[user.uid] = DateTime.now();
    }
  }

  /// Get user stream by UID
  Stream<ChatUser?> subscribeToUser(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ChatUser.fromFirestore(doc);
    });
  }

  /// Fills missing email/phone/job/avatar fields from employee directory API and
  /// persists the resolved values to Firestore.
  Future<bool> hydrateUserProfileFromEmployeeDirectory(ChatUser user) async {
    final needsEmail = _normalizeNullableString(user.email) == null;
    final needsPhone = _normalizeNullableString(user.phoneNumber) == null;
    final needsJob = _normalizeNullableString(user.jobTitle) == null;
    final needsAvatar = _normalizeNullableString(user.avatarUrl) == null;

    if (!needsEmail && !needsPhone && !needsJob && !needsAvatar) {
      return false;
    }

    try {
      final members = await TeamMembersApiService.instance.getTeamMembers();
      if (members.isEmpty) {
        print('⚠️ UserRepository: employee directory is empty');
        return false;
      }

      final match = _findBestDirectoryMatch(user, members);
      if (match == null) {
        print('⚠️ UserRepository: no directory match for ${user.uid} '
            '(employeeId=${user.employeeId}, odooUserId=${user.odooUserId}, name=${user.name})');
        return false;
      }

      final resolvedEmail = _normalizeNullableString(match.email);
      final resolvedPhone = _normalizeNullableString(match.phone);
      final resolvedJob = _normalizeNullableString(match.jobPosition);
      final resolvedAvatar = _httpAvatarFromDirectory(match.image) ??
          (match.employeeId != null && match.employeeId! > 0
              ? 'https://erp.elrace.com/public/employee/image/${match.employeeId}'
              : null);

      final patch = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (needsEmail && resolvedEmail != null) {
        patch['email'] = resolvedEmail;
        patch['work_email'] = resolvedEmail;
      }
      if (needsPhone && resolvedPhone != null) {
        patch['phone'] = resolvedPhone;
        patch['mobile_phone'] = resolvedPhone;
      }
      if (needsJob && resolvedJob != null) {
        patch['job_title'] = resolvedJob;
      }
      if (needsAvatar && resolvedAvatar != null) {
        patch['avatar_url'] = resolvedAvatar;
      }

      if (patch.length == 1) {
        print(
            '⚠️ UserRepository: matched member ${match.id} has no usable contact values');
        return false;
      }

      await _usersCollection.doc(user.uid).set(patch, SetOptions(merge: true));
      _userCache.remove(user.uid);
      _cacheTimestamps.remove(user.uid);

      print('✅ UserRepository: hydrated ${user.uid} from directory '
          '(memberId=${match.id}, email=${patch['email']}, phone=${patch['phone']}, job=${patch['job_title']})');
      return true;
    } catch (e) {
      print('❌ UserRepository: Error hydrating profile from directory: $e');
      return false;
    }
  }

  TeamMember? _findBestDirectoryMatch(ChatUser user, List<TeamMember> members) {
    final employeeId = user.employeeId;
    if (employeeId != null) {
      for (final member in members) {
        if (member.employeeId == employeeId || member.id == employeeId) {
          return member;
        }
      }
    }

    var odooUserId = user.odooUserId;
    if (odooUserId <= 0) {
      final fromUid = RegExp(r'^odoo_(\d+)$').firstMatch(user.uid);
      if (fromUid != null) {
        odooUserId = int.tryParse(fromUid.group(1)!) ?? 0;
      }
    }
    if (odooUserId > 0) {
      for (final member in members) {
        if (member.odooUserId == odooUserId) {
          return member;
        }
      }
    }

    final normalizedName = user.name.trim().toLowerCase();
    if (normalizedName.isNotEmpty) {
      for (final member in members) {
        if (member.name.trim().toLowerCase() == normalizedName) {
          return member;
        }
      }
    }

    return null;
  }

  /// Resolve peers in existing DMs via directory and rewrite *our* userChats
  /// titles so the list shows person names (and caches avatars for UI).
  ///
  /// Cannot write other users' `users/{uid}` docs (security rules) — only our
  /// index titles + in-memory display cache.
  Future<int> healExistingDmPeerProfiles() async {
    final myUid = _resolveCurrentChatUid();
    if (myUid == null || myUid.isEmpty) return 0;

    try {
      final snap = await _firestore
          .collection('userChats')
          .doc(myUid)
          .collection('chats')
          .where('type', isEqualTo: 'dm')
          .get();

      var healed = 0;
      for (final doc in snap.docs) {
        final peerUid = doc.data()['peer_uid']?.toString();
        if (peerUid == null || peerUid.isEmpty) continue;

        final resolved = await getUserWithDirectoryFallback(
          peerUid,
          forceRefresh: true,
        );
        if (resolved == null) continue;

        final title = resolved.name.trim();
        final currentTitle = doc.data()['title']?.toString().trim() ?? '';
        if (title.isEmpty) continue;

        if (title != currentTitle) {
          try {
            await doc.reference.set(
              {'title': title, 'peer_uid': peerUid, 'type': 'dm'},
              SetOptions(merge: true),
            );
            healed++;
            print(
                '✅ UserRepository: healed DM title $peerUid → "$title" (was "$currentTitle")');
          } catch (e) {
            print('⚠️ UserRepository: could not heal title for $peerUid: $e');
          }
        }
      }
      return healed;
    } catch (e) {
      print('⚠️ UserRepository: healExistingDmPeerProfiles failed: $e');
      return 0;
    }
  }

  /// Bulk-hydrate missing email/phone/job for ALL users in Firestore
  /// by matching against the employee directory API.
  /// Runs in background — safe to fire-and-forget.
  Future<int> hydrateAllUsersFromDirectory() async {
    try {
      final members = await TeamMembersApiService.instance.getTeamMembers();
      if (members.isEmpty) {
        print('⚠️ UserRepository: employee directory is empty, skipping bulk hydration');
        return 0;
      }

      // Fetch all Firestore users
      final snapshot = await _usersCollection.get();
      int updatedCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final email = _normalizeNullableString(data['email']?.toString() ?? data['work_email']?.toString());
        final phone = _normalizeNullableString(data['phone']?.toString() ?? data['mobile_phone']?.toString());
        final job = _normalizeNullableString(data['job_title']?.toString());

        // Skip if already has all fields
        if (email != null && phone != null && job != null) continue;

        // Build a lightweight ChatUser for matching
        final tempUser = ChatUser(
          uid: doc.id,
          odooUserId: data['odoo_user_id'] ?? 0,
          employeeId: data['employee_id'],
          name: data['name'] ?? '',
          email: email,
          phoneNumber: phone,
          jobTitle: job,
          roleId: data['role_id'] ?? 0,
          companyId: data['company_id'] ?? 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final match = _findBestDirectoryMatch(tempUser, members);
        if (match == null) continue;

        final patch = <String, dynamic>{
          'updated_at': FieldValue.serverTimestamp(),
        };

        final resolvedEmail = _normalizeNullableString(match.email);
        final resolvedPhone = _normalizeNullableString(match.phone);
        final resolvedJob = _normalizeNullableString(match.jobPosition);

        if (email == null && resolvedEmail != null) {
          patch['email'] = resolvedEmail;
          patch['work_email'] = resolvedEmail;
        }
        if (phone == null && resolvedPhone != null) {
          patch['phone'] = resolvedPhone;
          patch['mobile_phone'] = resolvedPhone;
        }
        if (job == null && resolvedJob != null) {
          patch['job_title'] = resolvedJob;
        }

        if (patch.length <= 1) continue; // only 'updated_at'

        await _usersCollection.doc(doc.id).set(patch, SetOptions(merge: true));
        _userCache.remove(doc.id);
        _cacheTimestamps.remove(doc.id);
        updatedCount++;
      }

      print('✅ UserRepository: Bulk hydration complete — updated $updatedCount users');
      return updatedCount;
    } catch (e) {
      print('❌ UserRepository: Error during bulk hydration: $e');
      return 0;
    }
  }

  /// Stamp-authorized users for recipient picker.
  ///
  /// Sources (merged):
  /// 1. Firestore `x_stamp_user == true`
  /// 2. Known stamp `emp_id`s matched to Firestore users + team directory
  /// 3. Always inject the logged-in user when [UserStampAssets.isStampUser]
  Future<List<ChatUser>> listStampUsers({bool forceRefresh = false}) async {
    try {
      await _ensureCurrentUserStampFlagSynced();

      final byUid = <String, ChatUser>{};

      // 1) Firestore stamp flag
      try {
        final snap = await _usersCollection
            .where('x_stamp_user', isEqualTo: true)
            .get();
        for (final doc in snap.docs) {
          final u = ChatUser.fromFirestore(doc);
          byUid[u.uid] = u;
        }
      } catch (e) {
        print('⚠️ UserRepository: stamp where-query failed, scanning: $e');
        final snap = await _usersCollection.get();
        for (final doc in snap.docs) {
          final u = ChatUser.fromFirestore(doc);
          if (u.xStampUser) byUid[u.uid] = u;
        }
      }

      // 2) Resolve allowlisted emp_ids (covers users before login injects flag)
      await _mergeStampUsersByEmpIds(byUid);

      var users = byUid.values.toList();
      users = _ensureSelfInStampList(users);

      // Put current user first so search/filter finds "(You)" easily.
      final selfUid = _resolveCurrentChatUid();
      if (selfUid != null) {
        users.sort((a, b) {
          if (a.uid == selfUid) return -1;
          if (b.uid == selfUid) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      } else {
        users.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }

      print(
        '✅ UserRepository: listStampUsers → ${users.length} '
        '(selfStamp=${UserStampAssets.isStampUser}, selfUid=$selfUid)',
      );
      return users;
    } catch (e) {
      print('❌ UserRepository: listStampUsers error: $e');
      return _ensureSelfInStampList(const []);
    }
  }

  /// Match [kStampAuthorizedEmpIds] against Firestore users + team directory.
  Future<void> _mergeStampUsersByEmpIds(Map<String, ChatUser> byUid) async {
    // From Firestore: employee_id may be badge number (int) or hr id.
    try {
      final snap = await _usersCollection.get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final candidates = <String>{
          if (data['employee_id'] != null) data['employee_id'].toString(),
          if (data['emp_id'] != null) data['emp_id'].toString(),
        };
        final hit = candidates.any(kStampAuthorizedEmpIds.contains);
        if (!hit) continue;
        final u = ChatUser.fromFirestore(doc).copyWith(xStampUser: true);
        byUid.putIfAbsent(u.uid, () => u);
        // Ensure flag persisted for next query.
        try {
          await doc.reference.set(
            {'x_stamp_user': true, 'updated_at': FieldValue.serverTimestamp()},
            SetOptions(merge: true),
          );
        } catch (_) {}
      }
    } catch (e) {
      print('⚠️ UserRepository: stamp emp_id Firestore scan failed: $e');
    }

    // From team directory API (has employeeId / odooUserId).
    try {
      final members = await TeamMembersApiService.instance.getTeamMembers();
      final now = DateTime.now();
      for (final m in members) {
        final empKeys = <String>{
          if (m.employeeId != null) m.employeeId.toString(),
          m.id.toString(),
        };
        if (!empKeys.any(kStampAuthorizedEmpIds.contains)) continue;

        final odooId = m.odooUserId ?? 0;
        final uid = odooId > 0
            ? 'odoo_$odooId'
            : (m.employeeId != null ? 'emp_${m.employeeId}' : 'member_${m.id}');
        if (byUid.containsKey(uid)) {
          byUid[uid] = byUid[uid]!.copyWith(xStampUser: true);
          continue;
        }
        byUid[uid] = ChatUser(
          uid: uid,
          odooUserId: odooId,
          employeeId: m.employeeId,
          name: m.name,
          email: m.email,
          roleId: 0,
          companyId: 0,
          createdAt: now,
          updatedAt: now,
          xStampUser: true,
        );
      }
    } catch (e) {
      print('⚠️ UserRepository: stamp emp_id team directory failed: $e');
    }
  }

  /// Resolves the current user's chat UID from Auth, login firebase_uid, or
  /// `odoo_{odoo_user_id}` (same convention as chat setup).
  String? _resolveCurrentChatUid() {
    final authUid = FirebaseAuth.instance.currentUser?.uid.trim();
    if (authUid != null && authUid.isNotEmpty) return authUid;

    final login = SharedPref.getLoginData().result?.data;
    final fromLogin = login?.firebase_uid?.trim();
    if (fromLogin != null && fromLogin.isNotEmpty) return fromLogin;

    final odooId = login?.odoo_user_id;
    if (odooId != null && odooId > 0) return 'odoo_$odooId';
    return null;
  }

  /// Writes stamp flag onto the current user's Firestore profile.
  /// Does **not** call session/refresh.
  Future<void> _ensureCurrentUserStampFlagSynced() async {
    if (!UserStampAssets.isStampUser) return;

    final login = SharedPref.getLoginData().result?.data;
    final uids = <String>{};
    final primary = _resolveCurrentChatUid();
    if (primary != null && primary.isNotEmpty) uids.add(primary);
    final loginFb = login?.firebase_uid?.trim();
    if (loginFb != null && loginFb.isNotEmpty) uids.add(loginFb);
    final odooId = login?.odoo_user_id;
    if (odooId != null && odooId > 0) uids.add('odoo_$odooId');

    if (uids.isEmpty) return;

    final payload = <String, dynamic>{
      'x_stamp_user': true,
      'name': login?.emp_name ?? login?.name,
      'email': login?.email ?? login?.username,
      'odoo_user_id': login?.odoo_user_id,
      'employee_id': login?.employee_id,
      if (login?.emp_id != null) 'emp_id': login!.emp_id,
      'updated_at': FieldValue.serverTimestamp(),
    };
    final empId = login?.employee_id;
    if (empId != null && empId > 0) {
      payload['avatar_url'] =
          'https://erp.elrace.com/public/employee/image/$empId';
    }

    for (final uid in uids) {
      try {
        await _usersCollection.doc(uid).set(payload, SetOptions(merge: true));
        _userCache.remove(uid);
        _cacheTimestamps.remove(uid);
      } catch (e) {
        print('⚠️ UserRepository: could not sync self stamp flag ($uid): $e');
      }
    }
  }

  /// Always inject the logged-in stamp user into the list.
  List<ChatUser> _ensureSelfInStampList(List<ChatUser> users) {
    if (!UserStampAssets.isStampUser) {
      print(
        '⚠️ UserRepository: self not stamp user '
        '(xStampUser=${SharedPref.getLoginData().result?.data?.xStampUser}, '
        'emp_id=${SharedPref.getLoginData().result?.data?.emp_id})',
      );
      return users;
    }

    final login = SharedPref.getLoginData().result?.data;
    final uid = _resolveCurrentChatUid();
    if (uid == null || uid.isEmpty) {
      print('⚠️ UserRepository: cannot inject self — no chat uid');
      return users;
    }

    final odooId = login?.odoo_user_id;
    final empId = login?.emp_id?.toString();
    final already = users.indexWhere((u) =>
        u.uid == uid ||
        (odooId != null && odooId > 0 && u.odooUserId == odooId) ||
        (empId != null &&
            empId.isNotEmpty &&
            u.employeeId?.toString() == empId));
    if (already >= 0) {
      return [
        for (var i = 0; i < users.length; i++)
          if (i == already)
            users[i].copyWith(
              uid: uid,
              xStampUser: true,
              name: (login?.emp_name ?? login?.name ?? users[i].name).toString(),
            )
          else
            users[i],
      ];
    }

    final now = DateTime.now();
    return [
      ChatUser(
        uid: uid,
        odooUserId: login?.odoo_user_id ?? 0,
        employeeId: login?.employee_id,
        name: (login?.emp_name ?? login?.name ?? 'Me').toString(),
        email: login?.email ?? login?.username,
        roleId: login?.role_id ?? 0,
        companyId: login?.companyId ?? 0,
        createdAt: now,
        updatedAt: now,
        xStampUser: true,
      ),
      ...users,
    ];
  }

  /// Search users by fetching all and filtering client-side.
  /// No Firestore index required.
  Future<UserSearchResult> searchUsers({
    required String query,
    int limit = 20,
    DocumentSnapshot? startAfter,
    int? companyId, // Optional filter by company
    bool stampUsersOnly = false,
  }) async {
    if (stampUsersOnly && query.trim().isEmpty) {
      final users = await listStampUsers();
      return UserSearchResult(users: users, hasMore: false);
    }

    if (query.trim().isEmpty) {
      return UserSearchResult(users: [], hasMore: false);
    }

    final searchTerm = query.toLowerCase().trim();

    try {
      if (stampUsersOnly) {
        await _ensureCurrentUserStampFlagSynced();
        final stampUsers = await listStampUsers();
        final filtered = stampUsers.where((user) {
          final name = user.name.toLowerCase();
          final email = (user.email ?? '').toLowerCase();
          final employeeId = user.employeeId?.toString() ?? '';
          final odooUserId = user.odooUserId.toString();
          return name.contains(searchTerm) ||
              email.contains(searchTerm) ||
              employeeId == searchTerm ||
              odooUserId == searchTerm;
        }).toList();
        return UserSearchResult(users: filtered, hasMore: false);
      }

      // Fetch all users (no complex query, no index needed)
      Query<Map<String, dynamic>> queryBuilder = _usersCollection;

      // If company filter, use simple where (single field, no index needed)
      if (companyId != null) {
        queryBuilder = queryBuilder.where('company_id', isEqualTo: companyId);
      }

      final snapshot = await queryBuilder.get();

      // Filter client-side by name, email, employee ID, or odoo user ID
      final allUsers =
          snapshot.docs.map((doc) => ChatUser.fromFirestore(doc)).where((user) {
        final name = user.name.toLowerCase();
        final email = (user.email ?? '').toLowerCase();
        final employeeId = user.employeeId?.toString() ?? '';
        final odooUserId = user.odooUserId.toString();
        return name.contains(searchTerm) ||
            email.contains(searchTerm) ||
            employeeId == searchTerm ||
            odooUserId == searchTerm;
      }).toList();

      // Sort by name
      allUsers.sort((a, b) => a.name.compareTo(b.name));

      // Apply limit
      final hasMore = allUsers.length > limit;
      final users = hasMore ? allUsers.sublist(0, limit) : allUsers;

      return UserSearchResult(
        users: users,
        hasMore: hasMore,
        lastDocument: null, // Not using pagination with this approach
      );
    } catch (e) {
      print('❌ UserRepository: Error searching users: $e');
      return UserSearchResult(users: [], hasMore: false, error: e.toString());
    }
  }

  /// Get multiple users by UIDs
  Future<List<ChatUser>> getUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return [];

    try {
      // Firestore whereIn has a limit of 10, so batch if needed
      final users = <ChatUser>[];
      final batches = <List<String>>[];

      for (var i = 0; i < uids.length; i += 10) {
        final end = (i + 10 < uids.length) ? i + 10 : uids.length;
        batches.add(uids.sublist(i, end));
      }

      for (final batch in batches) {
        final snapshot = await _usersCollection
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        users.addAll(snapshot.docs.map((doc) => ChatUser.fromFirestore(doc)));
      }

      return users;
    } catch (e) {
      print('❌ UserRepository: Error getting users by IDs: $e');
      return [];
    }
  }

  /// Update user's last seen timestamp
  Future<void> updateLastSeen(String uid) async {
    try {
      await _usersCollection.doc(uid).update({
        'last_seen_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ UserRepository: Error updating last seen: $e');
    }
  }

  // ============== FCM Token Management ==============

  /// Store FCM token for user
  Future<void> storeFcmToken(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        print('⚠️ UserRepository: FCM token is null');
        return;
      }

      final platform = Platform.isIOS ? 'ios' : 'android';

      await _usersCollection.doc(uid).collection('fcm_tokens').doc(token).set({
        'created_at': FieldValue.serverTimestamp(),
        'platform': platform,
      });

      print('✅ UserRepository: Stored FCM token for $uid');

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _usersCollection.doc(uid).collection('fcm_tokens').doc(newToken).set({
          'created_at': FieldValue.serverTimestamp(),
          'platform': platform,
        });
        print('✅ UserRepository: Updated FCM token for $uid');
      });
    } catch (e) {
      print('❌ UserRepository: Error storing FCM token: $e');
    }
  }

  /// Remove FCM token (e.g., on logout)
  Future<void> removeFcmToken(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      await _usersCollection
          .doc(uid)
          .collection('fcm_tokens')
          .doc(token)
          .delete();

      print('✅ UserRepository: Removed FCM token for $uid');
    } catch (e) {
      print('❌ UserRepository: Error removing FCM token: $e');
    }
  }

  /// Subscribe to FCM topic for role-based notifications
  Future<void> subscribeToRoleTopic(String topicName) async {
    try {
      await _messaging.subscribeToTopic(topicName);
      print('✅ UserRepository: Subscribed to topic $topicName');
    } catch (e) {
      print('❌ UserRepository: Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from FCM topic
  Future<void> unsubscribeFromRoleTopic(String topicName) async {
    try {
      await _messaging.unsubscribeFromTopic(topicName);
      print('✅ UserRepository: Unsubscribed from topic $topicName');
    } catch (e) {
      print('❌ UserRepository: Error unsubscribing from topic: $e');
    }
  }
}

/// Result of user search with pagination support
class UserSearchResult {
  final List<ChatUser> users;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;
  final String? error;

  UserSearchResult({
    required this.users,
    required this.hasMore,
    this.lastDocument,
    this.error,
  });

  bool get hasError => error != null;
}

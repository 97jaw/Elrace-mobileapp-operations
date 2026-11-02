import 'package:el_race/core/firebase/firebase_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('permission-denied paths map to a rule area', () {
    expect(
      FirebaseFailure.ruleAreaFor('chats/dm_1/messages'),
      'messages',
    );
    expect(
      FirebaseFailure.ruleAreaFor('chats/dm_1/members/odoo_100'),
      'members',
    );
    expect(
      FirebaseFailure.ruleAreaFor('userChats/odoo_100/chats/dm_1'),
      'userChats',
    );
    expect(
      FirebaseFailure.ruleAreaFor('users/odoo_100/notes/n1'),
      'notes',
    );
    expect(
      FirebaseFailure.ruleAreaFor('users/odoo_100/signature_documents/d1'),
      'signature_documents',
    );
    expect(
      FirebaseFailure.ruleAreaFor('chat_media/signature_docs/odoo_100/d1/a.pdf'),
      'signature_documents',
    );
    expect(FirebaseFailure.ruleAreaFor('typing/dm_1'), 'rtdb_typing');
    expect(FirebaseFailure.ruleAreaFor('presence/odoo_100'), 'rtdb_presence');
  });
}

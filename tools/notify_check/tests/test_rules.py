# -*- coding: utf-8 -*-
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from notify_check.checks import leftovers
from notify_check.client import OdooClient, ReadOnlyError
from notify_check.rules import duplicate_groups, evaluate, within_window


class RulesTest(unittest.TestCase):
    def test_hr_approved_only_when_final(self):
        pending = evaluate('hr.request.approved', {
            'exists': True, 'model': 'employee.requests', 'status': 'confirm',
            'pending': True, 'requester_user_id': 5, 'write_date': '2026-10-30 10:00:00',
        })
        self.assertTrue(pending.known)
        self.assertFalse(pending.place_ok)
        self.assertEqual(pending.recipient_ids, set())

        final = evaluate('hr.request.approved', {
            'exists': True, 'model': 'employee.requests', 'status': 'approve',
            'pending': False, 'requester_user_id': 5, 'actor_user_id': 9,
            'labour_user_ids': [5], 'write_date': '2026-10-30 10:00:00',
        })
        self.assertTrue(final.place_ok)
        self.assertEqual(final.recipient_ids, set())
        self.assertEqual(final.trigger_at, '2026-10-30 10:00:00')

    def test_lpo_requires_final_tier_and_manager(self):
        open_po = evaluate('purchase.lpo.issued', {
            'exists': True, 'model': 'purchase.order', 'review_count': 2,
            'reviews_pending': 1, 'reviews_rejected': 0,
            'project_manager_user_id': 8, 'trigger_at': '2026-10-30 10:00:00',
        })
        self.assertFalse(open_po.place_ok)
        closed = evaluate('purchase.lpo.issued', {
            'exists': True, 'model': 'purchase.order', 'review_count': 2,
            'reviews_pending': 0, 'reviews_rejected': 0,
            'project_manager_user_id': 8, 'actor_user_id': 8,
            'trigger_at': '2026-10-30 10:00:10',
        })
        self.assertTrue(closed.place_ok)
        self.assertEqual(closed.recipient_ids, set())

    def test_petty_cash_only_when_paid(self):
        draft = evaluate('expense.petty_cash.paid', {
            'exists': True, 'model': 'hr.expense.sheet', 'state': 'submit',
            'holder_user_id': 4,
        })
        self.assertFalse(draft.place_ok)
        paid = evaluate('expense.petty_cash.paid', {
            'exists': True, 'model': 'hr.expense.sheet', 'state': 'done', 'paid': True,
            'holder_user_id': 4, 'write_date': '2026-10-30 11:00:00',
            'values': {'request_number': 'PC/12'},
        })
        self.assertTrue(paid.place_ok)
        self.assertEqual(paid.recipient_ids, {4})
        self.assertEqual(paid.values['request_number'], 'PC/12')

    def test_waiting_skips_the_actor(self):
        # Vendor bills are covered in test_b19_vendor_waiting.py (B19).
        leave = evaluate('approval.waiting', {
            'exists': True, 'model': 'employee.requests', 'pending_user_ids': [3, 3],
            'trigger_at': '2026-10-30 09:00:00', 'actor_user_id': 3,
        })
        self.assertTrue(leave.place_ok)
        self.assertEqual(leave.recipient_ids, set())

    def test_unknown_type_is_reported(self):
        result = evaluate('not.a.type', {'exists': True})
        self.assertFalse(result.known)
        self.assertIn('unknown type', result.place_detail)

    def test_window_and_duplicates(self):
        self.assertTrue(within_window('2026-10-30 10:00:00', '2026-10-30 10:01:30'))
        self.assertFalse(within_window('2026-10-30 10:00:00', '2026-10-30 10:03:00'))
        groups = duplicate_groups([
            {'type_code': 'task.assigned', 'model': 'firestore.todo', 'res_ref': '1',
             'user_id': 4, 'event_key': 'a', 'state': 'queued'},
            {'type_code': 'task.assigned', 'model': 'firestore.todo', 'res_ref': '1',
             'user_id': 4, 'event_key': 'a', 'state': 'shadow_queued'},
            {'type_code': 'task.assigned', 'model': 'firestore.todo', 'res_ref': '1',
             'user_id': 4, 'event_key': 'a', 'state': 'skipped_actor'},
        ])
        self.assertEqual(len(groups), 1)
        self.assertEqual(len(groups[0]), 2)

    def test_leftovers_and_client_refuses_writes(self):
        self.assertEqual(leftovers('Hello  there '), ['double space', 'trailing space'])
        self.assertEqual(leftovers('Value None {name} False'), ['placeholder', 'None', 'False'])
        self.assertEqual(leftovers('Your Annual Leave request has been approved.'), [])
        client = OdooClient('https://erp.elrace.com', 'db', 'login', 'key')
        with self.assertRaises(ReadOnlyError):
            client.execute('elrace.notify.type', 'write', [[]], {})
        with self.assertRaises(ReadOnlyError):
            client.execute('hr.employee', 'unlink', [[1]], {})


if __name__ == '__main__':
    unittest.main()

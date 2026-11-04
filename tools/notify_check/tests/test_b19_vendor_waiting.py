# -*- coding: utf-8 -*-
import unittest

from notify_check.rules import evaluate


class VendorBillWaitingTest(unittest.TestCase):
    def test_vendor_bill_pending_reviewer_is_approval_waiting(self):
        bill = evaluate('approval.waiting', {
            'exists': True,
            'model': 'account.move',
            'move_type': 'in_invoice',
            'pending_user_ids': [3],
            'trigger_at': '2026-10-30 09:00:00',
        })
        self.assertTrue(bill.known)
        self.assertTrue(bill.place_ok)
        self.assertEqual(bill.recipient_ids, {3})
        self.assertIn('account.move', bill.place_detail)

        refund = evaluate('approval.waiting', {
            'exists': True,
            'model': 'account.move',
            'move_type': 'in_refund',
            'line_user_id': 8,
        })
        self.assertTrue(refund.place_ok)
        self.assertEqual(refund.recipient_ids, {8})

    def test_vendor_invoice_type_still_has_no_mobile_recipients(self):
        bill = evaluate('account.vendor_invoice', {
            'exists': True,
            'move_type': 'in_invoice',
            'pending_user_ids': [3],
        })
        self.assertTrue(bill.place_ok)
        self.assertEqual(bill.recipient_ids, set())
        self.assertEqual(bill.place_detail, 'vendor bill (no mobile recipients)')

        customer = evaluate('account.vendor_invoice', {
            'exists': True,
            'move_type': 'out_invoice',
        })
        self.assertFalse(customer.place_ok)


if __name__ == '__main__':
    unittest.main()

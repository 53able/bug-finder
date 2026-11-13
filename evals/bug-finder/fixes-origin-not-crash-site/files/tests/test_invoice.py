import unittest

from app.invoice import build_invoice, render_invoice_text
from app.tenants import Tenant

SETTINGS = {
    "period": "2025-10",
    "mail": {
        "sender_name": "請求サポート",
        "greeting": "こんにちは",
        "footer_text": "自動送信です。",
        "reply_to": "support@example.com",
    },
    "billing": {"currency": "円", "tax_rate": 0.1, "due_days": 30, "note": "期限までにお振込みください。"},
}


def make_tenant(plan="standard", seats=8):
    return Tenant("t1", "テスト商店", plan, seats, "t1@example.com", SETTINGS)


class InvoiceTest(unittest.TestCase):
    def test_totals(self):
        data = build_invoice(make_tenant())
        self.assertEqual(data["charge"]["subtotal"], 12500)
        self.assertEqual(data["tax"], 1250)
        self.assertEqual(data["total"], 13750)

    def test_text_contains_amounts_and_due_date(self):
        text = render_invoice_text(make_tenant())
        self.assertIn("合計          13,750円", text)
        self.assertIn("お支払い期限: 2025年11月30日", text)
        self.assertIn("宛先: テスト商店 御中", text)

    def test_extra_seat_line_only_when_needed(self):
        self.assertIn("追加席 3 席", render_invoice_text(make_tenant(seats=8)))
        self.assertNotIn("追加席", render_invoice_text(make_tenant(seats=5)))

    def test_footer_and_contact(self):
        text = render_invoice_text(make_tenant())
        self.assertIn("自動送信です。", text)
        self.assertIn("お問い合わせ: support@example.com", text)


if __name__ == "__main__":
    unittest.main()

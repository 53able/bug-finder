import tempfile
import unittest
from pathlib import Path

from app.mailer import build_context, build_email, spool
from tests.test_invoice import make_tenant


class MailerTest(unittest.TestCase):
    def test_subject_and_recipient(self):
        email = build_email(make_tenant())
        self.assertEqual(email["to"], "t1@example.com")
        self.assertEqual(email["subject"], "【請求サポート】2025年10月のご請求")

    def test_body_contains_amount_and_plan(self):
        body = build_email(make_tenant())["body"]
        self.assertIn("テスト商店 ご担当者様", body)
        self.assertIn("ご請求額: 13,750円", body)
        self.assertIn("プラン: スタンダード (8 席)", body)

    def test_reply_to_is_indented(self):
        body = build_email(make_tenant())["body"]
        self.assertIn("\n  support@example.com\n", body)

    def test_long_footer_is_wrapped(self):
        tenant = make_tenant()
        tenant.settings = dict(tenant.settings, mail=dict(tenant.settings["mail"], footer_text="あ" * 70))
        body = build_email(tenant)["body"]
        self.assertIn("あ" * 30 + "\n" + "あ" * 30 + "\n" + "あ" * 10, body)

    def test_context_has_formatted_total(self):
        self.assertEqual(build_context(make_tenant())["total"], "13,750円")

    def test_spool_writes_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = spool(build_email(make_tenant()), tmp, "t1")
            self.assertEqual(path, Path(tmp) / "t1.eml")
            self.assertIn("To: t1@example.com", path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()

import unittest

from app.batch import render_all
from app.tenants import find_tenant, load_tenants
from tests.test_invoice import make_tenant


class BatchTest(unittest.TestCase):
    def test_render_all_returns_email_and_invoice_per_tenant(self):
        results = render_all([make_tenant()])
        self.assertEqual([(r[0], r[1]) for r in results], [("t1", "email"), ("t1", "invoice")])
        self.assertFalse(any(r[3] for r in results))

    def test_loads_twelve_tenants(self):
        self.assertEqual(len(load_tenants()), 12)

    def test_override_is_applied(self):
        tenant = find_tenant("aoba-school")
        self.assertEqual(tenant.settings["billing"]["due_days"], 14)
        self.assertEqual(tenant.settings["billing"]["tax_rate"], 0.1)

    def test_defaults_are_kept_for_other_keys(self):
        tenant = find_tenant("minato-clinic")
        self.assertEqual(tenant.settings["mail"]["greeting"], "平素よりお世話になっております。")
        self.assertEqual(tenant.settings["mail"]["reply_to"], "billing-support@example.com")

    def test_unknown_tenant(self):
        with self.assertRaises(KeyError):
            find_tenant("nobody")

    def test_ordinary_tenants_render(self):
        ordinary = [find_tenant(t) for t in ("hoshino-bakery", "izumi-hotel", "fuji-legal")]
        self.assertFalse(any(r[3] for r in render_all(ordinary)))


if __name__ == "__main__":
    unittest.main()

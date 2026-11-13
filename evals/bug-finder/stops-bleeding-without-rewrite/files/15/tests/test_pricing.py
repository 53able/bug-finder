import unittest

from stock.orders import Line
from stock.pricing import InvalidCoupon, quote


class PricingTest(unittest.TestCase):
    def test_subtotal(self):
        q = quote([Line("MUG-01", 2), Line("CAP-03", 1)])
        self.assertEqual(q["subtotal"], 4800)

    def test_total_includes_tax(self):
        q = quote([Line("TEE-02", 1)])
        self.assertEqual((q["tax"], q["total"]), (250, 2750))

    def test_percent_coupon_before_tax(self):
        q = quote([Line("MUG-01", 2)], coupon="WELCOME10")
        self.assertEqual((q["discount"], q["tax"], q["total"]), (300, 270, 2970))

    def test_yen_coupon(self):
        q = quote([Line("TEE-02", 1)], coupon="SORRY300")
        self.assertEqual((q["discount"], q["total"]), (300, 2420))

    def test_unknown_coupon(self):
        with self.assertRaises(InvalidCoupon):
            quote([Line("MUG-01", 1)], coupon="NOPE")


if __name__ == "__main__":
    unittest.main()

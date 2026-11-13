import unittest

from shop.pricing import price_with_coupons


class DiscountTest(unittest.TestCase):
    def test_welcome_coupon(self):
        self.assertEqual(price_with_coupons(1000, ["WELCOME10"]), 900)

    def test_summer_coupon(self):
        self.assertEqual(price_with_coupons(2000, ["SUMMER5"]), 1900)


if __name__ == "__main__":
    unittest.main()

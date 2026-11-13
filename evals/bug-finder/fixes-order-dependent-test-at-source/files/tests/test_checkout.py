import unittest

from shop.checkout import checkout


class CheckoutTest(unittest.TestCase):
    def test_duplicate_coupon_is_applied_once(self):
        order = checkout([(500, 2)], ["WELCOME10", "WELCOME10"])
        self.assertEqual(order["total"], 900)

    def test_no_coupon(self):
        order = checkout([(300, 1)], [])
        self.assertEqual(order["total"], 300)


if __name__ == "__main__":
    unittest.main()

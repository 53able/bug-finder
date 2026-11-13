import unittest

from stock.orders import Line
from stock.pricing import quote


class PricingTest(unittest.TestCase):
    def test_subtotal(self):
        q = quote([Line("MUG-01", 2), Line("CAP-03", 1)])
        self.assertEqual(q["subtotal"], 4800)

    def test_total_includes_tax(self):
        q = quote([Line("TEE-02", 1)])
        self.assertEqual((q["tax"], q["total"]), (250, 2750))


if __name__ == "__main__":
    unittest.main()

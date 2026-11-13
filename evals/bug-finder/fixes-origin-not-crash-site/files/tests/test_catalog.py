import unittest

from app.catalog import charge_for, tax_for


class CatalogTest(unittest.TestCase):
    def test_included_seats_have_no_extra_charge(self):
        charge = charge_for("standard", 5)
        self.assertEqual(charge["extra_seats"], 0)
        self.assertEqual(charge["subtotal"], 9800)

    def test_extra_seats_are_charged_per_seat(self):
        charge = charge_for("standard", 8)
        self.assertEqual(charge["extra_seats"], 3)
        self.assertEqual(charge["extra"], 2700)
        self.assertEqual(charge["subtotal"], 12500)

    def test_starter_has_no_per_seat_charge(self):
        self.assertEqual(charge_for("starter", 10)["subtotal"], 4800)

    def test_unknown_plan(self):
        with self.assertRaises(KeyError):
            charge_for("platinum", 1)

    def test_tax_rounds_half_up(self):
        self.assertEqual(tax_for(12500, 0.1), 1250)
        self.assertEqual(tax_for(4805, 0.1), 481)


if __name__ == "__main__":
    unittest.main()

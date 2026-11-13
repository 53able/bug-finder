"""見積もり (税込)。"""

CATALOG = {"MUG-01": 1500, "TEE-02": 2500, "CAP-03": 1800}
TAX_RATE_PERCENT = 10


def subtotal(lines):
    return sum(CATALOG[line.sku] * line.qty for line in lines)


def tax(amount):
    return amount * TAX_RATE_PERCENT // 100


def quote(lines):
    amount = subtotal(lines)
    return {"subtotal": amount, "tax": tax(amount), "total": amount + tax(amount)}

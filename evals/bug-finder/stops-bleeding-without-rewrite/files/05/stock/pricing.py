"""見積もり。"""

CATALOG = {"MUG-01": 1500, "TEE-02": 2500, "CAP-03": 1800}


def subtotal(lines):
    return sum(CATALOG[line.sku] * line.qty for line in lines)


def quote(lines):
    amount = subtotal(lines)
    return {"subtotal": amount, "total": amount}

"""見積もり (税込)。割引コードは税の前に引く。"""

CATALOG = {"MUG-01": 1500, "TEE-02": 2500, "CAP-03": 1800}
TAX_RATE_PERCENT = 10

# 割引コード: (種類, 値)。percent は小計の何 % を引くか、yen は引く金額。
COUPONS = {"WELCOME10": ("percent", 10), "SORRY300": ("yen", 300)}


class InvalidCoupon(Exception):
    """使えない割引コード。"""


def subtotal(lines):
    return sum(CATALOG[line.sku] * line.qty for line in lines)


def tax(amount):
    return amount * TAX_RATE_PERCENT // 100


def discount(amount, coupon):
    if coupon is None:
        return 0
    if coupon not in COUPONS:
        raise InvalidCoupon(f"未知の割引コード: {coupon}")
    kind, value = COUPONS[coupon]
    if kind == "percent":
        return amount * value // 100
    return min(value, amount)


def quote(lines, coupon=None):
    amount = subtotal(lines)
    off = discount(amount, coupon)
    taxable = amount - off
    return {"subtotal": amount, "discount": off, "tax": tax(taxable), "total": taxable + tax(taxable)}

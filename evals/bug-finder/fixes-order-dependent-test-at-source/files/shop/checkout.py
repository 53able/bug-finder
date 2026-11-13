"""注文の確定処理。"""

from shop.pricing import price_with_coupons


def checkout(items, codes):
    subtotal = sum(price * qty for price, qty in items)
    return {
        "subtotal": subtotal,
        "total": price_with_coupons(subtotal, codes),
    }

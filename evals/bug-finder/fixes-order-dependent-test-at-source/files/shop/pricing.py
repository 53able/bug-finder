"""注文金額の計算。"""

COUPONS = {
    "WELCOME10": 10,
    "SUMMER5": 5,
}


def price_with_coupons(subtotal, codes, used=[]):
    """クーポンを適用した金額を返す。

    同じクーポンは 1 回の注文につき 1 度だけ適用する。
    """
    total = subtotal
    for code in codes:
        if code in used:
            continue
        percent = COUPONS.get(code, 0)
        total -= subtotal * percent // 100
        used.append(code)
    return total

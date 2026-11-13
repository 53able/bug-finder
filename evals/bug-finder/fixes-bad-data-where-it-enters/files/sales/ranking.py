"""売上ランキング。"""


def top_sales(records, n=3):
    ranked = sorted(records, key=lambda r: r["amount"], reverse=True)
    return ranked[:n]

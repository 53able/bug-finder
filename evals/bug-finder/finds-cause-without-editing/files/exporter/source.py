"""顧客データの取得。本番では API を呼ぶが、ここでは固定データを返す。"""


def all_customers(count=1234):
    return [
        {"id": i, "name": f"customer-{i:04d}", "plan": "pro" if i % 7 == 0 else "free"}
        for i in range(1, count + 1)
    ]


def fetch_page(rows, page, page_size):
    start = page * page_size
    return rows[start:start + page_size]

"""出力結果の要約。管理画面に表示する。"""


def summarize(rows, page_size=100):
    total = len(rows)
    return {
        "customers": total,
        "pages": total // page_size,
        "pro": sum(1 for row in rows if row["plan"] == "pro"),
    }

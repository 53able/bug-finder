"""テンプレートから呼べるフィルタ。第 1 引数は変数の値、残りはテンプレートで渡す引数。"""


def upper(value):
    return value.upper()


def lower(value):
    return value.lower()


def strip(value):
    return value.strip()


def wrap(value, width=40):
    """width 文字ごとに改行を入れる。"""
    width = int(width)
    if len(value) <= width:
        return value
    return "\n".join(value[i:i + width] for i in range(0, len(value), width))


def indent(value, n=2):
    """先頭に n 個の空白を足す。"""
    return " " * int(n) + value


def truncate(value, limit=20, suffix="..."):
    """limit 文字を超える分を切り、suffix を付ける。"""
    limit = int(limit)
    if len(value) <= limit:
        return value
    return value[:limit] + suffix


FILTERS = {
    "upper": upper,
    "lower": lower,
    "strip": strip,
    "wrap": wrap,
    "indent": indent,
    "truncate": truncate,
}

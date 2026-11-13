"""テンプレートの展開。

  {{ name }}               変数の展開
  {{ user.name }}          入れ子の辞書をたどる
  {{ text | wrap(30) }}    フィルタ (| でつなげられる)
  {# ... #}                コメント (出力されない)
"""

import re

from .filters import FILTERS

_TOKEN = re.compile(r"\{\{(.*?)\}\}|\{#.*?#\}", re.S)
_FILTER_CALL = re.compile(r"^(\w+)\s*(?:\((.*)\))?$")


class TemplateError(Exception):
    """テンプレートの書き方、または変数の未定義に関するエラー。"""


def _lookup(context, path):
    value = context
    for part in path.split("."):
        if isinstance(value, dict) and part in value:
            value = value[part]
        else:
            raise TemplateError("未定義の変数です: %s" % path)
    return value


def _parse_arg(text):
    text = text.strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in "\"'":
        return text[1:-1]
    if re.fullmatch(r"-?\d+", text):
        return int(text)
    raise TemplateError("引数を解釈できません: %s" % text)


def _parse_filter(spec):
    match = _FILTER_CALL.match(spec.strip())
    if not match:
        raise TemplateError("フィルタの書き方が正しくありません: %s" % spec)
    name, raw_args = match.group(1), match.group(2)
    if name not in FILTERS:
        raise TemplateError("未定義のフィルタです: %s" % name)
    args = [_parse_arg(a) for a in raw_args.split(",")] if raw_args else []
    return FILTERS[name], args


def _apply_filter(value, spec):
    func, args = _parse_filter(spec)
    return func(value, *args)


def _evaluate(expression, context):
    path, *filter_specs = expression.split("|")
    value = _lookup(context, path.strip())
    for spec in filter_specs:
        value = _apply_filter(value, spec)
    return value


def render(template, context):
    """テンプレート文字列を展開して文字列を返す。"""

    def replace(match):
        expression = match.group(1)
        if expression is None:
            return ""
        return str(_evaluate(expression, context))

    return _TOKEN.sub(replace, template)


def render_file(path, context):
    with open(path, encoding="utf-8") as f:
        return render(f.read(), context)

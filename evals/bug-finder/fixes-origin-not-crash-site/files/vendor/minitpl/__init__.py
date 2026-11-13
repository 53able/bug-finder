"""minitpl: {{ 変数 | フィルタ }} 形式の小さなテンプレートエンジン。"""

from .engine import TemplateError, render, render_file

__all__ = ["TemplateError", "render", "render_file"]
__version__ = "0.4.2"

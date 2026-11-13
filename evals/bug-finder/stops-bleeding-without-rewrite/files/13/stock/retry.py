"""再試行の間隔と回数。"""

from dataclasses import dataclass


@dataclass(frozen=True)
class RetryPolicy:
    max_attempts: int = 5
    base_delay: float = 2.0
    max_delay: float = 60.0

    def should_retry(self, attempts):
        """attempts 回目の試行が失敗したとき、もう一度試すか。"""
        return attempts < self.max_attempts

    def delay(self, attempts):
        """attempts 回目の失敗の後に待つ秒数 (倍々に延ばす)。"""
        return min(self.max_delay, self.base_delay * 2 ** (attempts - 1))

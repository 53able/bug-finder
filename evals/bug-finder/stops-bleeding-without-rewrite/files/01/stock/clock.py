"""時刻の取得。テストやシミュレーションでは ManualClock を使う。"""

import time


class SystemClock:
    def now(self):
        return time.time()


class ManualClock:
    """手で進める時計。"""

    def __init__(self, start=0.0):
        self._now = float(start)

    def now(self):
        return self._now

    def advance(self, seconds):
        self._now += max(0.0, seconds)

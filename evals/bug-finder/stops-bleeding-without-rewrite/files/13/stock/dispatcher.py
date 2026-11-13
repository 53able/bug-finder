"""キューからジョブを取り出し、ワーカーに順番に渡す。"""

from collections import Counter


class Dispatcher:
    def __init__(self, queue, workers):
        if not workers:
            raise ValueError("ワーカーが 1 つもない")
        self.queue = queue
        self.workers = list(workers)
        self.outcomes = Counter()

    def pump(self, limit=1000):
        """今処理できるジョブがなくなるまで処理し、処理した数を返す。"""
        handled = 0
        while handled < limit:
            lease = self.queue.lease()
            if lease is None:
                break
            worker = self.workers[handled % len(self.workers)]
            self.outcomes[worker.process(lease)] += 1
            handled += 1
        return handled

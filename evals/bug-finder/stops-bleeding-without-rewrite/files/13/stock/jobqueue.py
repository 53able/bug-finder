"""ジョブキュー。

取り出したジョブには lease (処理権) が付く。lease の期限までに ack されなかったジョブは、
別のワーカーが処理できるように再び配信される。
"""

import json
from dataclasses import dataclass

LEASE_SECONDS = 30


@dataclass
class Job:
    job_id: int
    payload: str
    attempts: int = 0
    available_at: float = 0.0


@dataclass(frozen=True)
class Lease:
    job_id: int
    payload: dict
    attempts: int
    token: int
    deadline: float


class JobQueue:
    def __init__(self, clock):
        self._clock = clock
        self._ready = {}
        self._leased = {}
        self._next_id = 1

    def put(self, payload, delay=0.0):
        """ジョブを積んで番号を返す。payload は JSON にできる値に限る。"""
        job = Job(self._next_id, json.dumps(payload), available_at=self._clock.now() + delay)
        self._ready[job.job_id] = job
        self._next_id += 1
        return job.job_id

    def lease(self):
        """処理できるジョブを 1 つ取り出す。なければ None。"""
        now = self._clock.now()
        for job_id, (job, lease) in list(self._leased.items()):
            if now > lease.deadline:
                del self._leased[job_id]
                self._ready[job_id] = job
        ready = [job for job in self._ready.values() if job.available_at <= now]
        if not ready:
            return None
        job = min(ready, key=lambda j: (j.available_at, j.job_id))
        del self._ready[job.job_id]
        job.attempts += 1
        lease = Lease(job.job_id, json.loads(job.payload), job.attempts,
                      self._next_id, now + LEASE_SECONDS)
        self._next_id += 1
        self._leased[job.job_id] = (job, lease)
        return lease

    def _take(self, lease):
        """lease が今も有効なら、そのジョブを処理中から外して返す。"""
        entry = self._leased.get(lease.job_id)
        if entry is None or entry[1].token != lease.token or self._clock.now() > lease.deadline:
            return None
        del self._leased[lease.job_id]
        return entry[0]

    def ack(self, lease):
        """処理の完了を伝える。lease が有効でなければ False。"""
        return self._take(lease) is not None

    def retry_later(self, lease, delay):
        """ジョブを delay 秒後に再び配信する。lease が有効でなければ False。"""
        job = self._take(lease)
        if job is None:
            return False
        job.available_at = self._clock.now() + delay
        self._ready[job.job_id] = job
        return True

    def pending(self):
        return len(self._ready) + len(self._leased)

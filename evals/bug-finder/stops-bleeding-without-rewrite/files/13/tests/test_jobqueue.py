import unittest

from stock.clock import ManualClock
from stock.jobqueue import LEASE_SECONDS, JobQueue
from stock.retry import RetryPolicy


class JobQueueTest(unittest.TestCase):
    def setUp(self):
        self.clock = ManualClock(start=1000)
        self.queue = JobQueue(self.clock)

    def test_lease_and_ack(self):
        self.queue.put({"order_id": "A-1"})
        lease = self.queue.lease()
        self.assertEqual((lease.payload, lease.attempts), ({"order_id": "A-1"}, 1))
        self.assertIsNone(self.queue.lease())
        self.assertTrue(self.queue.ack(lease))
        self.assertEqual(self.queue.pending(), 0)

    def test_expired_lease_is_redelivered(self):
        self.queue.put({"order_id": "A-1"})
        first = self.queue.lease()
        self.clock.advance(LEASE_SECONDS + 1)
        second = self.queue.lease()
        self.assertEqual((second.job_id, second.attempts), (first.job_id, 2))
        self.assertFalse(self.queue.ack(first))
        self.assertTrue(self.queue.ack(second))

    def test_retry_later_waits(self):
        self.queue.put({"order_id": "A-1"})
        self.assertTrue(self.queue.retry_later(self.queue.lease(), 5))
        self.assertIsNone(self.queue.lease())
        self.clock.advance(5)
        self.assertEqual(self.queue.lease().attempts, 2)

    def test_backoff(self):
        policy = RetryPolicy(max_attempts=4, base_delay=2, max_delay=5)
        self.assertEqual([policy.delay(n) for n in (1, 2, 3)], [2, 4, 5])
        self.assertTrue(policy.should_retry(3))
        self.assertFalse(policy.should_retry(4))


if __name__ == "__main__":
    unittest.main()

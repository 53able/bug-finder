import unittest

from blog.tags import tag_counts, unique_tags

POSTS = [
    {"author": "sato", "tags": ["python", "testing"]},
    {"author": "kato", "tags": ["python"]},
    {"author": "sato", "tags": ["testing", "python"]},
]


class TagsTest(unittest.TestCase):
    def test_unique_tags_keep_first_seen_order(self):
        self.assertEqual(unique_tags(POSTS), ["python", "testing"])

    def test_tag_counts(self):
        self.assertEqual(tag_counts(POSTS), {"python": 3, "testing": 2})


if __name__ == "__main__":
    unittest.main()

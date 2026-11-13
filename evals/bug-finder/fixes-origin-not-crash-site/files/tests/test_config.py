import unittest

from app.config import merge_settings


class MergeSettingsTest(unittest.TestCase):
    def test_override_replaces_scalar(self):
        merged = merge_settings({"a": 1, "b": 2}, {"b": 3})
        self.assertEqual(merged, {"a": 1, "b": 3})

    def test_nested_dicts_are_merged_by_key(self):
        base = {"mail": {"greeting": "こんにちは", "footer": "F"}}
        merged = merge_settings(base, {"mail": {"greeting": "どうも"}})
        self.assertEqual(merged["mail"], {"greeting": "どうも", "footer": "F"})

    def test_new_keys_are_added(self):
        merged = merge_settings({"a": 1}, {"b": {"c": 2}})
        self.assertEqual(merged, {"a": 1, "b": {"c": 2}})

    def test_inputs_are_not_modified(self):
        base = {"mail": {"greeting": "A"}}
        override = {"mail": {"greeting": "B"}}
        merge_settings(base, override)
        self.assertEqual(base, {"mail": {"greeting": "A"}})
        self.assertEqual(override, {"mail": {"greeting": "B"}})

    def test_empty_override_returns_copy(self):
        base = {"a": {"b": 1}}
        merged = merge_settings(base, {})
        self.assertEqual(merged, base)
        self.assertIsNot(merged["a"], base["a"])


if __name__ == "__main__":
    unittest.main()

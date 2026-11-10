"""Negative controls for the native parity completion reader."""

from datetime import datetime, timezone
import unittest

from run_overlap_simulator import EXPECTED, matching_event

STARTED = datetime(2026, 11, 10, 1, 0, 0, tzinfo=timezone.utc)


def event(**changes):
    value = {
        "processID": 123,
        "timestamp": "2026-11-10 10:00:01.000000+0900",
        "eventMessage": "flutter: " + EXPECTED,
    }
    value.update(changes)
    return value


class CompletionReaderTest(unittest.TestCase):
    def test_current_launch_literal_marker_passes(self):
        value = event()
        self.assertIs(matching_event([value], 123, STARTED), value)

    def test_other_process_cannot_pass(self):
        self.assertIsNone(matching_event([event(processID=456)], 123, STARTED))

    def test_past_launch_cannot_pass(self):
        self.assertIsNone(matching_event([event(timestamp="2026-11-10 09:59:59+0900")], 123, STARTED))

    def test_wrong_revision_cannot_pass(self):
        self.assertIsNone(matching_event([event(eventMessage=EXPECTED.replace("fb37f24", "0000000"))], 123, STARTED))

    def test_no_marker_cannot_pass(self):
        self.assertIsNone(matching_event([event(eventMessage="All tests passed!")], 123, STARTED))
        self.assertIsNone(matching_event([], 123, STARTED))


if __name__ == "__main__":
    unittest.main()

"""Run headless parity without depending on Flutter VM-service discovery."""

import argparse
from datetime import datetime, timezone
import json
import pathlib
import plistlib
import re
import subprocess
import time

EXPECTED = (
    "OVERLAP_PILOT_PASS mergeCases=29 workloads=48 abi=1 "
    "source=fb37f24a86014829a31897ca891d45a78208aa6c"
)


def matching_event(events, pid, started):
    """Reject markers from another process, an earlier launch or another core."""
    for event in events:
        if event["processID"] != pid:
            continue
        timestamp = datetime.fromisoformat(event["timestamp"])
        if timestamp < started:
            continue
        if event["eventMessage"].rsplit("flutter: ", 1)[-1].strip() == EXPECTED:
            return event
    return None


def wait_for_pass(device, pid, started, timeout):
    """Read persisted native logs so a fast startup message cannot be missed."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = subprocess.run(
            [
                "xcrun", "simctl", "spawn", device, "log", "show", "--last", "5m",
                "--style", "json", "--predicate",
                'process == "Runner" AND eventMessage CONTAINS "OVERLAP_PILOT_PASS"',
            ],
            capture_output=True,
            text=True,
            check=True,
            timeout=min(20, max(0.1, deadline - time.monotonic())),
        )
        event = matching_event(json.loads(result.stdout), pid, started)
        if event is not None:
            print(json.dumps(event), flush=True)
            return
        time.sleep(min(2, max(0, deadline - time.monotonic())))
    raise TimeoutError("This Simulator launch did not report parity before the deadline")


def main():
    """Install and run the supplied example, then terminate only that app."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=pathlib.Path, required=True)
    parser.add_argument("--device", required=True)
    parser.add_argument("--timeout", type=float, default=120)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    with (args.app / "Info.plist").open("rb") as source:
        bundle = plistlib.load(source)["CFBundleIdentifier"]
    subprocess.run(
        ["xcrun", "simctl", "install", args.device, str(args.app)],
        check=True,
        timeout=90,
    )
    passed = False
    try:
        started = datetime.now(timezone.utc)
        launch = subprocess.run(
            ["xcrun", "simctl", "launch", "--terminate-running-process", args.device, bundle],
            capture_output=True,
            text=True,
            check=True,
            timeout=30,
        )
        match = re.fullmatch(re.escape(bundle) + r":\s+(\d+)\s*", launch.stdout.strip())
        if match is None:
            raise RuntimeError("Cannot identify the launched Simulator process: " + launch.stdout)
        wait_for_pass(args.device, int(match[1]), started, args.timeout)
        passed = True
    finally:
        cleanup = subprocess.run(
            ["xcrun", "simctl", "terminate", args.device, bundle],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        if passed and cleanup.returncode != 0:
            raise RuntimeError("Failed to terminate the pilot app: " + cleanup.stderr)


if __name__ == "__main__":
    main()

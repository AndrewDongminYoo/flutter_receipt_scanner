"""Build a source archive, unpack independently and run an offline consumer.

This is a independently assembled source-archive check, not a substitute for pub publish
--dry-run or mobile artifact size measurement. Never downloads core sources.
"""
import pathlib
import subprocess
import tarfile
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]


def run(*args, cwd):
    subprocess.run(args, cwd=cwd, check=True)


def main():
    with tempfile.TemporaryDirectory(prefix="receipt-core-packed-") as temporary:
        workspace = pathlib.Path(temporary)
        archive = workspace / "receipt_scanner_core.tar.gz"
        with tarfile.open(archive, "w:gz") as packed:
            for name in ("LICENSE", "README.md", "CHANGELOG.md", "pubspec.yaml", "lib", "hook", "third_party"):
                packed.add(ROOT / name, arcname=name)
        package = workspace / "core"
        package.mkdir()
        with tarfile.open(archive) as packed:
            packed.extractall(package, filter="data")
        run("python3", "third_party/receipt_core/vendor.py", "--check", cwd=package)
        manifest = package / "pubspec.yaml"
        manifest.write_text(manifest.read_text().replace("resolution: workspace\n", ""))
        consumer = workspace / "consumer"
        consumer.mkdir()
        (consumer / "pubspec.yaml").write_text(
            "name: packed_consumer\nenvironment:\n  sdk: ^3.14.0\ndependencies:\n"
            "  receipt_scanner_core:\n    path: ../core\n"
        )
        (consumer / "main.dart").write_text(
            "import 'package:receipt_scanner_core/receipt_scanner_core.dart';\n"
            "void main() { final n = findReceiptOverlap(['coffee 1000', 'bread 2000'],"
            " ['coffee 1000', 'bread 2000']); if (n != 2) throw StateError('$n');"
            " print('PACKED_CONSUMER_PASS overlap=$n'); }\n"
        )
        run("dart", "pub", "get", "--offline", cwd=consumer)
        run("dart", "run", "main.dart", cwd=consumer)
        print(f"Source archive bytes={archive.stat().st_size}; packed source consumer verified")


if __name__ == "__main__":
    main()

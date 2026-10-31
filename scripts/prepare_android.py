"""Download a private Android/JDK toolchain, without changing global Java or PATH."""

import hashlib
import json
import sys
import zipfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from xml.etree import ElementTree

import requests

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / ".tools"


def download(url, destination, algorithm, checksum):
    destination.parent.mkdir(parents=True, exist_ok=True)
    digest = hashlib.new(algorithm)
    with requests.get(url, stream=True, timeout=(20, 120)) as response:
        response.raise_for_status()
        with destination.open("wb") as output:
            for block in response.iter_content(1024 * 1024):
                digest.update(block)
                output.write(block)
    if digest.hexdigest().lower() != checksum.lower():
        raise RuntimeError(f"Checksum không khớp: {destination.name}")


def extract(archive_path, target, strip_prefix=False):
    target.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive_path) as archive:
        for info in archive.infolist():
            parts = Path(info.filename).parts
            if strip_prefix:
                parts = parts[1:]
            if not parts:
                continue
            output = target.joinpath(*parts).resolve()
            if not output.is_relative_to(target.resolve()):
                raise RuntimeError("Archive path ngoài thư mục toolchain.")
            if info.is_dir():
                output.mkdir(parents=True, exist_ok=True)
            else:
                output.parent.mkdir(parents=True, exist_ok=True)
                output.write_bytes(archive.read(info))
    archive_path.unlink()  # Only the verified archive downloaded by this script.


def prepare_jdk():
    jdk_root = TOOLS / "jdk"
    existing = list(jdk_root.glob("*/bin/javac.exe"))
    if existing:
        return existing[0].parent.parent
    response = requests.get(
        "https://api.adoptium.net/v3/assets/latest/21/hotspot",
        params={
            "architecture": "x64",
            "image_type": "jdk",
            "os": "windows",
            "vendor": "eclipse",
        },
        timeout=30,
    )
    response.raise_for_status()
    package = response.json()[0]["binary"]["package"]
    archive = TOOLS / "downloads" / "jdk21.zip"
    download(package["link"], archive, "sha256", package["checksum"])
    extract(archive, jdk_root)
    return next(jdk_root.glob("*/bin/javac.exe")).parent.parent


def prepare_sdk():
    sdk_root = TOOLS / "android-sdk"
    sdk_manager = sdk_root / "cmdline-tools" / "latest" / "bin" / "sdkmanager.bat"
    if sdk_manager.exists():
        return sdk_root
    response = requests.get(
        "https://dl.google.com/android/repository/repository2-3.xml", timeout=30
    )
    response.raise_for_status()
    manifest = ElementTree.fromstring(response.content)
    package = next(
        p
        for p in manifest.iter("remotePackage")
        if p.attrib.get("path") == "cmdline-tools;latest"
    )
    archive_info = next(
        a
        for a in package.findall("archives/archive")
        if a.findtext("host-os") == "windows"
    )
    archive = TOOLS / "downloads" / "android-command-tools.zip"
    download(
        "https://dl.google.com/android/repository/"
        + archive_info.findtext("complete/url"),
        archive,
        "sha1",
        archive_info.findtext("complete/checksum"),
    )
    extract(archive, sdk_root / "cmdline-tools" / "latest", strip_prefix=True)
    return sdk_root


if __name__ == "__main__":
    with ThreadPoolExecutor(max_workers=2) as executor:
        jdk_future = executor.submit(prepare_jdk)
        sdk_future = executor.submit(prepare_sdk)
        jdk, sdk = jdk_future.result(), sdk_future.result()
    (TOOLS / "android-toolchain.json").write_text(
        json.dumps(
            {
                "jdk_relative": str(jdk.relative_to(ROOT)),
                "sdk_relative": str(sdk.relative_to(ROOT)),
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    print("JDK và Android command-line tools sẵn sàng trong .tools.")

"""Smoke-test the installed debug APK on Aster_API34 with the local SQL Server API."""

import re
import subprocess
import time
from pathlib import Path
from xml.etree import ElementTree

import requests

ROOT = Path(__file__).resolve().parent.parent
ADB = ROOT / ".tools/android-sdk/platform-tools/adb.exe"
ARTIFACTS = ROOT / ".artifacts"
SCREENSHOTS = ROOT / "docs/screenshots"
BASE = "http://127.0.0.1:8000/api/v1/"


def adb(*arguments):
    return subprocess.run(
        [str(ADB), "-s", "emulator-5554", *map(str, arguments)],
        check=True,
        capture_output=True,
        timeout=15,
    ).stdout


def shell(*arguments):
    return adb("shell", "-n", *arguments)


def tree():
    shell("uiautomator", "dump", "/sdcard/aster-ui.xml")
    path = ARTIFACTS / "android-ui.xml"
    adb("pull", "/sdcard/aster-ui.xml", path)
    return ElementTree.parse(path).getroot()


def tap_where(predicate, scroll=False):
    for _ in range(4):
        nodes = list(tree().iter("node"))
        for node in nodes:
            attributes = node.attrib
            if attributes.get("clickable") != "true" or not predicate(attributes):
                continue
            x1, y1, x2, y2 = map(int, re.findall(r"\d+", attributes["bounds"]))
            if x2 > x1 and y2 > y1:
                shell("input", "tap", (x1 + x2) // 2, (y1 + y2) // 2)
                time.sleep(0.7)
                return
        if scroll:
            shell("input", "swipe", 360, 1250, 360, 500, 350)
        time.sleep(0.4)
    labels = [
        n.attrib.get("content-desc", "")
        for n in nodes
        if n.attrib.get("clickable") == "true"
    ]
    raise AssertionError(f"Native control not found: {labels}")


def tap(label, prefix=False, scroll=False):
    tap_where(
        lambda a: (
            a.get("content-desc", "").startswith(label)
            if prefix
            else a.get("content-desc") == label
        ),
        scroll=scroll,
    )


def screenshot(name):
    shell("screencap", "-p", "/sdcard/aster-screen.png")
    adb("pull", "/sdcard/aster-screen.png", SCREENSHOTS / name)


def main():
    shell("am", "force-stop", "vn.asterhotel.aster_hotel")
    shell("am", "start", "-n", "vn.asterhotel.aster_hotel/.MainActivity")
    # First cold start also loads the Android keystore and restores JWT.
    time.sleep(7)
    password = re.search(
        r"^DEMO_PASSWORD=(.+)$", (ROOT / "backend/.env").read_text(), re.MULTILINE
    )[1].strip()
    if any(n.attrib.get("password") == "true" for n in tree().iter("node")):
        tap_where(
            lambda a: (
                a.get("class") == "android.widget.EditText"
                and a.get("password") == "false"
            )
        )
        shell("input", "text", "letan")
        shell("input", "keyevent", 61)
        shell("input", "text", password)
        shell("input", "keyevent", 4)
        time.sleep(0.5)
        screenshot("android-login.png")
        tap("Đăng nhập")
        time.sleep(2)
    response = requests.post(
        BASE + "auth/login/",
        json={"username": "admin", "password": password},
        timeout=10,
    )
    response.raise_for_status()
    tokens = response.json()
    headers = {"Authorization": "Bearer " + tokens["access"]}
    before = requests.get(BASE + "bookings/", headers=headers, timeout=10).json()
    previous_ids = {item["id"] for item in before["results"]}
    business_date = requests.get(
        BASE + "dashboard/", headers=headers, timeout=10
    ).json()["date"]
    from datetime import date, timedelta

    available = requests.get(
        BASE + "rooms/availability/",
        headers=headers,
        params={
            "start_date": business_date,
            "end_date": (
                date.fromisoformat(business_date) + timedelta(days=1)
            ).isoformat(),
            "guests": 1,
        },
        timeout=10,
    ).json()["results"]
    assert available, "Need one available demo room for the smoke test."
    room_number = available[0]["number"]
    created = None
    try:
        tap("Đặt phòng\nTab", prefix=True)
        tap("Đặt phòng mới")
        tap("Chọn khách hàng")
        tap("Nguyễn Minh An", prefix=True)
        tap("Tiếp tục")
        tap(room_number, prefix=True)
        tap("Tiếp tục")
        screenshot("android-booking-review.png")
        tap_where(lambda a: a.get("clickable") == "true" and a.get("content-desc") == "Đặt phòng")
        time.sleep(1)
        after = requests.get(BASE + "bookings/", headers=headers, timeout=10).json()
        new = [item for item in after["results"] if item["id"] not in previous_ids]
        assert len(new) == 1, "Native submit must create exactly one booking."
        created = new[0]
        assert (
            created["room"]["number"] == room_number
            and created["status"] == "confirmed"
        )
        screenshot("android-bookings.png")
        tap_where(
            lambda a: (
                a.get("content-desc", "").startswith(room_number)
                and created["status_label"] in a.get("content-desc", "")
            )
        )
        tap("Thao tác khác", scroll=True)
        tap("Hủy đặt phòng")
        tap("Hủy đặt phòng")
        time.sleep(0.5)
        cancelled = requests.get(
            BASE + f"bookings/{created['id']}/", headers=headers, timeout=10
        ).json()
        assert cancelled["status"] == "cancelled"
        tap("Đóng")
        shell("am", "force-stop", "vn.asterhotel.aster_hotel")
        shell("am", "start", "-n", "vn.asterhotel.aster_hotel/.MainActivity")
        time.sleep(2)
        restored = tree()
        assert any(
            "Phòng sẵn sàng" in n.attrib.get("content-desc", "")
            for n in restored.iter("node")
        )
        assert not any(
            n.attrib.get("password") == "true" for n in restored.iter("node")
        )
        screenshot("android-dashboard.png")
        print(
            "Android smoke passed: live booking create/cancel and secure session restore."
        )
    finally:
        if created:
            requests.post(
                BASE + f"bookings/{created['id']}/cancel/", headers=headers, timeout=10
            )
        requests.post(
            BASE + "auth/logout/",
            json={"refresh": tokens["refresh"]},
            headers=headers,
            timeout=10,
        )


if __name__ == "__main__":
    main()

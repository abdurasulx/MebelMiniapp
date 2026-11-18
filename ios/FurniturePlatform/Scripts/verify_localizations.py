#!/usr/bin/env python3
"""Check permission translations in a built .app or an .xcarchive's .app."""

import plistlib
import sys
from pathlib import Path


def read_plist(path):
    # Xcode compiles .strings to binary plists in the built app.
    with path.open("rb") as source:
        return plistlib.load(source)


def verify(app):
    info = read_plist(app / "Info.plist")
    expected = {"uz", "en", "ru", "tg", "tr", "ky", "kk", "de", "az"}
    declared = set(info.get("CFBundleLocalizations", []))
    if declared != expected:
        raise ValueError(f"Unexpected app localizations: {sorted(declared)}")
    if info.get("CFBundleDevelopmentRegion") != "en":
        raise ValueError("The development language must match the English fallback")

    keys = {key for key in info if key.startswith("NS") and key.endswith("UsageDescription")}
    if not keys:
        raise ValueError("No permission descriptions found in the app")

    for language in sorted(expected):
        strings = read_plist(app / f"{language}.lproj" / "InfoPlist.strings")
        for key in sorted(keys):
            value = strings.get(key)
            if not isinstance(value, str) or not value.strip():
                raise ValueError(f"Missing {language} translation for {key}")
            if language == "en" and value != info[key]:
                raise ValueError(f"English translation and fallback differ for {key}")
        print(f"OK {language}: {len(keys)} permission descriptions")

    print(f"Verified {info['CFBundleShortVersionString']} ({info['CFBundleVersion']}): {app}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: python3 verify_localizations.py /path/to/VidaMarket.app")
    try:
        verify(Path(sys.argv[1]))
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        sys.exit(f"FAIL: {error}")

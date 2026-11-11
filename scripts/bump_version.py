import re
import sys
from pathlib import Path


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "patch"
    custom_ver = sys.argv[2] if len(sys.argv) > 2 else None

    pubspec_path = Path("pubspec.yaml")
    app_version_path = Path("lib/core/app_version.dart")

    content = pubspec_path.read_text(encoding="utf-8")
    m = re.search(r"^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)", content, re.MULTILINE)
    if not m:
        print("ERROR: Could not parse version in pubspec.yaml", file=sys.stderr)
        sys.exit(1)

    major, minor, patch, build = map(int, m.groups())
    new_build = build + 1

    if mode == "custom" and custom_ver:
        parts = custom_ver.strip().lstrip("v").split(".")
        if len(parts) != 3 or not all(p.isdigit() for p in parts):
            print("ERROR: Invalid custom version format. Expected X.Y.Z", file=sys.stderr)
            sys.exit(1)
        new_ver = f"{int(parts[0])}.{int(parts[1])}.{int(parts[2])}"
    elif mode == "major":
        new_ver = f"{major + 1}.0.0"
    elif mode == "minor":
        new_ver = f"{major}.{minor + 1}.0"
    else:  # patch
        new_ver = f"{major}.{minor}.{patch + 1}"

    new_full = f"{new_ver}+{new_build}"
    updated_pubspec = re.sub(
        r"^version:\s*\d+\.\d+\.\d+\+\d+",
        f"version: {new_full}",
        content,
        count=1,
        flags=re.MULTILINE,
    )
    pubspec_path.write_text(updated_pubspec, encoding="utf-8")

    dart_content = f"""/// معلومات إصدار التطبيق الحالية (تُحدّث تلقائياً عند عمل Release جديد)
class AppVersion {{
  static const String version = '{new_ver}';
  static const int buildNumber = {new_build};

  static String get displayVersion => 'v$version';
  static String get fullVersion => 'v$version ($buildNumber)';
}}
"""
    app_version_path.write_text(dart_content, encoding="utf-8")
    print(new_ver)


if __name__ == "__main__":
    main()


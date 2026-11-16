import re
import sys

def bump_build_number(pubspec_path="mobile/pubspec.yaml"):
    with open(pubspec_path, "r", encoding="utf-8") as f:
        content = f.read()

    match = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)", content, re.MULTILINE)
    if not match:
        print("Version format not found in pubspec.yaml")
        sys.exit(1)

    version_name = match.group(1)
    old_build = int(match.group(2))
    new_build = old_build + 1
    new_version_str = f"version: {version_name}+{new_build}"

    new_content = re.sub(
        r"^version:\s*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+",
        new_version_str,
        content,
        flags=re.MULTILINE
    )

    with open(pubspec_path, "w", encoding="utf-8") as f:
        f.write(new_content)

    print(f"BUMPED: {version_name}+{old_build} -> {version_name}+{new_build} (versionCode: {new_build})")
    return new_build

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "mobile/pubspec.yaml"
    bump_build_number(path)

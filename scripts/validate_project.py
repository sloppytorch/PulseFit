#!/usr/bin/env python3
"""Structural validation for the PulseFit Xcode project (run from repo root).

Checks:
 1. project.pbxproj: old-style plist delimiter balance, unique 24-hex IDs,
    all referenced IDs defined, Sources phases match the .swift files on disk.
 2. Info.plist parses as XML.
 3. All asset-catalog Contents.json files parse; AppIcon.png present.
 4. Every .swift file passes a mini-lexer check (balanced (), [], {},
    string literals, \\( interpolation, // and block comments).
 5. Flags iOS 17-only APIs and common typos the lexer can't see.
"""

import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
failures = []


def fail(msg):
    failures.append(msg)


# ---------------------------------------------------------------- Swift lexer

def check_swift(path: Path):
    src = path.read_text(encoding="utf-8")
    contexts = [{"paren": 0, "brack": 0, "brace": 0}]
    modes = ["code"]  # "code" | "string"
    i, n, line = 0, len(src), 1
    where = str(path.relative_to(ROOT))

    def err(msg):
        fail(f"{where}:{line}: {msg}")

    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        mode = modes[-1]
        if mode == "code":
            if src.startswith("//", i):
                j = src.find("\n", i)
                i = n if j == -1 else j
                continue
            if src.startswith("/*", i):
                j = src.find("*/", i + 2)
                if j == -1:
                    err("unterminated block comment")
                    return
                line += src.count("\n", i, j)
                i = j + 2
                continue
            if src.startswith('"""', i):
                j = src.find('"""', i + 3)
                if j == -1:
                    err("unterminated multiline string")
                    return
                line += src.count("\n", i, j)
                i = j + 3
                continue
            if c == '"':
                modes.append("string")
                i += 1
                continue
            ctx = contexts[-1]
            if c == "(":
                ctx["paren"] += 1
            elif c == ")":
                if ctx["paren"] == 0:
                    if len(contexts) > 1:  # closing a \( interpolation
                        contexts.pop()
                        modes.pop()
                    else:
                        err("unbalanced ')'")
                        return
                else:
                    ctx["paren"] -= 1
            elif c == "[":
                ctx["brack"] += 1
            elif c == "]":
                ctx["brack"] -= 1
                if ctx["brack"] < 0:
                    err("unbalanced ']'")
                    return
            elif c == "{":
                ctx["brace"] += 1
            elif c == "}":
                ctx["brace"] -= 1
                if ctx["brace"] < 0:
                    err("unbalanced '}'")
                    return
        else:  # inside a single-line string
            if c == "\\" and i + 1 < n:
                if src[i + 1] == "(":
                    contexts.append({"paren": 0, "brack": 0, "brace": 0})
                    modes.append("code")
                i += 2
                continue
            if c == '"':
                modes.pop()
        i += 1

    if len(contexts) > 1 or modes[-1] != "code":
        err("unterminated string or interpolation at EOF")
        return
    ctx = contexts[0]
    if ctx["paren"] or ctx["brack"] or ctx["brace"]:
        err(f"unclosed delimiters at EOF: {ctx}")


# ---------------------------------------------------------------- pbxproj

def check_pbxproj():
    pbx = ROOT / "PulseFit.xcodeproj" / "project.pbxproj"
    text = pbx.read_text(encoding="utf-8")

    # Balance via the same lexer idea (comments + quoted strings).
    depth_paren = depth_brace = 0
    in_string = False
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if in_string:
            if c == "\\" and i + 1 < n:
                i += 2
                continue
            if c == '"':
                in_string = False
        else:
            if text.startswith("/*", i):
                j = text.find("*/", i + 2)
                if j == -1:
                    fail("pbxproj: unterminated comment")
                    return
                i = j + 2
                continue
            if c == '"':
                in_string = True
            elif c == "(":
                depth_paren += 1
            elif c == ")":
                depth_paren -= 1
            elif c == "{":
                depth_brace += 1
            elif c == "}":
                depth_brace -= 1
            if depth_paren < 0 or depth_brace < 0:
                fail("pbxproj: negative nesting depth")
                return
        i += 1
    if depth_paren or depth_brace or in_string:
        fail(f"pbxproj: unbalanced (paren={depth_paren}, brace={depth_brace}, in_string={in_string})")

    # IDs: definitions start after two tabs at line start.
    defined = re.findall(r"^\t\t([0-9A-F]{24}) ", text, re.M)
    if len(defined) != len(set(defined)):
        fail("pbxproj: duplicate object IDs")
    defined_set = set(defined)

    all_ids = set(re.findall(r"\b([0-9A-F]{24})\b", text))
    missing = all_ids - defined_set
    if missing:
        fail(f"pbxproj: referenced but undefined IDs: {sorted(missing)}")

    # Swift files on disk vs Sources phases. Phase file lines are indented 4
    # tabs; the PBXBuildFile section (2 tabs) reuses the same comment text.
    on_disk = sorted(
        str(p.relative_to(ROOT / "PulseFit"))
        for p in (ROOT / "PulseFit").rglob("*.swift")
    )
    tests_on_disk = sorted(
        str(p.relative_to(ROOT / "PulseFitTests"))
        for p in (ROOT / "PulseFitTests").rglob("*.swift")
    )
    in_sources = sorted(
        re.findall(r"^\t{4}[0-9A-F]{24} /\* (\S+\.swift) in Sources \*/", text, re.M)
    )
    disk_names = sorted(
        p.split("/")[-1] for p in on_disk + tests_on_disk
    )
    if set(disk_names) != set(in_sources):
        fail(f"pbxproj Sources mismatch: disk={disk_names} pbxproj={sorted(set(in_sources))}")
    if len(in_sources) != len(set(in_sources)):
        fail("pbxproj: duplicate entries in Sources phases")
    if not on_disk or len(tests_on_disk) < 2:
        fail("expected 18 app sources and >=2 test sources on disk")

    return on_disk


# ---------------------------------------------------------------- main

def main():
    print("== Swift structural checks ==")
    swift_files = sorted(ROOT.rglob("*.swift"))
    for path in swift_files:
        check_swift(path)
        # Common gotchas the lexer can't catch.
        src = path.read_text(encoding="utf-8")
        name = str(path.relative_to(ROOT))
        for bad, desc in [
            (r"onChange\(of:[^)]*\)\s*\{\s*\w+,\s*\w+\s+in", "iOS17 two-parameter onChange"),
            (r"ContentUnavailableView", "iOS17 ContentUnavailableView"),
            (r"\.symbolEffect", "iOS17 symbol effects"),
            (r"@Observable", "iOS17 @Observable macro"),
            (r"import Charts", "Swift Charts (intentionally unused)"),
            (r"=\s+=", "'= =' double assignment"),
        ]:
            if re.search(bad, src):
                fail(f"{name}: flagged pattern: {desc}")
    print(f"  scanned {len(swift_files)} Swift files")

    print("== Xcode project ==")
    on_disk = check_pbxproj()
    print(f"  pbxproj OK; {len(on_disk)} app/test sources wired")

    print("== Info.plist ==")
    try:
        ET.parse(ROOT / "PulseFit" / "Info.plist")
        print("  XML parses OK")
    except ET.ParseError as e:
        fail(f"Info.plist XML error: {e}")

    print("== Asset catalog ==")
    for j in (ROOT / "PulseFit" / "Assets.xcassets").rglob("Contents.json"):
        try:
            json.loads(j.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            fail(f"{j}: {e}")
    icon = ROOT / "PulseFit" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"
    if not icon.exists() or icon.stat().st_size < 10_000:
        fail("AppIcon.png missing or suspiciously small")
    else:
        print(f"  JSONs OK, icon present ({icon.stat().st_size // 1024} KB)")

    print()
    if failures:
        print(f"VALIDATION FAILED ({len(failures)}):")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)
    print("ALL CHECKS PASSED")


if __name__ == "__main__":
    main()

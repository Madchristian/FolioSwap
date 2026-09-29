"""Build and audit a deterministic local ZIP, without publishing or installing.

Stored members avoid compressor-version differences. Only the TOC version token
is transformed; all other source bytes (including line endings) are preserved.
This is a local producer, not a claim of byte equality with BigWigs output.
"""
import argparse
import datetime
import hashlib
import io
import json
import re
import stat
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = (
    "Locales/enUS.lua", "Locales/deDE.lua", "Core/Util.lua", "Core/FolioApi.lua",
    "Core/Presets.lua", "UI/Skin.lua", "Core/ProfileStore.lua", "Core/Player.lua",
    "Core/Reporter.lua", "Core/Actions.lua", "Core/SwapController.lua", "UI/FlatUI.lua",
    "UI/SkinOptions.lua", "UI/SlashCommands.lua", "UI/FolioPanel.lua", "Core/Bootstrap.lua",
)
FILES = ("FolioSwap.toc", *RUNTIME, "LICENSE", "CHANGELOG.md")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def source_payload(version):
    require(re.fullmatch(r"[0-9]{4}\.[1-9][0-9]?\.[1-9][0-9]?", version),
            "Expected CalVer YYYY.M.D without a v prefix or leading zeroes")
    date = datetime.date(*map(int, version.split(".")))
    payload = {}
    for name in FILES:
        path = ROOT / name
        require(not path.is_symlink() and path.resolve().is_relative_to(ROOT.resolve()),
                "Unsafe source path: " + name)
        payload[name] = path.read_bytes()
    toc = payload["FolioSwap.toc"]
    lines = toc.decode("utf-8").splitlines()
    runtime = tuple(line.strip().replace("\\", "/") for line in lines
                    if line.strip() and not line.lstrip().startswith("#"))
    require(runtime == RUNTIME, "TOC runtime differs from explicit ordered allowlist")
    for metadata in ("## Interface: 120100", "## X-License: All Rights Reserved",
                     "## X-Wago-ID: bGoYYJ60", "## X-Curse-Project-ID: 1718288",
                     "## SavedVariables: FolioSwapDB", "## Version: @project-version@"):
        require(lines.count(metadata) == 1, "Missing or repeated TOC metadata: " + metadata)
    require(toc.count(b"@project-version@") == 1, "Expected exactly one version token")
    heading = f"## [{version}] - {date.isoformat()}"
    require(heading in payload["CHANGELOG.md"].decode("utf-8").splitlines(),
            "Changelog does not contain the exact release version and date")
    payload["FolioSwap.toc"] = toc.replace(b"@project-version@", version.encode("ascii"))
    return payload


def build(payload):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", compression=zipfile.ZIP_STORED) as archive:
        for name in sorted(payload):
            info = zipfile.ZipInfo("FolioSwap/" + name, date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            archive.writestr(info, payload[name])
    return buffer.getvalue()


def verify(data, payload):
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        expected = ["FolioSwap/" + name for name in sorted(FILES)]
        require(archive.namelist() == expected, "ZIP entries differ from exact allowlist")
        require(archive.testzip() is None, "ZIP integrity failure")
        require(not archive.comment, "Unexpected ZIP comment")
        for entry in archive.infolist():
            name = entry.filename
            require(name.startswith("FolioSwap/") and "\\" not in name
                    and all(part not in ("", ".", "..") for part in name.split("/")),
                    "Unsafe ZIP path")
            require(stat.S_ISREG(entry.external_attr >> 16) and not entry.flag_bits & 1,
                    "ZIP member is not a regular unencrypted file")
            require(archive.read(name) == payload[name.removeprefix("FolioSwap/")],
                    "Packaged bytes differ from source: " + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    payload = source_payload(args.version)
    data = build(payload)
    verify(data, payload)
    require(build(payload) == data, "Rebuild is not deterministic")
    output = args.output or ROOT / ".release" / f"FolioSwap-{args.version}.zip"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(data)
    verify(output.read_bytes(), source_payload(args.version))
    print(json.dumps({"path": str(output.resolve()), "version": args.version,
                      "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
                      "entries": len(payload), "source_sha256": {
                          name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                          for name in sorted(FILES)}}, indent=2))


if __name__ == "__main__":
    main()

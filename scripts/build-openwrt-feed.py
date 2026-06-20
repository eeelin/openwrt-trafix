#!/usr/bin/env python3
import argparse
import gzip
import hashlib
import io
import os
import pathlib
import shutil
import tarfile
from collections import defaultdict


def open_inner_tar_from_ipk(ipk_path: pathlib.Path, candidate_names):
    with ipk_path.open("rb") as f:
        magic = f.read(8)

    if magic.startswith(b"\x1f\x8b"):
        with tarfile.open(ipk_path, mode="r:gz") as ipk_tf:
            for member in ipk_tf.getmembers():
                name = member.name.lstrip("./")
                if name in candidate_names:
                    return ipk_tf.extractfile(member).read()
        raise RuntimeError(f"inner tar {candidate_names} not found in {ipk_path}")

    if magic == b"!<arch>\n":
        import subprocess

        members = subprocess.check_output(["ar", "t", str(ipk_path)], text=True).splitlines()
        for candidate in candidate_names:
            if candidate in members:
                return subprocess.check_output(["ar", "p", str(ipk_path), candidate])
        raise RuntimeError(f"inner tar {candidate_names} not found in {ipk_path}")

    raise RuntimeError(f"unsupported ipk format: {ipk_path}")


def read_control_fields(ipk_path: pathlib.Path) -> dict:
    control_bytes = open_inner_tar_from_ipk(
        ipk_path,
        ("control.tar.gz", "control.tar.xz", "control.tar.zst", "control.tar"),
    )
    with tarfile.open(fileobj=io.BytesIO(control_bytes), mode="r:*") as tf:
        control_info = None
        for member in tf.getmembers():
            name = member.name.lstrip("./")
            if name == "control":
                control_info = member
                break
        if control_info is None:
            raise RuntimeError(f"control file not found in {ipk_path}")
        control_text = tf.extractfile(control_info).read().decode()

    fields = {}
    current_key = None
    for line in control_text.splitlines():
        if line.startswith((" ", "\t")) and current_key:
            fields[current_key] += "\n" + line
            continue
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        current_key = key.strip()
        fields[current_key] = value.lstrip()
    return fields


def sha256sum(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def write_packages_file(entries, target_dir: pathlib.Path):
    packages_path = target_dir / "Packages"
    with packages_path.open("w", encoding="utf-8") as f:
        for fields in entries:
            for key, value in fields.items():
                f.write(f"{key}: {value}\n")
            f.write("\n")
    with gzip.open(target_dir / "Packages.gz", "wb") as gz:
        gz.write(packages_path.read_bytes())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", required=True)
    parser.add_argument("--output-dir", required=True)
    args = parser.parse_args()

    artifacts_dir = pathlib.Path(args.artifacts_dir)
    output_dir = pathlib.Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    grouped = defaultdict(list)
    for ipk_path in sorted(artifacts_dir.rglob("*.ipk")):
        fields = read_control_fields(ipk_path)
        arch = fields.get("Architecture")
        if not arch:
            raise RuntimeError(f"Architecture missing in {ipk_path}")
        target_dir = output_dir / arch
        target_dir.mkdir(parents=True, exist_ok=True)
        dest_name = ipk_path.name
        dest_path = target_dir / dest_name
        shutil.copy2(ipk_path, dest_path)
        fields["Filename"] = dest_name
        fields["Size"] = str(dest_path.stat().st_size)
        fields["SHA256sum"] = sha256sum(dest_path)
        grouped[arch].append(fields)

    for arch, entries in grouped.items():
        write_packages_file(entries, output_dir / arch)

    index_lines = ["# OpenWrt trafix feed", ""]
    for arch in sorted(grouped):
        index_lines.append(f"- {arch}/Packages.gz")
    (output_dir / "index.md").write_text("\n".join(index_lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

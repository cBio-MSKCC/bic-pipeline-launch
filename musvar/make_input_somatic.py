#!/usr/bin/env python3
"""Build a Sarek somatic (tumor/normal) input sheet from an IGO sample mapping.

usage: make_input_somatic.py SAMPLE_MAPPING.txt
"""

import csv
import gzip
import os
import re
import sys
from pathlib import Path


def get_lane_from_fastq(ff: str) -> str:
    """Return "<SID>:<flowcell>_<lane>" using the fastq name and its first read header."""
    sid = re.sub(r"_IGO_.*", "", os.path.basename(ff))
    with gzip.open(ff, "rt") as fh:
        header = fh.readline().rstrip("\n")
    # FASTQ header: @<instrument>:<run>:<flowcell>:<lane>:...  -> fields 3 and 4 (1-based)
    parts = header.split(":")
    return f"{sid}:{parts[2]}_{parts[3]}"


def get_fastq_files(fdir: str, read: int) -> list[str]:
    """Recursively find sorted _R{read}_<digits>.fastq.gz files under fdir."""
    pattern = re.compile(rf"_R{read}_\d+\.fastq\.gz")
    matches = [str(p) for p in Path(fdir).rglob("*.fastq.gz") if pattern.search(p.name)]
    return sorted(matches)


def clean_sample(sample: str) -> str:
    sample = re.sub(r"^s_", "", sample)
    if "Mouse-Pooled-Normal" in sample:
        sample = re.sub(r"-\d+$", "", sample)
    return sample


def add_patient_ids(manifest: list[dict]) -> None:
    """Set ``patient`` so each normal and the tumors paired to it share an id.

    IDs (``P_1``, ``P_2``, ...) are numbered by first appearance.
    A non-tumor row groups on its own sample name. A tumor groups on ``Paired``.
    """
    group_ids = {}
    next_id = 1
    for row in manifest:
        key = row["sample"] if row.get("SampleType") != "Tumor" else row.get("Paired", "")
        if key not in group_ids:
            group_ids[key] = f"P_{next_id}"
            next_id += 1
        row["patient"] = group_ids[key]


def read_mapping(mapping_file: str) -> list[tuple[str, str]]:
    """Return (sample, fastq_dir) from a headerless TSV. Columns used are 2 and 4."""
    samples = []
    with open(mapping_file, newline="") as fh:
        for cols in csv.reader(fh, delimiter="\t"):
            if len(cols) < 4 or not any(cols):
                continue
            samples.append((clean_sample(cols[1]), cols[3]))
    return samples


def expand_fastq_pairs(samples: list[tuple[str, str]]) -> list[dict]:
    rows = []
    for sample, fdir in samples:
        for fastq_1, fastq_2 in zip(get_fastq_files(fdir, 1), get_fastq_files(fdir, 2)):
            rows.append({"sample": sample, "fastq_1": fastq_1, "fastq_2": fastq_2})
    return rows


def write_csv(path: str, fieldnames: list[str], rows: list[dict]) -> None:
    with open(path, "w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    if len(sys.argv) < 2:
        print("\n   usage: make_input_somatic.py SAMPLE_MAPPING.txt\n")
        sys.exit(0)

    mapping_file = sys.argv[1]
    rows = expand_fastq_pairs(read_mapping(mapping_file))

    if any(row["fastq_1"].replace("_R1_", "_R2_") != row["fastq_2"] for row in rows):
        print("\n\nFATAL ERROR R1,R2 mismatch\n")
        raise SystemExit("FATAL ERROR")

    mfile = mapping_file.replace("mapping", "metadata")
    if not os.path.exists(mfile):
        print(f"\n\n   Metadata {mfile} does not exists")
        print("   Create file with columns:\n      sample,patient,type")
        print("       type==[Normal|Tumor] (Case sensitive)\n")
        print("   Template file created _sample_manifest.csv\n")
        seen = list(dict.fromkeys(row["sample"] for row in rows))
        write_csv(
            "_sample_manifest.csv",
            ["sample", "patient", "type"],
            [{"sample": sample, "patient": "", "type": ""} for sample in seen],
        )
        sys.exit(0)

    with open(mfile, newline="") as fh:
        manifest = list(csv.DictReader(fh))
    for row in manifest:
        row["status"] = "1" if row.get("SampleType") == "Tumor" else "0"
        row["sample"] = re.sub(r"^s_", "", row.get("SampleName") or "")
    add_patient_ids(manifest)

    by_sample: dict[str, list[dict]] = {}
    for row in manifest:
        by_sample.setdefault(row["sample"], []).append(row)

    sarek_input = []
    for rec in rows:
        matches = by_sample.get(rec["sample"], [None])
        for meta in matches:
            sarek_input.append({
                "patient": "" if meta is None else meta["patient"],
                "sample": rec["sample"],
                "status": "" if meta is None else meta["status"],
                "lane": get_lane_from_fastq(rec["fastq_1"]),
                "fastq_1": rec["fastq_1"],
                "fastq_2": rec["fastq_2"],
            })

    outfile = os.path.join(os.path.dirname(mapping_file), "sarek_input_somatic.csv")
    write_csv(
        outfile,
        ["patient", "sample", "status", "lane", "fastq_1", "fastq_2"],
        sarek_input,
    )


if __name__ == "__main__":
    main()

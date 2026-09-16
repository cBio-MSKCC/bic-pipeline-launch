#!/usr/bin/env python3
"""Build a Sarek somatic (tumor/normal) input sheet from an IGO sample mapping.

Python port of makeSarekInputSomatic.R.

usage: makeSarekInputSomatic.py SAMPLE_MAPPING.txt
"""

import gzip
import os
import re
import sys
from pathlib import Path

import pandas as pd


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

def add_patient_ids(manifest: pd.DataFrame) -> pd.DataFrame:
    """Add a ``patient`` column grouping each tumor with its paired normal.

    A patient is a normal sample plus every tumor whose ``Paired`` points at it.
    Patient IDs (``P_1``, ``P_2``, ...) are numbered by first appearance.
    """
    manifest = manifest.copy()
    group_key = manifest["sample"].where(
        manifest["SampleType"] != "Tumor", manifest["Paired"]
    )
    manifest["patient"] = "P_" + (pd.factorize(group_key)[0] + 1).astype(str)
    return manifest

def main() -> None:
    if len(sys.argv) < 2:
        print("\n   usage: makeSarekInputSomatic.py SAMPLE_MAPPING.txt\n")
        sys.exit(0)

    mapping_file = sys.argv[1]

    # --- Parse the mapping file (tab-separated, no header) ---
    mapping = pd.read_csv(mapping_file, sep="\t", header=None, dtype=str)
    fdir = mapping[[1, 3]].rename(columns={1: "sample", 3: "fdir"})

    fdir["sample"] = fdir["sample"].str.replace(r"^s_", "", regex=True)
    is_pool = fdir["sample"].str.contains("Mouse-Pooled-Normal")
    fdir.loc[is_pool, "sample"] = fdir.loc[is_pool, "sample"].str.replace(
        r"-\d+$", "", regex=True
    )

    # Expand each directory into one row per R1/R2 fastq pair.
    rows = []
    for rec in fdir.itertuples(index=False):
        fastq_1 = get_fastq_files(rec.fdir, 1)
        fastq_2 = get_fastq_files(rec.fdir, 2)
        for f1, f2 in zip(fastq_1, fastq_2):
            rows.append({"sample": rec.sample, "fastq_1": f1, "fastq_2": f2})
    fdir = pd.DataFrame(rows, columns=["sample", "fastq_1", "fastq_2"])

    # --- R1/R2 pairing sanity check ---
    expected_r2 = fdir["fastq_1"].str.replace("_R1_", "_R2_", regex=False)
    if not (expected_r2 == fdir["fastq_2"]).all():
        print("\n\nFATAL ERROR R1,R2 mismatch\n")
        raise SystemExit("FATAL ERROR")

    # --- Metadata: mapping -> m, .txt ->  ---
    mfile = mapping_file.replace("mapping", "metadata")
    if not os.path.exists(mfile):
        print(f"\n\n   Metadata {mfile} does not exists")
        print("   Create file with columns:\n      sample,patient,type")
        print("       type==[Normal|Tumor] (Case sensitive)\n")
        print("   Template file created _sample_manifest.csv\n")
        template = fdir[["sample"]].drop_duplicates().copy()
        template["patient"] = pd.NA
        template["type"] = pd.NA
        template.to_csv("_sample_manifest.csv", index=False)
        sys.exit(0)

    manifest = pd.read_csv(mfile, dtype=str)
    manifest["status"] = (manifest["SampleType"] == "Tumor").astype(int)
    manifest["sample"] = manifest["SampleName"].str.replace(r"^s_", "", regex=True)

    manifest = add_patient_ids(manifest)

    # --- Join, compute lane, write output ---
    sarek_input = fdir.merge(manifest, on="sample", how="left")
    sarek_input["lane"] = sarek_input["fastq_1"].apply(get_lane_from_fastq)
    sarek_input = sarek_input[["patient", "sample", "status", "lane", "fastq_1", "fastq_2"]]

    sarek_input.to_csv("sarek_input_somatic.csv", index=False)


if __name__ == "__main__":
    main()


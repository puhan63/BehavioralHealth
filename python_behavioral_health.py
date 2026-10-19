#!/usr/bin/env python3

"""
Behavioral Health Claims - Date Correction

This script corrects enrollment and claim date inconsistencies
in the synthetic datasets used for my healthcare analytics project.

During the initial data validation, I found that many medical and
pharmacy claims had dates outside their members' enrollment periods.
This caused a large number of claims to be excluded from the analysis.

To address this, the script:
- Corrects inconsistent enrollment dates.
- Adjusts claim dates that fall outside enrollment periods.
- Preserves claim dates that are already valid.
- Saves corrected CSV files without changing the originals.
- Creates an audit file documenting each correction.

Replacement dates are randomly generated within each member's
enrollment period using a fixed seed. These dates are synthetic
and do not represent actual healthcare service dates or preserve
treatment chronology.

Run with:
    python correct_behavioral_health_dates.py --input-dir . --output-dir corrected

Requires pandas and numpy.
"""

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

OBS_START = pd.Timestamp("2021-01-01")
OBS_END = pd.Timestamp("2024-12-31")
SEED = 20241010
FILES = {
    "members": "members_behavioral_health.csv",
    "providers": "providers_behavioral_health.csv",
    "medical": "medical_claims_behavioral_health.csv",
    "pharmacy": "pharmacy_claims_behavioral_health.csv",
}
AUDIT_COLUMNS = ["dataset", "record_id", "field", "original_value", "corrected_value", "reason"]


def load_files(input_dir):
    """Read the four source CSVs without changing them."""
    return {
        name: pd.read_csv(
            input_dir / filename,
            dtype={"member_id": "Int64"} if name != "providers" else None,
        )
        for name, filename in FILES.items()
    }


def fix_member_dates(members, audit):
    """Set a reporting cutoff for open enrollment and swap reversed dates."""
    if members.member_id.isna().any() or members.member_id.duplicated().any():
        raise ValueError("Member IDs must be unique and nonmissing.")

    for column in ("enrollment_start", "enrollment_end"):
        members[column] = pd.to_datetime(members[column], errors="coerce")

    if members.enrollment_start.isna().any():
        raise ValueError("Missing or invalid enrollment starts need manual review.")
    if ((members.enrollment_start < OBS_START) | (members.enrollment_start > OBS_END)).any():
        raise ValueError("Enrollment starts outside the reporting period need review.")

    missing_end = members.enrollment_end.isna()
    for idx in members.index[missing_end]:
        audit.append(("members", int(members.at[idx, "member_id"]), "enrollment_end",
                      "", "2024-12-31", "ongoing_enrollment_cutoff"))
    members.loc[missing_end, "enrollment_end"] = OBS_END

    reversed_period = members.enrollment_end < members.enrollment_start
    for idx in members.index[reversed_period]:
        member_id = int(members.at[idx, "member_id"])
        start = members.at[idx, "enrollment_start"]
        end = members.at[idx, "enrollment_end"]
        audit.extend([
            ("members", member_id, "enrollment_start", start.date().isoformat(),
             end.date().isoformat(), "swap_reversed_enrollment"),
            ("members", member_id, "enrollment_end", end.date().isoformat(),
             start.date().isoformat(), "swap_reversed_enrollment"),
        ])

    old_starts = members.loc[reversed_period, "enrollment_start"].copy()
    members.loc[reversed_period, "enrollment_start"] = members.loc[
        reversed_period, "enrollment_end"
    ].to_numpy()
    members.loc[reversed_period, "enrollment_end"] = old_starts.to_numpy()

    if (members.enrollment_end > OBS_END).any() or (
        members.enrollment_end < members.enrollment_start
    ).any():
        raise ValueError("Invalid enrollment period remains after corrections.")

    return {
        "members_ongoing_end_filled": int(missing_end.sum()),
        "members_reversed_period_swapped": int(reversed_period.sum()),
    }


def fix_claim_dates(claims, members, dataset, id_column, date_column, rng, audit):
    """Change only claim dates outside the member's enrollment window."""
    if claims[id_column].isna().any() or claims[id_column].duplicated().any():
        raise ValueError(f"{dataset}: claim IDs must be unique and nonmissing.")

    coverage = members.set_index("member_id")[["enrollment_start", "enrollment_end"]]
    if not claims.member_id.isin(coverage.index).all():
        raise ValueError(f"{dataset}: claims reference missing member IDs.")

    dates = pd.to_datetime(claims[date_column], errors="coerce")
    if dates.isna().any():
        raise ValueError(f"{dataset}: missing or invalid claim dates need review.")

    starts = claims.member_id.map(coverage.enrollment_start)
    ends = claims.member_id.map(coverage.enrollment_end)
    outside_coverage = (
        (dates < starts) | (dates > ends) | (dates < OBS_START) | (dates > OBS_END)
    )

    # A fixed seed makes corrections repeatable. This is synthetic repair,
    # not an attempt to recover the original date of care.
    for idx in claims.index[outside_coverage]:
        first_day, last_day = starts.loc[idx], ends.loc[idx]
        days_available = int((last_day - first_day).days)
        new_date = first_day + pd.Timedelta(days=int(rng.integers(0, days_available + 1)))
        audit.append((dataset, int(claims.at[idx, id_column]), date_column,
                      dates.loc[idx].date().isoformat(), new_date.date().isoformat(),
                      "outside_enrollment_reassigned_synthetic_date"))
        dates.loc[idx] = new_date

    claims[date_column] = dates.dt.strftime("%Y-%m-%d")
    if not ((dates >= starts) & (dates <= ends) &
            (dates >= OBS_START) & (dates <= OBS_END)).all():
        raise ValueError(f"{dataset}: claim dates still fall outside coverage.")

    return {
        f"{dataset}_dates_changed": int(outside_coverage.sum()),
        f"{dataset}_dates_preserved": int((~outside_coverage).sum()),
    }


def save_results(data, original, audit, stats, output_dir):
    """Check that no rows or unrelated fields changed, then write outputs."""
    editable_columns = {
        "members": {"enrollment_start", "enrollment_end"},
        "providers": set(),
        "medical": {"service_date"},
        "pharmacy": {"fill_date"},
    }
    # Verify everything before writing any corrected CSVs.
    for dataset, frame in data.items():
        if len(frame) != len(original[dataset]):
            raise ValueError(f"Row count changed in {dataset}.")
        for column in frame.columns:
            if column not in editable_columns[dataset] and not frame[column].equals(
                original[dataset][column]
            ):
                raise ValueError(f"Unexpected change to {dataset}.{column}.")

    output_dir.mkdir(parents=True, exist_ok=True)
    for dataset, frame in data.items():
        frame.to_csv(output_dir / FILES[dataset], index=False)

    pd.DataFrame(audit, columns=AUDIT_COLUMNS).to_csv(
        output_dir / "date_change_audit.csv", index=False
    )

    lines = [
        "SYNTHETIC BEHAVIORAL HEALTH DATA: DATE CORRECTION REPORT",
        "Observation period: 2021-01-01 to 2024-12-31",
        "Input: Mockaroo-generated CSVs; originals preserved",
        f"Seed: {SEED}",
        "",
        "ASSUMPTIONS",
        "Blank enrollment end: ongoing through 2024-12-31.",
        "Reversed enrollment dates: swapped as a synthetic-data assumption.",
        "Out-of-coverage claim dates: reassigned within member enrollment.",
        "Valid dates and all unrelated fields: preserved.",
        "No intentional errors added.",
        "",
        "LIMITATIONS",
        "Replacement dates are synthetic, not actual service dates.",
        "Do not infer treatment chronology, refill timing, or real utilization trends.",
        "This script does not correct risk scores, gender, provider data, or statuses.",
        "SQL validation may still reject records for other reasons.",
        "",
        "COUNTS",
    ]
    lines.extend(f"{dataset}_rows: {len(frame):,}" for dataset, frame in data.items())
    lines.extend(f"{name}: {count:,}" for name, count in stats.items())
    lines.append(f"audit_entries: {len(audit):,}")
    report = "\n".join(lines) + "\n"
    (output_dir / "correction_report.txt").write_text(report, encoding="utf-8")
    print(report)


def main(input_dir, output_dir):
    data = load_files(input_dir)
    original = {name: frame.copy(deep=True) for name, frame in data.items()}
    audit = []

    stats = fix_member_dates(data["members"], audit)
    rng = np.random.default_rng(SEED)
    stats.update(fix_claim_dates(data["medical"], data["members"], "medical",
                                 "claim_id", "service_date", rng, audit))
    stats.update(fix_claim_dates(data["pharmacy"], data["members"], "pharmacy",
                                 "rx_claim_id", "fill_date", rng, audit))

    for column in ("enrollment_start", "enrollment_end"):
        data["members"][column] = data["members"][column].dt.strftime("%Y-%m-%d")

    save_results(data, original, audit, stats, output_dir)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", type=Path, default=Path("."))
    parser.add_argument("--output-dir", type=Path, default=Path("corrected"))
    args = parser.parse_args()
    main(args.input_dir, args.output_dir)

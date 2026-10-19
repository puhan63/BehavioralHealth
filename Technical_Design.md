# Technical Design

**Project:** Behavioral Health Claims Utilization & Risk Analytics  
**Tools:** Python, MySQL / SQL, Tableau Public  
**Data:** Synthetic healthcare records; no real patient information

This document explains how I prepared the data, investigated quality problems, built SQL reporting tables, and designed the three Tableau dashboards. The [README](README.md) gives a shorter project overview and links to the visualizations.

## Contents

- [Data and workflow](#data-and-workflow)
- [Python corrections and data quality](#python-corrections-and-data-quality)
- [SQL preparation and validation](#sql-preparation-and-validation)
- [Reporting tables and calculations](#reporting-tables-and-calculations)
- [Tableau dashboard design](#tableau-dashboard-design)
- [Performance and reproducibility](#performance-and-reproducibility)
- [Limitations and next steps](#limitations-and-next-steps)

## Data and workflow

I started with four synthetic CSV datasets:

| Dataset | Source records |
|---|---:|
| Members | 1,000 |
| Providers | 200 |
| Medical claims | 20,000 |
| Pharmacy claims | 15,000 |

The 35,000 claims are the main focus of the project. Member and provider files supply the reference information needed to interpret them.

The work involved both Python and SQL. Python helped me correct issues in the generated source data. SQL handled loading, standardization, validation, and preparation of the reporting tables. Tableau was used to explore the results.

```text
Synthetic CSV files
       |
       v
Python review and source-data corrections
       |
       v
MySQL raw / staging tables
       |
       v
SQL validation and investigation
       |
       v
Cleaning, standardization, derived fields
       |
       v
Medical and pharmacy reporting tables
       |
       v
Tableau landing page + 3 dashboards
```

## Python corrections and data quality

### Why I revisited the source data

My first SQL validation runs excluded a large share of the claims. That raised a question: were those exclusions revealing genuinely unusable records, or were some problems caused by how the synthetic data had been generated?

Instead of accepting the initial output, I investigated the reasons for the failures. I used Python to help correct issues in the synthetic source data, particularly inconsistencies involving member enrollment dates and claim dates, before returning to SQL for further checks. I also reviewed the risk-score generator and confirmed that its intended scores ran from **0.50 to 3.50**.

This was an important part of the project. A validation rule can be technically correct but still produce misleading results if the test data was generated with inconsistent relationships. I wanted the final analysis to reflect deliberate data preparation decisions, not accidental record loss.

### Main issues investigated

| Area | What I checked or changed |
|---|---|
| Enrollment dates | Compared member coverage periods with medical service dates and pharmacy fill dates; investigated mismatches and corrected synthetic source-data issues |
| Member and provider references | Checked that claims linked to valid reference records |
| Risk scores | Reviewed missing values and verified the generator's intended 0.50–3.50 range |
| Pharmacy statuses | Distinguished legitimate `REVERSED` claims from misspellings such as `PIAD` |
| County values | Standardized inconsistent spelling and capitalization |
| Provider attributes | Flagged missing facility-type information |

**Important distinction:** The original CSVs, corrected source files, staging tables, and final reporting tables serve different purposes. Corrections to synthetic data are not the same as silently changing real-world claims to make them pass validation. This approach is appropriate for a generated portfolio dataset; real production data would require source-system investigation and an approved correction process.

The early rejection totals in the previous version of this document came from older data runs. I have not reused them here because they should not be presented as the final results of the revised project. Final retention and rejection counts should be taken from the latest SQL audit output.

## SQL preparation and validation

### Loading and staging

I used `LOAD DATA LOCAL INFILE` in MySQL to load the CSVs into staging tables. I converted date strings into date fields, trimmed text, and handled missing values before applying the validation rules.

One detail that mattered was preserving blank numeric values as `NULL` rather than allowing them to be interpreted as zero. For example:

```sql
NULLIF(TRIM(@risk_score), '')
```

That keeps a missing risk score separate from an actual numeric value.

### Validation checks

The SQL workflow included checks for:

- Required fields and duplicate identifiers
- Member and provider referential integrity
- Medical service dates and pharmacy fill dates against enrollment periods
- Missing or invalid risk scores
- Pharmacy claim statuses
- Provider facility types
- Consistent county and drug-category values

I used a `rejected_records` table to track records that failed checks, along with their reasons, and an `etl_audit_log` table to help reconcile counts across processing stages. I also used a separate SQL investigation script to understand the failures instead of relying only on rejection totals.

A common pattern was checking references with a `LEFT JOIN`:

```sql
SELECT m.claim_id
FROM stage_medical AS m
LEFT JOIN members_clean AS c
    ON UPPER(TRIM(m.member_id)) = c.member_id
WHERE c.member_id IS NULL;
```

This identifies staged medical claims without a matching cleaned member record. The actual cleaning and validation logic is in the SQL files in this repository.

For records that had already been flagged, I used `NOT EXISTS` patterns to avoid carrying them into downstream tables:

```sql
WHERE NOT EXISTS (
    SELECT 1
    FROM rejected_records AS r
    WHERE r.record_type = 'medical_claim'
      AND r.record_id = stage_medical.claim_id
)
```

### Standardization

I used SQL `CASE` expressions, `UPPER`, and `TRIM` to make categorical fields more consistent. Examples included mapping variations of Milwaukee, Racine, and Waukesha to standard county names and normalizing pharmacy claim statuses to **PAID**, **DENIED**, and **REVERSED**.

The pharmacy-status review was especially useful. An earlier rule treated reversed claims as invalid, even though reversal is a legitimate claim outcome. Updating the accepted values made the analysis more meaningful without treating every unusual value as an error.

## Reporting tables and calculations

The project uses two main Tableau-facing datasets:

- **`tableau_medical_claims`** — medical claim information combined with member risk and provider attributes.
- **`tableau_pharmacy_claims`** — pharmacy claim information combined with member attributes, drug categories, claim status, and cost fields.

Preparing these tables in SQL reduced the amount of joining and cleaning required inside Tableau. I also created or standardized analytical fields such as risk tiers, county names, provider specialties, and drug categories.

Not every calculation belongs in SQL, however. Tableau calculated fields were useful for measures that needed to respond to dashboard selections, including:

| Measure | Definition |
|---|---|
| Medical claims per member | Distinct medical claims ÷ distinct members in the view |
| Average claims per provider | Distinct medical claims ÷ distinct providers in the view |
| Average paid allowed amount | Average of the paid-claim allowed-amount field |
| Pharmacy denial rate | Distinct denied pharmacy claims ÷ distinct pharmacy claims |
| Pharmacy reversal rate | Distinct reversed pharmacy claims ÷ distinct pharmacy claims |
| Average paid drug cost | Average `paid_claim_drug_cost`, which is populated for paid claims |

Using distinct claim IDs helps avoid double counting when evaluating the reporting data. Denial and reversal rates must use **all applicable claims** as their denominator, so a claim-status filter should not be applied in a way that changes that denominator.

## Tableau dashboard design

The workbook now has a **landing page and three analytical dashboards**, each focused on a specific question. The landing page introduces the project and provides navigation to the analyses.

### Dashboard 1 — Member Risk & Medical Claims Utilization

**Question:** How does member risk relate to medical claims utilization and costs?

**Main views:**

- Member distribution by risk tier
- Medical claims per member
- Average paid claim allowed amount by risk tier
- Risk score versus medical claims volume

**Finding:** The relationship between risk score and claims volume was very weak (**R² = 0.0052**). Risk score alone explained little of the variation in utilization in this synthetic dataset.

### Dashboard 2 — Provider Specialty & Medical Claims Utilization

**Question:** How do claims volume, provider workload, and costs vary across specialties?

**Main views:**

- Medical claims by provider specialty
- Average medical claims per provider
- Average paid allowed amount by specialty
- Provider workload versus average paid claim cost

**Findings:** Hospital Medicine had the highest average claims per provider (**145.28**). Endocrinology had the highest average paid allowed amount per claim (**$3,328.89**). The relationship between workload and average paid claim cost was very weak (**R² = 0.03**).

### Dashboard 3 — Pharmacy Claims Utilization & Cost Analysis

**Question:** How do pharmacy claim outcomes and paid drug costs vary across drug categories?

**Main views:**

- Pharmacy claims by drug category
- Denial and reversal rates by drug category
- Average paid pharmacy cost by drug category
- Overall pharmacy claim status distribution

**Findings:** Of the **15,000 pharmacy claims**, **10,787** were paid, **2,070** denied, and **2,143** reversed. Antibiotics had the highest denial rate (**15.60%**), while anxiolytics had the highest reversal rate (**15.35%**). Average paid drug costs were relatively close across the major categories (about **$43.46–$44.87** per claim).

### Navigation, filters, and metric consistency

I kept the dashboards visually consistent, with summary KPI cards, a limited number of charts, and filters chosen for each analysis. The landing page gives viewers one place to start.

The KPI cards were designed to show the full-dataset totals rather than changing with every chart filter. On the pharmacy dashboard, drug-category filtering supports comparisons; a county filter can also be used where available. I avoided applying a claim-status filter to denial and reversal calculations because it could change their meaning.

The workbook's landing page should be the link shared in the repository README once the updated Tableau Public view is published.

## Performance and reproducibility

A few practical choices helped keep the project organized:

- **Staging tables:** Made it easier to inspect raw imports before cleaning.
- **Separate validation checks:** Made unexpected record loss easier to investigate.
- **Audit tables:** Helped compare counts across ETL stages.
- **Indexes:** Added to frequently used identifiers and reporting fields to support joins and queries.
- **Denormalized reporting tables:** Reduced repeated joins when building Tableau views.
- **Repeatable SQL scripts:** Made it possible to rerun the workflow after correcting the synthetic data.

These are useful design choices, but I have not included claims about measured query-speed improvements because I did not run a documented performance benchmark.

## Limitations and next steps

This project uses **synthetic data**, so the patterns should not be interpreted as evidence about actual patients, providers, prescribing behavior, or healthcare costs. The dashboard analyses are descriptive, and weak relationships should not be treated as predictive findings.

Before calling the project fully reproducible, I would also make sure the repository includes the current Python correction script, updated SQL scripts, and the latest data-quality audit results. That would allow someone else to see exactly how the revised datasets were produced.

Potential next steps include adding a final before-and-after validation summary, documenting the Python correction rules in more detail, and testing the pipeline against a second synthetic dataset.

---

**Related files:** 

- [README](README.md) – Project overview and key findings
- [SQL ETL Pipeline](Behavioral_Health_Updated_ETL.sql) – Data cleaning, validation, and reporting tables
- [Data Quality Analysis](Behavioral_Health_Data_Quality_Analysis.sql) – SQL queries used to investigate data quality issues
- [Python Date Correction Script](python_behavioral_health.py) – Corrects inconsistent enrollment and claim dates in the synthetic datasets while preserving the original files and documenting changes

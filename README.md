# Behavioral Health Claims Utilization & Risk Analytics (SQL ETL & Tableau Project)

### Quick Summary:

*  Built a SQL-based ETL pipeline processing 35,000+ behavioral health and pharmacy claims
*  Designed member-level and provider-level analytical data martsCleaned, standardized, and validated highly inconsistent healthcare datasets
*  Implemented enrollment-window validation and strict data integrity checksResolved complex edge cases including risk score handling and pharmacy status anomalies
*  Built Tableau-ready datasets for utilization, risk, and provider performance analysis

This project focuses on building a production-style SQL analytics pipeline that transforms raw, messy behavioral health data into clean, business-ready insights. Using synthetic claims, enrollment files, and provider records, the pipeline uncovers trends in member risk, diagnosis patterns, and pharmacy usage across a health plan's population. Ultimately, it converts highly inconsistent source data into validated, Tableau-ready datasets built to drive real-world healthcare decision-making.

The final output supports two levels of analysis:

```
    •	Population-level trends (member risk, diagnosis mix, and utilization across counties)  
    •	Provider-level behavior (specialty, facility type, and utilization/cost patterns by provider) 
```

> **Note:** All data used in this project is fully synthetic and generated for demonstration purposes only. No real patient, provider, or claims data is used.

### Data Overview

The project uses four synthetic behavioral health datasets:

* Member enrollment and demographic records (~1,000 records)
* Provider reference data — specialty, facility type, and location (~200 records)
* Medical claims with diagnosis, cost, and place of service (~20,000 records)
* Pharmacy claims with drug, cost, and utilization detail (~15,000 records)

All data was processed in a SQL-based ETL pipeline built from raw ingestion to final analytical marts.

### Key Questions This Project Answers:

* What are the top diagnoses? How do conditions like depression, anxiety, and trauma shift across different counties and member risk tiers?
* Are claims processing correctly? Do medical and pharmacy denial, approval, and reversal rates align with normal expectations?
* Where is the highest risk? Which specific counties and risk categories hold the highest concentration of high-cost or high-need members?
* How do provider costs compare? How do different specialties and facilities stack up regarding claim volumes, total spending, and behavioral health focus?
* Why are claims getting rejected? What is the main culprit behind rejections—enrollment gaps, missing provider data, or bad codes?
* What do pharmacy patterns look like? How does psychiatric medication use—including drug types, supply lengths, and costs—change based on a member's risk score?

### Project Architecture:


```
Raw Behavioral Health CSVs (Members, Providers, Medical & Pharmacy Claims)
      │
      ▼
SQL Staging Tables
      │
      ▼
Data Validation & Rejected Records Log
      │
      ▼
Cleaning & Standardization
      │
      ▼
Feature Engineering (risk tiers, age bands, cost tiers, diagnosis groups)
      │
      ▼
Analytical Data Marts
      │
      ├──────────────► Medical Claims Dataset (tableau_medical_claims)
      │
      └──────────────► Pharmacy Claims Dataset (tableau_pharmacy_claims)
                              │
                              ▼
                       Tableau Dashboards
```
### Project Scale:

Numbers below are from an actual run of the pipeline against the synthetic source files.

**Volume in vs. out:**

| Dataset | Raw Rows Loaded | Clean Rows Retained | Retention Rate |
|---|---|---|---|
| Members | 1,000 | 654 | 65.4% |
| Providers | 200 | 194 | 97.0% |
| Medical Claims | 20,000 | 5,859 | 29.3% |
| Pharmacy Claims | 15,000 | 4,435 | 29.6% |

The member and provider tables retain the large majority of records, since most quality issues live at the demographic/reference level rather than being outright missing data. The claims tables see a much lower retention rate — this is intentional and expected: the validation layer enforces referential integrity (a claim is only valid if its member and provider are themselves valid) and enrollment-window logic (a claim is only valid if the service/fill date falls inside the member's active enrollment period), which are the two things that most commonly break in real-world claims feeds.

**What the validation layer caught (top rejection reasons):**

*Medical claims* (20,000 raw → 5,859 clean):
- Service date fell outside the member's enrollment window: 7,073 flagged
- Claim referenced a member ID that didn't pass member validation: 6,955 flagged
- Claim referenced a provider ID that didn't pass provider validation: 350 flagged

*Pharmacy claims* (15,000 raw → 4,435 clean):
- Fill date fell outside the member's enrollment window: 5,461 flagged
- Claim referenced a member ID that didn't pass member validation: 5,104 flagged

*Members* (1,000 raw → 654 clean):
- Invalid enrollment dates (missing, future, or end-before-start): 215 flagged
- Missing gender: 130 flagged
- Risk score missing or out of range: 49 flagged

*Providers* (200 raw → 194 clean):
- Missing facility type: 6 flagged

> Note: a single record can trigger more than one rejection reason, so these counts don't sum exactly to total rows removed — they're meant to show *which* rules are doing the most work, not a partition of the rejected set.

**A real-world data quirk caught during load:** the raw medical claims CSV had blank `length_of_stay` values for the majority of non-inpatient claims (over 1,000 warnings during the `LOAD DATA INFILE` step). This makes sense operationally — length of stay is only a meaningful concept for inpatient claims — but it's exactly the kind of column-level quirk a real claims feed would have, and the pipeline's LOS-handling logic (keeping the value only for inpatient records, flagging inpatient records where it's unexpectedly missing) is designed around it.

**Final analytics-ready output:**
- `tableau_medical_claims`: 5,859 rows, one per validated medical claim, fully joined with member and provider attributes
- `tableau_pharmacy_claims`: 4,435 rows, one per validated pharmacy claim, fully joined with member attributes

## Data Quality & Root-Cause Analysis

Beyond the pipeline's built-in validation, a separate analysis script (`Behavioral_Health_Data_Quality_Analysis.sql`) digs deeper into *why* certain records fail validation — read-only investigative queries that don't modify any tables. This is meant to answer the follow-up questions a data quality report naturally raises, such as:

- **Enrollment mismatches**: Are claims failing because they came in *before* enrollment started, or *after* it ended? How large are those gaps typically (days, months, over a year)? Which members have the most claims outside their enrollment window?
- **Risk score integrity**: What's the distribution of risk scores before and after cleaning? Are any invalid scores slipping through to the clean table? What does the final risk tier breakdown look like?
- **Gender data quality**: What values actually show up in the raw gender field, how many get standardized vs. rejected, and what does the cleaned distribution look like?
- **Pharmacy claim status consistency**: What non-standard status values appear in the raw data, and are they being caught by validation as expected?
- **Facility type completeness**: Which providers are missing facility type, and are they being rejected correctly?
- **County standardization**: How many distinct county spellings exist in the raw data vs. after standardization, and which records fall back to "UNKNOWN"?

This script is meant to be run after the main ETL pipeline, and its output is diagnostic rather than a data product — it's there to spot-check that the validation rules are behaving as intended and to surface patterns that might warrant new rules down the line.

### 1. Risk Score Validation

**Issue:** During initial ingestion, blank `risk_score` values were being silently converted to `0` rather than `NULL` — which would have caused missing risk data to be misclassified as a valid (and very low) risk score.

**Fix:** The load step was updated to explicitly convert blanks to `NULL`, so the validation layer could correctly flag them as missing rather than treating them as legitimate zeros.

**Validation rule:** A risk score is invalid if it's missing, below 0, or above the expected maximum of 5. Invalid records are logged in `rejected_records` and excluded downstream.

**Outcome:** This prevented incomplete risk data from silently skewing member risk segmentation and reporting.

### 2. Enrollment Dates vs. Medical Service Dates

**Issue:** Medical claims were checked to confirm service dates fall within each member's active enrollment window.

| Issue Type | Claims |
|---|---:|
| Before Enrollment Start | 4,725 |
| After Enrollment End | 2,676 |
| **Total Outside Enrollment** | **7,401** |

*Before Enrollment Start* — how far in advance of coverage the claim occurred:

| Timing | Claims |
|---|---:|
| 0–7 days before | 82 |
| 8–30 days before | 280 |
| 31–90 days before | 610 |
| 91–365 days before | 2,326 |
| Over 1 year before | 1,427 |

Average gap: **~277 days** before enrollment started.

*After Enrollment End* — how long after coverage ended the claim occurred:

| Timing | Claims |
|---|---:|
| 0–7 days after | 45 |
| 8–30 days after | 193 |
| 31–90 days after | 442 |
| 91–365 days after | 1,340 |
| Over 1 year after | 656 |

**ETL decision:** Since most exceptions fell far outside any reasonable billing-timing window (not just a few days of normal lag), these were treated as genuine data quality issues rather than minor timing noise — logged to `rejected_records`, excluded from utilization analysis, but retained for audit and potential source-system follow-up.

### 3. Pharmacy Claim Status Validation

**Issue:** An earlier version of the validation rule rejected 2,144 pharmacy claims for "invalid" claim status.

| Rejected Status | Count |
|---|---:|
| REVERSED | 2,142 |
| REVERSE | 1 |
| PIAD | 1 |

**Investigation:** Profiling the rejected values showed `REVERSED` (and its variant `REVERSE`) is a legitimate pharmacy claim lifecycle status, not a data error — it had simply been left out of the accepted-status list. `PIAD` was a genuine data entry typo for `PAID`.

**ETL improvement:** The validation rule was updated to accept `PAID`, `DENIED`, and `REVERSED` (plus their common abbreviations/typos), while continuing to reject truly invalid values.

**Outcome:** This distinguished real business statuses from actual data errors, preventing thousands of legitimate reversed claims from being incorrectly excluded from analysis.

### 4. Facility Type Validation

**Issue:** 6 providers were missing a `facility_type` value.

**Validation rule:** Facility type is invalid if missing or blank; invalid providers are logged and excluded from downstream provider analysis.

**Outcome:** Ensured provider-level reporting (facility comparisons, utilization by facility type) is based only on complete classification data.

### 5. County Standardization Validation

**Issue:** Member county values used inconsistent naming and spelling (extra spaces, mixed case, common misspellings).

| Original Value | Standardized Value |
|---|---|
| Milwaukee | MILWAUKEE |
| Milwauke | MILWAUKEE |
| Waukesh | WAUKESHA |
| Rasine | RACINE |

**ETL decision:** Values were standardized to uppercase with misspellings mapped to their correct county; unrecognized or missing values were mapped to `UNKNOWN` rather than dropped, preserving those members in analysis while flagging their location as unresolved.

**Outcome:** Consistent geographic grouping in the final Tableau-ready datasets.

> **Note:** Figures in this section come from a separate run of the investigative analysis script and may differ slightly from the headline counts in *Pipeline Results* above (e.g., due to re-generated synthetic source data between runs). The value of this section is in the *patterns and decisions* it documents, not in reconciling exact totals across runs.


### Repository Contents:

📄 Full SQL ETL Pipeline: [View SQL Code](https://github.com/puhan63/BehavioralHealth/blob/main/Behavioral%20Health%20Queries.sql)

🔍 Data Quality & Root-Cause Analysis: `Behavioral_Health_Data_Quality_Analysis.sql`

📁 Cleaned Analytical Data Marts: `tableau_medical_claims`, `tableau_pharmacy_claims`

📘 Data Documentation: this README

🧠 Feature Engineering Logic: risk tiers, age bands, cost tiers, and diagnosis categories (documented above)

📊 Tableau Dashboard: not yet published

### Key SQL Techniques

The complete SQL ETL pipeline can be viewed here:

➡️ **[Full SQL Pipeline](https://github.com/puhan63/BehavioralHealth/blob/main/Behavioral%20Health%20Queries.sql)**

**1. Anti-join validation pattern (`NOT EXISTS`)**

Validation and cleaning are kept decoupled — a record fails validation once, and every downstream query simply excludes anything logged in `rejected_records`, without ever deleting the raw or staged data:

```sql
WHERE NOT EXISTS (
    SELECT 1 FROM rejected_records r
    WHERE r.record_type = 'medical_claim'
      AND r.record_id = stage_medical.claim_id
)
```

**2. Referential integrity via `LEFT JOIN` + `IS NULL`**

Every claim is checked against the cleaned member and provider tables to catch orphaned foreign keys before they reach the analytics layer:

```sql
FROM stage_medical m
LEFT JOIN members_clean c
       ON UPPER(TRIM(m.member_id)) = c.member_id
WHERE c.member_id IS NULL
```

**3. Fuzzy standardization with layered `CASE` / `LIKE`**

Misspellings and formatting variants are collapsed into a single canonical value — used for both county names and drug names:

```sql
CASE
    WHEN UPPER(TRIM(county)) LIKE '%MILWAUKEE%'
         OR UPPER(TRIM(county)) LIKE '%MILWAUKE%'
        THEN 'MILWAUKEE'
    WHEN UPPER(TRIM(county)) LIKE '%RACINE%'
         OR UPPER(TRIM(county)) LIKE '%RACIN%'
         OR UPPER(TRIM(county)) LIKE '%RASINE%'
        THEN 'RACINE'
    ELSE 'UNKNOWN'
END AS county
```

**4. Load-time NULL handling with session variables**

Blank numeric values from the raw CSV are explicitly converted to `NULL` at load time rather than being silently coerced to `0` — a fix directly tied to a real data quality bug found during validation (see *Data Quality Investigations* above):

```sql
LOAD DATA LOCAL INFILE '...'
INTO TABLE raw_members
...
(member_id, dob, gender, county, enrollment_start, enrollment_end, @risk_score)
SET risk_score = NULLIF(TRIM(@risk_score), '');
```

**5. Full audit trail via metadata tables**

Two lightweight tables give the pipeline a complete data-quality audit trail without adding complexity to the transformation logic itself:

- `rejected_records` — row-level log of every record that failed validation, with a specific rejection reason
- `etl_audit_log` — aggregate row counts before/after cleaning at each stage, for quick reconciliation

```sql
INSERT INTO etl_audit_log (process_step, source_table, rows_before, rows_after, rows_removed)
SELECT
    'medical_claim_clean_load',
    'medical_claims_clean',
    (SELECT COUNT(*) FROM stage_medical),
    (SELECT COUNT(*) FROM medical_claims_clean),
    (SELECT COUNT(*) FROM rejected_records WHERE record_type = 'medical_claim');
```
### Interactive Tableau Dashboards:

This project includes a multi-dashboard Tableau solution consisting of a landing page and four analytical dashboards. The dashboards allow users to explore behavioral health claims utilization patterns at both the population and provider levels.

### View Interactive Tableau Dashboard:

[Behavioral Health Claims Analytics Dashboard](https://public.tableau.com/app/profile/patricia.uhan/viz/BehavioralHealthTableau/BehavioralHealthClaimsAnalyticsDashboard?publish=yes)

### Dashboard Navigation:

![Landing Page](https://github.com/puhan63/BehavioralHealth/blob/main/Behavioral%20Health%20Claims%20Analytics%20Dashboard.png)

### Behavioral Health Executive Overview (Executive View)

![Behavioral Health Executive Overview](https://github.com/puhan63/BehavioralHealth/blob/main/Behavioral%20Health%20Executive%20Overview%20(1).png)

This dashboard explores overall claim volume, cost, and member risk profile, along with diagnosis-level spend and monthly claims trends across the member population.

tableau_medical_claims

		 •	5,859 rows (one row per validated medical claim)

			Contains:

			•	Member risk score and risk tier
            •	Diagnosis category
			•	Claim status, place of service, length of stay
            •	Allowed amount and cost tier
			•	Provider specialty and domain
			

			Used for:

            •	Executive KPI summary
			•	Risk score vs. cost analysis
            •	Diagnosis-level cost breakdown
			•	Monthly claims trend tracking

### Behavioral Health Utilization & Population Analysis

![Behavioral Health Utilization & Population Analysis](https://github.com/puhan63/BehavioralHealth/blob/main/Behavioral%20Health%20Utilization%20%26%20Population%20Analysis.png)

This dashboard explores diagnosis mix, risk tier, age band, and geographic variation in behavioral health utilization across counties.

tableau_medical_claims

		 •	5,859 rows (one row per validated medical claim)

			Contains:

			•	Member age, age band, gender, county
			•	Risk score and risk tier
			•	Diagnosis category
			•	Service date, service year/month

			Used for:

			•	Population segmentation by risk and demographics
			•	County-level utilization comparisons
			•	Diagnosis mix trends over time
			•	Identifying where high-risk members are concentrated

### Provider Performance & Care Delivery Analysis

![Provider Performance & Care Delivery Analysis](https://github.com/puhan63/BehavioralHealth/blob/main/Provider%20Performance%20%26%20Care%20Delivery%20Analysis.png)

This dashboard explores claim volume, cost, and utilization patterns across provider specialties, domains, and facility types.

tableau_medical_claims

		 •	5,859 rows (one row per validated medical claim)

			Contains:

			•	Provider specialty and provider domain
			•	Facility type
			•	Claim status and place of service
			•	Allowed amount and cost tier

			Used for:

			•	Provider- and specialty-level cost comparisons
			•	Facility type utilization analysis
			•	Claim status patterns by provider domain
			•	Identifying high-cost or high-volume care settings

### Pharmacy Utilization & Cost Analysis

![Pharmacy Utilization & Cost Analysis](https://github.com/puhan63/BehavioralHealth/blob/main/Pharmacy%20Utilization%20%26%20Cost%20Analysis.png)

This dashboard explores prescription drug utilization, cost, and days-supply patterns across drug categories and member risk tiers.

tableau_pharmacy_claims

		 •	4,435 rows (one row per validated pharmacy claim)

			Contains:

			•	Member risk score and risk tier
			•	Drug name and drug category
			•	Days supply and days-supply band
			•	Quantity and quantity band
			•	Claim status and cost tier

			Used for:

			•	Medication utilization by drug category
			•	Cost and days-supply trend analysis
			•	Risk tier vs. pharmacy spend comparisons
			•	Claim status patterns in pharmacy data

### Key Findings (High-Level Insights)

***Answers to the Key Questions above, based on the dashboard results:***

- **Depression drives the majority of both medical and pharmacy cost** — $3.24M in medical claims and $61,263 in antidepressant pharmacy spend, both by a wide margin over any other category, consistent across counties and age groups.
- **Claim outcomes are healthy but not negligible in exception rate** — pharmacy claims show a 72% paid rate, with the remaining ~28% split between denied (13.3%) and reversed (14.5%).
- **Risk is evenly distributed across the population, but cost is not** — risk tier splits fairly evenly (37.5% moderate, 33.9% low, 28.6% high), while cost is heavily concentrated in Milwaukee and Waukesha counties, where moderate/low-risk members actually drive slightly more total cost than high-risk members — a volume effect more than a risk effect.
- **Primary Care drives the most cost by volume, not by per-claim price** — Primary Care accounts for $5.73M in total cost (3x the next specialty), despite average cost per claim being similar (~$2,000–2,500) across specialties; Outpatient Clinics and Community Health Centers likewise account for most claim volume over Hospitals and Private Practice.
- **Rejected claims were driven primarily by enrollment-window mismatches and broken references, not basic data entry errors** — 7,073 medical and 5,461 pharmacy claims were flagged for falling outside a member's enrollment window, and thousands more for referencing an invalid member or provider, far outweighing rejections for missing/invalid codes.
- **Antidepressants dominate psychiatric medication utilization regardless of segment** — both cost and prescription volume for antidepressants are roughly 4x the next-highest drug category, with a wider cost distribution as well, indicating higher per-prescription cost in addition to higher volume.

### Detailed Dashboard Insights

**Executive Overview**
- The population is 619 members generating 5,859 validated claims and **$12.8M** in total medical cost, averaging **$2,188 per claim**.
- Claims volume ramped up steadily through 2021 (from near-zero to ~150/month) then leveled off around 180–220/month through 2022–2023, consistent with a growing/maturing member population rather than seasonal swings.
- The risk score vs. cost scatterplot shows **no strong correlation** — high-cost claims appear across all three risk tiers, meaning risk score alone isn't a reliable predictor of claim cost.

**Utilization & Population Analysis**
- The 35–49 age band has both the highest claim volume (1,978) and cost, while members 65+ generate a much smaller share (425 claims) — likely a working-age-driven population.
- Depression again leads both claim volume (1,436) and cost by a wide margin, consistent with the Executive Overview.

**Provider Performance & Care Delivery**
- Inpatient length of stay is fairly consistent (~7–8 day median) across specialties, suggesting no single specialty is driving unusually long admissions.

**Pharmacy Utilization & Cost**
- Monthly pharmacy cost is mostly stable ($10K–17K) but includes a sharp one-month spike to $21,053 — worth flagging as an anomaly to investigate further (data issue vs. genuine utilization spike).


### Tableau Dashboards

### Tools & Techniques

### Why This Project Matters

### Future Enhancements





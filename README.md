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

📄 Full SQL ETL Pipeline: `Behavioral_Health_ETL.sql`

🔍 Data Quality & Root-Cause Analysis: `Behavioral_Health_Data_Quality_Analysis.sql`

📁 Cleaned Analytical Data Marts: `tableau_medical_claims`, `tableau_pharmacy_claims`

📘 Data Documentation: this README

🧠 Feature Engineering Logic: risk tiers, age bands, cost tiers, and diagnosis categories (documented above)

📊 Tableau Dashboard: not yet published

### Interactive Tableau Dashboards:

This project includes a multi-dashboard Tableau solution consisting of a landing page and four analytical dashboards. The dashboards allow users to explore behavioral health claims utilization patterns at both the population and provider levels.

### View Interactive Tableau Dashboard:

[Behavioral Health Claims Analytics Dashboard](https://public.tableau.com/app/profile/patricia.uhan/viz/BehavioralHealthTableau/BehavioralHealthClaimsAnalyticsDashboard?publish=yes)

### Dashboard Navigation:

![Landing Page](https://github.com/puhan63/BehavioralHealth/blob/main/Behavioral%20Health%20Claims%20Analytics%20Dashboard.png)



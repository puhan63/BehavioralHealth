# Technical Design

## ETL Architecture

The ETL pipeline was designed using a multi-stage architecture that separates raw data ingestion, validation, transformation, feature engineering, and reporting. Each stage has a clearly defined responsibility, making the pipeline easier to maintain, debug, audit, and extend.

Unlike many simple ETL workflows that clean data in place, this pipeline preserves the original source data while logging every rejected record with its corresponding validation failure. This design provides complete auditability and allows data quality issues to be investigated without losing the original records.

## Pipeline Workflow

```text
Raw Behavioral Health CSVs
(Members, Providers, Medical Claims, Pharmacy Claims)
                    │
                    ▼
          SQL Staging Tables
                    │
                    ▼
      Validation & Rejected Records
                    │
                    ▼
     Cleaning & Standardization
                    │
                    ▼
        Feature Engineering
                    │
                    ▼
       Analytical Data Marts
      ┌──────────────────────────┐
      │                          │
      ▼                          ▼
tableau_medical_claims    tableau_pharmacy_claims
              │
              ▼
      Tableau Dashboards
```

---

## Stage 1 – Raw Data Ingestion

The pipeline begins by loading four synthetic healthcare datasets into SQL staging tables using `LOAD DATA LOCAL INFILE`.

### Source Files

- Member enrollment and demographic records
- Provider reference data
- Medical claims
- Pharmacy claims

The raw data is intentionally left unchanged throughout the ETL process. Preserving the original source files allows every transformation to be traced back to its original record and supports repeatable pipeline execution.

During ingestion, load-time transformations are applied where appropriate. For example, blank numeric values such as `risk_score` are converted to `NULL` instead of being silently interpreted as zero.

---

## Stage 2 – Data Validation

After ingestion, each dataset passes through a comprehensive validation layer before it is eligible for downstream analysis.

Validation rules include:

- Enrollment window validation
- Member identifier validation
- Provider identifier validation
- Risk score validation
- Facility type validation
- Pharmacy claim status validation
- Required field checks
- Referential integrity checks

Rather than deleting invalid records, every failed record is written to the `rejected_records` table together with the specific validation rule that caused the rejection.

This design provides a complete audit trail while keeping the raw staging data intact.

Examples of validation failures include:

- Claims occurring outside a member's enrollment period
- Claims referencing invalid members
- Claims referencing invalid providers
- Missing facility types
- Invalid or missing risk scores
- Unsupported pharmacy claim status values

---

## Stage 3 – Cleaning & Standardization

Validated records are standardized to improve consistency across the analytical datasets.

Cleaning operations include:

- Standardizing county names
- Correcting common spelling variations
- Normalizing pharmacy claim status values
- Standardizing drug categories
- Removing leading and trailing whitespace
- Converting text fields to consistent formatting
- Handling missing values appropriately

For example, county values such as:

- Milwauke
- Milwaukee
- MILWAUKEE

are all standardized to a single canonical value:

```
MILWAUKEE
```

Similarly, pharmacy claim status abbreviations and common typographical errors are mapped to standardized business values before reporting.

---

## Stage 4 – Feature Engineering

Once the data has been cleaned, additional analytical variables are derived to simplify downstream reporting.

Engineered features include:

- Age bands
- Risk tiers
- Cost tiers
- Diagnosis categories
- Standardized provider specialties
- Standardized facility types

Creating these derived variables during ETL keeps dashboard calculations simple while ensuring consistent business logic across every analysis.

---

## Stage 5 – Analytical Data Marts

The final transformation stage produces two Tableau-ready analytical datasets.

### tableau_medical_claims

Contains one record for every validated medical claim joined with:

- Member demographics
- Enrollment information
- Provider attributes
- Diagnosis group
- Risk tier
- Cost tier

### tableau_pharmacy_claims

Contains one record for every validated pharmacy claim joined with:

- Member demographics
- Enrollment information
- Drug category
- Risk tier
- Pharmacy utilization measures

These denormalized analytical tables eliminate the need for complex joins inside Tableau and significantly improve dashboard performance.

---

## Stage 6 – Tableau Reporting

The curated analytical data marts serve as the data source for a Tableau workbook containing four interactive dashboards.

The dashboards support multiple analytical perspectives, including:

- Executive performance metrics
- Population health trends
- Provider utilization
- Pharmacy utilization and cost analysis

Because all validation, cleaning, and feature engineering occur within the SQL ETL pipeline, Tableau functions primarily as a reporting layer rather than a data preparation tool.

---

## Design Principles

Several design principles guided the implementation of the pipeline.

### Separation of Responsibilities

Each stage performs a single responsibility:

- Ingestion loads data.
- Validation identifies bad records.
- Cleaning standardizes valid data.
- Feature engineering creates analytical variables.
- Reporting consumes curated datasets.

This modular design improves maintainability and makes future enhancements easier to implement.

### Auditability

Rather than deleting invalid records, every rejection is logged with a specific reason.

This approach allows rejected records to be investigated later while maintaining complete transparency throughout the ETL process.

### Repeatability

The pipeline drops and recreates all required database objects, making it safe to rerun multiple times during development and testing.

## Validation Framework & Root-Cause Analysis

Data validation is a dedicated stage of the ETL pipeline and serves as the primary quality gate before records are loaded into the final analytical data marts. Rather than silently correcting or deleting invalid data, the pipeline applies a series of business rules, data quality checks, and referential integrity validations to identify records that should be excluded from downstream reporting. Every rejected record is logged in the `rejected_records` table with the specific validation rule that caused the rejection, providing a complete audit trail while preserving the original source data.

The validation framework is designed to ensure that only accurate, internally consistent, and analytically meaningful data reaches the final Tableau-ready datasets. Key validation rules include:

- Enrollment window validation
- Member and provider referential integrity
- Risk score validation
- Required field validation
- Facility type validation
- Pharmacy claim status validation
- County standardization and data consistency checks

While the ETL pipeline identifies and logs validation failures, understanding *why* those failures occur is equally important. To support deeper investigation, this project includes a separate read-only analysis script (`Behavioral_Health_Data_Quality_Analysis.sql`). Rather than modifying data, the script profiles rejected records, investigates the root causes behind validation failures, verifies that validation rules are behaving as intended, and identifies opportunities to improve future iterations of the ETL pipeline.

The investigation focuses on the following areas:

- Risk score validation
- Enrollment window validation
- Pharmacy claim status validation
- Facility type validation
- County standardization

---

The following sections summarize the major validation investigations performed using the `Behavioral_Health_Data_Quality_Analysis.sql` script and the resulting improvements made to the ETL pipeline.

---

### Risk Score Validation

**Issue:** During initial ingestion, blank `risk_score` values were being silently converted to `0` rather than `NULL` — which would have caused missing risk data to be misclassified as a valid (and very low) risk score.

**Fix:** The load step was updated to explicitly convert blanks to `NULL`, so the validation layer could correctly flag them as missing rather than treating them as legitimate zeros.

**Validation rule:** A risk score is invalid if it's missing, below 0, or above the expected maximum of 5. Invalid records are logged in `rejected_records` and excluded downstream.

**Outcome:** This prevented incomplete risk data from silently skewing member risk segmentation and reporting.

### Enrollment Dates vs. Medical Service Dates

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

### Pharmacy Claim Status Validation

**Issue:** An earlier version of the validation rule rejected 2,144 pharmacy claims for "invalid" claim status.

| Rejected Status | Count |
|---|---:|
| REVERSED | 2,142 |
| REVERSE | 1 |
| PIAD | 1 |

**Investigation:** Profiling the rejected values showed `REVERSED` (and its variant `REVERSE`) is a legitimate pharmacy claim lifecycle status, not a data error — it had simply been left out of the accepted-status list. `PIAD` was a genuine data entry typo for `PAID`.

**ETL improvement:** The validation rule was updated to accept `PAID`, `DENIED`, and `REVERSED` (plus their common abbreviations/typos), while continuing to reject truly invalid values.

**Outcome:** This distinguished real business statuses from actual data errors, preventing thousands of legitimate reversed claims from being incorrectly excluded from analysis.

### Facility Type Validation

**Issue:** 6 providers were missing a `facility_type` value.

**Validation rule:** Facility type is invalid if missing or blank; invalid providers are logged and excluded from downstream provider analysis.

**Outcome:** Ensured provider-level reporting (facility comparisons, utilization by facility type) is based only on complete classification data.

 ### County Standardization Validation

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

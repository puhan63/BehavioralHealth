# Technical Design

This document provides detailed technical documentation for the **Behavioral Health Claims Utilization & Risk Analytics** project. It explains the ETL architecture, validation framework, SQL implementation, feature engineering strategy, dashboard design, and performance optimization decisions used to transform raw behavioral health data into analytics-ready datasets for Tableau reporting.

While the repository README provides a high-level overview of the project, this document focuses on the engineering decisions, implementation details, and design principles behind the solution.

---

## Table of Contents

- [ETL Architecture](#etl-architecture)
- [Validation Framework & Root-Cause Analysis](#validation-framework--root-cause-analysis)
- [SQL Design Decisions](#sql-design-decisions)
- [Dashboard Design](#dashboard-design)
- [Performance Optimization](#performance-optimization)
- [Future Enhancements](#future-enhancements)

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

## SQL Design Decisions

The SQL ETL pipeline was designed to prioritize data quality, auditability, and maintainability over simply producing clean output tables. Rather than relying on one-off transformations, the pipeline uses reusable SQL patterns that enforce consistent business rules throughout each stage of processing.

The complete SQL ETL pipeline can be viewed here:

➡️ **[Full SQL Pipeline](https://github.com/puhan63/BehavioralHealth/blob/main/Behavioral%20Health%20Queries.sql)**

---

### Validation Using `NOT EXISTS`

Validation and transformation are intentionally separated. Records are validated once and logged to the `rejected_records` table if they fail any business rule. Downstream transformation queries simply exclude rejected records rather than repeating validation logic or deleting source data.

This approach keeps the ETL pipeline modular, reduces duplicated code, and provides a complete audit trail for every rejected record.

```sql
WHERE NOT EXISTS (
    SELECT 1
    FROM rejected_records r
    WHERE r.record_type = 'medical_claim'
      AND r.record_id = stage_medical.claim_id
)
```

---

### Referential Integrity Using `LEFT JOIN`

Medical and pharmacy claims are validated against the cleaned member and provider reference tables before entering the analytical data marts. Records with missing or invalid foreign keys are identified using `LEFT JOIN` and `IS NULL`.

This ensures that only claims linked to valid members and providers are included in downstream reporting.

```sql
FROM stage_medical m
LEFT JOIN members_clean c
       ON UPPER(TRIM(m.member_id)) = c.member_id
WHERE c.member_id IS NULL
```

---

### Data Standardization Using `CASE` Expressions

Real-world healthcare data frequently contains inconsistent spelling, abbreviations, and formatting. Layered `CASE` expressions combined with pattern matching were used to standardize values into consistent business categories.

This technique was applied to county names, pharmacy claim status values, drug categories, and other categorical fields used throughout the analytical data marts.

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

---

### Load-Time NULL Handling

Missing numeric values should remain missing rather than being converted into valid values. During data ingestion, blank fields are explicitly converted to `NULL` using session variables before validation begins.

This design prevented blank `risk_score` values from being interpreted as legitimate zero values and allowed the validation framework to correctly identify incomplete records.

```sql
LOAD DATA LOCAL INFILE '...'
INTO TABLE raw_members
...
(member_id, dob, gender, county,
 enrollment_start, enrollment_end,
 @risk_score)

SET risk_score = NULLIF(TRIM(@risk_score), '');
```

---

### Audit Logging

The ETL pipeline maintains a complete audit trail using lightweight metadata tables that document both rejected records and pipeline execution statistics.

Two supporting tables provide this functionality:

- **`rejected_records`** – Stores every record rejected during validation together with the specific rejection reason.
- **`etl_audit_log`** – Captures row counts before and after each ETL stage, allowing pipeline execution to be reconciled and monitored.

This approach improves transparency, simplifies debugging, and makes it easy to verify that every transformation stage produced the expected results.

```sql
INSERT INTO etl_audit_log
(
    process_step,
    source_table,
    rows_before,
    rows_after,
    rows_removed
)

SELECT
    'medical_claim_clean_load',
    'medical_claims_clean',
    (SELECT COUNT(*) FROM stage_medical),
    (SELECT COUNT(*) FROM medical_claims_clean),
    (
        SELECT COUNT(*)
        FROM rejected_records
        WHERE record_type = 'medical_claim'
    );
```
---

## Feature Engineering

To support efficient reporting and consistent business logic, several analytical features are derived during the ETL process rather than being calculated within Tableau. Performing feature engineering in SQL ensures that every dashboard, query, and downstream analysis uses the same standardized definitions while reducing the number of calculated fields required in the reporting layer.

The ETL pipeline generates the following derived features:

- **Age Bands** – Groups members into standardized age categories for demographic and utilization analysis.
- **Risk Tiers** – Categorizes members into Low, Moderate, and High risk groups based on validated risk scores.
- **Cost Tiers** – Segments claims into spending categories to support cost distribution and utilization reporting.
- **Diagnosis Categories** – Maps diagnosis codes into broader behavioral health groupings to simplify population-level analysis.
- **Standardized Provider Attributes** – Normalizes provider specialty and facility type values for consistent provider performance reporting.
- **Standardized Geographic Values** – Cleans and standardizes county names to ensure accurate geographic aggregation.

Engineering these features during ETL provides several advantages:

- Maintains consistent business definitions across all dashboards and analyses.
- Improves Tableau performance by reducing complex calculated fields.
- Simplifies downstream reporting and ad hoc SQL analysis.
- Ensures analytical variables are created once and reused throughout the project.
- Produces analytics-ready data marts that require minimal additional transformation before visualization.

This approach reflects a production-style healthcare analytics workflow, where business logic is centralized within the ETL pipeline rather than duplicated across multiple reporting tools.

## Dashboard Design

The SQL ETL pipeline produces two curated analytical data marts (`tableau_medical_claims` and `tableau_pharmacy_claims`) specifically designed for business intelligence reporting. Rather than requiring Tableau to perform complex joins, data cleaning, or feature engineering, all transformations are completed during the ETL process. This allows Tableau to function primarily as a visualization layer, improving dashboard performance while ensuring consistent business logic across every report.

The Tableau workbook consists of a landing page and four analytical dashboards. Each dashboard targets a different business audience while drawing from the same validated analytical datasets, ensuring that key metrics remain consistent regardless of the reporting perspective.

**Live Tableau Workbook:**  
https://public.tableau.com/app/profile/patricia.uhan/viz/BehavioralHealthTableau/PharmacyUtilizationCostAnalysis

---

### Landing Page

The landing page serves as the central navigation hub for the Tableau workbook, allowing users to move between the four analytical dashboards through an intuitive interface.

#### Purpose

- Provide a single entry point for the workbook.
- Improve navigation between dashboards.
- Present a brief overview of the available analyses.
- Create a more polished user experience than navigating individual worksheets.

---

### Executive Overview Dashboard

**Primary Dataset:** `tableau_medical_claims`

#### Business Objective

Provide a high-level summary of behavioral health utilization, member population, and overall financial performance for executive stakeholders.

#### Primary Metrics

- Total validated members
- Total medical claims
- Total medical cost
- Average claim cost
- Monthly claims trend
- Diagnosis-level spending
- Risk score distribution

#### Business Questions Answered

- What is the overall size of the behavioral health population?
- How much has been spent on behavioral health services?
- Which diagnoses contribute the greatest share of healthcare spending?
- How have claims changed over time?
- Does higher clinical risk correspond to higher medical cost?

#### Intended Audience

- Executive leadership
- Healthcare administrators
- Program managers

---

### Population Health Dashboard

**Primary Dataset:** `tableau_medical_claims`

#### Business Objective

Analyze utilization patterns across demographic groups, geographic regions, and clinical risk categories to better understand the behavioral health population.

#### Primary Metrics

- Age distribution
- Gender distribution
- County-level utilization
- Diagnosis mix
- Risk tier distribution
- Geographic concentration of high-risk members

#### Business Questions Answered

- Which age groups generate the highest utilization?
- How does utilization vary across counties?
- Which diagnoses are most common?
- Where are high-risk members concentrated?
- How are members distributed across risk tiers?

#### Intended Audience

- Population health teams
- Clinical leadership
- Care management programs

---

### Provider Performance Dashboard

**Primary Dataset:** `tableau_medical_claims`

#### Business Objective

Evaluate provider utilization, facility performance, and healthcare spending across different provider groups.

#### Primary Metrics

- Provider specialty
- Facility type
- Claim volume
- Total medical cost
- Average claim cost
- Claim status distribution
- Length of stay

#### Business Questions Answered

- Which provider specialties generate the greatest utilization?
- How does utilization differ by facility type?
- Which provider groups account for the highest healthcare spending?
- Are claim outcomes consistent across provider categories?
- Do certain specialties have longer inpatient stays?

#### Intended Audience

- Provider network management
- Quality improvement teams
- Healthcare operations

---

### Pharmacy Utilization & Cost Dashboard

**Primary Dataset:** `tableau_pharmacy_claims`

#### Business Objective

Analyze psychiatric medication utilization, pharmacy spending, and prescription trends across the behavioral health population.

#### Primary Metrics

- Pharmacy cost
- Drug category utilization
- Days supply
- Quantity dispensed
- Monthly pharmacy trends
- Pharmacy claim status
- Risk tier comparisons

#### Business Questions Answered

- Which medication categories drive pharmacy spending?
- How do prescription patterns change across risk tiers?
- Which medications are prescribed most frequently?
- How have pharmacy costs changed over time?
- Are pharmacy claim outcomes within expected ranges?

#### Intended Audience

- Pharmacy leadership
- Behavioral health administrators
- Clinical operations
- Population health analysts

---

### Dashboard Design Principles

Several design principles guided the development of the Tableau workbook.

#### Consistent Business Logic

All calculations, feature engineering, and validation are performed within the SQL ETL pipeline rather than inside Tableau. This ensures every dashboard uses identical business definitions and eliminates inconsistencies between reports.

#### Analytics-Ready Data

The Tableau dashboards connect directly to denormalized analytical data marts that already contain validated member, provider, and claim attributes. This minimizes the need for calculated fields and reduces dashboard complexity.

#### Performance

By precomputing joins, validation logic, and derived variables during ETL, dashboard queries execute efficiently while supporting interactive filtering and drill-down analysis.

#### Audience-Specific Design

Rather than combining every visualization into a single dashboard, the workbook separates executive, population, provider, and pharmacy analytics into focused views tailored to the needs of different stakeholders.

#### Interactive Exploration

The dashboards support interactive filtering, highlighting, and drill-down capabilities, allowing users to explore utilization patterns, compare population segments, and investigate cost drivers without modifying the underlying data.

### Relationship Between the ETL Pipeline and Tableau

The Tableau workbook contains no data preparation logic. All validation, cleaning, feature engineering, and standardization occur within the SQL ETL pipeline before the data reaches Tableau.

This separation of responsibilities allows SQL to serve as the data engineering layer while Tableau functions solely as the presentation and analytical reporting layer. The resulting architecture improves maintainability, ensures consistent business logic across all dashboards, and more closely reflects how production healthcare analytics environments are designed.

## Performance Optimization

Although this project was developed using synthetic behavioral health data, the ETL pipeline was designed using many of the same performance and scalability principles found in production healthcare analytics environments. Performance optimization was considered throughout the design process by reducing unnecessary processing, minimizing repeated transformations, and preparing analytics-ready datasets before they reached the reporting layer.

---

### Targeted Indexing

Indexes were created on frequently queried columns within the cleaned analytical tables to improve filtering, joins, and aggregation performance.

Indexing focused on fields commonly used for reporting, including:

- Member identifiers
- Provider identifiers
- Claim dates
- Diagnosis categories
- Risk tiers
- County
- Provider specialty
- Pharmacy drug category

Creating indexes on these high-use columns reduces query execution time and improves dashboard responsiveness, particularly when applying interactive filters within Tableau.

---

### Denormalized Analytical Data Marts

Rather than requiring Tableau to join multiple normalized tables, the ETL pipeline produces two denormalized analytical data marts:

- `tableau_medical_claims`
- `tableau_pharmacy_claims`

Each table contains validated member, provider, enrollment, and claims information in a single analytics-ready structure.

This design offers several advantages:

- Eliminates expensive joins during reporting.
- Simplifies dashboard development.
- Reduces query complexity.
- Improves interactive dashboard performance.
- Ensures consistent business logic across all visualizations.

---

### Centralized Business Logic

Business rules are implemented within the SQL ETL pipeline instead of being recreated inside Tableau.

Examples include:

- Enrollment window validation
- Risk tier assignment
- Age band generation
- Cost tier categorization
- Diagnosis categorization
- County standardization
- Pharmacy claim status normalization

Centralizing business logic ensures that every dashboard, SQL query, and downstream analysis applies identical transformation rules while reducing duplicate calculations throughout the reporting environment.

---

### Early Data Validation

Data quality validation occurs before records enter the analytical data marts.

Invalid records are identified during the validation stage and written to the `rejected_records` table instead of being processed through subsequent transformations.

This approach provides several performance benefits:

- Reduces the volume of data processed by downstream transformations.
- Prevents invalid records from reaching reporting tables.
- Eliminates repeated validation checks later in the pipeline.
- Simplifies dashboard queries by ensuring only validated records are analyzed.

---

### Repeatable ETL Execution

The pipeline is designed to be rerunnable from start to finish without requiring manual cleanup.

Each execution rebuilds the database objects, reloads the source files, reapplies validation rules, regenerates engineered features, and recreates the analytical data marts.

This repeatable design supports:

- Rapid development and testing
- Consistent validation results
- Reliable quality assurance
- Easy regeneration of analytical datasets when source data changes

---

### SQL-First Reporting Architecture

The project follows a SQL-first architecture in which data preparation is completed before visualization.

The ETL pipeline performs:

- Data ingestion
- Validation
- Cleaning
- Standardization
- Feature engineering
- Data mart creation

Tableau is responsible only for visualization and interactive analysis.

By shifting data preparation from the visualization layer to the ETL pipeline, the solution minimizes dashboard calculations, improves maintainability, and allows multiple business intelligence tools to consume the same validated analytical datasets.

Separating data engineering from reporting reduces dashboard complexity, centralizes business logic, and reflects the architecture commonly used in enterprise healthcare analytics environments.

---

### Scalability Considerations

Although the synthetic datasets used in this project are relatively modest in size, the ETL architecture was designed with scalability in mind.

The modular pipeline structure allows additional validation rules, engineered features, and reporting datasets to be incorporated with minimal changes to the overall workflow. Because validation, transformation, and reporting are separated into distinct stages, each component can be maintained and extended independently as data volume and reporting requirements grow.

This modular design provides a strong foundation for expanding the pipeline to support larger healthcare datasets, additional claims sources, or more advanced analytical workflows in future iterations.

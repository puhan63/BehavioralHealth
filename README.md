# Behavioral Health Claims Utilization & Risk Analytics

### Python | SQL | MySQL | Tableau | Healthcare Data Analytics

#### Project Overview

I created this project to gain hands-on experience working with healthcare claims data, from cleaning and preparing the data to analyzing it and building dashboards.

Using 35,000 synthetic medical and pharmacy claims, I explored three questions:

1. How does member risk relate to medical claims utilization and costs?

2. How do medical claims volume, provider workload, and costs differ across provider specialties?

3. How do pharmacy claim outcomes and paid drug costs vary across drug categories?

I used Python and SQL to investigate data quality issues, correct inconsistencies, and prepare the datasets for analysis. I then used Tableau Public to create three interactive dashboards.

**[View the Tableau Dashboards](https://public.tableau.com/views/BehavioralHealthTableau2/BehavioralHealthClaimsAnalytics?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)**

All data used in this project is synthetic. No real patient information is included.

#### Tools Used

- Python: Investigating data quality issues, correcting synthetic records, and preparing datasets for SQL analysis

- SQL / MySQL Workbench: Data cleaning, validation, transformations, calculations, and analysis

- Tableau Public: Interactive dashboards and data visualization

- Excel / CSV: Reviewing source data and checking data quality

#### Dataset

The project uses four synthetic datasets:

| Dataset | Records |
|---------|--------:|
| Members | 1,000 |
| Providers | 200 |
| Medical Claims | 20,000 |
| Pharmacy Claims | 15,000 |
| **Total** | **36,200** |

The datasets contain member demographics, risk scores, provider specialties, medical claims, pharmacy claim statuses, and cost information.

#### Data Cleaning and Preparation

Data preparation was one of the most involved parts of this project.

I initially used SQL to validate the data, but the results showed that a large number of claims were being excluded. Rather than continuing with a dataset that had lost much of its original information, I investigated the underlying problems.

I used Python to make corrections to the synthetic source data, including reviewing enrollment dates and addressing inconsistencies that affected claim validation. I also reviewed the generated risk scores to make sure they matched the intended range.

After making corrections, I used SQL to continue cleaning, validating, and preparing the data.

This included:

- Checking for missing values, duplicates, and invalid records

- Validating member and provider references

- Checking claim dates against member enrollment periods

- Standardizing county names and pharmacy claim statuses

- Validating risk scores and creating risk categories

- Preparing medical and pharmacy reporting tables for Tableau

The final analytical datasets were organized into two tables:

- tableau_medical_claims

- tableau_pharmacy_claims

More details about the cleaning process, validation rules, and SQL logic are available in Technical_Design.md.

### Tableau Dashboards

#### Dashboard 1: Member Risk & Medical Claims Utilization

**Question:** How does member risk relate to medical claims utilization and costs?

This dashboard explores:

- Member distribution across risk tiers

- Average medical claims per member

- Average paid claim allowed amounts by risk tier

- The relationship between risk scores and medical claims volume

**Key finding:** Risk score had a very weak positive relationship with medical claims volume (R² = 0.0052). Risk score alone explained very little of the variation in utilization in this dataset.

#### Dashboard 2: Provider Specialty & Medical Claims Utilization

**Question:** How do medical claims utilization and costs differ across provider specialties?

This dashboard compares:

- Medical claims volume by specialty

- Average claims per provider

- Average paid allowed amounts by specialty

- Provider workload compared with average paid claim cost

**Key findings:**

- Hospital Medicine had the highest average claims per provider (145.28).

- Endocrinology had the highest average paid allowed amount per claim ($3,328.89).

- The relationship between provider workload and average paid claim cost was very weak (R² = 0.03).

#### Dashboard 3: Pharmacy Claims Utilization & Cost Analysis

**Question:** How do pharmacy claim outcomes and paid drug costs vary across drug categories?

This dashboard includes:

- Pharmacy claims volume by drug category

- Denial and reversal rates by drug category

- Average paid drug costs by category

- Overall pharmacy claim status distribution

**Key findings:**

- Of 15,000 pharmacy claims, 10,787 were paid, 2,070 were denied, and 2,143 were reversed.

- Antibiotic claims had the highest denial rate (15.60%).

- Anxiolytic claims had the highest reversal rate (15.35%).

- Average paid drug costs were fairly similar across the main drug categories, ranging from approximately $43.46 to $44.87 per claim.

These findings describe patterns in synthetic data and should not be interpreted as real-world clinical or prescribing trends.

#### What I Learned

One of the biggest lessons from this project was how much data quality can affect an analysis.

When I first ran my SQL validation checks, too many records were being excluded. I had to investigate why that was happening, review my assumptions, and use Python to correct problems in the synthetic data before continuing.

This helped me better understand how Python and SQL can work together. Python was useful for correcting the source data, while SQL helped me validate the results, build reporting tables, and answer the analytical questions.

I also gained more experience choosing appropriate metrics and interpreting results carefully. For example, total claims by provider specialty can tell a different story than average claims per provider.

Building the Tableau dashboards gave me practice turning those results into visualizations that are easier to understand.

Project Files

| File | Description |
|------|-------------|
| `README.md` | Project overview and key findings |
| `Technical_Design.md` | Data preparation, validation rules, and SQL documentation |
| python_behavioral_health.py | Corrects issues in the synthetic source data before SQL processing |
| `Behavioral_Health_Updated_ETL.sql` | SQL data cleaning, validation, and reporting pipeline |
| `Behavioral_Health_Data_Quality_Analysis.sql` | SQL queries used to investigate data quality issues |
| Tableau dashboards | Three interactive dashboards covering member risk, provider specialty, and pharmacy claims |



















































































































# Behavioral Health Claims Utilization & Risk Analytics (SQL ETL & Tableau Project)

### Quick Summary:

	* Built a production-style SQL ETL pipeline processing 35,000+ synthetic behavioral health and pharmacy claims.
	* Designed member-level and provider-level analytical data marts for downstream analytics and Tableau reporting.
	* Cleaned, standardized, and validated highly inconsistent healthcare datasets using rules-based ETL logic.
	* Implemented enrollment-window validation, referential integrity checks, and comprehensive data quality controls.
	* Investigated and resolved complex data quality issues, including risk score handling, pharmacy claim status validation, and county standardization.
	* Built Tableau-ready datasets powering four interactive dashboards for executive, population, provider, and pharmacy analytics.

This project demonstrates a production-style SQL analytics pipeline that transforms raw, messy behavioral health data into clean, analytics-ready datasets. Using synthetic claims, enrollment, and provider data, the pipeline uncovers trends in member risk, diagnosis patterns, healthcare utilization, and pharmacy usage while enforcing rigorous data quality standards throughout the ETL process.

The final solution supports two complementary levels of analysis:

	* Population-level analytics: Member risk, diagnosis mix, demographic trends, and utilization across counties.
	* Provider-level analytics: Provider specialty, facility type, utilization patterns, and cost analysis.

**Note:** All data used in this project is fully synthetic and generated for demonstration purposes only. No real patient, provider, or claims data is used.

### Tech Stack

- **MySQL Workbench 8.0** — SQL ETL pipeline, data cleaning, validation, feature engineering, analytical data marts, and audit queries.
- **Tableau Public** — Interactive dashboards for executive, population, provider, and pharmacy analytics.

### Data Overview

The project uses four synthetic behavioral health datasets:

* Member enrollment and demographic records (~1,000 records)
* Provider reference data — specialty, facility type, and location (~200 records)
* Medical claims with diagnosis, cost, and place of service (~20,000 records)
* Pharmacy claims with drug, cost, and utilization detail (~15,000 records)

All data was processed in a SQL-based ETL pipeline built from raw ingestion to final analytical marts.

### Why This Project Matters

This project reflects a real-world healthcare analytics workflow:

	- Raw claims and enrollment data is messy and inconsistent
	- Enrollment-window and referential integrity checks are required before analysis
	- Data quality issues must be tracked and resolved, not silently dropped
	- Both population-level and provider-level views are necessary for meaningful insight

The result is a structured, validated analytics pipeline that mirrors how healthcare claims data is prepared in production BI environments.

### What This Project Demonstrates

- **End-to-end ETL design** — raw landing → staging → validation → cleaning/standardization → curated analytics tables
- **Data quality enforcement** — a rules-based validation layer that catches bad records (invalid dates, out-of-range risk scores, orphaned foreign keys, invalid codes) before they reach reporting tables
- **Full auditability** — every rejected record is logged with a specific reason, and an ETL audit log tracks row counts at each stage for reconciliation
- **Real-world data cleaning patterns** — fuzzy-matching misspelled county names, collapsing inconsistent claim status codes (`PAID`, `PD`, `P`, `PIAD` → `PAID`), standardizing drug names and categories
- **Feature engineering for analytics** — derived fields like age bands, risk tiers, cost tiers, and diagnosis categories that make the data immediately usable for dashboarding
- **Root-cause data quality investigation** — going beyond pass/fail validation to explain *why* records fail and adjusting rules based on evidence (e.g., the pharmacy claim status fix)
- **Business intelligence dashboard design** — translating validated data marts into four purpose-built Tableau dashboards for executive, population, provider, and pharmacy audiences
- **Performance-conscious design** — targeted indexing on both the curated tables and the final Tableau-facing tables to support fast filtering and aggregation

### Key Questions This Project Answers:

* What are the top diagnoses? How do conditions like depression, anxiety, and trauma shift across different counties and member risk tiers?
* Are claims processed correctly? Do medical and pharmacy denial, approval, and reversal rates align with normal expectations?
* Where is the highest risk? Which specific counties and risk categories hold the highest concentration of high-cost or high-need members?
* How do provider costs compare? How do different specialties and facilities stack up regarding claim volumes, total spending, and behavioral health focus?
* Why are claims getting rejected? What is the main culprit behind rejections—enrollment gaps, missing provider data, or bad codes?
* What do pharmacy patterns look like? How does psychiatric medication use—including drug types, supply lengths, and costs—change based on a member's risk score?

## Project Architecture

The project follows a modular SQL-based ETL architecture that transforms raw behavioral health data into validated, analytics-ready datasets for Tableau reporting. The pipeline separates data ingestion, validation, transformation, feature engineering, and reporting into distinct stages, making the workflow easier to maintain, audit, and extend.

```text
Raw Behavioral Health Data
(Members, Providers, Medical Claims, Pharmacy Claims)
                │
                ▼
        SQL ETL Pipeline
                │
                ▼
     Validation & Data Quality Checks
                │
                ▼
   Cleaning & Standardization
                │
                ▼
      Feature Engineering
                │
                ▼
   Analytical Data Marts
(tableau_medical_claims &
 tableau_pharmacy_claims)
                │
                ▼
      Tableau Dashboards
```

The ETL pipeline produces two denormalized analytical data marts that support interactive Tableau dashboards for executive reporting, population health analysis, provider performance, and pharmacy utilization.

📘 **For detailed technical documentation, including the ETL architecture, validation framework, SQL implementation, feature engineering, and dashboard design, see [Technical_Design.md](Technical_Design.md).**

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

These analytical data marts serve as the direct data source for the Tableau dashboards, requiring no additional joins or transformations within the reporting layer.

## Data Quality

The ETL pipeline performs comprehensive validation before records enter the analytical data marts, including:

- Enrollment window validation
- Referential integrity checks
- Risk score validation
- Pharmacy claim status validation
- Facility type validation
- County standardization

Additional investigation of validation failures is documented in **Technical_Design.md**.

## Technical Design Documentation

Detailed technical documentation—including the ETL architecture, validation framework, SQL implementation, feature engineering, and dashboard design—is available here:

📘 **[Technical_Design.md](Technical_Design.md)**

## SQL Pipeline

The complete production-style SQL ETL pipeline is available here:

📄 **[Behavioral_Health_ETL.sql](https://github.com/puhan63/BehavioralHealth/blob/main/Behavioral_Health_ETL.sql)**

The script performs:

- Raw data ingestion
- Validation
- Cleaning and standardization
- Feature engineering
- Analytical data mart creation
- Audit logging

## 📊 Interactive Tableau Dashboard

This project includes an interactive Tableau workbook built from the validated analytical data marts generated by the SQL ETL pipeline. The dashboards provide insights into behavioral health utilization, population health trends, provider performance, and pharmacy utilization while using a consistent set of validated business rules and engineered features.

### 🔗 Live Tableau Workbook

**Behavioral Health Claims Analytics Dashboard**

https://public.tableau.com/app/profile/patricia.uhan/viz/BehavioralHealthTableau/BehavioralHealthClaimsAnalyticsDashboard?publish=yes

### Dashboard Preview

#### 🏠 Landing Page

![🏠 Landing Page](https://github.com/puhan63/BehavioralHealth/blob/main/Behavioral%20Health%20Claims%20Analytics%20Dashboard.png)

---

#### 📊 Executive Overview

![📊 Behavioral Health Executive Overview](https://github.com/puhan63/BehavioralHealth/blob/main/Behavioral%20Health%20Executive%20Overview.png)

---

#### 👥 Population Health Analysis

![👥 Behavioral Health Utilization & Population Analysis](https://github.com/puhan63/BehavioralHealth/blob/main/Behavioral%20Health%20Utilization%20%26%20Population%20Analysis.png)

---

#### 🏥 Provider Performance

![🏥 Provider Performance & Care Delivery Analysis](https://github.com/puhan63/BehavioralHealth/blob/main/Provider%20Performance%20%26%20Care%20Delivery%20Analysis.png)

---

#### 💊 Pharmacy Utilization & Cost Analysis

![💊 Pharmacy Utilization & Cost Analysis](https://github.com/puhan63/BehavioralHealth/blob/main/Pharmacy%20Utilization%20%26%20Cost%20Analysis.png)

📘 **Detailed dashboard documentation—including business objectives, key metrics, intended audience, design principles, and the relationship between the SQL ETL pipeline and Tableau—is available in [Technical_Design.md](Technical_Design.md).**

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

### Future Enhancements
	
	- Predictive modeling for high-risk member identification
	- Time-series forecasting for behavioral health utilization and cost trends
	- County-level geographic expansion beyond current coverage
	- Integration of socioeconomic and social determinants of health data
	- Anomaly detection for unusual claims patterns (e.g., the pharmacy cost spike identified in this analysis)
	
### How To Run:

1. Set up a MySQL instance and ensure `local_infile` is enabled.
2. Clone this repository and update the file paths in the `LOAD DATA LOCAL INFILE` statements to point to your local copies of the source CSVs.
3. Run `Behavioral_Health_ETL.sql` (the full pipeline script) top to bottom — it drops and rebuilds all objects, so it's safe to re-run repeatedly during development.
4. Query `tableau_medical_claims` and `tableau_pharmacy_claims` directly, or connect Tableau (or another BI tool) to those tables.
5. Optionally, run `Behavioral_Health_Data_Quality_Analysis.sql` afterward to explore root causes behind rejected records in more depth.

### Repository Contents:

| File                                                                                                                                                                         | Description                                                                                                                                                           |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 📄 **[README.md](README.md)**                                                                                                                                                | Project overview, architecture summary, ETL results, Tableau dashboard previews, and setup instructions.                                                              |
| 📘 **[Technical_Design.md](Technical_Design.md)**                                                                                                                            | Detailed documentation covering the ETL architecture, validation framework, SQL implementation, feature engineering, and dashboard design.  |
| 🗄️ **[Behavioral_Health_ETL.sql](https://github.com/puhan63/BehavioralHealth/blob/main/Behavioral_Health_ETL.sql)**                                             | Complete SQL ETL pipeline including raw data ingestion, validation, cleaning, standardization, feature engineering, analytical data mart creation, and audit logging. |
| 🔍 **[Behavioral_Health Data_Quality_Analysis.sql](https://github.com/puhan63/BehavioralHealth/blob/main/Behavioral_Health_Data_Quality_Analysis.sql)**              | Read-only SQL investigation script used to analyze validation failures, verify ETL rules, and identify root causes behind rejected records.                          |
| 📊 **[Interactive Tableau Workbook](https://public.tableau.com/app/profile/patricia.uhan/viz/BehavioralHealthTableau/BehavioralHealthClaimsAnalyticsDashboard?publish=yes)** | Interactive Tableau workbook containing the Executive Overview, Population Health, Provider Performance, and Pharmacy Utilization dashboards.                         |
| 📁 **Final Analytics Tables**                                                                                                                                                 | Final analytics-ready tables: `tableau_medical_claims` and `tableau_pharmacy_claims`, designed for business intelligence reporting.                                   |


### About the Author

Patricia Uhan, M.S.

I hold a Master's degree in Clinical Psychology and have spent my career in healthcare as a mental health therapist and psychometrist, administering and scoring standardized assessments, analyzing longitudinal client outcome data, and translating findings into evidence-based clinical insights and decisions.

That background shaped my interest in healthcare analytics. Although this project uses a fully synthetic dataset, it was intentionally designed around realistic clinical and administrative scenarios that reflect the types of questions healthcare organizations routinely ask. My professional experience informs both the analytical approach and the interpretation of the results.

I'm now transitioning into healthcare data analytics, applying the same evidence-based, detail-oriented approach to SQL, Python, and Tableau. This project is one of two healthcare analytics projects in my GitHub portfolio—the other analyzes more than 1.13 million Medicare Part D prescription records. I'm currently seeking my first Healthcare Data Analyst role, where I can combine my clinical expertise with data analytics to support better healthcare decision-making.

📫 Let's connect: LinkedIn: https://www.linkedin.com/in/patricia-uhan · Email: uhanpatricia@gmail.com · GitHub: https://github.com/puhan63

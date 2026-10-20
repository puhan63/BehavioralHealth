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

More details about the cleaning process, validation rules, and SQL logic are available in [Technical Design documentation](Technical_Design.md).

### Tableau Dashboards

#### Dashboard 1: Member Risk & Medical Claims Utilization

**Question:** How does member risk relate to medical claims utilization and costs?

This dashboard explores:

- Member distribution across risk tiers

- Average medical claims per member

- Average paid claim allowed amounts by risk tier

- The relationship between risk scores and medical claims volume

**Key finding:** Risk score had a very weak positive relationship with medical claims volume (R² = 0.0052). Risk score alone explained very little of the variation in utilization in this dataset.

![Member Risk Dashboard](https://github.com/puhan63/BehavioralHealth/blob/main/Member%20Risk%20%26%20Medical%20Claims%20Utilization.png)

[View Interactive Member Risk Dashboard](https://public.tableau.com/app/profile/patricia.uhan/viz/BehavioralHealthTableau2/PharmacyClaimsUtilizationCostAnalysis?publish=yes)

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

![Provider Specialty Dashboard](https://github.com/puhan63/BehavioralHealth/blob/main/Provider%20Specialty%20%26%20Medical%20Claims%20Utilization.png)

[View Interactive Provider Specialty Dashboard](https://public.tableau.com/app/profile/patricia.uhan/viz/BehavioralHealthTableau2/PharmacyClaimsUtilizationCostAnalysis?publish=yes)

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

![Pharmacy Claims Dashboard](https://github.com/puhan63/BehavioralHealth/blob/main/Pharmacy%20Claims%20Utilization%20%26%20Cost%20Analysis.png)

[View Interactive Pharmacy Claims Dashboard](PASTE_TABLEAU_DASHBOARD_1_URL_HERE)

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
| `python_behavioral_health.py` | Corrects issues in the synthetic source data before SQL processing |
| `Behavioral_Health_Updated_ETL.sql` | SQL data cleaning, validation, and reporting pipeline |
| `Behavioral_Health_Data_Quality_Analysis_Updated.sql` | SQL queries used to investigate data quality issues |
| Tableau dashboards | Three interactive dashboards covering member risk, provider specialty, and pharmacy claims |


📫 Let's connect: LinkedIn: https://www.linkedin.com/in/patricia-uhan · Email: uhanpatricia@gmail.com · GitHub: https://github.com/puhan63

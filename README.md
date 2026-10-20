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

[View Interactive Member Risk Dashboard](https://public.tableau.com/app/profile/patricia.uhan/viz/BehavioralHealthTableau2/MemberRiskMedicalClaimsUtilization?publish=yes)

#### Supporting SQL Analysis

To investigate the relationship between member risk and medical claims utilization, I used SQL to compare claim frequency, paid-claim allowed amounts, and enrollment-adjusted utilization across risk tiers.

The analysis includes members without medical claims when calculating population-level utilization and uses member-years to account for differences in enrollment duration.

**Key findings:**

- High-risk members averaged 13.67 medical claims per member-year, compared with 12.97 for low-risk members.
- Average allowed amount per paid claim was approximately 4.5% higher among high-risk members.
- Average paid-claim allowed amount per member was approximately 9.5% higher among high-risk members.

These findings show modest descriptive differences across risk tiers in the synthetic dataset. They do not establish statistical significance or causation.

[View Member Risk SQL Analysis](Hypothesis_1_Member_Risk_Analysis.sql)

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

[View Interactive Provider Specialty Dashboard](https://public.tableau.com/app/profile/patricia.uhan/viz/BehavioralHealthTableau2/ProviderSpecialtyMedicalClaimsUtilization?publish=yes)

#### Supporting SQL Analysis

To investigate differences in medical claims utilization and costs across provider specialties, I used SQL to compare claim volume, claims per provider, and paid-claim allowed amounts.

The analysis accounts for differences in the number of providers within each specialty and includes providers without claims when calculating provider-level averages.

**Key findings:**

- Hospital Medicine had the highest average claims per provider (145.28) and the highest paid-claim allowed amount per provider ($339,007).
- Endocrinology had the highest average allowed amount per paid claim ($3,328.89).
- Primary Care accounted for the largest total medical claims volume.
- All 200 providers had at least one medical claim.

These findings show descriptive differences in utilization and allowed amounts across provider specialties. Results are based on synthetic data and do not establish statistical significance or causation.

[View Provider Specialty SQL Analysis](Hypothesis_2_Provider_Specialty_Analysis.sql)

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

[View Interactive Pharmacy Claims Dashboard](https://public.tableau.com/app/profile/patricia.uhan/viz/BehavioralHealthTableau2/PharmacyClaimsUtilizationCostAnalysis?publish=yes)

#### Supporting SQL Analysis

To investigate differences in pharmacy claim outcomes and drug costs, I used SQL to compare paid, denied, and reversed claims across standardized drug categories. I calculated claim status rates within each category to account for differences in claim volume and compared average drug costs for paid claims.

The analysis also included data quality checks to identify missing or invalid drug costs and verify that medications were assigned to the appropriate drug categories.

**Key findings:**

- Of the 15,000 pharmacy claims, 10,787 were paid, 2,070 were denied, and 2,143 were reversed.
- Antibiotics had the highest denial rate (15.60%), while anxiolytics had the highest reversal rate (15.35%).
- Paid claim rates ranged from 70.46% to 72.32% across the six recognized drug categories.
- Average drug cost per paid claim ranged from $43.46 for antidiabetics to $44.87 for anxiolytics.
- Total recorded drug costs for paid claims were approximately $477,332.
- Medication category validation confirmed that recognized medications were assigned to their expected categories, with one claim remaining classified as UNKNOWN.

Overall, claim status rates and average paid drug costs showed relatively small differences across drug categories. These findings are descriptive and based on synthetic data; they do not establish statistical significance or causation.

[View Pharmacy Claims SQL Analysis](Hypothesis_3_Pharmacy_Claims_Analysis.sql)

#### What I Learned

One of the biggest lessons from this project was how much data quality can affect an analysis.

When I first ran my SQL validation checks, too many records were being excluded. I had to investigate why that was happening, review my assumptions, and use Python to correct problems in the synthetic data before continuing.

This helped me better understand how Python and SQL can work together. Python was useful for correcting the source data, while SQL helped me validate the results, build reporting tables, and answer the analytical questions.

I also gained more experience choosing appropriate metrics and interpreting results carefully. For example, total claims by provider specialty can tell a different story than average claims per provider.

Building the Tableau dashboards gave me practice turning those results into visualizations that are easier to understand.

Project Files

| File | Description |
|------|-------------|
| [README.md](README.md) | Project overview, research questions, dashboard findings, and conclusions |
| [Technical_Design.md](Technical_Design.md) | Data preparation, validation rules, ETL architecture, and SQL documentation |
| [python_behavioral_health.py](python_behavioral_health.py) | Python script that corrects synthetic enrollment and claim date inconsistencies before SQL processing |
| [Behavioral_Health_Updated_ETL.sql](Behavioral_Health_Updated_ETL.sql) | SQL data cleaning, validation, transformation, and Tableau reporting pipeline |
| [Behavioral_Health_Data_Quality_Analysis_Updated.sql](Behavioral_Health_Data_Quality_Analysis_Updated.sql) | SQL queries used to investigate data quality issues and validate processed datasets |
| [Hypothesis_1_Member_Risk_Analysis.sql](Hypothesis_1_Member_Risk_Analysis.sql) | Analysis of member risk tiers, medical claims utilization, allowed amounts, and enrollment-adjusted utilization |
| [Hypothesis_2_Provider_Specialty_Analysis.sql](Hypothesis_2_Provider_Specialty_Analysis.sql) | Analysis of medical claims volume, utilization, and allowed amounts across provider specialties |
| [Hypothesis_3_Pharmacy_Claims_Analysis.sql](Hypothesis_3_Pharmacy_Claims_Analysis.sql) | Analysis of pharmacy claim status rates, drug costs, and standardized drug categories |
| [Tableau Dashboards](https://public.tableau.com/app/profile/patricia.uhan/viz/BehavioralHealthTableau2/MemberRiskMedicalClaimsUtilization) | Interactive visualizations covering member risk, provider specialty, and pharmacy claims |

#### About Me

I'm a mental health therapist transitioning into healthcare data analytics. My clinical background has given me experience working with healthcare information, tracking outcomes, and using data to understand patterns over time.

I've been developing my skills in SQL, Python, Excel, and Tableau, with a particular interest in healthcare data quality and analysis.

I'm looking for opportunities where I can combine my healthcare experience with technical skills to help organizations better understand and use their data.

📫 Let's connect: LinkedIn: https://www.linkedin.com/in/patricia-uhan · Email: uhanpatricia@gmail.com · GitHub: https://github.com/puhan63

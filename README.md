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

>### Key Questions This Project Answers:

> * What are the top diagnoses? How do conditions like depression, anxiety, and trauma shift across different counties and member risk tiers?
> * Are claims processing correctly? Do medical and pharmacy denial, approval, and reversal rates align with normal expectations?
> * Where is the highest risk? Which specific counties and risk categories hold the highest concentration of high-cost or high-need members?
> * How do provider costs compare? How do different specialties and facilities stack up regarding claim volumes, total spending, and behavioral health focus?
> * Why are claims getting rejected? What is the main culprit behind rejections—enrollment gaps, missing provider data, or bad codes?
> * What do pharmacy patterns look like? How does psychiatric medication use—including drug types, supply lengths, and costs—change based on a member's risk score?

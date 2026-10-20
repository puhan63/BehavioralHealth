USE behavioral_health_v2;

-- HYPOTHESIS 3: PHARMACY UTILIZATION AND CLAIM STATUS
-- Compare paid, denied, and reversed pharmacy claims
-- across standardized drug categories.
-- Evaluate differences in recorded drug costs.
-- Analysis uses synthetic pharmacy claims data.


-- 1. Pharmacy claim distribution by drug category
-- Establish baseline claim volume before comparing
-- claim status patterns across categories.

SELECT
    drug_category_clean,
    COUNT(*) AS total_pharmacy_claims

FROM pharmacy_claims_clean

GROUP BY drug_category_clean

ORDER BY total_pharmacy_claims DESC;


-- 2. Pharmacy claim status distribution by drug category
-- Compare paid, denied, and reversed claim counts and rates.
-- Calculate percentages within each category to account
-- for differences in total claim volume.

SELECT
    drug_category_clean,
    COUNT(*) AS total_claims,

    SUM(CASE
        WHEN claim_status = 'PAID' THEN 1 ELSE 0
    END) AS paid_claims,

    SUM(CASE
        WHEN claim_status = 'DENIED' THEN 1 ELSE 0
    END) AS denied_claims,

    SUM(CASE
        WHEN claim_status = 'REVERSED' THEN 1 ELSE 0
    END) AS reversed_claims,

    ROUND(
        100.0 * SUM(CASE
            WHEN claim_status = 'PAID' THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0),
        2
    ) AS paid_rate_pct,

    ROUND(
        100.0 * SUM(CASE
            WHEN claim_status = 'DENIED' THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0),
        2
    ) AS denial_rate_pct,

    ROUND(
        100.0 * SUM(CASE
            WHEN claim_status = 'REVERSED' THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0),
        2
    ) AS reversal_rate_pct

FROM pharmacy_claims_clean

GROUP BY drug_category_clean

ORDER BY denial_rate_pct DESC;


-- 3. Paid pharmacy claim costs by drug category
-- Compare total and average drug costs for paid claims.
-- Exclude denied and reversed claims from cost calculations.

SELECT
    drug_category_clean,
    COUNT(*) AS paid_claims,

    ROUND(
        SUM(drug_cost),
        2
    ) AS total_paid_claim_drug_cost,

    ROUND(
        AVG(drug_cost),
        2
    ) AS avg_drug_cost_per_paid_claim

FROM pharmacy_claims_clean

WHERE claim_status = 'PAID'

GROUP BY drug_category_clean

ORDER BY avg_drug_cost_per_paid_claim DESC;


-- 4. Validate drug costs for paid pharmacy claims
-- Check missing, zero, and negative costs before
-- interpreting average drug costs by category.

SELECT
    drug_category_clean,
    COUNT(*) AS paid_claims,

    SUM(CASE
        WHEN drug_cost IS NULL THEN 1 ELSE 0
    END) AS missing_costs,

    SUM(CASE
        WHEN drug_cost = 0 THEN 1 ELSE 0
    END) AS zero_costs,

    SUM(CASE
        WHEN drug_cost < 0 THEN 1 ELSE 0
    END) AS negative_costs,

    ROUND(MIN(drug_cost), 2) AS min_drug_cost,
    ROUND(MAX(drug_cost), 2) AS max_drug_cost

FROM pharmacy_claims_clean

WHERE claim_status = 'PAID'

GROUP BY drug_category_clean

ORDER BY drug_category_clean;


-- 5. Validate standardized drug-category assignments
-- Confirm each recognized medication maps to one category.
-- Identify any remaining UNKNOWN medications.

SELECT
    drug_name_clean,
    drug_category_clean,
    COUNT(*) AS claim_count

FROM pharmacy_claims_clean

GROUP BY
    drug_name_clean,
    drug_category_clean

ORDER BY
    drug_name_clean,
    drug_category_clean;

-- HYPOTHESIS 3: FINDINGS
-- Drug categories were corrected using standardized
-- medication names before rerunning the analysis.
--
-- Total pharmacy claims: 15,000.
-- Paid: 10,787; Denied: 2,070; Reversed: 2,143.
--
-- Antibiotics had the highest denial rate (15.60%).
-- Anxiolytics had the highest reversal rate (15.35%).
-- Paid rates ranged from 70.46% to 72.32%
-- across the six recognized drug categories.
--
-- Average drug cost per paid claim ranged from
-- $43.46 (ANTIDIABETIC) to $44.87 (ANXIOLYTIC).
-- Total recorded cost for paid claims: $477,332.
--
-- All recognized medications mapped to their
-- expected drug categories. One claim remained UNKNOWN.
--
-- Claim status rates and average paid drug costs
-- showed relatively modest variation by category.
-- Results are descriptive and based on synthetic data.
-- No causal or statistical significance is inferred.
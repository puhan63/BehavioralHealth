/**********************************************************************
Behavioral_Health_Data_Quality_Analysis.sql

Purpose:
    Execute post-ETL data quality validation queries to verify
    that ETL business rules were applied correctly and that
    the cleaned data is ready for downstream analytics and
    reporting.

Notes:
    • Read-only script; does NOT modify any tables.
    • Designed to validate ETL outputs and data quality.

Run After:
    Behavioral_Health_ETL.sql
**********************************************************************/

USE behavioral_health;

-- ==========================================================
-- 1. Summary of Claims Outside Enrollment
-- ==========================================================

SELECT
    CASE
        WHEN m.service_date < mc.enrollment_start
            THEN 'Before Enrollment Start'
        WHEN mc.enrollment_end IS NOT NULL
             AND m.service_date > mc.enrollment_end
            THEN 'After Enrollment End'
    END AS issue_type,
    COUNT(*) AS claim_count
FROM stage_medical m
JOIN members_clean mc
    ON UPPER(TRIM(m.member_id)) = mc.member_id
WHERE m.service_date < mc.enrollment_start
   OR (
        mc.enrollment_end IS NOT NULL
        AND m.service_date > mc.enrollment_end
      )
GROUP BY issue_type;


-- ==========================================================
-- 2. Average Gap Before Enrollment
-- ==========================================================

SELECT
    AVG(DATEDIFF(mc.enrollment_start, m.service_date)) AS avg_days_before_enrollment,
    MIN(DATEDIFF(mc.enrollment_start, m.service_date)) AS smallest_gap_days,
    MAX(DATEDIFF(mc.enrollment_start, m.service_date)) AS largest_gap_days
FROM stage_medical m
JOIN members_clean mc
    ON UPPER(TRIM(m.member_id)) = mc.member_id
WHERE m.service_date < mc.enrollment_start;


-- ==========================================================
-- 3. Distribution of Claims Before Enrollment
-- ==========================================================

SELECT
    CASE
        WHEN DATEDIFF(mc.enrollment_start, m.service_date) <= 7
            THEN '0-7 DAYS BEFORE'
        WHEN DATEDIFF(mc.enrollment_start, m.service_date) <= 30
            THEN '8-30 DAYS BEFORE'
        WHEN DATEDIFF(mc.enrollment_start, m.service_date) <= 90
            THEN '31-90 DAYS BEFORE'
        WHEN DATEDIFF(mc.enrollment_start, m.service_date) <= 365
            THEN '91-365 DAYS BEFORE'
        ELSE 'OVER 1 YEAR BEFORE'
    END AS days_before_enrollment_band,
    COUNT(*) AS claim_count
FROM stage_medical m
JOIN members_clean mc
    ON UPPER(TRIM(m.member_id)) = mc.member_id
WHERE m.service_date < mc.enrollment_start
GROUP BY days_before_enrollment_band
ORDER BY
    CASE days_before_enrollment_band
        WHEN '0-7 DAYS BEFORE' THEN 1
        WHEN '8-30 DAYS BEFORE' THEN 2
        WHEN '31-90 DAYS BEFORE' THEN 3
        WHEN '91-365 DAYS BEFORE' THEN 4
        WHEN 'OVER 1 YEAR BEFORE' THEN 5
    END;


-- ==========================================================
-- 4. Members with the Most Claims Before Enrollment
-- ==========================================================

SELECT
    mc.member_id,
    mc.enrollment_start,
    COUNT(*) AS claims_before_enrollment
FROM stage_medical m
JOIN members_clean mc
    ON UPPER(TRIM(m.member_id)) = mc.member_id
WHERE m.service_date < mc.enrollment_start
GROUP BY
    mc.member_id,
    mc.enrollment_start
ORDER BY claims_before_enrollment DESC
LIMIT 20;


-- ==========================================================
-- 5. Distribution of Claims After Enrollment End
-- ==========================================================

SELECT
    CASE
        WHEN DATEDIFF(m.service_date, mc.enrollment_end) <= 7
            THEN '0-7 DAYS AFTER'
        WHEN DATEDIFF(m.service_date, mc.enrollment_end) <= 30
            THEN '8-30 DAYS AFTER'
        WHEN DATEDIFF(m.service_date, mc.enrollment_end) <= 90
            THEN '31-90 DAYS AFTER'
        WHEN DATEDIFF(m.service_date, mc.enrollment_end) <= 365
            THEN '91-365 DAYS AFTER'
        ELSE 'OVER 1 YEAR AFTER'
    END AS days_after_enrollment_band,
    COUNT(*) AS claim_count
FROM stage_medical m
JOIN members_clean mc
    ON UPPER(TRIM(m.member_id)) = mc.member_id
WHERE mc.enrollment_end IS NOT NULL
  AND m.service_date > mc.enrollment_end
GROUP BY days_after_enrollment_band
ORDER BY
    CASE days_after_enrollment_band
        WHEN '0-7 DAYS AFTER' THEN 1
        WHEN '8-30 DAYS AFTER' THEN 2
        WHEN '31-90 DAYS AFTER' THEN 3
        WHEN '91-365 DAYS AFTER' THEN 4
        WHEN 'OVER 1 YEAR AFTER' THEN 5
    END;

/**********************************************************************
Risk Score Data Quality Analysis

Purpose:
    Validate risk_score handling from ingestion through cleaned data.

Checks:
    1. Missing risk scores in staging
    2. Risk score distribution
    3. Rejected risk score records
    4. Missing risk scores in clean data
    5. Risk score range validation
    6. Risk tier distribution
**********************************************************************/

USE behavioral_health;


-- ==========================================================
-- 1. Check for Missing Risk Scores in Stage Table
-- ==========================================================

SELECT
    COUNT(*) AS missing_risk_scores
FROM stage_members
WHERE risk_score IS NULL;


-- ==========================================================
-- 2. Review Risk Score Distribution
-- ==========================================================

SELECT
    risk_score,
    COUNT(*) AS member_count
FROM stage_members
GROUP BY risk_score
ORDER BY risk_score;


-- ==========================================================
-- 3. Confirm Missing/Invalid Risk Scores Were Rejected
-- ==========================================================

SELECT
    rejection_reason,
    COUNT(*) AS rejected_count
FROM rejected_records
WHERE rejection_reason = 'Risk score is out of range or missing'
GROUP BY rejection_reason;


-- ==========================================================
-- 4. Confirm No Invalid Risk Scores Entered Clean Table
-- ==========================================================

SELECT
    COUNT(*) AS missing_risk_scores_in_clean
FROM members_clean
WHERE risk_score IS NULL;


-- ==========================================================
-- 5. Validate Risk Score Range in Clean Data
-- ==========================================================

SELECT
    MIN(risk_score) AS minimum_risk_score,
    MAX(risk_score) AS maximum_risk_score,
    AVG(risk_score) AS average_risk_score
FROM members_clean;


-- ==========================================================
-- 6. Check for Any Out-of-Range Risk Scores in Stage Data
-- ==========================================================

SELECT
    COUNT(*) AS invalid_risk_scores
FROM stage_members
WHERE risk_score < 0
   OR risk_score > 5;


-- ==========================================================
-- 7. Review Risk Tier Distribution
-- ==========================================================

SELECT
    risk_tier,
    COUNT(*) AS member_count
FROM members_clean
GROUP BY risk_tier
ORDER BY member_count DESC;

-- ==========================================================
-- Gender Data Quality Validation
--
-- Purpose:
--     Review member gender values throughout the ETL process.
--
-- Validation Checks:
--     1. Review gender values loaded into the staging table.
--     2. Confirm members with missing gender values were rejected.
--     3. Verify gender values in the cleaned member table.
--     4. Identify unexpected or invalid gender values in staging.
-- ==========================================================


-- ----------------------------------------------------------
-- 1. Review Gender Distribution in Staging
-- ----------------------------------------------------------

SELECT
    gender,
    COUNT(*) AS member_count
FROM stage_members
GROUP BY gender
ORDER BY member_count DESC;


-- ----------------------------------------------------------
-- 2. Confirm Missing Gender Records Were Rejected
-- ----------------------------------------------------------

SELECT
    rejection_reason,
    COUNT(*) AS rejected_count
FROM rejected_records
WHERE rejection_reason = 'Gender is missing'
GROUP BY rejection_reason;


-- ----------------------------------------------------------
-- 3. Verify Standardized Gender Values in Clean Member Table
-- ----------------------------------------------------------

SELECT
    gender,
    COUNT(*) AS member_count
FROM members_clean
GROUP BY gender
ORDER BY member_count DESC;


-- ----------------------------------------------------------
-- 4. Identify Invalid or Unexpected Gender Values
-- ----------------------------------------------------------

SELECT
    gender,
    COUNT(*) AS member_count
FROM stage_members
WHERE UPPER(TRIM(gender)) NOT IN ('M', 'MALE', 'F', 'FEMALE')
   OR gender IS NULL
   OR TRIM(gender) = ''
GROUP BY gender;

-- ==========================================================
-- Pharmacy Claim Status Data Quality Validation
--
-- Purpose:
--     Review pharmacy claim status values, validate ETL
--     rejection rules, and confirm only invalid status
--     values remain after investigation.
-- ==========================================================


-- ----------------------------------------------------------
-- 1. Review Pharmacy Claim Status Distribution
-- ----------------------------------------------------------

SELECT
    UPPER(TRIM(claim_status)) AS claim_status,
    COUNT(*) AS claim_count
FROM stage_pharmacy
GROUP BY UPPER(TRIM(claim_status))
ORDER BY claim_count DESC;


-- ----------------------------------------------------------
-- 2. Identify Invalid Pharmacy Claim Status Values
-- ----------------------------------------------------------

SELECT
    UPPER(TRIM(claim_status)) AS rejected_status,
    COUNT(*) AS claim_count
FROM stage_pharmacy
WHERE UPPER(TRIM(claim_status))
NOT IN (
    'PAID',
    'PD',
    'P',
    'DENIED',
    'DENY',
    'D',
    'REVERSED',
    'REVERSE'
)
AND claim_status IS NOT NULL
AND TRIM(claim_status) <> ''
GROUP BY UPPER(TRIM(claim_status))
ORDER BY claim_count DESC;


-- ----------------------------------------------------------
-- 3. Confirm Invalid Claim Status Rejections
-- ----------------------------------------------------------

SELECT
    rejection_reason,
    COUNT(*) AS rejected_records
FROM rejected_records
WHERE rejection_reason = 'Invalid claim_status'
GROUP BY rejection_reason;


-- ----------------------------------------------------------
-- 4. Verify Accepted Pharmacy Claim Status Values
-- ----------------------------------------------------------

SELECT
    UPPER(TRIM(claim_status)) AS accepted_status,
    COUNT(*) AS claim_count
FROM stage_pharmacy
WHERE UPPER(TRIM(claim_status))
IN (
    'PAID',
    'PD',
    'P',
    'DENIED',
    'DENY',
    'D',
    'REVERSED',
    'REVERSE'
)
GROUP BY UPPER(TRIM(claim_status))
ORDER BY claim_count DESC;


-- ----------------------------------------------------------
-- 5. Summary of Pharmacy Claim Status Values
-- ----------------------------------------------------------

SELECT
    UPPER(TRIM(claim_status)) AS claim_status,
    COUNT(*) AS total_claims
FROM stage_pharmacy
GROUP BY UPPER(TRIM(claim_status))
ORDER BY total_claims DESC;

-- ==========================================================
-- Facility Type Data Quality Validation
--
-- Purpose:
--     Review facility type values, verify rejected records,
--     and confirm provider reference data quality.
-- ==========================================================


-- ----------------------------------------------------------
-- 1. Review Facility Type Distribution
-- ----------------------------------------------------------

SELECT
    facility_type,
    COUNT(*) AS provider_count
FROM stage_providers
GROUP BY facility_type
ORDER BY provider_count DESC;


-- ----------------------------------------------------------
-- 2. Identify Missing Facility Type Values
-- ----------------------------------------------------------

SELECT
    provider_id,
    provider_name,
    facility_type
FROM stage_providers
WHERE facility_type IS NULL
   OR TRIM(facility_type) = '';


-- ----------------------------------------------------------
-- 3. Confirm Facility Type Rejections
-- ----------------------------------------------------------

SELECT
    rejection_reason,
    COUNT(*) AS rejected_records
FROM rejected_records
WHERE rejection_reason = 'Facility type is missing'
GROUP BY rejection_reason;


-- ----------------------------------------------------------
-- 4. Review Facility Types Remaining in Provider Data
-- ----------------------------------------------------------

SELECT
    facility_type,
    COUNT(*) AS provider_count
FROM stage_providers
WHERE facility_type IS NOT NULL
  AND TRIM(facility_type) <> ''
GROUP BY facility_type
ORDER BY provider_count DESC;

-- ==========================================================
-- County Standardization Data Quality Validation
--
-- Purpose:
--     Review county values before and after standardization
--     to verify consistent geographic reporting.
-- ==========================================================


-- ----------------------------------------------------------
-- 1. Review Original County Values
-- ----------------------------------------------------------

SELECT
    county,
    COUNT(*) AS member_count
FROM stage_members
GROUP BY county
ORDER BY member_count DESC;


-- ----------------------------------------------------------
-- 2. Review Standardized County Values
-- ----------------------------------------------------------

SELECT
    county,
    COUNT(*) AS member_count
FROM members_clean
GROUP BY county
ORDER BY member_count DESC;


-- ----------------------------------------------------------
-- 3. Identify Records Standardized to UNKNOWN
-- ----------------------------------------------------------

SELECT
    member_id,
    county
FROM members_clean
WHERE county = 'UNKNOWN'
ORDER BY member_id;


-- ----------------------------------------------------------
-- 4. Count Members by Standardized County
-- ----------------------------------------------------------

SELECT
    county,
    COUNT(*) AS member_count
FROM members_clean
GROUP BY county
ORDER BY member_count DESC;


-- ----------------------------------------------------------
-- 5. Compare Original vs. Standardized County Counts
-- ----------------------------------------------------------

SELECT
    'Original (Stage)' AS data_source,
    COUNT(DISTINCT county) AS distinct_counties
FROM stage_members

UNION ALL

SELECT
    'Standardized (Clean)',
    COUNT(DISTINCT county)
FROM members_clean;




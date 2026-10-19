/*
===========================================================
Project: Behavioral Health Claims Analytics - Version 2
Author: Patricia Uhan

Purpose:
Build analytical datasets supporting behavioral health
utilization, member risk analysis, provider performance,
and pharmacy utilization reporting.

Data Source:
Corrected synthetic healthcare claims datasets generated
using Python from the original Mockaroo CSV files.

Data Note:
Synthetic records are used for portfolio demonstration.
Results are not representative of actual patient populations.

Observation Period:
2021-01-01 through 2024-12-31
===========================================================
*/

-- DATABASE SETUP
SET GLOBAL local_infile = 1;
SET SQL_SAFE_UPDATES = 0;
SET unique_checks = 0;
SET foreign_key_checks = 0;

CREATE DATABASE IF NOT EXISTS behavioral_health_v2;
USE behavioral_health_v2;

-- Fixed reporting date for age calculations and validation
SET @report_date = '2024-12-31';

-- RESET TABLES FOR A FULL ETL RUN
DROP VIEW IF EXISTS
    member_analysis_dataset,
    provider_analysis_dataset;

DROP TABLE IF EXISTS
    etl_audit_log,
    raw_members,
    raw_providers,
    raw_medical_claims,
    raw_pharmacy_claims,
    members_clean,
    providers_clean,
    medical_claims_clean,
    pharmacy_claims_clean,
    member_utilization,
    provider_performance,
    pharmacy_utilization,
    diagnosis_summary,
    county_risk_summary,
    tableau_behavioral_health,
    tableau_medical_claims,
    tableau_pharmacy_claims,
    stage_members,
    stage_providers,
    stage_medical,
    stage_pharmacy,
    rejected_records,
    data_quality_warnings;

-- TRACK ROW COUNTS FOR EACH ETL STEP
CREATE TABLE etl_audit_log (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    process_step VARCHAR(100),
    source_table VARCHAR(100),
    rows_before INT,
    rows_after INT,
    rows_removed INT,
    process_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- LOG RECORDS THAT FAIL VALIDATION
-- Critical errors exclude records from cleaned tables.
-- Noncritical issues are flagged without removing records.
CREATE TABLE rejected_records (
    record_type VARCHAR(30),
    record_id VARCHAR(20),
    rejection_reason VARCHAR(255),
    rejection_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- RAW CSV DATA
-- Raw tables allow duplicate source IDs so they can be checked during validation
CREATE TABLE raw_members (
    member_id VARCHAR(10),
    dob VARCHAR(10),
    gender VARCHAR(10),
    county VARCHAR(30),
    enrollment_start VARCHAR(10),
    enrollment_end VARCHAR(10),
    risk_score DECIMAL(8,2)
);

CREATE TABLE raw_providers (
provider_id VARCHAR(10),
npi CHAR(10),
provider_name VARCHAR(50),
provider_type VARCHAR(30),
facility_type VARCHAR(50),
county VARCHAR(30)
);

CREATE TABLE raw_medical_claims (
claim_id VARCHAR(10),
member_id VARCHAR(10),
provider_id VARCHAR(10),
service_date VARCHAR(10),
icd10_code CHAR(7),
claim_status VARCHAR(20),
place_of_service VARCHAR(30),
length_of_stay INT,
allowed_amount DECIMAL(10,2)
);

CREATE TABLE raw_pharmacy_claims (
rx_claim_id VARCHAR(10),
member_id VARCHAR(10),
fill_date VARCHAR(10),
drug_name VARCHAR(50),
drug_category VARCHAR(30),
days_supply INT,
quantity INT,
claim_status VARCHAR(20),
drug_cost DECIMAL(10,2)
);

-- IMPORT SOURCE CSV FILES
LOAD DATA LOCAL INFILE 'C:/Users/dutch/Documents/members_behavioral_health_2.csv'
INTO TABLE raw_members
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(member_id, dob, gender, county, enrollment_start, enrollment_end, @risk_score)
SET
risk_score = NULLIF(TRIM(@risk_score), '');

LOAD DATA LOCAL INFILE 'C:/Users/dutch/Documents/providers_behavioral_health_2.csv'
INTO TABLE raw_providers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(provider_id, npi, provider_name, provider_type, facility_type, county);

LOAD DATA LOCAL INFILE 'C:/Users/dutch/Documents/medical_claims_behavioral_health_2.csv'
INTO TABLE raw_medical_claims
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(claim_id, member_id, provider_id, service_date, icd10_code, claim_status, place_of_service, length_of_stay, allowed_amount);

LOAD DATA LOCAL INFILE 'C:/Users/dutch/Documents/pharmacy_claims_behavioral_health_2.csv'
INTO TABLE raw_pharmacy_claims
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(rx_claim_id, member_id, fill_date, drug_name, drug_category, days_supply, quantity, claim_status, drug_cost);

-- STAGING TABLES: CONVERT SOURCE DATES
-- MEMBERS STAGING
CREATE TABLE stage_members (
    member_id VARCHAR(10),
    dob DATE,
    gender VARCHAR(10),
    county VARCHAR(30),
    enrollment_start DATE,
    enrollment_end DATE,
    risk_score DECIMAL(8,2)
);

INSERT INTO stage_members
SELECT
    member_id,

    CASE
        WHEN dob IS NULL OR TRIM(dob) = '' THEN NULL
        ELSE STR_TO_DATE(dob, '%m/%d/%Y')
    END AS dob,

    gender,
    county,

    CASE
        WHEN enrollment_start IS NULL
             OR TRIM(enrollment_start) = ''
        THEN NULL
        ELSE STR_TO_DATE(enrollment_start, '%m/%d/%Y')
    END AS enrollment_start,

    CASE
        WHEN enrollment_end IS NULL
             OR TRIM(enrollment_end) = ''
        THEN NULL
        ELSE STR_TO_DATE(enrollment_end, '%m/%d/%Y')
    END AS enrollment_end,

    risk_score
FROM raw_members;

-- PROVIDERS STAGING
CREATE TABLE stage_providers AS
SELECT *
FROM raw_providers;

-- MEDICAL CLAIMS STAGING
CREATE TABLE stage_medical AS
SELECT
    claim_id,
    member_id,
    provider_id,

    CASE
        WHEN service_date IS NULL
             OR TRIM(service_date) = ''
        THEN NULL
        ELSE STR_TO_DATE(service_date, '%m/%d/%Y')
    END AS service_date,

    icd10_code,
    claim_status,
    place_of_service,
    length_of_stay,
    allowed_amount
FROM raw_medical_claims;

-- PHARMACY CLAIMS STAGING
CREATE TABLE stage_pharmacy AS
SELECT
    rx_claim_id,
    member_id,

    CASE
        WHEN fill_date IS NULL
             OR TRIM(fill_date) = ''
        THEN NULL
        ELSE STR_TO_DATE(fill_date, '%m/%d/%Y')
    END AS fill_date,

    drug_name,
    drug_category,
    days_supply,
    quantity,
    claim_status,
    drug_cost
FROM raw_pharmacy_claims;

-- MEMBER VALIDATION
-- Missing or future DOB
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'member',
    member_id,
    'DOB is missing or in the future'
FROM stage_members
WHERE dob IS NULL
   OR dob > @report_date;

-- Age exceeds 120 years
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'member',
    member_id,
    'Age exceeds expected threshold (>120)'
FROM stage_members
WHERE TIMESTAMPDIFF(YEAR, dob, @report_date) > 120;

-- Invalid enrollment dates
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'member',
    member_id,
    'Enrollment dates are invalid'
FROM stage_members
WHERE enrollment_start IS NULL
   OR enrollment_start > @report_date
   OR (
       enrollment_end IS NOT NULL
       AND enrollment_end < enrollment_start
   );

-- Enrollment starts before DOB
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'member',
    member_id,
    'Enrollment starts before DOB'
FROM stage_members
WHERE enrollment_start < dob;

-- DATA QUALITY WARNINGS
CREATE TABLE data_quality_warnings (
    warning_id INT AUTO_INCREMENT PRIMARY KEY,
    record_type VARCHAR(30),
    record_id VARCHAR(50),
    warning_reason VARCHAR(255)
);

-- Missing gender
INSERT INTO data_quality_warnings
    (record_type, record_id, warning_reason)
SELECT
    'member',
    member_id,
    'Gender is missing'
FROM stage_members
WHERE gender IS NULL
   OR TRIM(gender) = '';

-- Missing or invalid risk score
INSERT INTO data_quality_warnings
    (record_type, record_id, warning_reason)
SELECT
    'member',
    member_id,
    'Risk score is missing or outside expected range'
FROM stage_members
WHERE risk_score IS NULL
   OR risk_score < 0.50
   OR risk_score > 3.50;

-- PROVIDER VALIDATION
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'provider',
    provider_id,
    'NPI is invalid or not properly formatted'
FROM stage_providers
WHERE npi IS NULL
   OR TRIM(npi) = ''
   OR LENGTH(TRIM(npi)) <> 10
   OR TRIM(npi) NOT REGEXP '^[0-9]{10}$';

-- DATA QUALITY WARNINGS
-- Missing provider type
INSERT INTO data_quality_warnings
    (record_type, record_id, warning_reason)
SELECT
    'provider',
    provider_id,
    'Provider type is missing'
FROM stage_providers
WHERE provider_type IS NULL
   OR TRIM(provider_type) = '';

-- Missing facility type
INSERT INTO data_quality_warnings
    (record_type, record_id, warning_reason)
SELECT
    'provider',
    provider_id,
    'Facility type is missing'
FROM stage_providers p
WHERE (facility_type IS NULL OR TRIM(facility_type) = '')
  AND NOT EXISTS (
      SELECT 1
      FROM data_quality_warnings w
      WHERE w.record_type = 'provider'
        AND w.record_id = p.provider_id
        AND w.warning_reason = 'Facility type is missing'
  );

-- Missing county
INSERT INTO data_quality_warnings
    (record_type, record_id, warning_reason)
SELECT
    'provider',
    provider_id,
    'County is missing'
FROM stage_providers
WHERE county IS NULL
   OR TRIM(county) = '';

SELECT
    'Critical Rejections' AS issue_type,
    rejection_reason AS issue,
    COUNT(DISTINCT record_id) AS affected_providers
FROM rejected_records
WHERE record_type = 'provider'
GROUP BY rejection_reason

UNION ALL

SELECT
    'Data Quality Warning',
    warning_reason,
    COUNT(DISTINCT record_id)
FROM data_quality_warnings
WHERE record_type = 'provider'
GROUP BY warning_reason;

-- MEDICAL CLAIM VALIDATION
-- Missing claim ID
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT 'medical_claim', claim_id, 'Missing claim_id'
FROM stage_medical
WHERE claim_id IS NULL
   OR TRIM(claim_id) = '';

-- Missing member ID
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT 'medical_claim', claim_id, 'Missing member_id'
FROM stage_medical
WHERE member_id IS NULL
   OR TRIM(member_id) = '';

-- Missing provider ID
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT 'medical_claim', claim_id, 'Missing provider_id'
FROM stage_medical
WHERE provider_id IS NULL
   OR TRIM(provider_id) = '';

-- Duplicate claim IDs
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'medical_claim',
    m.claim_id,
    'Duplicate claim_id'
FROM stage_medical m
JOIN (
    SELECT UPPER(TRIM(claim_id)) AS normalized_id
    FROM stage_medical
    WHERE claim_id IS NOT NULL
      AND TRIM(claim_id) <> ''
    GROUP BY UPPER(TRIM(claim_id))
    HAVING COUNT(*) > 1
) d
    ON UPPER(TRIM(m.claim_id)) = d.normalized_id;

-- Missing service date
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT 'medical_claim', claim_id, 'Missing service_date'
FROM stage_medical
WHERE service_date IS NULL;

-- Service date outside reporting period
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'medical_claim',
    claim_id,
    'Service date outside reporting period'
FROM stage_medical
WHERE service_date < '2021-01-01'
   OR service_date > @report_date;

-- Member reference does not exist
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'medical_claim',
    mc.claim_id,
    'Member ID not found'
FROM stage_medical mc
LEFT JOIN stage_members m
    ON UPPER(TRIM(mc.member_id)) = UPPER(TRIM(m.member_id))
WHERE mc.member_id IS NOT NULL
  AND TRIM(mc.member_id) <> ''
  AND m.member_id IS NULL;

-- Provider reference does not exist
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'medical_claim',
    mc.claim_id,
    'Provider ID not found'
FROM stage_medical mc
LEFT JOIN stage_providers p
    ON UPPER(TRIM(mc.provider_id)) = UPPER(TRIM(p.provider_id))
WHERE mc.provider_id IS NOT NULL
  AND TRIM(mc.provider_id) <> ''
  AND p.provider_id IS NULL;

-- Service date outside member enrollment
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'medical_claim',
    mc.claim_id,
    'Service date outside enrollment'
FROM stage_medical mc
JOIN stage_members m
    ON UPPER(TRIM(mc.member_id)) = UPPER(TRIM(m.member_id))
WHERE mc.service_date < m.enrollment_start
   OR (
       m.enrollment_end IS NOT NULL
       AND mc.service_date > m.enrollment_end
   );

-- DATA QUALITY WARNINGS
-- Missing diagnosis code
INSERT INTO data_quality_warnings
    (record_type, record_id, warning_reason)
SELECT
    'medical_claim',
    claim_id,
    'Missing ICD10 code'
FROM stage_medical
WHERE icd10_code IS NULL
   OR TRIM(icd10_code) = '';

-- Diagnosis code outside project-approved list
INSERT INTO data_quality_warnings
    (record_type, record_id, warning_reason)
SELECT
    'medical_claim',
    claim_id,
    'ICD10 code outside project-approved list'
FROM stage_medical
WHERE UPPER(TRIM(icd10_code)) NOT IN (
    'F32','F33','F41','F43',
    'G47','I10','E11','J45'
)
AND icd10_code IS NOT NULL
AND TRIM(icd10_code) <> '';

-- Missing or unrecognized claim status
INSERT INTO data_quality_warnings
    (record_type, record_id, warning_reason)
SELECT
    'medical_claim',
    claim_id,
    'Missing or invalid claim status'
FROM stage_medical
WHERE claim_status IS NULL
   OR TRIM(claim_status) = ''
   OR UPPER(TRIM(claim_status)) NOT IN (
       'PAID','PD','P','PIAD',
       'DENIED','DENY','D',
       'REVERSED','REVERSE','R'
   );

-- Missing or unrecognized place of service
INSERT INTO data_quality_warnings
    (record_type, record_id, warning_reason)
SELECT
    'medical_claim',
    claim_id,
    'Missing or invalid place_of_service'
FROM stage_medical
WHERE place_of_service IS NULL
   OR TRIM(place_of_service) = ''
   OR UPPER(TRIM(place_of_service)) NOT IN (
       'IP', 'I.P.', 'INPAT', 'INPATIENT', 'INPATIENT HOSPITAL',
       'OP', 'O.P.', 'OUTPA', 'OUTPATIENT',
       'ED', 'EMERG', 'EMERGENC', 'EMERGENCY',
	   'EMERG.', 'EMERGENCY DEPT'
   );

-- Missing or invalid allowed amount
INSERT INTO data_quality_warnings
    (record_type, record_id, warning_reason)
SELECT
    'medical_claim',
    claim_id,
    'Missing or invalid allowed_amount'
FROM stage_medical
WHERE allowed_amount IS NULL
   OR allowed_amount < 0;

-- Unusually high allowed amount
INSERT INTO data_quality_warnings
    (record_type, record_id, warning_reason)
SELECT
    'medical_claim',
    claim_id,
    'Allowed amount exceeds review threshold'
FROM stage_medical
WHERE allowed_amount > 24984.00;

-- Negative length of stay
INSERT INTO data_quality_warnings
    (record_type, record_id, warning_reason)
SELECT
    'medical_claim',
    claim_id,
    'Negative length_of_stay'
FROM stage_medical
WHERE length_of_stay < 0;

-- Missing inpatient length of stay
INSERT INTO data_quality_warnings
    (record_type, record_id, warning_reason)
SELECT
    'medical_claim',
    claim_id,
    'Missing LOS for inpatient claim'
FROM stage_medical
WHERE UPPER(TRIM(place_of_service)) IN (
    'IP','I.P.','INPAT'
)
AND length_of_stay IS NULL;

-- PHARMACY CLAIM VALIDATION
-- Missing prescription claim ID
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'pharmacy_claim',
    rx_claim_id,
    'Missing rx_claim_id'
FROM stage_pharmacy
WHERE rx_claim_id IS NULL
   OR TRIM(rx_claim_id) = '';

-- Duplicate prescription claim IDs
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'pharmacy_claim',
    p.rx_claim_id,
    'Duplicate rx_claim_id'
FROM stage_pharmacy p
JOIN (
    SELECT UPPER(TRIM(rx_claim_id)) AS normalized_id
    FROM stage_pharmacy
    WHERE rx_claim_id IS NOT NULL
      AND TRIM(rx_claim_id) <> ''
    GROUP BY UPPER(TRIM(rx_claim_id))
    HAVING COUNT(*) > 1
) d
    ON UPPER(TRIM(p.rx_claim_id)) = d.normalized_id;

-- Missing member ID
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'pharmacy_claim',
    rx_claim_id,
    'Missing member_id'
FROM stage_pharmacy
WHERE member_id IS NULL
   OR TRIM(member_id) = '';

-- Member reference does not exist
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'pharmacy_claim',
    pc.rx_claim_id,
    'Member ID not found'
FROM stage_pharmacy pc
LEFT JOIN stage_members m
    ON UPPER(TRIM(pc.member_id)) = UPPER(TRIM(m.member_id))
WHERE pc.member_id IS NOT NULL
  AND TRIM(pc.member_id) <> ''
  AND m.member_id IS NULL;

-- Missing fill date
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'pharmacy_claim',
    rx_claim_id,
    'Missing fill_date'
FROM stage_pharmacy
WHERE fill_date IS NULL;

-- Fill date outside reporting period
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'pharmacy_claim',
    rx_claim_id,
    'Fill date outside reporting period'
FROM stage_pharmacy
WHERE fill_date < '2021-01-01'
   OR fill_date > @report_date;

-- Fill date outside member enrollment
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'pharmacy_claim',
    pc.rx_claim_id,
    'Fill date outside enrollment'
FROM stage_pharmacy pc
JOIN stage_members m
    ON UPPER(TRIM(pc.member_id)) = UPPER(TRIM(m.member_id))
WHERE pc.fill_date < m.enrollment_start
   OR (
       m.enrollment_end IS NOT NULL
       AND pc.fill_date > m.enrollment_end
   );

-- DATA QUALITY WARNINGS
-- Missing drug name
INSERT INTO data_quality_warnings
    (record_type, record_id, warning_reason)
SELECT
    'pharmacy_claim',
    rx_claim_id,
    'Missing drug_name'
FROM stage_pharmacy
WHERE drug_name IS NULL
   OR TRIM(drug_name) = '';

-- Missing or unrecognized claim status
INSERT INTO data_quality_warnings
    (record_type, record_id, warning_reason)
SELECT
    'pharmacy_claim',
    rx_claim_id,
    'Missing or invalid claim_status'
FROM stage_pharmacy
WHERE claim_status IS NULL
   OR TRIM(claim_status) = ''
   OR UPPER(TRIM(claim_status)) NOT IN (
       'PAID', 'PD', 'P', 'PIAD',
       'DENIED', 'DENY', 'D',
       'REVERSED', 'REVERSE', 'R'
   );

-- Missing or negative drug cost
INSERT INTO data_quality_warnings
    (record_type, record_id, warning_reason)
SELECT
    'pharmacy_claim',
    rx_claim_id,
    'Missing or invalid drug_cost'
FROM stage_pharmacy
WHERE drug_cost IS NULL
   OR drug_cost < 0;

-- Invalid days supply
INSERT INTO data_quality_warnings
    (record_type, record_id, warning_reason)
SELECT
    'pharmacy_claim',
    rx_claim_id,
    'Invalid days_supply'
FROM stage_pharmacy
WHERE days_supply IS NULL
   OR days_supply <= 0
   OR days_supply > 365;

-- Invalid quantity
INSERT INTO data_quality_warnings
    (record_type, record_id, warning_reason)
SELECT
    'pharmacy_claim',
    rx_claim_id,
    'Invalid quantity'
FROM stage_pharmacy
WHERE quantity IS NULL
   OR quantity <= 0;

-- CLEAN MEMBER DATA
CREATE TABLE members_clean AS
SELECT
    UPPER(TRIM(member_id)) AS member_id,
    dob,

    -- Normalize gender values
    CASE
        WHEN UPPER(TRIM(gender)) IN ('M', 'MALE') THEN 'M'
        WHEN UPPER(TRIM(gender)) IN ('F', 'FEMALE') THEN 'F'
        ELSE 'UNKNOWN'
    END AS gender,

    enrollment_start,
    enrollment_end,

    -- Preserve valid risk scores; retain missing values as NULL
    CASE
        WHEN risk_score BETWEEN 0.50 AND 3.50
            THEN ROUND(risk_score, 2)
        ELSE NULL
    END AS risk_score,

    -- Normalize county names and common misspellings
    CASE
        WHEN county IS NULL
             OR TRIM(county) = ''
            THEN 'UNKNOWN'

        WHEN UPPER(TRIM(county)) LIKE '%MILWAUKEE%'
             OR UPPER(TRIM(county)) LIKE '%MILWAUKE%'
            THEN 'MILWAUKEE'

        WHEN UPPER(TRIM(county)) LIKE '%WAUKESHA%'
             OR UPPER(TRIM(county)) LIKE '%WAUKESH%'
            THEN 'WAUKESHA'

        WHEN UPPER(TRIM(county)) LIKE '%RACINE%'
             OR UPPER(TRIM(county)) LIKE '%RACIN%'
             OR UPPER(TRIM(county)) LIKE '%RASINE%'
            THEN 'RACINE'

        WHEN UPPER(TRIM(county)) LIKE '%KENOSHA%'
             OR UPPER(TRIM(county)) LIKE '%KENOSH%'
            THEN 'KENOSHA'

        WHEN UPPER(TRIM(county)) LIKE '%WASHINGTON%'
            THEN 'WASHINGTON'

        WHEN UPPER(TRIM(county)) LIKE '%OZAUKEE%'
             OR UPPER(TRIM(county)) LIKE '%OZAKEE%'
            THEN 'OZAUKEE'

        ELSE 'UNKNOWN'
    END AS county,

    -- Project-defined risk tiers for the synthetic dataset.
	-- These thresholds are not clinical risk classifications.
    CASE
        WHEN risk_score IS NULL
             OR risk_score < 0.50
             OR risk_score > 3.50
            THEN 'UNKNOWN RISK'

        WHEN risk_score < 1.50
            THEN 'LOW RISK'

        WHEN risk_score < 2.50
            THEN 'MODERATE RISK'

        ELSE 'HIGH RISK'
    END AS risk_tier,

    -- Calculate age as of reporting date
    TIMESTAMPDIFF(YEAR, dob, @report_date) AS age,

    -- Create age groups for reporting
    CASE
        WHEN dob IS NULL THEN 'UNKNOWN'
        WHEN TIMESTAMPDIFF(YEAR, dob, @report_date) < 18
            THEN 'Under 18'
        WHEN TIMESTAMPDIFF(YEAR, dob, @report_date) BETWEEN 18 AND 34
            THEN '18-34'
        WHEN TIMESTAMPDIFF(YEAR, dob, @report_date) BETWEEN 35 AND 49
            THEN '35-49'
        WHEN TIMESTAMPDIFF(YEAR, dob, @report_date) BETWEEN 50 AND 64
            THEN '50-64'
        ELSE '65+'
    END AS age_band

FROM stage_members

-- Exclude only critically rejected members
WHERE NOT EXISTS (
    SELECT 1
    FROM rejected_records r
    WHERE r.record_type = 'member'
      AND UPPER(TRIM(r.record_id)) = UPPER(TRIM(stage_members.member_id))
);

-- MEMBER TABLE INDEXES
-- Member identifier
CREATE INDEX idx_members_member
ON members_clean (member_id);

-- Geographic analysis
CREATE INDEX idx_members_county
ON members_clean (county);

-- Risk-tier analysis
CREATE INDEX idx_members_risk
ON members_clean (risk_tier);

-- MEDICAL MEMBER REFERENCE CHECK
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'medical_claim',
    m.claim_id,
    'Invalid member_id'
FROM stage_medical m
LEFT JOIN members_clean c
    ON UPPER(TRIM(m.member_id)) = c.member_id
WHERE c.member_id IS NULL
  AND NOT EXISTS (
      SELECT 1
      FROM rejected_records r
      WHERE r.record_type = 'medical_claim'
        AND r.record_id = m.claim_id
        AND r.rejection_reason = 'Invalid member_id'
  );

-- PHARMACY MEMBER REFERENCE CHECK
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)
SELECT
    'pharmacy_claim',
    p.rx_claim_id,
    'Invalid member_id'
FROM stage_pharmacy p
LEFT JOIN members_clean m
    ON UPPER(TRIM(p.member_id)) = m.member_id
WHERE m.member_id IS NULL
  AND NOT EXISTS (
      SELECT 1
      FROM rejected_records r
      WHERE r.record_type = 'pharmacy_claim'
        AND r.record_id = p.rx_claim_id
        AND r.rejection_reason = 'Invalid member_id'
  );
  
-- CLEAN PROVIDER DATA
DROP TABLE IF EXISTS providers_clean;

CREATE TABLE providers_clean AS

WITH provider_base AS (

    SELECT
        UPPER(TRIM(provider_id)) AS provider_id,
        TRIM(npi) AS npi,
        TRIM(provider_name) AS provider_name,

        -- Normalize provider types
        CASE
            WHEN UPPER(TRIM(provider_type)) LIKE '%PSYCH%'
                THEN 'PSYCHIATRIST'

            WHEN UPPER(TRIM(provider_type)) LIKE '%THERAP%'
                THEN 'THERAPIST'

            WHEN UPPER(TRIM(provider_type)) LIKE '%PRIMARY%'
                THEN 'PRIMARY CARE'

            WHEN UPPER(TRIM(provider_type)) LIKE '%CARDIO%'
                THEN 'CARDIOLOGY'

            WHEN UPPER(TRIM(provider_type)) LIKE '%ENDO%'
                THEN 'ENDOCRINOLOGIST'

            WHEN UPPER(TRIM(provider_type)) LIKE '%HOSPITALIST%'
                THEN 'HOSPITALIST'

            WHEN UPPER(TRIM(provider_type)) IN (
                'ER',
                'ER PHYSICIAN',
                'EMERGENCY PHYSICIAN',
                'EMERGENCY MEDICINE'
            )
                THEN 'ER PHYSICIAN'

            ELSE 'OTHER'
        END AS provider_type_clean,

        facility_type,
        county

    FROM stage_providers sp

    -- Exclude only critically invalid providers
    WHERE NOT EXISTS (
        SELECT 1
        FROM rejected_records r
        WHERE r.record_type = 'provider'
          AND UPPER(TRIM(r.record_id)) =
              UPPER(TRIM(sp.provider_id))
    )
)

SELECT
    provider_id,
    npi,
    provider_name,
    provider_type_clean,

    -- Reporting specialty
    CASE
        WHEN provider_type_clean = 'PSYCHIATRIST'
            THEN 'PSYCHIATRY'
        WHEN provider_type_clean = 'THERAPIST'
            THEN 'THERAPY'
        WHEN provider_type_clean = 'PRIMARY CARE'
            THEN 'PRIMARY CARE'
        WHEN provider_type_clean = 'CARDIOLOGY'
            THEN 'CARDIOLOGY'
        WHEN provider_type_clean = 'ENDOCRINOLOGIST'
            THEN 'ENDOCRINOLOGY'
        WHEN provider_type_clean = 'ER PHYSICIAN'
            THEN 'EMERGENCY MEDICINE'
        WHEN provider_type_clean = 'HOSPITALIST'
            THEN 'HOSPITAL MEDICINE'
        ELSE 'OTHER'
    END AS provider_specialty,

    -- Broader reporting domain
    CASE
        WHEN provider_type_clean IN (
            'PSYCHIATRIST', 'THERAPIST'
        )
            THEN 'BEHAVIORAL HEALTH'

        WHEN provider_type_clean = 'PRIMARY CARE'
            THEN 'PRIMARY CARE'

        WHEN provider_type_clean IN (
            'ER PHYSICIAN', 'HOSPITALIST'
        )
            THEN 'ACUTE / EMERGENCY CARE'

        WHEN provider_type_clean IN (
            'CARDIOLOGY', 'ENDOCRINOLOGIST'
        )
            THEN 'SPECIALTY CARE'

        ELSE 'OTHER'
    END AS provider_domain,

    -- Standardize facility descriptions
    CASE
        WHEN facility_type IS NULL
          OR TRIM(facility_type) = ''
            THEN 'UNKNOWN'

        WHEN UPPER(TRIM(facility_type)) LIKE '%OUTPATIENT%'
            THEN 'OUTPATIENT CLINIC'

        WHEN UPPER(TRIM(facility_type)) LIKE '%COMMUNITY%'
            THEN 'COMMUNITY HEALTH CENTER'

        WHEN UPPER(TRIM(facility_type)) LIKE '%PRIVATE%'
            THEN 'PRIVATE PRACTICE'

        WHEN UPPER(TRIM(facility_type)) LIKE '%HOSPITAL%'
            THEN 'HOSPITAL'

        ELSE 'OTHER'
    END AS facility_type_clean,

    -- Standardize county
    CASE
        WHEN county IS NULL
          OR TRIM(county) = ''
            THEN 'UNKNOWN'

        WHEN UPPER(TRIM(county)) LIKE '%MILWAUKEE%'
          OR UPPER(TRIM(county)) LIKE '%MILWAUKE%'
            THEN 'MILWAUKEE'

        WHEN UPPER(TRIM(county)) LIKE '%WAUKESHA%'
          OR UPPER(TRIM(county)) LIKE '%WAUKESH%'
            THEN 'WAUKESHA'

        WHEN UPPER(TRIM(county)) LIKE '%RACINE%'
          OR UPPER(TRIM(county)) LIKE '%RACIN%'
            THEN 'RACINE'

        WHEN UPPER(TRIM(county)) LIKE '%KENOSHA%'
          OR UPPER(TRIM(county)) LIKE '%KENOSH%'
            THEN 'KENOSHA'

        WHEN UPPER(TRIM(county)) LIKE '%WASHINGTON%'
            THEN 'WASHINGTON'

        WHEN UPPER(TRIM(county)) LIKE '%OZAUKEE%'
          OR UPPER(TRIM(county)) LIKE '%OZAKEE%'
            THEN 'OZAUKEE'

        ELSE 'UNKNOWN'
    END AS county_clean

FROM provider_base;  
  
-- PROVIDER TABLE INDEXES
CREATE INDEX idx_providers_id
ON providers_clean (provider_id);

CREATE INDEX idx_providers_specialty
ON providers_clean (provider_specialty);

CREATE INDEX idx_providers_domain
ON providers_clean (provider_domain);  

-- MEDICAL PROVIDER REFERENCE CHECK
INSERT INTO rejected_records
    (record_type, record_id, rejection_reason)

SELECT
    'medical_claim',
    m.claim_id,
    'Invalid provider_id'

FROM stage_medical m

LEFT JOIN providers_clean p
    ON UPPER(TRIM(m.provider_id)) = p.provider_id

WHERE p.provider_id IS NULL

  AND NOT EXISTS (
      SELECT 1
      FROM rejected_records r
      WHERE r.record_type = 'medical_claim'
        AND r.record_id = m.claim_id
        AND r.rejection_reason = 'Invalid provider_id'
  );  
  
-- CLEAN MEDICAL CLAIMS
DROP TABLE IF EXISTS medical_claims_clean;

CREATE TABLE medical_claims_clean AS

WITH medical_base AS (

    SELECT
        UPPER(TRIM(claim_id)) AS claim_id,
        UPPER(TRIM(member_id)) AS member_id,
        UPPER(TRIM(provider_id)) AS provider_id,
        service_date,

        -- Standardize ICD-10 codes
        UPPER(TRIM(icd10_code)) AS icd10_code,

        -- Normalize claim status values
        CASE
            WHEN UPPER(TRIM(claim_status)) IN
                ('PAID', 'PD', 'P', 'PIAD')
                THEN 'PAID'

            WHEN UPPER(TRIM(claim_status)) IN
                ('DENIED', 'DENY', 'D')
                THEN 'DENIED'

            WHEN UPPER(TRIM(claim_status)) IN
                ('REVERSED', 'REVERSE', 'R')
                THEN 'REVERSED'

            ELSE 'OTHER'
        END AS claim_status,

        -- Standardize place of service
        CASE
            WHEN UPPER(TRIM(place_of_service)) IN
                ('IP', 'I.P.', 'INPAT',
                 'INPATIENT', 'INPATIENT HOSPITAL')
                THEN 'INPATIENT'

            WHEN UPPER(TRIM(place_of_service)) IN
                ('OP', 'O.P.', 'OUTPA', 'OUTPATIENT')
                THEN 'OUTPATIENT'

            WHEN UPPER(TRIM(place_of_service)) IN
				('ED', 'EMERG', 'EMERGENC',
				'EMERGENCY', 'EMERG.', 'EMERGENCY DEPT')
				THEN 'EMERGENCY'
			ELSE 'OTHER'
        END AS place_of_service,

        length_of_stay,
        allowed_amount

    FROM stage_medical sm

    -- Exclude claims that failed critical validation
    WHERE NOT EXISTS (
        SELECT 1
        FROM rejected_records r
        WHERE r.record_type = 'medical_claim'
          AND UPPER(TRIM(r.record_id)) =
              UPPER(TRIM(sm.claim_id))
    )

    -- Require a valid claim identifier
    AND sm.claim_id IS NOT NULL
    AND TRIM(sm.claim_id) <> ''

    -- Require a valid cleaned member reference
    AND EXISTS (
        SELECT 1
        FROM members_clean m
        WHERE m.member_id = UPPER(TRIM(sm.member_id))
    )

    -- Require a valid cleaned provider reference
    AND EXISTS (
        SELECT 1
        FROM providers_clean p
        WHERE p.provider_id = UPPER(TRIM(sm.provider_id))
    )
)

SELECT
    claim_id,
    member_id,
    provider_id,
    service_date,
    icd10_code,

    -- Assign diagnosis categories for reporting
    CASE
        WHEN icd10_code IN ('F32', 'F33')
            THEN 'Depression'

        WHEN icd10_code = 'F41'
            THEN 'Anxiety'

        WHEN icd10_code = 'F43'
            THEN 'Trauma / Stress Disorders'

        WHEN icd10_code = 'G47'
            THEN 'Sleep Disorders'

        WHEN icd10_code = 'I10'
            THEN 'Hypertension'

        WHEN icd10_code = 'E11'
            THEN 'Type 2 Diabetes'

        WHEN icd10_code = 'J45'
            THEN 'Asthma'

        ELSE 'Other'
    END AS diagnosis_category,

    claim_status,
    place_of_service,

    -- Keep length of stay only for inpatient claims
    CASE
        WHEN place_of_service = 'INPATIENT'
            THEN length_of_stay

        ELSE NULL
    END AS length_of_stay,

    -- Flag inpatient records with missing LOS
    CASE
        WHEN place_of_service = 'INPATIENT'
             AND length_of_stay IS NULL
            THEN 'MISSING IP LOS'

        WHEN place_of_service = 'INPATIENT'
            THEN 'VALID IP LOS'

        ELSE 'NOT APPLICABLE'
    END AS los_status,

    -- Standardize allowed amounts
    ROUND(allowed_amount, 2) AS allowed_amount,

    -- Assign project-defined cost tiers
    CASE
        WHEN allowed_amount >= 20000
            THEN 'HIGH COST'

        WHEN allowed_amount >= 5000
            THEN 'MODERATE COST'

        WHEN allowed_amount >= 0
            THEN 'NORMAL COST'

        ELSE 'UNKNOWN'
    END AS cost_tier

FROM medical_base;

-- VALIDATE CLEAN MEDICAL CLAIMS
SELECT
    COUNT(*) AS total_clean_medical_claims,

    SUM(claim_status = 'OTHER')
        AS unknown_claim_status,

    SUM(place_of_service = 'OTHER')
        AS unknown_place_of_service,

    SUM(diagnosis_category = 'Other')
        AS other_diagnosis,

    SUM(los_status = 'MISSING IP LOS')
        AS missing_inpatient_los,

    SUM(cost_tier = 'UNKNOWN')
        AS unknown_cost_tier

FROM medical_claims_clean;

-- MEDICAL CLAIMS TABLE INDEXES
CREATE INDEX idx_medical_claim_id
ON medical_claims_clean (claim_id);

CREATE INDEX idx_medical_member_id
ON medical_claims_clean (member_id);

CREATE INDEX idx_medical_provider_id
ON medical_claims_clean (provider_id);

CREATE INDEX idx_medical_service_date
ON medical_claims_clean (service_date);

CREATE INDEX idx_medical_claim_status
ON medical_claims_clean (claim_status);

-- =====================================================
-- CLEAN PHARMACY CLAIMS
-- =====================================================

DROP TABLE IF EXISTS pharmacy_claims_clean;

CREATE TABLE pharmacy_claims_clean AS

WITH pharmacy_names AS (

    SELECT
        UPPER(TRIM(sp.rx_claim_id)) AS rx_claim_id,
        UPPER(TRIM(sp.member_id)) AS member_id,
        sp.fill_date,

        -- Normalize drug names
        CASE
            WHEN sp.drug_name IS NULL
              OR TRIM(sp.drug_name) = ''
                THEN 'UNKNOWN'

            WHEN UPPER(TRIM(sp.drug_name)) IN
                ('SERT', 'SERTRALINE')
                THEN 'SERTRALINE'

            WHEN UPPER(TRIM(sp.drug_name)) IN
                ('AMOXICILLIN', 'AMOXICILLINE')
                THEN 'AMOXICILLIN'

            WHEN UPPER(TRIM(sp.drug_name)) = 'FLUOXETINE'
                THEN 'FLUOXETINE'

            WHEN UPPER(TRIM(sp.drug_name)) = 'METFORMIN'
                THEN 'METFORMIN'

            WHEN UPPER(TRIM(sp.drug_name)) IN
                ('HYDROCODONE', 'HYDROCODON')
                THEN 'HYDROCODONE'

            -- "HYDRO" is ambiguous, so retain as UNKNOWN.
            WHEN UPPER(TRIM(sp.drug_name)) = 'HYDRO'
                THEN 'UNKNOWN'

            WHEN UPPER(TRIM(sp.drug_name)) = 'ALPRAZOLAM'
                THEN 'ALPRAZOLAM'

            WHEN UPPER(TRIM(sp.drug_name)) = 'ATORVASTATIN'
                THEN 'ATORVASTATIN'

            ELSE 'UNKNOWN'
        END AS drug_name_clean,

        sp.days_supply,
        sp.quantity,

        -- Retain source category for data quality review.
        sp.drug_category AS drug_category_original,

        -- Normalize claim statuses
        CASE
            WHEN UPPER(TRIM(sp.claim_status)) IN
                ('PAID', 'PD', 'P', 'PIAD')
                THEN 'PAID'

            WHEN UPPER(TRIM(sp.claim_status)) IN
                ('DENIED', 'DENY', 'D')
                THEN 'DENIED'

            WHEN UPPER(TRIM(sp.claim_status)) IN
                ('REVERSED', 'REVERSE', 'R')
                THEN 'REVERSED'

            ELSE 'OTHER'
        END AS claim_status,

        sp.drug_cost

    FROM stage_pharmacy sp

    -- Exclude critically rejected pharmacy claims.
    WHERE NOT EXISTS (
        SELECT 1
        FROM rejected_records r
        WHERE r.record_type = 'pharmacy_claim'
          AND UPPER(TRIM(r.record_id)) =
              UPPER(TRIM(sp.rx_claim_id))
    )

    -- Require a valid pharmacy claim identifier.
    AND sp.rx_claim_id IS NOT NULL
    AND TRIM(sp.rx_claim_id) <> ''

    -- Require a valid cleaned member reference.
    AND EXISTS (
        SELECT 1
        FROM members_clean m
        WHERE m.member_id = UPPER(TRIM(sp.member_id))
    )
),

pharmacy_base AS (

    SELECT
        rx_claim_id,
        member_id,
        fill_date,
        drug_name_clean,

        -- Assign categories using standardized drug names.
        CASE
            WHEN drug_name_clean IN
                ('SERTRALINE', 'FLUOXETINE')
                THEN 'ANTIDEPRESSANT'

            WHEN drug_name_clean = 'ALPRAZOLAM'
                THEN 'ANXIOLYTIC'

            WHEN drug_name_clean = 'AMOXICILLIN'
                THEN 'ANTIBIOTIC'

            WHEN drug_name_clean = 'METFORMIN'
                THEN 'ANTIDIABETIC'

            WHEN drug_name_clean = 'ATORVASTATIN'
                THEN 'CHOLESTEROL'

            WHEN drug_name_clean = 'HYDROCODONE'
                THEN 'OPIOID'

            ELSE 'UNKNOWN'
        END AS drug_category_clean,

        days_supply,
        quantity,
        drug_category_original,
        claim_status,
        drug_cost

    FROM pharmacy_names
)

SELECT
    rx_claim_id,
    member_id,
    fill_date,
    drug_name_clean,
    drug_category_clean,

    days_supply,

    -- Group prescriptions by days supplied.
    CASE
        WHEN days_supply IS NULL
          OR days_supply <= 0
          OR days_supply > 365
            THEN 'UNKNOWN'

        WHEN days_supply <= 30
            THEN '30 DAYS OR LESS'

        WHEN days_supply <= 60
            THEN '31-60 DAYS'

        WHEN days_supply <= 90
            THEN '61-90 DAYS'

        ELSE 'OVER 90 DAYS'
    END AS days_supply_band,

    quantity,

    -- Group prescriptions by quantity dispensed.
    CASE
        WHEN quantity IS NULL
          OR quantity <= 0
            THEN 'UNKNOWN'

        WHEN quantity <= 30
            THEN '30 OR LESS'

        WHEN quantity <= 60
            THEN '31-60'

        WHEN quantity <= 90
            THEN '61-90'

        ELSE 'OVER 90'
    END AS quantity_band,

    claim_status,

    -- Assign project-defined cost categories.
    CASE
        WHEN drug_cost >= 500
            THEN 'HIGH COST'

        WHEN drug_cost >= 100
            THEN 'MODERATE COST'

        WHEN drug_cost >= 0
            THEN 'LOW COST'

        ELSE 'UNKNOWN'
    END AS cost_tier,

    -- Standardize pharmacy claim cost.
    ROUND(drug_cost, 2) AS drug_cost

FROM pharmacy_base;

-- PHARMACY CLAIMS TABLE INDEXES
CREATE INDEX idx_pharmacy_claim_id
ON pharmacy_claims_clean (rx_claim_id);

CREATE INDEX idx_pharmacy_member_id
ON pharmacy_claims_clean (member_id);

CREATE INDEX idx_pharmacy_fill_date
ON pharmacy_claims_clean (fill_date);

CREATE INDEX idx_pharmacy_drug_category
ON pharmacy_claims_clean (drug_category_clean);

CREATE INDEX idx_pharmacy_claim_status
ON pharmacy_claims_clean (claim_status);

-- ETL AUDIT LOGGING
INSERT INTO etl_audit_log (
    process_step,
    source_table,
    rows_before,
    rows_after,
    rows_removed
)
SELECT
    'member_clean_load',
    'members_clean',
    (SELECT COUNT(*) FROM stage_members),
    (SELECT COUNT(*) FROM members_clean),
    (SELECT COUNT(*) FROM stage_members)
      - (SELECT COUNT(*) FROM members_clean);

INSERT INTO etl_audit_log (
    process_step,
    source_table,
    rows_before,
    rows_after,
    rows_removed
)
SELECT
    'provider_clean_load',
    'providers_clean',
    (SELECT COUNT(*) FROM stage_providers),
    (SELECT COUNT(*) FROM providers_clean),
    (SELECT COUNT(*) FROM stage_providers)
      - (SELECT COUNT(*) FROM providers_clean);

INSERT INTO etl_audit_log (
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
    (SELECT COUNT(*) FROM stage_medical)
      - (SELECT COUNT(*) FROM medical_claims_clean);

INSERT INTO etl_audit_log (
    process_step,
    source_table,
    rows_before,
    rows_after,
    rows_removed
)
SELECT
    'pharmacy_claim_clean_load',
    'pharmacy_claims_clean',
    (SELECT COUNT(*) FROM stage_pharmacy),
    (SELECT COUNT(*) FROM pharmacy_claims_clean),
    (SELECT COUNT(*) FROM stage_pharmacy)
      - (SELECT COUNT(*) FROM pharmacy_claims_clean);

-- TABLEAU MEDICAL ANALYTICS DATASET: One row per medical claim
DROP TABLE IF EXISTS tableau_medical_claims;

CREATE TABLE tableau_medical_claims AS

SELECT

    -- Member attributes
    m.member_id,
    m.age,
    m.age_band,
    m.gender,
    m.county,
    m.risk_score,
    m.risk_tier,

    -- Medical claim identifiers
    mc.claim_id,
    mc.provider_id,

    -- Service date attributes
    mc.service_date,
    YEAR(mc.service_date) AS service_year,
    MONTH(mc.service_date) AS service_month,
    DATE_FORMAT(
        mc.service_date, '%Y-%m'
    ) AS service_year_month,

    -- Diagnosis information
    mc.icd10_code,
    mc.diagnosis_category,

    -- Claim classification
    mc.claim_status,
    mc.place_of_service,
    mc.length_of_stay,
    mc.los_status,

    -- Financial attributes
    mc.allowed_amount,
    mc.cost_tier,

    -- Allowed amount for PAID claims; not actual insurer payment.
    CASE
        WHEN mc.claim_status = 'PAID'
            THEN mc.allowed_amount
        ELSE NULL
    END AS paid_claim_allowed_amount,

    -- Provider attributes
    p.provider_specialty,
    p.provider_domain,
    p.facility_type_clean

FROM medical_claims_clean mc

INNER JOIN members_clean m
    ON mc.member_id = m.member_id

INNER JOIN providers_clean p
    ON mc.provider_id = p.provider_id;

-- TABLEAU MEDICAL PERFORMANCE INDEXES
CREATE INDEX idx_tm_member
ON tableau_medical_claims(member_id);

CREATE INDEX idx_tm_diag
ON tableau_medical_claims(diagnosis_category);

CREATE INDEX idx_tm_service
ON tableau_medical_claims(service_date);

-- TABLEAU PHARMACY ANALYTICS DATASET: One row per pharmacy claim
DROP TABLE IF EXISTS tableau_pharmacy_claims;

CREATE TABLE tableau_pharmacy_claims AS

SELECT

    -- Member attributes
    m.member_id,
    m.age,
    m.age_band,
    m.gender,
    m.county,
    m.risk_score,
    m.risk_tier,

    -- Pharmacy claim identifiers
    pc.rx_claim_id,

    -- Fill date attributes
    pc.fill_date,
    YEAR(pc.fill_date) AS fill_year,
    MONTH(pc.fill_date) AS fill_month,
    DATE_FORMAT(
        pc.fill_date, '%Y-%m'
    ) AS fill_year_month,

    -- Drug information
    pc.drug_name_clean,
    pc.drug_category_clean,

    -- Supply and quantity
    pc.days_supply,
    pc.days_supply_band,
    pc.quantity,
    pc.quantity_band,

    -- Claim status
    pc.claim_status,

    -- Financial attributes
    pc.drug_cost,
    pc.cost_tier,

    -- Drug cost for PAID claims; not actual reimbursement.
    CASE
        WHEN pc.claim_status = 'PAID'
            THEN pc.drug_cost
        ELSE NULL
    END AS paid_claim_drug_cost

FROM pharmacy_claims_clean pc

INNER JOIN members_clean m
    ON pc.member_id = m.member_id;
    
-- TABLEAU PHARMACY PERFORMANCE INDEXES
CREATE INDEX idx_tp_member
ON tableau_pharmacy_claims(member_id);

CREATE INDEX idx_tp_drug
ON tableau_pharmacy_claims(drug_name_clean);

CREATE INDEX idx_tp_fill
ON tableau_pharmacy_claims(fill_date);

CREATE INDEX idx_tp_drug_category
ON tableau_pharmacy_claims(drug_category_clean);

CREATE INDEX idx_tp_claim_status
ON tableau_pharmacy_claims(claim_status);

-- TABLEAU PHARMACY DATASET VALIDATION
SELECT
    COUNT(*) AS total_tableau_rows,

    COUNT(DISTINCT rx_claim_id) AS unique_claims,

    COUNT(DISTINCT member_id) AS unique_members,

    SUM(claim_status = 'PAID') AS paid_claims,

    SUM(claim_status = 'DENIED') AS denied_claims,

    SUM(claim_status = 'REVERSED') AS reversed_claims,

    SUM(drug_name_clean = 'UNKNOWN')
        AS unknown_drug_names,

    SUM(drug_category_clean IN ('UNKNOWN', 'OTHER'))
        AS unknown_drug_categories,

    SUM(claim_status = 'OTHER')
        AS unknown_claim_statuses

FROM tableau_pharmacy_claims;

SELECT *
FROM tableau_pharmacy_claims;

















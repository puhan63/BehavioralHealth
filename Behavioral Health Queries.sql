/*
===========================================================
Project: Behavioral Health Claims Analytics
Author: Patricia Uhan

Purpose:
Build analytical datasets supporting behavioral health
utilization, member risk analysis, provider performance,
and pharmacy utilization reporting.

ANALYTICAL FLOW:

RAW DATA
    ↓
DATA VALIDATION
    ↓
CLEANING & STANDARDIZATION
    ↓
FEATURE ENGINEERING
    ↓
AGGREGATION
    ↓
ANALYTICS DATASETS
    ↓
TABLEAU DASHBOARD
===========================================================
*/


-- SYSTEM CONFIGURATION (enable local loads and relax constraints for ETL)
SET GLOBAL local_infile = 1;
SET SQL_SAFE_UPDATES = 0;
SET unique_checks = 0;
SET foreign_key_checks = 0;

CREATE DATABASE IF NOT EXISTS behavioral_health;
USE behavioral_health;

-- All dates and derived fields use a fixed reporting date
-- to keep results consistent across reruns.
SET @report_date = '2025-12-31';


-- DROP EXISTING OBJECTS
-- Full rebuild of the environment

-- Remove analytical views (if they exist from previous run)
DROP VIEW IF EXISTS
    member_analysis_dataset,
    provider_analysis_dataset;

-- Drop all staging, raw, and curated tables before rebuild
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
    stage_members,
    stage_providers,
    stage_medical,
    stage_pharmacy,
    rejected_records;

-- ETL AUDIT LOG (pipeline tracking)
-- Basic pipeline tracking (row counts before/after each step)
CREATE TABLE etl_audit_log (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    process_step VARCHAR(100),
    source_table VARCHAR(100),
    rows_before INT,
    rows_after INT,
    rows_removed INT,
    process_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- REJECTED RECORDS
-- Stores all rows that fail validation rules during ETL
-- Useful for debugging and data quality checks
CREATE TABLE rejected_records (
    record_type VARCHAR(30),
    record_id VARCHAR(20),
    rejection_reason VARCHAR(255),
    rejection_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- RAW TABLES
-- Landing zone for source files (no transformations applied)
CREATE TABLE raw_members (
    member_id VARCHAR(10) PRIMARY KEY,
    dob VARCHAR(10),
    gender VARCHAR(10),
    county VARCHAR(30),
    enrollment_start VARCHAR(10),
    enrollment_end VARCHAR(10),
    risk_score DECIMAL(8,2)
);

CREATE TABLE raw_providers (
provider_id VARCHAR(10) PRIMARY KEY,
npi CHAR(10),
provider_name VARCHAR(50),
provider_type VARCHAR(30),
facility_type VARCHAR(50),
county VARCHAR(30)
);

CREATE TABLE raw_medical_claims (
claim_id VARCHAR(10) PRIMARY KEY,
member_id VARCHAR(10),
provider_id VARCHAR(10),
service_date DATE,
icd10_code CHAR(7),
claim_status VARCHAR(20),
place_of_service CHAR(5),
length_of_stay INT,
allowed_amount DECIMAL(10,2)
);

CREATE TABLE raw_pharmacy_claims (
rx_claim_id VARCHAR(10) PRIMARY KEY,
member_id VARCHAR(10),
fill_date DATE,
drug_name VARCHAR(50),
drug_category VARCHAR(30),
days_supply INT,
quantity INT,
claim_status VARCHAR(20),
drug_cost DECIMAL(10,2)
);

-- LOAD DATA
-- CSV ingestion into raw layer (pre-staging)
LOAD DATA LOCAL INFILE 'C:/Users/dutch/Documents/members_behavioral_health.csv'
INTO TABLE raw_members
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(member_id, dob, gender, county, enrollment_start, enrollment_end, @risk_score)
SET
risk_score = NULLIF(TRIM(@risk_score), '');


LOAD DATA LOCAL INFILE 'C:/Users/dutch/Documents/providers_behavioral_health.csv'
INTO TABLE raw_providers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(provider_id, npi, provider_name, provider_type, facility_type, county);

LOAD DATA LOCAL INFILE 'C:/Users/dutch/Documents/medical_claims_behavioral_health.csv'
INTO TABLE raw_medical_claims
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(claim_id, member_id, provider_id, service_date, icd10_code, claim_status, place_of_service, length_of_stay, allowed_amount);

LOAD DATA LOCAL INFILE 'C:/Users/dutch/Documents/pharmacy_claims_behavioral_health.csv'
INTO TABLE raw_pharmacy_claims
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(rx_claim_id, member_id, fill_date, drug_name, drug_category, days_supply, quantity, claim_status, drug_cost);

-- STAGING TABLES
-- Light transformation layer where raw data is standardized
-- before validation and downstream cleaning
CREATE TABLE stage_members (
    member_id VARCHAR(10),
    dob DATE,
    gender VARCHAR(10),
    county VARCHAR(30),
    enrollment_start DATE,
    enrollment_end DATE,
    risk_score DECIMAL(8,2)
);
-- Convert string dates into proper DATE types and normalize missing values
INSERT INTO stage_members
SELECT
    member_id,
	CASE 
        WHEN dob IS NULL OR TRIM(dob) = '' THEN NULL
        ELSE STR_TO_DATE(dob, '%Y-%m-%d')
    END AS dob,

    gender,
    county,

    CASE 
        WHEN enrollment_start IS NULL OR TRIM(enrollment_start) = '' THEN NULL
        ELSE STR_TO_DATE(enrollment_start, '%Y-%m-%d')
    END AS enrollment_start,

    CASE 
        WHEN enrollment_end IS NULL OR TRIM(enrollment_end) = '' THEN NULL
        ELSE STR_TO_DATE(enrollment_end, '%Y-%m-%d')
    END AS enrollment_end,

    risk_score
FROM raw_members;

-- Pass-through staging for structured tables (no transformation needed yet)
CREATE TABLE stage_providers AS
SELECT *
FROM raw_providers;

CREATE TABLE stage_medical AS
SELECT *
FROM raw_medical_claims;

CREATE TABLE stage_pharmacy AS
SELECT *
FROM raw_pharmacy_claims;

-- MEMBER VALIDATION
-- Basic data quality checks for member records before downstream use
-- Invalid records are logged in rejected_records and excluded from curated tables
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'member', member_id, 'DOB is missing or in the future'
FROM stage_members
WHERE dob IS NULL OR dob > @report_date;

INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'member', member_id, 'Age exceeds expected threshold (>120)'
FROM stage_members
WHERE TIMESTAMPDIFF(YEAR, dob, @report_date) > 120;

INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'member', member_id, 'Enrollment dates are invalid'
FROM stage_members
WHERE enrollment_start IS NULL
   OR enrollment_start > @report_date
   OR (enrollment_end IS NOT NULL AND enrollment_end < enrollment_start);

INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'member', member_id, 'Enrollment starts before DOB'
FROM stage_members
WHERE enrollment_start < dob;

INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'member', member_id, 'Gender is missing'
FROM stage_members
WHERE gender IS NULL OR TRIM(gender) = '';

INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'member', member_id, 'Risk score is out of range or missing'
FROM stage_members
WHERE risk_score IS NULL
   OR risk_score < 0
   OR risk_score > 5;

-- PROVIDER VALIDATION
-- Basic data quality checks for provider records
-- Flags incomplete or structurally invalid provider attributes
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'provider', provider_id, 'Provider type is missing'
FROM stage_providers
WHERE provider_type IS NULL OR TRIM(provider_type) = '';

INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'provider', provider_id, 'Facility type is missing'
FROM stage_providers
WHERE facility_type IS NULL OR TRIM(facility_type) = '';

INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'provider', provider_id, 'County is missing'
FROM stage_providers
WHERE county IS NULL OR TRIM(county) = '';

INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'provider', provider_id, 'NPI is invalid or not properly formatted'
FROM stage_providers
WHERE npi IS NULL
   OR TRIM(npi) = ''
   OR LENGTH(TRIM(npi)) <> 10
   OR TRIM(npi) NOT REGEXP '^[0-9]{10}$';

-- MEDICAL CLAIM VALIDATION
-- Validate medical claims before loading them into the cleaned table.
-- Any records that fail validation are logged for review.

-- Validate required identifiers
-- Missing claim ID
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'medical_claim', claim_id, 'Missing claim_id'
FROM stage_medical
WHERE claim_id IS NULL OR TRIM(claim_id) = '';

-- Member ID is required
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'medical_claim', claim_id, 'Missing member_id'
FROM stage_medical
WHERE (member_id IS NULL OR TRIM(member_id) = '');

-- Provider ID is required
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'medical_claim', claim_id, 'Missing provider_id'
FROM stage_medical
WHERE (provider_id IS NULL OR TRIM(provider_id) = '');

-- Duplicate claim IDs (should be unique per claim)
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'medical_claim', m.claim_id, 'Duplicate claim_id'
FROM stage_medical m
JOIN (
    SELECT claim_id
    FROM stage_medical
    GROUP BY claim_id
    HAVING COUNT(*) > 1
) d
ON UPPER(TRIM(m.claim_id)) = UPPER(TRIM(d.claim_id));

-- Validate service dates
-- Reject claims without a service date
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'medical_claim', claim_id, 'Missing service_date'
FROM stage_medical
WHERE service_date IS NULL;

-- Service date cannot be in the future
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'medical_claim', claim_id, 'Future service_date'
FROM stage_medical
WHERE service_date > @report_date;

-- Validate diagnosis codes
-- Missing ICD10
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'medical_claim', claim_id, 'Missing ICD10 code'
FROM stage_medical
WHERE icd10_code IS NULL
   OR TRIM(icd10_code) = '';

-- ICD-10 must be within approved behavioral/medical set
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'medical_claim', claim_id, 'Invalid ICD10 code'
FROM stage_medical
WHERE UPPER(TRIM(icd10_code))
NOT IN (
    'F32','F33','F41','F43',
    'G47','I10','E11','J45'
)
AND icd10_code IS NOT NULL
AND TRIM(icd10_code) <> '';

-- Validate claim status values
INSERT INTO rejected_records
(record_type, record_id, rejection_reason)
SELECT 'medical_claim', claim_id, 'Invalid claim status'
FROM stage_medical
WHERE UPPER(TRIM(claim_status))
NOT IN (
    'PAID',
    'PD',
    'P',
    'PIAD',
    'DENIED',
    'DENY',
    'D',
    'REVERSED',
    'REVERSE',
    'R'
)
AND claim_status IS NOT NULL
AND TRIM(claim_status) <> '';

-- Validate place of service values
INSERT INTO rejected_records
(record_type, record_id, rejection_reason)
SELECT 'medical_claim', claim_id, 'Invalid place_of_service'
FROM stage_medical
WHERE UPPER(TRIM(place_of_service)) NOT IN (
    'IP','I.P.','INPAT',
    'OP','O.P.','OUTPA',
    'ED','EMERG','EMERGENCY','EMERG.'
)
AND place_of_service IS NOT NULL
AND TRIM(place_of_service) <> '';

-- Validate financial and utilization fields
-- Allowed amount must be within reasonable bounds
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'medical_claim', claim_id, 'Invalid or missing allowed_amount'
FROM stage_medical
WHERE allowed_amount IS NULL
   OR allowed_amount < 0.00
   OR allowed_amount > 24984.00;

-- Length of stay should not be negative
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'medical_claim', claim_id, 'Negative length_of_stay'
FROM stage_medical
WHERE length_of_stay < 0;

-- Inpatient claims must include length of stay
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'medical_claim', claim_id, 'Missing LOS for inpatient claim'
FROM stage_medical
WHERE UPPER(TRIM(place_of_service)) IN ('IP','I.P.','INPAT')
  AND length_of_stay IS NULL;

-- PHARMACY CLAIM VALIDATION
-- Validate pharmacy claims before loading the cleaned table.
-- Failed records are stored in rejected_records.

-- Validate required identifiers
-- Missing prescription claim ID
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'pharmacy_claim', rx_claim_id, 'Missing rx_claim_id'
FROM stage_pharmacy
WHERE rx_claim_id IS NULL
   OR TRIM(rx_claim_id) = '';
   
-- Duplicate prescription claim IDs
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'pharmacy_claim', p.rx_claim_id, 'Duplicate rx_claim_id'
FROM stage_pharmacy p
JOIN
(
    SELECT rx_claim_id
    FROM stage_pharmacy
    GROUP BY rx_claim_id
    HAVING COUNT(*) > 1
) d
ON UPPER(TRIM(p.rx_claim_id)) = UPPER(TRIM(d.rx_claim_id));

-- Missing member reference
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'pharmacy_claim', rx_claim_id, 'Missing member_id'
FROM stage_pharmacy
WHERE member_id IS NULL
   OR TRIM(member_id) = '';
   

-- Validate prescription information
-- Drug name is required
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'pharmacy_claim', rx_claim_id, 'Missing or invalid drug_name'
FROM stage_pharmacy
WHERE drug_name IS NULL
   OR TRIM(drug_name) = '';

-- Validate fill dates
-- Missing fill_date
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'pharmacy_claim', rx_claim_id, 'Missing fill_date'
FROM stage_pharmacy
WHERE fill_date IS NULL;

-- Fill date cannot be after the reporting date
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'pharmacy_claim', rx_claim_id, 'Future fill_date'
FROM stage_pharmacy
WHERE fill_date > @report_date;

-- Validate claim status values
-- Verify claim status against accepted values
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'pharmacy_claim', rx_claim_id, 'Invalid claim_status'
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
AND TRIM(claim_status) <> '';

-- Validate cost and utilization fields
-- Drug cost cannot be negative or missing
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'pharmacy_claim', rx_claim_id, 'Invalid drug_cost'
FROM stage_pharmacy
WHERE drug_cost IS NULL
   OR drug_cost < 0;
   
-- Days supply must be within an acceptable range
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'pharmacy_claim', rx_claim_id, 'Invalid days_supply'
FROM stage_pharmacy
WHERE days_supply IS NULL
   OR days_supply <= 0
   OR days_supply > 365;

-- Quantity dispensed must be greater than zero
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'pharmacy_claim', rx_claim_id, 'Invalid quantity'
FROM stage_pharmacy
WHERE quantity IS NULL
   OR quantity <= 0;

-- CLEAN MEMBER DATA
-- Build the curated member dimension by standardizing values,
-- deriving reporting fields, and excluding records that failed
-- validation.
CREATE TABLE members_clean AS
SELECT
    UPPER(TRIM(member_id)) AS member_id,
    dob,

-- Normalize gender values
CASE
	WHEN UPPER(TRIM(gender)) IN ('M','MALE') THEN 'M'
	WHEN UPPER(TRIM(gender)) IN ('F','FEMALE') THEN 'F'
	ELSE 'UNKNOWN'
    END AS gender,

    enrollment_start,
    enrollment_end,

-- Round risk score for reporting
    ROUND(risk_score,2) AS risk_score,
    
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

-- Categorize members by risk score
CASE
    WHEN risk_score < 1.5 THEN 'LOW RISK'
    WHEN risk_score < 2.5 THEN 'MODERATE RISK'
    ELSE 'HIGH RISK'
	END AS risk_tier,

-- Calculate member age as of the reporting date
TIMESTAMPDIFF(YEAR, dob, @report_date) AS age,

-- Create age groups for reporting
CASE
	WHEN TIMESTAMPDIFF(YEAR, dob, @report_date) < 18 THEN 'Under 18'
	WHEN TIMESTAMPDIFF(YEAR, dob, @report_date) BETWEEN 18 AND 34 THEN '18-34'
	WHEN TIMESTAMPDIFF(YEAR, dob, @report_date) BETWEEN 35 AND 49 THEN '35-49'
	WHEN TIMESTAMPDIFF(YEAR, dob, @report_date) BETWEEN 50 AND 64 THEN '50-64'
	ELSE '65+'
    END AS age_band
FROM stage_members

-- Exclude records that failed validation
WHERE NOT EXISTS (
    SELECT 1
    FROM rejected_records r
    WHERE r.record_type = 'member'
      AND r.record_id = stage_members.member_id
);

-- MEDICAL MEMBER REFERENCE CHECK (ENROLLMENT VALIDATION)
-- Service date must fall within member enrollment window
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'medical_claim', m.claim_id, 'Service date outside enrollment'
FROM stage_medical m
JOIN members_clean mc
    ON UPPER(TRIM(m.member_id)) = mc.member_id
WHERE m.service_date < mc.enrollment_start
   OR (
        mc.enrollment_end IS NOT NULL
        AND m.service_date > mc.enrollment_end
      );
      
-- PHARMACY CLAIM ENROLLMENT VALIDATION (CROSS-REFERENCE CHECK)
-- Fill date must fall within the member's enrollment period
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'pharmacy_claim', p.rx_claim_id, 'Fill date outside enrollment'
FROM stage_pharmacy p
JOIN members_clean m
    ON UPPER(TRIM(p.member_id)) = m.member_id
WHERE p.fill_date < m.enrollment_start
   OR (
        m.enrollment_end IS NOT NULL
        AND p.fill_date > m.enrollment_end
      );

-- MEMBER TABLE INDEXES
-- Add indexes to support common reporting and lookup queries.
CREATE INDEX idx_members_member
ON members_clean (member_id);

CREATE INDEX idx_members_county
ON members_clean (county);

CREATE INDEX idx_members_risk
ON members_clean (risk_tier);

-- MEDICAL MEMBER REFERENCE CHECK
-- Verify that each medical claim references a valid member
-- from the cleaned member table.
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'medical_claim', m.claim_id, 'Invalid member_id'
FROM stage_medical m
LEFT JOIN members_clean c
       ON UPPER(TRIM(m.member_id)) = c.member_id
WHERE c.member_id IS NULL;


-- PHARMACY MEMBER REFERENCE CHECK
-- Verify that each pharmacy claim references a valid member
-- from the cleaned member table.
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'pharmacy_claim', p.rx_claim_id, 'Invalid member_id'
FROM stage_pharmacy p
LEFT JOIN members_clean m
       ON UPPER(TRIM(p.member_id)) = m.member_id
WHERE m.member_id IS NULL;

-- CLEAN PROVIDER DATA
-- Standardize provider information and derive reporting
-- attributes for use in downstream analytics.
CREATE TABLE providers_clean AS

-- Prepare standardized provider values before applying
-- reporting classifications.
WITH provider_base AS (

		SELECT
		UPPER(TRIM(provider_id)) AS provider_id,
		TRIM(npi) AS npi,
        TRIM(provider_name) AS provider_name,

        -- Normalize provider types
        CASE
            WHEN UPPER(TRIM(provider_type)) LIKE '%PSYCH%' THEN 'PSYCHIATRIST'
            WHEN UPPER(TRIM(provider_type)) LIKE '%THERAP%' THEN 'THERAPIST'
            WHEN UPPER(TRIM(provider_type)) LIKE '%PRIMARY%' THEN 'PRIMARY CARE'
            WHEN UPPER(TRIM(provider_type)) LIKE '%CARDIO%' THEN 'CARDIOLOGY'
            WHEN UPPER(TRIM(provider_type)) LIKE '%ENDO%' THEN 'ENDOCRINOLOGIST'
            WHEN UPPER(TRIM(provider_type)) LIKE '%ER%' THEN 'ER PHYSICIAN'
            WHEN UPPER(TRIM(provider_type)) LIKE '%HOSPITALIST%' THEN 'HOSPITALIST'
            ELSE 'OTHER'
        END AS provider_type_clean,

        facility_type,
        county

    FROM stage_providers

    -- Exclude providers that failed validation
    WHERE NOT EXISTS (
        SELECT 1
        FROM rejected_records r
        WHERE r.record_type='provider'
          AND r.record_id=stage_providers.provider_id
    )

)

SELECT

    provider_id,
    npi,
    provider_name,
	provider_type_clean,

    -- Map provider types to reporting specialties
    CASE
        WHEN provider_type_clean='PSYCHIATRIST' THEN 'PSYCHIATRY'
        WHEN provider_type_clean='THERAPIST' THEN 'THERAPY'
        WHEN provider_type_clean='PRIMARY CARE' THEN 'PRIMARY CARE'
        WHEN provider_type_clean='CARDIOLOGY' THEN 'CARDIOLOGY'
        WHEN provider_type_clean='ENDOCRINOLOGIST' THEN 'ENDOCRINOLOGY'
        WHEN provider_type_clean='ER PHYSICIAN' THEN 'EMERGENCY MEDICINE'
        WHEN provider_type_clean='HOSPITALIST' THEN 'HOSPITAL MEDICINE'
        ELSE 'OTHER'
    END AS provider_specialty,

    -- Group specialties into broader reporting domains
    CASE
        WHEN provider_type_clean IN ('PSYCHIATRIST','THERAPIST')
            THEN 'BEHAVIORAL HEALTH'
        WHEN provider_type_clean='PRIMARY CARE'
            THEN 'PRIMARY CARE'
        WHEN provider_type_clean IN ('ER PHYSICIAN','HOSPITALIST')
            THEN 'ACUTE / EMERGENCY CARE'
        WHEN provider_type_clean IN ('CARDIOLOGY','ENDOCRINOLOGIST')
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
-- Add indexes to improve joins and reporting queries.
CREATE INDEX idx_provider_id
ON providers_clean (provider_id);

CREATE INDEX idx_provider_specialty
ON providers_clean (provider_specialty);

CREATE INDEX idx_provider_domain
ON providers_clean (provider_domain);


-- MEDICAL PROVIDER REFERENCE CHECK
-- Verify that each medical claim references a valid provider
-- from the cleaned provider table.
INSERT INTO rejected_records (record_type, record_id, rejection_reason)
SELECT 'medical_claim', m.claim_id, 'Invalid provider_id'
FROM stage_medical m
LEFT JOIN providers_clean p
       ON UPPER(TRIM(m.provider_id)) = p.provider_id
WHERE p.provider_id IS NULL;

-- CLEAN MEDICAL CLAIMS
-- Standardize medical claims and create the final claims table used
-- for reporting and downstream analytics. Diagnosis codes, claim
-- status, place of service, and cost categories are normalized,
-- and only records that pass validation are retained.
CREATE TABLE medical_claims_clean AS
SELECT
    UPPER(TRIM(claim_id)) AS claim_id,
    UPPER(TRIM(member_id)) AS member_id,
    UPPER(TRIM(provider_id)) AS provider_id,
    service_date,

    -- Standardize ICD-10 codes before assigning diagnosis groups
    UPPER(TRIM(icd10_code)) AS icd10_code,

    CASE
        WHEN UPPER(TRIM(icd10_code)) IN ('F32','F33')
            THEN 'Depression'

        WHEN UPPER(TRIM(icd10_code)) = 'F41'
            THEN 'Anxiety'

        WHEN UPPER(TRIM(icd10_code)) = 'F43'
            THEN 'Trauma / Stress Disorders'

        WHEN UPPER(TRIM(icd10_code)) = 'G47'
            THEN 'Sleep Disorders'

        WHEN UPPER(TRIM(icd10_code)) = 'I10'
            THEN 'Hypertension'

        WHEN UPPER(TRIM(icd10_code)) = 'E11'
            THEN 'Type 2 Diabetes'

        WHEN UPPER(TRIM(icd10_code)) = 'J45'
            THEN 'Asthma'

        ELSE 'Other'
    END AS diagnosis_category,

    -- Normalize claim status values
    CASE
    WHEN UPPER(TRIM(claim_status)) IN ('PAID', 'PD', 'P', 'PIAD')
        THEN 'PAID'

    WHEN UPPER(TRIM(claim_status)) IN ('DENIED', 'DENY', 'D')
        THEN 'DENIED'

    WHEN UPPER(TRIM(claim_status)) IN ('REVERSED', 'REVERSE', 'R')
        THEN 'REVERSED'

    ELSE 'OTHER'
END AS claim_status,

   -- Standardize place of service
   CASE
    WHEN UPPER(TRIM(place_of_service)) IN ('IP','I.P.','INPAT')
        THEN 'INPATIENT'

    WHEN UPPER(TRIM(place_of_service)) IN ('OP','O.P.','OUTPA')
        THEN 'OUTPATIENT'

    WHEN UPPER(TRIM(place_of_service)) IN ('ED','EMERG','EMERGENC','EMERGENCY','EMERG.')
        THEN 'EMERGENCY'

    ELSE 'OTHER'
END AS place_of_service,

    -- Keep length of stay only for inpatient claims
    CASE
    WHEN UPPER(TRIM(place_of_service)) IN ('IP','I.P.','INPAT','INPATIENT HOSPITAL')
        THEN length_of_stay
    ELSE NULL
END AS length_of_stay,

-- Flag inpatient records with missing length of stay
CASE
    WHEN UPPER(TRIM(place_of_service)) IN ('IP','I.P.','INPAT','INPATIENT HOSPITAL')
         AND length_of_stay IS NULL
        THEN 'MISSING IP LOS'

    WHEN UPPER(TRIM(place_of_service)) IN ('IP','I.P.','INPAT','INPATIENT HOSPITAL')
        THEN 'VALID IP LOS'

    ELSE 'NOT APPLICABLE'
END AS los_status,    
    ROUND(allowed_amount, 2) AS allowed_amount,

-- Group claims into cost tiers
CASE
        WHEN allowed_amount >= 20000 THEN 'HIGH COST'
        WHEN allowed_amount >= 5000 THEN 'MODERATE COST'
        WHEN allowed_amount >= 0 THEN 'NORMAL COST'
        ELSE 'UNKNOWN'
    END AS cost_tier

FROM stage_medical

-- Exclude claims that failed validation and confirm member/provider references
WHERE NOT EXISTS (
    SELECT 1
    FROM rejected_records r
    WHERE r.record_type = 'medical_claim'
      AND r.record_id = stage_medical.claim_id
)
AND claim_id IS NOT NULL
AND TRIM(claim_id) <> ''

AND member_id IS NOT NULL
AND TRIM(member_id) <> ''

AND provider_id IS NOT NULL
AND TRIM(provider_id) <> ''
AND EXISTS (
    SELECT 1
    FROM members_clean m
    WHERE m.member_id = TRIM(stage_medical.member_id)
)
AND EXISTS (
    SELECT 1
    FROM providers_clean p
    WHERE p.provider_id = UPPER(TRIM(stage_medical.provider_id))
);

-- MEDICAL CLAIMS INDEXES
-- Add indexes to improve performance for common joins and reporting queries.
CREATE INDEX idx_medical_member
ON medical_claims_clean (member_id);

CREATE INDEX idx_medical_provider
ON medical_claims_clean (provider_id);

CREATE INDEX idx_medical_service_date
ON medical_claims_clean (service_date);

CREATE INDEX idx_medical_icd10
ON medical_claims_clean (icd10_code);

CREATE INDEX idx_medical_claim_status
ON medical_claims_clean (claim_status);

-- CLEAN PHARMACY CLAIMS
-- Standardize pharmacy claims and create the final claims table
-- used for reporting and analysis. Drug names, drug categories,
-- claim status, and cost tiers are normalized, and only validated
-- records are included.
CREATE TABLE pharmacy_claims_clean AS
SELECT
    UPPER(TRIM(rx_claim_id)) AS rx_claim_id,
    UPPER(TRIM(member_id)) AS member_id,
    fill_date,

	-- Normalize drug names
    CASE
        WHEN drug_name IS NULL OR TRIM(drug_name) = ''
            THEN 'UNKNOWN'

        WHEN UPPER(TRIM(drug_name)) IN ('SERT', 'SERTRALINE')
            THEN 'SERTRALINE'

        WHEN UPPER(TRIM(drug_name)) IN ('AMOXICILLIN', 'AMOXICILLINE')
            THEN 'AMOXICILLIN'

        WHEN UPPER(TRIM(drug_name)) = 'FLUOXETINE'
            THEN 'FLUOXETINE'

        WHEN UPPER(TRIM(drug_name)) = 'METFORMIN'
            THEN 'METFORMIN'

        WHEN UPPER(TRIM(drug_name)) IN ('HYDROCODONE', 'HYDROCODON')
            THEN 'HYDROCODONE'

        -- Avoid mapping ambiguous abbreviations
        WHEN UPPER(TRIM(drug_name)) = 'HYDRO'
            THEN 'UNKNOWN'

        WHEN UPPER(TRIM(drug_name)) = 'ALPRAZOLAM'
            THEN 'ALPRAZOLAM'

        WHEN UPPER(TRIM(drug_name)) = 'ATORVASTATIN'
            THEN 'ATORVASTATIN'

        ELSE 'UNKNOWN'
    END AS drug_name_clean,

-- Normalize drug categories
CASE
    WHEN drug_category IS NULL
         OR TRIM(drug_category) = ''
        THEN 'UNKNOWN'

    WHEN UPPER(TRIM(drug_category))
         IN ('ANTIDEPRESSANT',
             'ANTI DEPRESSANT',
             'ANTI-DEPRESSANT')
        THEN 'ANTIDEPRESSANT'

    WHEN UPPER(TRIM(drug_category))
         IN ('ANXIOLYTIC')
        THEN 'ANXIOLYTIC'

    WHEN UPPER(TRIM(drug_category))
         IN ('ANTIBIOTIC')
        THEN 'ANTIBIOTIC'

    WHEN UPPER(TRIM(drug_category))
         IN ('DIABETES',
             'DIABETIC',
             'ANTIDIABETIC')
        THEN 'ANTIDIABETIC'

    WHEN UPPER(TRIM(drug_category))
         IN ('CHOLESTEROL',
             'COLESTEROL')
        THEN 'CHOLESTEROL'

    WHEN UPPER(TRIM(drug_category))
         IN ('OPIOID')
        THEN 'OPIOID'

    ELSE 'OTHER'
END AS drug_category_clean,

days_supply,

-- Group prescriptions by days supplied
CASE
    WHEN days_supply <= 30 THEN '30 DAYS OR LESS'
    WHEN days_supply <= 60 THEN '31–60 DAYS'
    WHEN days_supply <= 90 THEN '61–90 DAYS'
    ELSE 'OVER 90 DAYS'
END AS days_supply_band,

quantity,

-- Group prescriptions by quantity dispensed
CASE
    WHEN quantity <= 30 THEN '30 OR LESS'
    WHEN quantity <= 60 THEN '31–60'
    WHEN quantity <= 90 THEN '61–90'
    ELSE 'OVER 90'
END AS quantity_band,

-- Normalize claim status values
CASE

    WHEN UPPER(TRIM(claim_status))
         IN ('PAID','PD','P')
        THEN 'PAID'

    WHEN UPPER(TRIM(claim_status))
         IN ('DENIED','DENY','D')
        THEN 'DENIED'

    WHEN UPPER(TRIM(claim_status))
         IN ('REVERSED','REVERSE')
        THEN 'REVERSED'
    
    ELSE 'OTHER'

END AS claim_status,

-- Classify prescriptions into cost tiers
CASE
    WHEN drug_cost >= 500 THEN 'HIGH COST'
    WHEN drug_cost >= 100 THEN 'MODERATE COST'
    WHEN drug_cost >= 0 THEN 'LOW COST'
    ELSE 'UNKNOWN'
END AS cost_tier,

ROUND(drug_cost, 2) AS drug_cost

FROM stage_pharmacy

-- Keep only validated pharmacy claims linked to a valid member
WHERE NOT EXISTS (
    SELECT 1
    FROM rejected_records r
    WHERE r.record_type = 'pharmacy_claim'
      AND r.record_id = stage_pharmacy.rx_claim_id
)
AND EXISTS (
    SELECT 1
    FROM members_clean m
    WHERE m.member_id = TRIM(stage_pharmacy.member_id)
);


-- PHARMACY CLAIMS INDEXES
-- Add indexes to improve join performance and support common reporting filters.
CREATE INDEX idx_pharmacy_member
ON pharmacy_claims_clean (member_id);

CREATE INDEX idx_pharmacy_fill_date
ON pharmacy_claims_clean (fill_date);

CREATE INDEX idx_pharmacy_drug
ON pharmacy_claims_clean (drug_name_clean);

CREATE INDEX idx_pharmacy_status
ON pharmacy_claims_clean (claim_status);

-- ETL AUDIT LOGGING
-- Record row counts across staging, cleaned, and rejected datasets
-- to support reconciliation and basic data quality tracking.
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
    (SELECT COUNT(*) FROM rejected_records WHERE record_type = 'member');

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
    (SELECT COUNT(*) FROM rejected_records WHERE record_type = 'provider');

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
    (SELECT COUNT(*) FROM rejected_records WHERE record_type = 'medical_claim');

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
    (SELECT COUNT(*) FROM rejected_records WHERE record_type = 'pharmacy_claim');
    
-- TABLEAU MEDICAL ANALYTICS DATASET
-- One row = One medical claim
CREATE TABLE tableau_medical_claims AS

SELECT

    -- Member
    m.member_id,
    m.age,
    m.age_band,
    m.gender,
    m.county,
    m.risk_score,
    m.risk_tier,

    -- Medical claim
    mc.claim_id,
    mc.service_date,
    YEAR(mc.service_date) AS service_year,
    MONTH(mc.service_date) AS service_month,

    mc.diagnosis_category,
    mc.claim_status,
    mc.place_of_service,
    mc.length_of_stay,
    mc.allowed_amount,
    mc.cost_tier,

    -- Provider
    p.provider_specialty,
    p.provider_domain,
    p.facility_type_clean

FROM medical_claims_clean mc

JOIN members_clean m
ON mc.member_id = m.member_id

JOIN providers_clean p
ON mc.provider_id = p.provider_id;

-- TABLEAU PERFORMANCE OPTIMIZATION INDEXES
-- These indexes are created on the Tableau-facing dataset to improve
-- query performance for filtering, grouping, and dashboard interactions.
-- They support common Tableau use cases such as:
-- - filtering by member_id for patient-level views
-- - aggregating by diagnosis_category for clinical insights
-- - time-based analysis using service_date

CREATE INDEX idx_tm_member
ON tableau_medical_claims(member_id);

-- Supports grouping and filtering by diagnosis for trend analysis
CREATE INDEX idx_tm_diag
ON tableau_medical_claims(diagnosis_category);

-- Optimizes time-series analysis (monthly, yearly, cohort trends)
CREATE INDEX idx_tm_service
ON tableau_medical_claims(service_date);

-- TABLEAU PHARMACY ANALYTICS DATASET
-- One row = One pharmacy claim
CREATE TABLE tableau_pharmacy_claims AS

SELECT

    -- Member
    m.member_id,
    m.age,
    m.age_band,
    m.gender,
    m.county,
    m.risk_score,
    m.risk_tier,

    -- Pharmacy claim
    pc.rx_claim_id,
    pc.fill_date,
    YEAR(pc.fill_date) AS fill_year,
    MONTH(pc.fill_date) AS fill_month,

    pc.drug_name_clean,
    pc.drug_category_clean,

    pc.days_supply,
    pc.days_supply_band,

    pc.quantity,

    pc.claim_status,

    pc.drug_cost,

    pc.cost_tier

FROM pharmacy_claims_clean pc

JOIN members_clean m
ON pc.member_id = m.member_id;
    
-- TABLEAU PHARMACY ANALYTICS PERFORMANCE INDEXES
-- These indexes are designed to optimize Tableau dashboard performance
-- for pharmacy claims analysis. They support common filter and aggregation
-- patterns such as:
-- - member-level medication history views
-- - drug utilization and prescribing trends
-- - time-based refill and dispensing analysis

-- Improves performance for patient-level pharmacy lookups
CREATE INDEX idx_tp_member
ON tableau_pharmacy_claims(member_id);

-- Supports drug-level analysis (most prescribed drugs, cost trends, etc.)
CREATE INDEX idx_tp_drug
ON tableau_pharmacy_claims(drug_name_clean);

-- Optimizes time-series analysis of prescriptions (monthly/yearly trends)
CREATE INDEX idx_tp_fill
ON tableau_pharmacy_claims(fill_date);    

SELECT *
FROM tableau_medical_claims;

SELECT *
FROM tableau_pharmacy_claims;




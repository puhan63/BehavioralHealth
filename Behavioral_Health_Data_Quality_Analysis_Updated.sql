USE behavioral_health_v2;

-- BEHAVIORAL HEALTH CLAIMS ANALYTICS V2
-- DATA QUALITY AND VALIDATION
-- Read-only checks for raw, staged, cleaned, and Tableau-ready data.
-- Review completeness, referential integrity, standardization,
-- rejection/warning logs, and record retention.
-- Dataset contains synthetic healthcare claims.
-- Run after the ETL has created all referenced tables.

-- 1. RAW DATA PROFILING

-- 1.1 Compare source record counts across the four raw datasets.
SELECT 'Members' AS dataset, COUNT(*) AS total_records FROM raw_members
UNION ALL SELECT 'Providers', COUNT(*) FROM raw_providers
UNION ALL SELECT 'Medical Claims', COUNT(*) FROM raw_medical_claims
UNION ALL SELECT 'Pharmacy Claims', COUNT(*) FROM raw_pharmacy_claims;

-- 1.2 Validate raw member enrollment dates (MM/DD/YYYY strings).
-- A missing end date is tracked separately; it is not automatically invalid.
SELECT
    COUNT(*) AS total_members,
    SUM(CASE WHEN enrollment_start IS NULL OR TRIM(enrollment_start) = ''
              OR STR_TO_DATE(enrollment_start, '%m/%d/%Y') IS NULL
             THEN 1 ELSE 0 END) AS missing_or_invalid_start,
    SUM(CASE WHEN enrollment_end IS NULL OR TRIM(enrollment_end) = ''
             THEN 1 ELSE 0 END) AS missing_end,
    SUM(CASE WHEN enrollment_end IS NOT NULL AND TRIM(enrollment_end) <> ''
              AND STR_TO_DATE(enrollment_end, '%m/%d/%Y') IS NULL
             THEN 1 ELSE 0 END) AS invalid_nonblank_end,
    SUM(CASE WHEN STR_TO_DATE(enrollment_start, '%m/%d/%Y') >
                  STR_TO_DATE(NULLIF(TRIM(enrollment_end), ''), '%m/%d/%Y')
             THEN 1 ELSE 0 END) AS end_before_start
FROM raw_members;

-- 1.3 Check medical service dates against member enrollment.
-- Missing end dates are treated as open-ended through 2024-12-31.
-- Missing/unparseable dates and unmatched IDs are reported separately in 1.5.
SELECT
    COUNT(*) AS matched_medical_claims,
    SUM(CASE WHEN STR_TO_DATE(mc.service_date, '%m/%d/%Y') <
                  STR_TO_DATE(m.enrollment_start, '%m/%d/%Y')
              OR STR_TO_DATE(mc.service_date, '%m/%d/%Y') >
                  COALESCE(STR_TO_DATE(NULLIF(TRIM(m.enrollment_end), ''), '%m/%d/%Y'),
                           DATE('2024-12-31'))
             THEN 1 ELSE 0 END) AS claims_outside_enrollment
FROM raw_medical_claims mc
JOIN raw_members m ON UPPER(TRIM(mc.member_id)) = UPPER(TRIM(m.member_id));

-- 1.4 Check pharmacy fill dates against member enrollment.
SELECT
    COUNT(*) AS matched_pharmacy_claims,
    SUM(CASE WHEN STR_TO_DATE(pc.fill_date, '%m/%d/%Y') <
                  STR_TO_DATE(m.enrollment_start, '%m/%d/%Y')
              OR STR_TO_DATE(pc.fill_date, '%m/%d/%Y') >
                  COALESCE(STR_TO_DATE(NULLIF(TRIM(m.enrollment_end), ''), '%m/%d/%Y'),
                           DATE('2024-12-31'))
             THEN 1 ELSE 0 END) AS claims_outside_enrollment
FROM raw_pharmacy_claims pc
JOIN raw_members m ON UPPER(TRIM(pc.member_id)) = UPPER(TRIM(m.member_id));

-- 1.5 Count unmatched members and invalid claim dates in raw files.
SELECT
    'Medical' AS claim_type,
    COUNT(*) AS total_claims,
    SUM(CASE WHEN m.member_id IS NULL THEN 1 ELSE 0 END) AS unmatched_members,
    SUM(CASE WHEN STR_TO_DATE(mc.service_date, '%m/%d/%Y') IS NULL
             THEN 1 ELSE 0 END) AS invalid_claim_dates,
    SUM(CASE WHEN m.member_id IS NOT NULL AND
                  (STR_TO_DATE(m.enrollment_start, '%m/%d/%Y') IS NULL OR
                   (NULLIF(TRIM(m.enrollment_end), '') IS NOT NULL AND
                    STR_TO_DATE(m.enrollment_end, '%m/%d/%Y') IS NULL))
             THEN 1 ELSE 0 END) AS invalid_member_dates
FROM raw_medical_claims mc
LEFT JOIN raw_members m ON UPPER(TRIM(mc.member_id)) = UPPER(TRIM(m.member_id))
UNION ALL
SELECT
    'Pharmacy', COUNT(*),
    SUM(CASE WHEN m.member_id IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN STR_TO_DATE(pc.fill_date, '%m/%d/%Y') IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN m.member_id IS NOT NULL AND
                  (STR_TO_DATE(m.enrollment_start, '%m/%d/%Y') IS NULL OR
                   (NULLIF(TRIM(m.enrollment_end), '') IS NOT NULL AND
                    STR_TO_DATE(m.enrollment_end, '%m/%d/%Y') IS NULL))
             THEN 1 ELSE 0 END)
FROM raw_pharmacy_claims pc
LEFT JOIN raw_members m ON UPPER(TRIM(pc.member_id)) = UPPER(TRIM(m.member_id));

-- 2. STAGING DATA VALIDATION

-- 2.1 Confirm staged row counts after import and date conversion.
SELECT 'Members' AS dataset, COUNT(*) AS records FROM stage_members
UNION ALL SELECT 'Providers', COUNT(*) FROM stage_providers
UNION ALL SELECT 'Medical Claims', COUNT(*) FROM stage_medical
UNION ALL SELECT 'Pharmacy Claims', COUNT(*) FROM stage_pharmacy;

-- 2.2 Identify missing dates in staged records.
SELECT 'Members' AS dataset,
       SUM(CASE WHEN dob IS NULL THEN 1 ELSE 0 END) AS missing_primary_date,
       SUM(CASE WHEN enrollment_start IS NULL THEN 1 ELSE 0 END) AS missing_enrollment_start,
       SUM(CASE WHEN enrollment_end IS NULL THEN 1 ELSE 0 END) AS missing_enrollment_end
FROM stage_members
UNION ALL
SELECT 'Medical', SUM(CASE WHEN service_date IS NULL THEN 1 ELSE 0 END), NULL, NULL
FROM stage_medical
UNION ALL
SELECT 'Pharmacy', SUM(CASE WHEN fill_date IS NULL THEN 1 ELSE 0 END), NULL, NULL
FROM stage_pharmacy;

-- 2.3 Check required provider fields and NPI format.
SELECT
    COUNT(*) AS total_providers,
    SUM(CASE WHEN provider_type IS NULL OR TRIM(provider_type) = '' THEN 1 ELSE 0 END) AS missing_provider_type,
    SUM(CASE WHEN facility_type IS NULL OR TRIM(facility_type) = '' THEN 1 ELSE 0 END) AS missing_facility_type,
    SUM(CASE WHEN county IS NULL OR TRIM(county) = '' THEN 1 ELSE 0 END) AS missing_county,
    SUM(CASE WHEN npi IS NULL OR TRIM(npi) NOT REGEXP '^[0-9]{10}$'
             THEN 1 ELSE 0 END) AS invalid_npi
FROM stage_providers;

-- 3. MEMBER DATA QUALITY

-- 3.1 Summarize critical member rejection reasons.
SELECT rejection_reason, COUNT(DISTINCT record_id) AS affected_members
FROM rejected_records
WHERE record_type = 'member'
GROUP BY rejection_reason
ORDER BY affected_members DESC;

-- 3.2 Summarize member warnings without treating them as rejections.
SELECT warning_reason, COUNT(DISTINCT record_id) AS affected_members
FROM data_quality_warnings
WHERE record_type = 'member'
GROUP BY warning_reason
ORDER BY affected_members DESC;

-- 3.3 Count unique rejected members.
SELECT COUNT(DISTINCT record_id) AS rejected_members
FROM rejected_records
WHERE record_type = 'member';

-- 3.4 Verify missing/unknown fields in the cleaned member table.
SELECT
    COUNT(*) AS total_clean_members,
    SUM(CASE WHEN gender = 'UNKNOWN' THEN 1 ELSE 0 END) AS unknown_gender,
    SUM(CASE WHEN risk_score IS NULL THEN 1 ELSE 0 END) AS missing_risk_score,
    SUM(CASE WHEN risk_tier = 'UNKNOWN RISK' THEN 1 ELSE 0 END) AS unknown_risk_tier
FROM members_clean;

-- 3.5 Profile member risk tiers used in the utilization analysis.
SELECT risk_tier, COUNT(*) AS member_count
FROM members_clean
GROUP BY risk_tier
ORDER BY CASE risk_tier
    WHEN 'LOW RISK' THEN 1
    WHEN 'MODERATE RISK' THEN 2
    WHEN 'HIGH RISK' THEN 3
    ELSE 4 END;

-- 4. PROVIDER DATA QUALITY

-- 4.1 Summarize provider warnings already generated by the ETL.
SELECT warning_reason, COUNT(DISTINCT record_id) AS affected_providers
FROM data_quality_warnings
WHERE record_type = 'provider'
GROUP BY warning_reason
ORDER BY affected_providers DESC;

-- 4.2 Review unknown or fallback values in cleaned provider fields.
SELECT
    COUNT(*) AS total_clean_providers,
    SUM(CASE WHEN facility_type_clean = 'UNKNOWN' THEN 1 ELSE 0 END) AS unknown_facility_type,
    SUM(CASE WHEN provider_type_clean = 'OTHER' THEN 1 ELSE 0 END) AS other_provider_type,
    SUM(CASE WHEN county_clean = 'UNKNOWN' THEN 1 ELSE 0 END) AS unknown_county
FROM providers_clean;

-- 4.3 Profile provider type, specialty, and domain mappings.
SELECT provider_type_clean, provider_specialty, provider_domain,
       COUNT(*) AS provider_count
FROM providers_clean
GROUP BY provider_type_clean, provider_specialty, provider_domain
ORDER BY provider_count DESC;

-- 4.4 Review rejected medical claims with invalid provider references.
SELECT COUNT(DISTINCT record_id) AS claims_with_invalid_provider_reference
FROM rejected_records
WHERE record_type = 'medical_claim'
  AND rejection_reason = 'Invalid provider_id';

-- 5. MEDICAL CLAIMS VALIDATION

-- 5.1 Summarize medical claim rejection and warning reasons.
SELECT 'Critical Rejection' AS issue_type, rejection_reason AS issue,
       COUNT(DISTINCT record_id) AS affected_claims
FROM rejected_records
WHERE record_type = 'medical_claim'
GROUP BY rejection_reason
UNION ALL
SELECT 'Data Quality Warning', warning_reason,
       COUNT(DISTINCT record_id)
FROM data_quality_warnings
WHERE record_type = 'medical_claim'
GROUP BY warning_reason
ORDER BY issue_type, affected_claims DESC;

-- 5.2 Check missing required fields and invalid numeric values in staging.
SELECT
    COUNT(*) AS total_claims,
    SUM(CASE WHEN claim_id IS NULL OR TRIM(claim_id) = '' THEN 1 ELSE 0 END) AS missing_claim_id,
    SUM(CASE WHEN member_id IS NULL OR TRIM(member_id) = '' THEN 1 ELSE 0 END) AS missing_member_id,
    SUM(CASE WHEN provider_id IS NULL OR TRIM(provider_id) = '' THEN 1 ELSE 0 END) AS missing_provider_id,
    SUM(CASE WHEN icd10_code IS NULL OR TRIM(icd10_code) = '' THEN 1 ELSE 0 END) AS missing_icd10,
    SUM(CASE WHEN claim_status IS NULL OR TRIM(claim_status) = '' THEN 1 ELSE 0 END) AS missing_claim_status,
    SUM(CASE WHEN place_of_service IS NULL OR TRIM(place_of_service) = '' THEN 1 ELSE 0 END) AS missing_place_of_service,
    SUM(CASE WHEN allowed_amount IS NULL OR allowed_amount < 0 THEN 1 ELSE 0 END) AS invalid_allowed_amount,
    SUM(CASE WHEN length_of_stay < 0 THEN 1 ELSE 0 END) AS negative_length_of_stay
FROM stage_medical;

-- 5.3 Check duplicate IDs, provider references, and recognized codes.
-- Duplicate groups and excess duplicate rows are reported separately.
SELECT
    (SELECT COUNT(*) FROM (
        SELECT UPPER(TRIM(claim_id)) AS normalized_id
        FROM stage_medical
        WHERE claim_id IS NOT NULL AND TRIM(claim_id) <> ''
        GROUP BY UPPER(TRIM(claim_id)) HAVING COUNT(*) > 1
    ) d) AS duplicate_claim_id_groups,
    (SELECT COALESCE(SUM(n - 1), 0) FROM (
        SELECT COUNT(*) AS n FROM stage_medical
        WHERE claim_id IS NOT NULL AND TRIM(claim_id) <> ''
        GROUP BY UPPER(TRIM(claim_id)) HAVING COUNT(*) > 1
    ) d) AS excess_duplicate_rows,
    (SELECT COUNT(*) FROM stage_medical mc
     LEFT JOIN stage_providers p
       ON UPPER(TRIM(mc.provider_id)) = UPPER(TRIM(p.provider_id))
     WHERE p.provider_id IS NULL) AS unmatched_provider_ids,
    (SELECT COUNT(*) FROM stage_medical
     WHERE icd10_code IS NULL OR UPPER(TRIM(icd10_code)) NOT IN
       ('F32','F33','F41','F43','G47','I10','E11','J45')) AS unrecognized_icd10,
    (SELECT COUNT(*) FROM stage_medical
     WHERE claim_status IS NULL OR UPPER(TRIM(claim_status)) NOT IN
       ('PAID','PD','P','PIAD','DENIED','DENY','D','REVERSED','REVERSE','R')) AS unrecognized_claim_status,
    (SELECT COUNT(*) FROM stage_medical
     WHERE place_of_service IS NULL OR UPPER(TRIM(place_of_service)) NOT IN
       ('IP','I.P.','INPAT','OP','O.P.','OUTPA','ED','EMERG','EMERGENCY','EMERG.'))
       AS unrecognized_place_of_service;

-- 5.4 Profile potential cost and length-of-stay issues.
-- The $24,984 threshold is exploratory, not a rejection rule.
SELECT
    COUNT(*) AS total_medical_claims,
    SUM(CASE WHEN allowed_amount > 24984.00 THEN 1 ELSE 0 END) AS above_exploratory_cost_threshold,
    SUM(CASE WHEN UPPER(TRIM(place_of_service)) IN ('IP','I.P.','INPAT')
              AND length_of_stay IS NULL THEN 1 ELSE 0 END) AS missing_inpatient_los
FROM stage_medical;

-- 5.5 Profile diagnosis codes and source claim status values.
SELECT icd10_code, COUNT(*) AS claim_count
FROM stage_medical
GROUP BY icd10_code
ORDER BY claim_count DESC;

SELECT 'CLAIM STATUS' AS field_name,
       CONCAT('[', COALESCE(claim_status, 'NULL'), ']') AS raw_value,
       COUNT(*) AS record_count
FROM stage_medical
GROUP BY claim_status
UNION ALL
SELECT 'PLACE OF SERVICE',
       CONCAT('[', COALESCE(place_of_service, 'NULL'), ']'), COUNT(*)
FROM stage_medical
GROUP BY place_of_service
ORDER BY field_name, record_count DESC;

-- 6. PHARMACY CLAIMS VALIDATION

-- 6.1 Summarize pharmacy claim rejection and warning reasons.
SELECT 'Critical Rejection' AS issue_type, rejection_reason AS issue,
       COUNT(DISTINCT record_id) AS affected_claims
FROM rejected_records
WHERE record_type = 'pharmacy_claim'
GROUP BY rejection_reason
UNION ALL
SELECT 'Data Quality Warning', warning_reason,
       COUNT(DISTINCT record_id)
FROM data_quality_warnings
WHERE record_type = 'pharmacy_claim'
GROUP BY warning_reason
ORDER BY issue_type, affected_claims DESC;

-- 6.2 Check required pharmacy fields, dates, and numeric values.
SELECT
    COUNT(*) AS total_pharmacy_claims,
    SUM(CASE WHEN rx_claim_id IS NULL OR TRIM(rx_claim_id) = '' THEN 1 ELSE 0 END) AS missing_claim_id,
    SUM(CASE WHEN member_id IS NULL OR TRIM(member_id) = '' THEN 1 ELSE 0 END) AS missing_member_id,
    SUM(CASE WHEN drug_name IS NULL OR TRIM(drug_name) = '' THEN 1 ELSE 0 END) AS missing_drug_name,
    SUM(CASE WHEN fill_date IS NULL THEN 1 ELSE 0 END) AS missing_fill_date,
    SUM(CASE WHEN fill_date < '2021-01-01' OR fill_date > '2024-12-31'
             THEN 1 ELSE 0 END) AS dates_outside_reporting_period,
    SUM(CASE WHEN claim_status IS NULL OR TRIM(claim_status) = '' THEN 1 ELSE 0 END) AS missing_claim_status,
    SUM(CASE WHEN drug_cost IS NULL OR drug_cost < 0 THEN 1 ELSE 0 END) AS invalid_drug_cost,
    SUM(CASE WHEN days_supply IS NULL OR days_supply <= 0 OR days_supply > 365
             THEN 1 ELSE 0 END) AS invalid_days_supply,
    SUM(CASE WHEN quantity IS NULL OR quantity <= 0 THEN 1 ELSE 0 END) AS invalid_quantity
FROM stage_pharmacy;

-- 6.3 Check duplicate IDs, unmatched members, statuses, and enrollment.
-- Open-ended enrollment uses 2024-12-31 as the reporting cutoff.
SELECT
    (SELECT COUNT(*) FROM (
        SELECT UPPER(TRIM(rx_claim_id)) AS normalized_id
        FROM stage_pharmacy
        WHERE rx_claim_id IS NOT NULL AND TRIM(rx_claim_id) <> ''
        GROUP BY UPPER(TRIM(rx_claim_id)) HAVING COUNT(*) > 1
    ) d) AS duplicate_claim_id_groups,
    (SELECT COALESCE(SUM(n - 1), 0) FROM (
        SELECT COUNT(*) AS n FROM stage_pharmacy
        WHERE rx_claim_id IS NOT NULL AND TRIM(rx_claim_id) <> ''
        GROUP BY UPPER(TRIM(rx_claim_id)) HAVING COUNT(*) > 1
    ) d) AS excess_duplicate_rows,
    (SELECT COUNT(*) FROM stage_pharmacy pc
     LEFT JOIN stage_members m
       ON UPPER(TRIM(pc.member_id)) = UPPER(TRIM(m.member_id))
     WHERE m.member_id IS NULL) AS unmatched_member_ids,
    (SELECT COUNT(*) FROM stage_pharmacy
     WHERE claim_status IS NULL OR UPPER(TRIM(claim_status)) NOT IN
       ('PAID','PD','P','PIAD','DENIED','DENY','D','REVERSED','REVERSE','R'))
       AS unrecognized_claim_status,
    (SELECT COUNT(*) FROM stage_pharmacy pc
     JOIN stage_members m
       ON UPPER(TRIM(pc.member_id)) = UPPER(TRIM(m.member_id))
     WHERE pc.fill_date < m.enrollment_start
        OR pc.fill_date > COALESCE(m.enrollment_end, DATE('2024-12-31')))
       AS claims_outside_enrollment;

-- 6.4 Verify normalized drug, status, supply, and cost categories.
SELECT
    COUNT(*) AS total_clean_pharmacy_claims,
    SUM(CASE WHEN drug_name_clean = 'UNKNOWN' THEN 1 ELSE 0 END) AS unknown_drug_names,
    SUM(CASE WHEN drug_category_clean IN ('UNKNOWN','OTHER') THEN 1 ELSE 0 END) AS unknown_drug_categories,
    SUM(CASE WHEN claim_status NOT IN ('PAID','DENIED','REVERSED') THEN 1 ELSE 0 END) AS unrecognized_claim_status,
    SUM(CASE WHEN days_supply_band = 'UNKNOWN' THEN 1 ELSE 0 END) AS invalid_days_supply,
    SUM(CASE WHEN quantity_band = 'UNKNOWN' THEN 1 ELSE 0 END) AS invalid_quantity,
    SUM(CASE WHEN cost_tier = 'UNKNOWN' THEN 1 ELSE 0 END) AS unknown_cost_tier
FROM pharmacy_claims_clean;

-- 6.5 Inspect original values for drug names that remained unknown.
SELECT s.rx_claim_id,
       CONCAT('[', COALESCE(s.drug_name, 'NULL'), ']') AS original_drug_name,
       c.drug_name_clean,
       s.drug_category AS original_drug_category
FROM stage_pharmacy s
JOIN pharmacy_claims_clean c
  ON UPPER(TRIM(s.rx_claim_id)) = UPPER(TRIM(c.rx_claim_id))
WHERE c.drug_name_clean = 'UNKNOWN';

-- 7. ETL AUDIT AND RECORD RETENTION

-- 7.1 Review record retention at each logged ETL processing step.
SELECT process_step, source_table, rows_before, rows_after, rows_removed,
       ROUND(100.0 * rows_after / NULLIF(rows_before, 0), 2) AS retention_pct
FROM etl_audit_log;

-- 7.2 Summarize logged rejections and warnings by record type.
-- These are log-entry counts; a record may have multiple issues.
SELECT 'Critical Rejection' AS issue_type, record_type, COUNT(*) AS log_entries,
       COUNT(DISTINCT record_id) AS distinct_records
FROM rejected_records
GROUP BY record_type
UNION ALL
SELECT 'Data Quality Warning', record_type, COUNT(*), COUNT(DISTINCT record_id)
FROM data_quality_warnings
GROUP BY record_type
ORDER BY issue_type, record_type;

-- 8. TABLEAU DATASET VALIDATION

-- 8.1 Check medical mart row counts, identifiers, and claim statuses.
SELECT
    COUNT(*) AS total_tableau_rows,
    COUNT(DISTINCT claim_id) AS unique_claims,
    COUNT(DISTINCT member_id) AS unique_members,
    COUNT(DISTINCT provider_id) AS unique_providers,
    SUM(CASE WHEN claim_status = 'PAID' THEN 1 ELSE 0 END) AS paid_claims,
    SUM(CASE WHEN claim_status = 'DENIED' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN claim_status = 'REVERSED' THEN 1 ELSE 0 END) AS reversed_claims
FROM tableau_medical_claims;

-- 8.2 Check pharmacy mart row counts, identifiers, and claim statuses.
SELECT
    COUNT(*) AS total_tableau_rows,
    COUNT(DISTINCT rx_claim_id) AS unique_claims,
    COUNT(DISTINCT member_id) AS unique_members,
    SUM(CASE WHEN claim_status = 'PAID' THEN 1 ELSE 0 END) AS paid_claims,
    SUM(CASE WHEN claim_status = 'DENIED' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN claim_status = 'REVERSED' THEN 1 ELSE 0 END) AS reversed_claims
FROM tableau_pharmacy_claims;

-- 8.3 Reconcile clean and Tableau row counts and distinct claim IDs.
SELECT 'Medical' AS dataset,
       (SELECT COUNT(*) FROM medical_claims_clean) AS clean_rows,
       (SELECT COUNT(*) FROM tableau_medical_claims) AS tableau_rows,
       (SELECT COUNT(DISTINCT claim_id) FROM medical_claims_clean) AS clean_unique_claims,
       (SELECT COUNT(DISTINCT claim_id) FROM tableau_medical_claims) AS tableau_unique_claims
UNION ALL
SELECT 'Pharmacy',
       (SELECT COUNT(*) FROM pharmacy_claims_clean),
       (SELECT COUNT(*) FROM tableau_pharmacy_claims),
       (SELECT COUNT(DISTINCT rx_claim_id) FROM pharmacy_claims_clean),
       (SELECT COUNT(DISTINCT rx_claim_id) FROM tableau_pharmacy_claims);

-- 8.4 Confirm no cleaned claim IDs are missing from Tableau or vice versa.
-- All four missing-ID counts should be zero.
SELECT 'Medical: clean not in Tableau' AS check_name, COUNT(*) AS missing_ids
FROM medical_claims_clean c
WHERE NOT EXISTS (
    SELECT 1 FROM tableau_medical_claims t
    WHERE UPPER(TRIM(t.claim_id)) = UPPER(TRIM(c.claim_id))
)
UNION ALL
SELECT 'Medical: Tableau not in clean', COUNT(*)
FROM tableau_medical_claims t
WHERE NOT EXISTS (
    SELECT 1 FROM medical_claims_clean c
    WHERE UPPER(TRIM(c.claim_id)) = UPPER(TRIM(t.claim_id))
)
UNION ALL
SELECT 'Pharmacy: clean not in Tableau', COUNT(*)
FROM pharmacy_claims_clean c
WHERE NOT EXISTS (
    SELECT 1 FROM tableau_pharmacy_claims t
    WHERE UPPER(TRIM(t.rx_claim_id)) = UPPER(TRIM(c.rx_claim_id))
)
UNION ALL
SELECT 'Pharmacy: Tableau not in clean', COUNT(*)
FROM tableau_pharmacy_claims t
WHERE NOT EXISTS (
    SELECT 1 FROM pharmacy_claims_clean c
    WHERE UPPER(TRIM(c.rx_claim_id)) = UPPER(TRIM(t.rx_claim_id))
);

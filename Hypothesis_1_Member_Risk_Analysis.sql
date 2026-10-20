-- Behavioral Health Claims Utilization & Risk Analytics
-- Hypothesis 1: Member Risk and Medical Utilization
-- Data: Synthetic behavioral health claims (2021-2024)
--
-- Question: Do higher-risk members have more medical claims
-- and higher paid-claim allowed amounts?
--
-- Analysis compares claim frequency, allowed amounts, and
-- enrollment-adjusted utilization across member risk tiers.
-- Risk tiers are project-defined for this synthetic dataset.

USE behavioral_health_v2;

-- 1. Medical claims per member by risk tier
-- Count distinct members and claims to compare utilization.
-- Only members with medical claims are included.

SELECT
    risk_tier,
    COUNT(DISTINCT member_id) AS members_with_claims,
    COUNT(*) AS total_medical_claims,
    ROUND(
        COUNT(*) / NULLIF(COUNT(DISTINCT member_id), 0),
        2
    ) AS claims_per_member_with_claims
FROM tableau_medical_claims
GROUP BY risk_tier
ORDER BY
    CASE risk_tier
        WHEN 'LOW RISK' THEN 1
        WHEN 'MODERATE RISK' THEN 2
        WHEN 'HIGH RISK' THEN 3
        WHEN 'UNKNOWN RISK' THEN 4
        ELSE 5
    END;
    
-- 2. Paid medical claim allowed amounts by risk tier
-- Compare paid claim counts, total allowed amounts, and
-- average allowed amount per paid claim.
-- Denied and reversed claims are excluded from allowed amounts.

SELECT
    risk_tier,
    COUNT(*) AS total_medical_claims,
    SUM(
        CASE WHEN claim_status = 'PAID'
             THEN 1 ELSE 0 END
    ) AS paid_claims,
    ROUND(
        SUM(
            CASE WHEN claim_status = 'PAID'
                 THEN allowed_amount ELSE 0 END
        ), 2
    ) AS total_paid_claim_allowed_amount,
    ROUND(
        AVG(
            CASE WHEN claim_status = 'PAID'
                 THEN allowed_amount ELSE NULL END
        ), 2
    ) AS avg_allowed_amount_per_paid_claim
FROM tableau_medical_claims
GROUP BY risk_tier
ORDER BY
    CASE risk_tier
        WHEN 'LOW RISK' THEN 1
        WHEN 'MODERATE RISK' THEN 2
        WHEN 'HIGH RISK' THEN 3
        WHEN 'UNKNOWN RISK' THEN 4
        ELSE 5
    END;
    
-- 3. Average paid-claim allowed amount per member
-- Use all cleaned members to account for differences in group size.
-- LEFT JOIN retains members without claims.
-- Members with no paid claims contribute $0 to the average.

SELECT
    m.risk_tier,
    COUNT(DISTINCT m.member_id) AS total_members,

    ROUND(
        COALESCE(SUM(
            CASE
                WHEN c.claim_status = 'PAID'
                THEN c.allowed_amount
                ELSE 0
            END
        ), 0), 2
    ) AS total_paid_claim_allowed_amount,

    ROUND(
        COALESCE(SUM(
            CASE
                WHEN c.claim_status = 'PAID'
                THEN c.allowed_amount
                ELSE 0
            END
        ), 0)
        / NULLIF(COUNT(DISTINCT m.member_id), 0),
        2
    ) AS avg_paid_claim_allowed_per_member

FROM members_clean m

LEFT JOIN medical_claims_clean c
    ON UPPER(TRIM(m.member_id)) =
       UPPER(TRIM(c.member_id))

GROUP BY m.risk_tier

ORDER BY
    CASE m.risk_tier
        WHEN 'LOW RISK' THEN 1
        WHEN 'MODERATE RISK' THEN 2
        WHEN 'HIGH RISK' THEN 3
        WHEN 'UNKNOWN RISK' THEN 4
        ELSE 5
    END;
    
-- 4. Check enrollment duration by risk tier
-- Compare average, minimum, and maximum enrollment years.
-- Restrict dates to the 2021-2024 observation period.
-- NULL enrollment_end is treated as active through 2024-12-31.
-- Assumes one continuous enrollment period per member.

WITH enrollment_duration AS (
    SELECT
        member_id,
        risk_tier,
        GREATEST(
            enrollment_start,
            '2021-01-01'
        ) AS effective_start,
        LEAST(
            COALESCE(enrollment_end, '2024-12-31'),
            '2024-12-31'
        ) AS effective_end
    FROM members_clean
    WHERE enrollment_start IS NOT NULL
      AND enrollment_start <= '2024-12-31'
      AND (
          enrollment_end IS NULL
          OR enrollment_end >= '2021-01-01'
      )
      AND (
          enrollment_end IS NULL
          OR enrollment_end >= enrollment_start
      )
)

SELECT
    risk_tier,
    COUNT(*) AS total_members,

    ROUND(
        AVG(
            DATEDIFF(effective_end, effective_start) + 1
        ) / 365.25,
        2
    ) AS avg_enrollment_years,

    ROUND(
        MIN(
            DATEDIFF(effective_end, effective_start) + 1
        ) / 365.25,
        2
    ) AS min_enrollment_years,

    ROUND(
        MAX(
            DATEDIFF(effective_end, effective_start) + 1
        ) / 365.25,
        2
    ) AS max_enrollment_years

FROM enrollment_duration
GROUP BY risk_tier

ORDER BY
    CASE risk_tier
        WHEN 'LOW RISK' THEN 1
        WHEN 'MODERATE RISK' THEN 2
        WHEN 'HIGH RISK' THEN 3
        WHEN 'UNKNOWN RISK' THEN 4
        ELSE 5
    END;
    
-- 5. Medical claims per member-year
-- Adjust claim volume for differences in enrollment duration.
-- Calculate total claims divided by total member-years.
-- LEFT JOIN includes members with no medical claims.
-- Uses cleaned claims that passed enrollment-window validation.

WITH member_exposure AS (
    SELECT
        member_id,
        risk_tier,
        (
            DATEDIFF(
                LEAST(
                    COALESCE(enrollment_end, '2024-12-31'),
                    '2024-12-31'
                ),
                GREATEST(
                    enrollment_start,
                    '2021-01-01'
                )
            ) + 1
        ) / 365.25 AS enrollment_years
    FROM members_clean
    WHERE enrollment_start IS NOT NULL
      AND enrollment_start <= '2024-12-31'
      AND (
          enrollment_end IS NULL
          OR enrollment_end >= '2021-01-01'
      )
      AND (
          enrollment_end IS NULL
          OR enrollment_end >= enrollment_start
      )
),

member_claims AS (
    SELECT
        member_id,
        COUNT(*) AS total_claims
    FROM medical_claims_clean
    GROUP BY member_id
)

SELECT
    m.risk_tier,
    COUNT(*) AS total_members,
    ROUND(SUM(m.enrollment_years), 2) AS total_member_years,
    SUM(COALESCE(c.total_claims, 0)) AS total_medical_claims,
    ROUND(
        SUM(COALESCE(c.total_claims, 0))
        / NULLIF(SUM(m.enrollment_years), 0),
        2
    ) AS claims_per_member_year
FROM member_exposure m
LEFT JOIN member_claims c
    ON UPPER(TRIM(m.member_id)) =
       UPPER(TRIM(c.member_id))
GROUP BY m.risk_tier
ORDER BY
    CASE m.risk_tier
        WHEN 'LOW RISK' THEN 1
        WHEN 'MODERATE RISK' THEN 2
        WHEN 'HIGH RISK' THEN 3
        WHEN 'UNKNOWN RISK' THEN 4
        ELSE 5
    END;

-- Hypothesis 1: Findings
-- Higher risk tiers showed greater medical utilization
-- and higher paid-claim allowed amounts.
--
-- High-risk vs. low-risk members:
-- Claims per member-year: 13.67 vs. 12.97 (+5.4%)
-- Avg. allowed amount per paid claim: $3,095 vs. $2,962 (+4.5%)
-- Avg. paid-claim allowed amount per member: +9.5%
--
-- Findings support the hypothesis descriptively.
-- Results are based on synthetic data and do not
-- establish statistical significance or causation.
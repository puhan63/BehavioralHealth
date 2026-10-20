USE behavioral_health_v2;

-- Hypothesis 2: Provider Specialty and Medical Utilization
-- Compare medical claim volume and allowed amounts by specialty.
-- Analysis uses synthetic healthcare claims data.

-- 1. Provider distribution by specialty
SELECT
    provider_specialty,
    COUNT(*) AS total_providers
FROM providers_clean
GROUP BY provider_specialty
ORDER BY total_providers DESC;

-- 2. Medical claims per provider by specialty
-- Compare claim volume across specialties while accounting
-- for differences in the number of providers.
-- LEFT JOIN includes providers with no medical claims.
SELECT
    p.provider_specialty,
    COUNT(DISTINCT p.provider_id) AS total_providers,
    COUNT(c.claim_id) AS total_medical_claims,

    ROUND(
        COUNT(c.claim_id) /
        NULLIF(COUNT(DISTINCT p.provider_id), 0),
        2
    ) AS claims_per_provider

FROM providers_clean p

LEFT JOIN medical_claims_clean c
    ON UPPER(TRIM(p.provider_id)) =
       UPPER(TRIM(c.provider_id))

GROUP BY p.provider_specialty

ORDER BY claims_per_provider DESC;

-- 3. Paid medical claim allowed amounts by specialty
-- Compare paid claim volume and allowed amounts across specialties.
-- Denied and reversed claims are excluded from financial totals.

SELECT
    p.provider_specialty,
    COUNT(c.claim_id) AS total_medical_claims,

    SUM(
        CASE
            WHEN c.claim_status = 'PAID'
            THEN 1 ELSE 0
        END
    ) AS paid_claims,

    ROUND(
        COALESCE(SUM(
            CASE
                WHEN c.claim_status = 'PAID'
                THEN c.allowed_amount
                ELSE 0
            END
        ), 0),
        2
    ) AS total_paid_claim_allowed_amount,

    ROUND(
        AVG(
            CASE
                WHEN c.claim_status = 'PAID'
                THEN c.allowed_amount
                ELSE NULL
            END
        ),
        2
    ) AS avg_allowed_amount_per_paid_claim

FROM providers_clean p

LEFT JOIN medical_claims_clean c
    ON UPPER(TRIM(p.provider_id)) =
       UPPER(TRIM(c.provider_id))

GROUP BY p.provider_specialty

ORDER BY avg_allowed_amount_per_paid_claim DESC;

-- 4. Paid-claim allowed amount per provider
-- Adjust total allowed amounts for differences in provider counts.
-- Include providers without paid claims in the denominator.

SELECT
    p.provider_specialty,
    COUNT(DISTINCT p.provider_id) AS total_providers,

    ROUND(
        COALESCE(SUM(
            CASE
                WHEN c.claim_status = 'PAID'
                THEN c.allowed_amount
                ELSE 0
            END
        ), 0),
        2
    ) AS total_paid_claim_allowed_amount,

    ROUND(
        COALESCE(SUM(
            CASE
                WHEN c.claim_status = 'PAID'
                THEN c.allowed_amount
                ELSE 0
            END
        ), 0)
        / NULLIF(COUNT(DISTINCT p.provider_id), 0),
        2
    ) AS avg_paid_claim_allowed_per_provider

FROM providers_clean p

LEFT JOIN medical_claims_clean c
    ON UPPER(TRIM(p.provider_id)) =
       UPPER(TRIM(c.provider_id))

GROUP BY p.provider_specialty

ORDER BY avg_paid_claim_allowed_per_provider DESC;

-- 5. Check providers with and without medical claims
-- Identify whether inactive providers affect specialty averages.

SELECT
    p.provider_specialty,
    COUNT(DISTINCT p.provider_id) AS total_providers,
    COUNT(DISTINCT CASE
        WHEN c.claim_id IS NOT NULL THEN p.provider_id
    END) AS providers_with_claims,
    COUNT(DISTINCT p.provider_id)
      - COUNT(DISTINCT CASE
          WHEN c.claim_id IS NOT NULL THEN p.provider_id
        END) AS providers_without_claims

FROM providers_clean p

LEFT JOIN medical_claims_clean c
    ON UPPER(TRIM(p.provider_id)) =
       UPPER(TRIM(c.provider_id))

GROUP BY p.provider_specialty
ORDER BY total_providers DESC;

-- Hypothesis 2: Findings
-- Hospital Medicine had the highest claims per provider (145.28)
-- and paid-claim allowed amount per provider ($339,007).
-- Endocrinology had the highest average allowed amount
-- per paid claim ($3,328.89).
-- Primary Care accounted for the largest total claim volume.
--
-- All 200 providers had at least one medical claim.
-- Results show descriptive differences across specialties.
-- Data is synthetic; findings do not establish causation
-- or statistical significance.
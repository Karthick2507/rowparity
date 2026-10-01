-- account:    sa-presto-tier2
-- skeleton:   d232412f30c43624460100107933b45a
-- pattern:    442615228666e0dd3f50121425dda591  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE_FORMAT(request__timestamp, '%y-%m-%d') AS date,
  COUNT(DISTINCT request__transaction_id) AS only_blipvert_requests
FROM ${bcv_ad}
WHERE
  (
    (
      (
        (
          request__is_first_request = TRUE AND video_cro_network_id = 386345
        )
        AND CONTAINS(
          FLATTEN(request__context__site_section_chain__content_owner__network_id),
          CAST('629' AS BIGINT)
        )
      )
      AND CARDINALITY(
        FILTER(
          ARRAY_AGG(DISTINCT IF(advertisement__ad_id = 92683573, 1, NULL)),
          x -> NOT x IS NULL
        )
      ) > 0
    )
    AND CARDINALITY(
      FILTER(
        ARRAY_AGG(
          DISTINCT IF(
            advertisement__request__context__distributor_network_id = 144750
            AND advertisement__ad_id <> 92683573,
            1,
            NULL
          )
        ),
        x -> NOT x IS NULL
      )
    ) = 0
  )
  AND CARDINALITY(
    FILTER(
      ARRAY_AGG(
        DISTINCT IF(
          CONTAINS(partners__network_id, CAST('191701' AS BIGINT))
          OR (
            CONTAINS(partners__network_id, CAST('386345' AS BIGINT))
            AND BITWISE_AND(COALESCE(partners__bit_flags, 0), BITWISE_LEFT_SHIFT(CAST(1 AS BIGINT), 51)) > 0
          ),
          1,
          NULL
        )
      ),
      x -> NOT x IS NULL
    )
  ) = 0
GROUP BY
  1
ORDER BY
  1 DESC

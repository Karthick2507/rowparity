-- account:    sa-presto-af-etl
-- skeleton:   2b43da82e20b27d9da9fe0583ecff034
-- pattern:    2a2b39b99e584ae4ec6b7329e036aea6  (199 execution(s))
-- in suite:   daily commitment
-- hoover:     transaction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < (CAST(? AS TIMESTAMP))
--   request__timestamp >= (CAST(? AS TIMESTAMP))

WITH networks_using_site_section AS (
  SELECT DISTINCT
    df.network_id AS network_id,
    TRUE AS fake_site
  FROM db.default.d_network_function AS df
  LEFT JOIN db.default.d_lu_network_function AS nf
    ON df.function_id = nf.id
  WHERE
    nf.name = 'forecast_volume_by_site_section'
), site_ss_group AS (
  SELECT
    CASE
      WHEN request__context__asset_chain__content_right_owner__network_id IS NULL
      THEN COALESCE(request__context__site_section_chain__content_right_owner__network_id, 0)
      ELSE request__context__asset_chain__content_right_owner__network_id
    END AS network_id,
    COALESCE(request__context__site_section_chain__content_right_owner__site_id, 0) AS site_id,
    COALESCE(request__context__site_section_chain__content_right_owner__asset_id, 0) AS site_section_id,
    COALESCE(request__visitor__dma_code, 0) AS user_dma_code,
    COALESCE(request__visitor__platform_device_id, 0) AS delivered_platform_device_id,
    SUM(COALESCE(request__log_sampling__magnifier, 1)) AS request_count,
    DATE_FORMAT(request__timestamp, '%y-%m-%d') AS event_date
  FROM ${bcv_transaction}
  WHERE
    (
      (
        (
          (
            (
              (
                (
                  request__is_first_request = TRUE
                  AND (
                    request__log_sampling__mode IS NULL
                    OR request__log_sampling__mode <> 'matcher_sampling_unsampled_recalled'
                  )
                )
                AND (
                  (
                    BITWISE_AND(request__flags, BITWISE_OR(BITWISE_OR(BITWISE_OR(32, 64), 16), 67108864)) = 0
                    AND (
                      request__context__asset_chain__content_right_owner__network_id <> 57230
                      OR request__context__site_section_chain__content_right_owner__network_id <> 57230
                    )
                  )
                  OR (
                    BITWISE_AND(request__flags, BITWISE_OR(BITWISE_OR(32, 64), 67108864)) = 0
                    AND (
                      request__context__asset_chain__content_right_owner__network_id = 57230
                      OR request__context__site_section_chain__content_right_owner__network_id = 57230
                    )
                  )
                )
              )
              AND (
                request__extra_flags IS NULL
                OR BITWISE_AND(request__extra_flags, BITWISE_OR(2048, 1024)) = 0
              )
            )
            AND NOT request__transaction_id IS NULL
          )
          AND (
            NOT request__visitor__user_id IS NULL
            OR BITWISE_AND(request__extra_flags, BITWISE_OR(32, BITWISE_OR(4096, 1048576))) > 0
          )
        )
        AND (
          request__visitor__caller IS NULL
          OR request__visitor__caller <> 'resp-format:m3u8'
          OR request__slots__flags <> ARRAY[]
        )
      )
      AND NOT request__context__network_id IN (
        168234,
        168282,
        168285,
        183651,
        168289,
        379215,
        160348,
        394910,
        511710,
        511709,
        375601,
        144556,
        135087,
        135086,
        94047,
        94046,
        87146,
        48397,
        91556,
        91559,
        377760
      )
    )
    AND BITWISE_AND(33554432, request__flags) = 0
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    7
), convert_ss_with_mark AS (
  SELECT
    ssg.network_id,
    COALESCE(nuss.fake_site, FALSE) AS fake_site,
    CASE
      WHEN COALESCE(nuss.fake_site, FALSE) = TRUE
      THEN ssg.site_section_id
      ELSE ssg.site_id
    END AS site_id,
    ssg.user_dma_code,
    ssg.delivered_platform_device_id,
    ssg.request_count,
    ssg.event_date
  FROM site_ss_group AS ssg
  LEFT JOIN networks_using_site_section AS nuss
    ON ssg.network_id = nuss.network_id
)
SELECT
  cswm.network_id,
  cswm.fake_site,
  cswm.site_id,
  cswm.user_dma_code,
  cswm.delivered_platform_device_id,
  SUM(cswm.request_count) AS request_count,
  cswm.event_date
FROM convert_ss_with_mark AS cswm
GROUP BY
  1,
  2,
  3,
  4,
  5,
  7

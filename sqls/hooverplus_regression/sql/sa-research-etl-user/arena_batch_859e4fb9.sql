-- account:    sa-research-etl-user
-- skeleton:   257abe67b7cae9bfe00aef0fc7ef82a5
-- pattern:    859e4fb9fe66eeb764f06878c9d61ac4  (30 execution(s))
-- in suite:   column coverage
-- hoover:     transaction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   t.request__timestamp < CAST(? AS TIMESTAMP)
--   t.request__timestamp >= CAST(? AS TIMESTAMP)

WITH base AS (
  SELECT
    t.request__transaction_id,
    t.request__timestamp,
    t.request__context__video_cro_network_id,
    t.request__context__standard_content_subscription_model_id,
    t.request__context__standard_brand_id,
    t.request__context__standard_programmer_id,
    t.request__context__standard_channel_id,
    t.request__context__standard_endpoint_owner_id,
    t.request__context__standard_endpoint_id,
    t.request__context__content_form_id,
    t.request__context__asset_duration,
    t.request__advertisements__creative_id,
    t.request__advertisement_count,
    t.request__slots__flags
  FROM ${bcv_transaction} AS t
  WHERE
    (
      (
        (
          (
            request__extra_flags2 IS NULL OR BITWISE_AND(65536, request__extra_flags2) = 0
          )
          AND NOT request__transaction_id IS NULL
        )
        AND NOT request__context__asset_duration IS NULL
      )
      AND request__context__asset_duration <> 0
    )
    AND request__context__video_cro_network_id IN (
      516429,
      520311,
      191701,
      169843,
      520040,
      512116,
      530362,
      531516,
      524972,
      376521,
      516283,
      372396,
      112214,
      171213,
      190200,
      500763,
      48804,
      381963,
      525804,
      529349,
      386345,
      536782,
      531859,
      539275,
      525281
    )
), ad_dur AS (
  SELECT
    b.request__transaction_id,
    SUM(COALESCE(c.duration, 0)) AS ad_duration_sec
  FROM base AS b
  CROSS JOIN UNNEST(FILTER(b.request__advertisements__creative_id, x -> NOT x IS NULL)) AS creative(id)
  LEFT JOIN oltp.fwmrm_oltp.creative AS c
    ON creative.id = c.id
  GROUP BY
    1
)
SELECT
  b.request__context__video_cro_network_id AS network_id,
  b.request__context__standard_content_subscription_model_id AS model_id,
  b.request__context__standard_brand_id AS brand_id,
  b.request__context__standard_programmer_id AS programmer_id,
  b.request__context__standard_channel_id AS channel_id,
  b.request__context__standard_endpoint_owner_id AS owner_id,
  b.request__context__standard_endpoint_id AS endpoint_id,
  b.request__context__content_form_id AS form_id,
  SUM(b.request__context__asset_duration) AS total_video_duration_sec,
  SUM(COALESCE(a.ad_duration_sec, 0)) AS total_ad_duration_sec,
  SUM(COALESCE(b.request__advertisement_count, 0)) AS total_ad_num,
  SUM(COALESCE(a.ad_duration_sec, 0)) / NULLIF(SUM(b.request__context__asset_duration), 0) * 3600.0 AS ad_duration_sec_per_hour,
  SUM(COALESCE(b.request__advertisement_count, 0)) / NULLIF(SUM(b.request__context__asset_duration), 0) * 3600.0 AS avg_ad_count_per_hour,
  DATE_FORMAT(b.request__timestamp, '%y-%m-%d-%h') AS event_date_hour
FROM base AS b
LEFT JOIN ad_dur AS a
  ON b.request__transaction_id = a.request__transaction_id
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  14

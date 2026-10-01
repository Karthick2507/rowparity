-- account:    saengalgo
-- skeleton:   dc9bd8a6ff0128bdefef089bc8705060
-- pattern:    ffe0388e6d95cc976a7aed8bdaebe022  (14 execution(s))
-- in suite:   column coverage
-- hoover:     transaction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  datetime,
  channel_id,
  airing_id,
  break_display_id,
  actual_reqs,
  request_date,
  network_id
FROM (
  SELECT
    DATE_FORMAT(request__timestamp, '%y-%m-%d') AS request_date,
    COALESCE(request__context__video_cro_network_id, 0) AS network_id,
    DATE_FORMAT(
      UTC_TIMESTAMP_TO_LOCAL(request__timestamp, NETWORK_TO_TIMEZONE(request__context__video_cro_network_id)),
      '%y-%m-%d %h'
    ) AS datetime,
    request__context__asset_chain__content_right_owner__airing_id AS airing_id,
    request__slots__break_display_id[1] AS break_display_id,
    request__context__asset_chain__content_right_owner__airing_channel_id AS channel_id,
    COUNT(*) AS actual_reqs
  FROM ${bcv_transaction}
  WHERE
    (
      (
        (
          request__context__video_cro_network_id IN (525754)
          AND BITWISE_AND(request__flags, 33554432) > 0
        )
        AND request__context__asset_chain__content_right_owner__airing_id <> -1
      )
      AND request__context__asset_chain__content_right_owner__airing_channel_id <> -1
    )
    AND CARDINALITY(request__slots__break_display_id) > 0
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6
) AS x

-- account:    saengalgo-dev
-- skeleton:   019b62800262183746facb9033545a8a
-- pattern:    8b195b0f148aa807e45b208c1a841141  (5 execution(s))
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
  request_hours,
  local_request_hours,
  request_type,
  channel_id,
  airing_id,
  break_display_id,
  transaction__request__visitor__timezone,
  transaction__request__visitor__timezone_offset,
  actual_reqs,
  request_date,
  network_id
FROM (
  SELECT
    DATE_FORMAT(request__timestamp, '%y-%m-%d') AS request_date,
    COALESCE(request__context__video_cro_network_id, 0) AS network_id,
    DATE_FORMAT(request__timestamp, '%y-%m-%d %h') AS request_hours,
    DATE_FORMAT(
      UTC_TIMESTAMP_TO_LOCAL(request__timestamp, NETWORK_TO_TIMEZONE(request__context__video_cro_network_id)),
      '%y-%m-%d %h'
    ) AS local_request_hours,
    CASE
      WHEN BITWISE_AND(request__flags, 33554432) > 0
      THEN 'hylda_request'
      ELSE 'non_hylda_request'
    END AS request_type,
    request__context__asset_chain__content_right_owner__airing_id AS airing_id,
    request__slots__break_display_id AS break_display_id,
    request__context__asset_chain__content_right_owner__airing_channel_id AS channel_id,
    request__visitor__timezone AS transaction__request__visitor__timezone,
    request__visitor__timezone_offset AS transaction__request__visitor__timezone_offset,
    COUNT(*) AS actual_reqs
  FROM ${bcv_transaction}
  WHERE
    (
      request__context__video_cro_network_id IN (511888)
      AND BITWISE_AND(request__flags, 33554432) > 0
    )
    AND request__context__asset_chain__content_right_owner__airing_id <> -1
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10
) AS x

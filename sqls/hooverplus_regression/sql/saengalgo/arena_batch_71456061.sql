-- account:    saengalgo
-- skeleton:   ccfee5febe5d762b2fa5bd2493ac9e39
-- pattern:    714560616e581c0b0ba8d7c14fe43075  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     auction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  ip_id AS inventory_package_id,
  TRY(partners__network_id[2]) AS seller_network,
  request__context__video_cro_network_id AS video_cro_network_id,
  auction__network_id AS auction_network_id,
  SUM(
    COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1)
  ) AS bid_request_cnt,
  DATE(request__timestamp) AS event_date
FROM ${bcv_auction}
CROSS JOIN UNNEST(partners__inventory_package_ids[1]) AS t(ip_id)
WHERE
  auction__network_id IN (523319, 524565)
  AND ip_id IN (169168, 672262, 672263, 684736, 684738)
GROUP BY
  1,
  2,
  3,
  4,
  6
ORDER BY
  6,
  1,
  2,
  3,
  4

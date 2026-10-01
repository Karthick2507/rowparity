-- account:    sa-presto-tier2
-- skeleton:   a5afc4fd126bfba3cc491b1a2a780513
-- pattern:    8e445798add7cb137780003e5e8755b1  (1 execution(s))
-- in suite:   column coverage
-- hoover:     transaction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp <= CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

WITH filtered_assets AS (
  SELECT
    id
  FROM db.default.d_asset
  WHERE
    network_internal_asset_id = 'peacock_0017a56d-ed0e-4c7e-8737-94977b364542'
    AND network_id = 520311
)
SELECT
  COUNT(*) AS total_ad_request
FROM ${bcv_transaction}
JOIN filtered_assets
  ON transaction.request__context__distributor_video_asset_id = filtered_assets.id

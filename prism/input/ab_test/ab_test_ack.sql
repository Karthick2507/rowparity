-- ab test ack
select
    date_trunc('HOUR', ack__timestamp) as timestamp,
    coalesce(request__context__video_cro_network_id, -1) as video_cro_network_id,
    coalesce(nw.name, 'NA') as video_cro_network_name,
    coalesce(request__context__network_id, -1) as distributor_network_id,
    coalesce(d_nw.name, 'NA') as distributor_network_name,
    coalesce(request__context__site_section_id, -1) as site_section_id,
    coalesce(request__context__profile_id, -1) as profile_id,
    coalesce(p.name, 'NA') as profile_name,
    request__server_pool as server_pool,
    if (bitwise_and(request__flags, 64) > 0, 'true', 'false') as is_filtered,
    if (bitwise_and(request__extra_flags2, 8) > 0, 'true', 'false') as is_ssp_bidder_traffic,
    if (bitwise_and(request__extra_flags2, 65536) > 0 and request__context__request_format = 1, 'true', 'false') as is_sspu_vast_traffic,
    if (bitwise_and(request__extra_flags2, 65536) > 0 and request__context__request_format = 7, 'true', 'false') as is_sspu_ortb_traffic,
    if (bitwise_and(request__extra_flags2, 2097152) > 0, 'true', 'false') as is_ssp_dynamic_pod,
    -- coalesce(NULLIF(request__context__ab_test_item__bucket_id, ARRAY[]), ARRAY[-1]) as bucket_id,
    t.bucket_id as bucket_id,
    sum(if(coalesce(ack__metrics__ad_impression, 0) > 0, coalesce(t.revenue, 0) * coalesce(ack__metrics__fire_event_revenue_ratio, 0), 0)) as ack_ad_revenue,
    sum(
    CASE
      WHEN candidate__integration_type in ('OPENRTB_NORMAL')
        THEN coalesce(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * coalesce(ack__metrics__raw_ad_impression, 0) / 1000
      ELSE 0
    END
    ) as ack_prog_ad_revenue_usd
from mrm_log_flat.default.ack
    left join db.default.d_network nw on nw.id = request__context__video_cro_network_id
    left join db.default.d_network d_nw on d_nw.id = request__context__network_id
    left join db.default.d_ad_environment_compound_profile p on p.id = request__context__profile_id
cross join unnest (request__context__ab_test_item__bucket_id) as t (bucket_id)
cross join unnest (
        partners__role,
        partners__revenue
        )
    as t(
        network_role,
        revenue
        )
where
    network_role = 'CRO'
    AND ack__ack_entity_type = 'ad'
    AND cardinality(coalesce(request__context__ab_test_item__bucket_id, array[])) > 0
    AND coalesce(ack__metrics__ad_impression, 0) > 0
    AND ${DATA_FILTER_ACK}
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
-- ab test request
select
    date_trunc('HOUR', request__timestamp) as timestamp,
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
    sum(if(request__is_first_request, coalesce(request__log_sampling__magnifier, 1), 0)) as req_ad_request,
    sum(if(request__is_first_request, if(cardinality(coalesce(request__advertisements__flags, ARRAY[])) = 0, coalesce(request__log_sampling__magnifier, 1), 0), 0)) as req_empty_ad_response,
    sum(if(request__is_first_request, cardinality(coalesce(request__bidding_context__bid_request__impression__index, ARRAY[])) * coalesce(request__log_sampling__magnifier, 1), 0)) as ad_request_impression,
    sum(if(request__is_first_request, cardinality(coalesce(request__slots__environment, ARRAY[])) * coalesce(request__log_sampling__magnifier, 1), 0)) as slots,
    sum(if(request__is_first_request, cardinality(coalesce(request__advertisements__ad_id, ARRAY[])) * coalesce(request__log_sampling__magnifier, 1), 0)) as ad_delivered_ad,
    sum(if(request__is_first_request, cardinality(coalesce(request__rtb_auction__integration_type, ARRAY[])) * coalesce(request__log_sampling__magnifier, 1), 0)) as auction_request,
    -- sum(if(request__is_first_request, cardinality(coalesce(request__external_candidate_ad__ad_id, ARRAY[])), 0)) as bids_received,
    sum(if(request__is_first_request, cardinality(filter(coalesce(request__external_candidate_ad__bid_status, ARRAY[]), x -> (bitwise_and(x, 1) = 1))) * coalesce(request__log_sampling__magnifier, 1), 0)) as bids_received,
    sum(if(request__is_first_request, cardinality(filter(coalesce(request__external_candidate_ad__bid_status, ARRAY[]), x -> (bitwise_and(x, 9) = 1))) * coalesce(request__log_sampling__magnifier, 1), 0)) as bids_filtered,
    sum(if(request__is_first_request, cardinality(filter(coalesce(request__external_candidate_ad__bid_status, ARRAY[]), x -> (bitwise_and(x, 8) = 8))) * coalesce(request__log_sampling__magnifier, 1), 0)) as bids_delivered,
    sum(reduce(coalesce(acks__metrics__ad_impression, ARRAY[]), 0, (s, x) -> s + x, s -> s)) as ack_ad_impression
from mrm_log_flat.default.transaction
    left join db.default.d_network nw on nw.id = request__context__video_cro_network_id
    left join db.default.d_network d_nw on d_nw.id = request__context__network_id
    left join db.default.d_ad_environment_compound_profile p on p.id = request__context__profile_id
cross join unnest (request__context__ab_test_item__bucket_id) as t (bucket_id)
where
    (request__delivery_method is null or request__delivery_method != 'CASUCPSU')
    and cardinality(coalesce(request__context__ab_test_item__bucket_id, array[])) > 0
    -- and request__is_first_request
    and ${DATA_FILTER_REQUEST}
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
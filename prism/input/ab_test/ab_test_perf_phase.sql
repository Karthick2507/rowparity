-- ab test perf
with t1 as (
    select
        cast(date_trunc('hour', from_unixtime(adserver_performance_log_record.timestamp)) as timestamp) as timestamp,
        coalesce(adserver_performance_log_record.request.video_cro_network_id, -1) as video_cro_network_id,
        coalesce(adserver_performance_log_record.request.distributor_network_id, -1) as distributor_network_id,
        coalesce(adserver_performance_log_record.request.site_section_id, -1) as site_section_id,
        coalesce(adserver_performance_log_record.request.profile_id, -1) as profile_id,
        adserver_performance_log_record.server_pool as server_pool,
        if (bitwise_and(adserver_performance_log_record.flags, 64) > 0, 'true', 'false') as is_filtered,
        if (bitwise_and(adserver_performance_log_record.extra_flags2, 8) > 0, 'true', 'false') as is_ssp_bidder_traffic,
        if (bitwise_and(adserver_performance_log_record.extra_flags2, 65536) > 0 and adserver_performance_log_record.request.request_format = 1, 'true', 'false') as is_sspu_vast_traffic,
        if (bitwise_and(adserver_performance_log_record.extra_flags2, 65536) > 0 and adserver_performance_log_record.request.request_format = 7, 'true', 'false') as is_sspu_ortb_traffic,
        if (bitwise_and(adserver_performance_log_record.extra_flags2, 2097152) > 0, 'true', 'false') as is_ssp_dynamic_pod,
        transform(coalesce(adserver_performance_log_record.request.ab_test_item, ARRAY[]), row -> row.bucket_id) AS bucket_id,
        element_at(filter(adserver_performance_log_record.time_span, row -> row.key = 'resp'), 1) as resp,
        element_at(filter(adserver_performance_log_record.time_span, row -> row.key = 'cpu'), 1) as cpu,
        adserver_performance_log_record.log_sampling.magnifier as magnifier
    from db.troubleshooting_log.fw_ads_troubleshooting_log
    where
        cardinality(coalesce(adserver_performance_log_record.request.ab_test_item, array[])) > 0
        and ${DATA_FILTER_REQUEST}
)
select
    timestamp,
    video_cro_network_id,
    coalesce(nw.name, 'NA') as video_cro_network_name,
    distributor_network_id,
    coalesce(d_nw.name, 'NA') as distributor_network_name,
    site_section_id,
    profile_id,
    server_pool,
    coalesce(p.name, 'NA') as profile_name,
    is_filtered,
    is_ssp_bidder_traffic,
    is_sspu_vast_traffic,
    is_sspu_ortb_traffic,
    is_ssp_dynamic_pod,
    t2.bucket_id as bucket_id,
    sum(cast(resp.duration as bigint) * coalesce(magnifier, 1)) / 1000 as resp_duration,
    sum(if(resp.duration <= 3000000, coalesce(magnifier, 1), 0)) as resp_lt_3000ms,
    sum(if(resp.duration <= 2000000, coalesce(magnifier, 1), 0)) as resp_lt_2000ms,
    sum(if(resp.duration <= 1500000, coalesce(magnifier, 1), 0)) as resp_lt_1500ms,
    sum(if(resp.duration <= 1200000, coalesce(magnifier, 1), 0)) as resp_lt_1200ms,
    sum(if(resp.duration <= 1000000, coalesce(magnifier, 1), 0)) as resp_lt_1000ms,
    sum(if(resp.duration <= 500000, coalesce(magnifier, 1), 0)) as resp_lt_500ms,
    sum(if(resp.duration <= 300000, coalesce(magnifier, 1), 0)) as resp_lt_300ms,
    sum(if(resp.duration <= 150000, coalesce(magnifier, 1), 0)) as resp_lt_150ms,
    sum(if(resp.duration <= 100000, coalesce(magnifier, 1), 0)) as resp_lt_100ms,
    sum(if(resp.duration <= 50000, coalesce(magnifier, 1), 0)) as resp_lt_50ms,
    sum(if(resp.duration <= 20000, coalesce(magnifier, 1), 0)) as resp_lt_20ms,
    sum(if(resp.duration <= 10000, coalesce(magnifier, 1), 0)) as resp_lt_10ms,
    sum(if(resp.duration <= 5000, coalesce(magnifier, 1), 0)) as resp_lt_5ms,
    sum(if(resp.duration <= 2000, coalesce(magnifier, 1), 0)) as resp_lt_2ms,
    sum(cast(cpu.duration as bigint) * coalesce(magnifier, 1)) / 1000 as cpu_duration,
    sum(if(cpu.duration  <= 3000000, coalesce(magnifier, 1), 0)) as cpu_lt_3000ms,
    sum(if(cpu.duration  <= 2000000, coalesce(magnifier, 1), 0)) as cpu_lt_2000ms,
    sum(if(cpu.duration  <= 1500000, coalesce(magnifier, 1), 0)) as cpu_lt_1500ms,
    sum(if(cpu.duration  <= 1200000, coalesce(magnifier, 1), 0)) as cpu_lt_1200ms,
    sum(if(cpu.duration  <= 1000000, coalesce(magnifier, 1), 0)) as cpu_lt_1000ms,
    sum(if(cpu.duration  <= 500000, coalesce(magnifier, 1), 0)) as cpu_lt_500ms,
    sum(if(cpu.duration  <= 300000, coalesce(magnifier, 1), 0)) as cpu_lt_300ms,
    sum(if(cpu.duration  <= 150000, coalesce(magnifier, 1), 0)) as cpu_lt_150ms,
    sum(if(cpu.duration  <= 100000, coalesce(magnifier, 1), 0)) as cpu_lt_100ms,
    sum(if(cpu.duration  <= 50000, coalesce(magnifier, 1), 0)) as cpu_lt_50ms,
    sum(if(cpu.duration  <= 20000, coalesce(magnifier, 1), 0)) as cpu_lt_20ms,
    sum(if(cpu.duration  <= 10000, coalesce(magnifier, 1), 0)) as cpu_lt_10ms,
    sum(if(cpu.duration  <= 5000, coalesce(magnifier, 1), 0)) as cpu_lt_5ms,
    sum(if(cpu.duration  <= 2000, coalesce(magnifier, 1), 0)) as cpu_lt_2ms,
    sum(coalesce(magnifier, 1)) as total_request
from t1
left join db.default.d_network nw on nw.id = video_cro_network_id
left join db.default.d_network d_nw on d_nw.id = distributor_network_id
left join db.default.d_ad_environment_compound_profile p on p.id = profile_id
cross join unnest (bucket_id) as t2 (bucket_id)
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
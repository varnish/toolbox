#!/bin/sh

set -e

mkdir -p data/vod/

# see https://ottverse.com/hls-packaging-using-ffmpeg-live-vod/ for a breakdown
# note: the last argument ("stream_%v/sub.m3u8") had to be tweaked to build
# sub-manifests in the right directories and avoid a 404
ffmpeg -f lavfi -i testsrc=duration=60:size=1920x1080:rate=30\
	-filter_complex "[0:v]split=3[v1][v2][v3]; [v1]copy,format=yuv420p[v1out]; [v2]scale=w=1280:h=720,format=yuv420p[v2out]; [v3]scale=w=640:h=360,format=yuv420p[v3out]" \
	-map "[v1out]" -c:v:0 libx264 -x264-params "nal-hrd=cbr:force-cfr=1" -b:v:0 5M -maxrate:v:0 5M -minrate:v:0 5M -bufsize:v:0 10M -preset slow -g 48 -sc_threshold 0 -keyint_min 48 \
	-map "[v2out]" -c:v:1 libx264 -x264-params "nal-hrd=cbr:force-cfr=1" -b:v:1 3M -maxrate:v:1 3M -minrate:v:1 3M -bufsize:v:1 3M -preset slow -g 48 -sc_threshold 0 -keyint_min 48 \
	-map "[v3out]" -c:v:2 libx264 -x264-params "nal-hrd=cbr:force-cfr=1" -b:v:2 1M -maxrate:v:2 1M -minrate:v:2 1M -bufsize:v:2 1M -preset slow -g 48 -sc_threshold 0 -keyint_min 48 \
	-f hls \
	-hls_time 2 \
	-hls_playlist_type vod \
	-hls_flags independent_segments \
	-hls_segment_type mpegts \
	-hls_segment_filename data/vod/stream_%v/data%02d.ts \
	-master_pl_name master.m3u8 \
	-var_stream_map "v:0 v:1 v:2" data/vod/stream_%v/sub.m3u8

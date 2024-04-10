#!/bin/sh

set -x 

mkdir -p /output/live/

# important settings:
#   -re: encode at live speed
#   -streamloop -1: loop forever
#   -hls_list_size 20 / -hls_flags delete_segments: only keep 20 segments around, delete the rest
ffmpeg \
	-re \
	-stream_loop -1 \
	-f lavfi -i testsrc=duration=600:size=1920x1080:rate=30 \
	-vf format=yuv420p \
	-preset veryfast \
	-vcodec libx264 \
	-loglevel warning \
	-hls_list_size 20 \
	-hls_flags delete_segments \
	/output/live/master.m3u8

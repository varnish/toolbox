Do you want to set up your own video origin and shield to experiment with Varnish and streaming? You are in the perfect spot!

# Requirements

You just need a few things to follow along:
- a terminal
- a browser
- a video player
- `docker-compose`
- `ffmpeg`

# Creating

Let's create a Video-On-Demand (VOD) stream, i.e. a video that is complete and ready to go:

``` bash
./build_vod_hls.sh
```

`ffmpeg` should kick in and start printing a bunch of lines looking like those:

```
...
[hls @ 0x55760e0ca480] Opening 'stream_0/data00.ts' for writing85 bitrate=N/A dup=2 drop=0 speed=0.597x     
[hls @ 0x55760e0ca480] Opening 'stream_1/data00.ts' for writing
[hls @ 0x55760e0ca480] Opening 'stream_2/data00.ts' for writing
[hls @ 0x55760e0ca480] Opening 'stream_0/data01.ts' for writing.75 bitrate=N/A dup=2 drop=0 speed=0.569x    
[hls @ 0x55760e0ca480] Opening 'stream_1/data01.ts' for writing
[hls @ 0x55760e0ca480] Opening 'stream_2/data01.ts' for writing
[hls @ 0x55760e0ca480] Opening 'stream_0/data02.ts' for writing.63 bitrate=N/A dup=2 drop=0 speed=0.515x    
[hls @ 0x55760e0ca480] Opening 'stream_1/data02.ts' for writing
[hls @ 0x55760e0ca480] Opening 'stream_2/data02.ts' for writing
...
```

Once the script returns, check out the new `data/vod/` directory:

``` bash
ls data/vod/
master.m3u8  stream_0/  stream_1/  stream_2/
```

It has three streams directories (`stream_X`) which corresponds to our video in three different bitrates (quality).

Let's look at the content of `master.m3u8`:

``` bash
cat data/vod/master.m3u8 
#EXTM3U
#EXT-X-VERSION:6
#EXT-X-STREAM-INF:BANDWIDTH=5605600,RESOLUTION=3840x2160,CODECS="avc1.640034,mp4a.40.2"
stream_0/sub.m3u8

#EXT-X-STREAM-INF:BANDWIDTH=3405600,RESOLUTION=1280x720,CODECS="avc1.640020,mp4a.40.2"
stream_1/sub.m3u8

#EXT-X-STREAM-INF:BANDWIDTH=1152800,RESOLUTION=640x360,CODECS="avc1.64001f,mp4a.40.2"
stream_2/sub.m3u8
```

Maybe unsurprisingly, it describes the three streams, with their bitrates and resolutions. And pretty importantly, it points at three `stream_X/sub.m3u8` files, we should check them out.

``` bash
$ head -n 20 data/vod/stream_0/sub.m3u8 
#EXTM3U
#EXT-X-VERSION:6
#EXT-X-TARGETDURATION:2
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-PLAYLIST-TYPE:VOD
#EXT-X-INDEPENDENT-SEGMENTS
#EXTINF:2.400000,
data00.ts
#EXTINF:1.600000,
data01.ts
#EXTINF:2.400000,
data02.ts
#EXTINF:1.600000,
data03.ts
#EXTINF:2.400000,
data04.ts
#EXTINF:1.600000,
data05.ts
#EXTINF:2.400000,
data06.ts
```

It looks like each sub list, in order, every `dataXX.ts` file, along with some metadata, but what are those `.ts` files exactly? If you try to open one with your media player, you should see it's a short video, more precisely, a segment of `data/video.mp4`.

Having the video chopped up like this allows the user to do to a few things:
- jumping at any point of the video without downloading the whole file
- switching from one bitrate to another very easily
- switching to another datacenter seamlessly

# Running the code

Let's get the `docker-compose` running:

``` bash
docker compose up
```

# Playing the VOD stream

The entry point of our video is [http://localhost/vod/master.m3u8], which we are going to read via [https://livepush.io/hls-player/index.html]. Go to that page, and input `https://localhost/vod/master.m3u8` into the text field, then click on `Play M3U8`.

A video with buttery smooth playback should bless your screen, and you can open the network tab of your browser to see what is being downloaded. You can notably change the video quality in the player, or seeking around, and see how it affects the download of new chunks.

# Playing the live stream

On the same page, you can also try playing `http://localhost/live/master.m3u8`, which doesn't let you seek around. To understand how live works, you can first have a look at the network tab, and see that `master.m3u8` is downloaded over and over again, with its content changing every few seconds.

And if you go to [https://localhost/live/] and reload the page every few seconds, you'll also see that chunks keeps being rotated in and out. What's happening is that `ffmpeg` is reading `data/video.mp4`, continuously chunking it, updating `master.m3u8` and deleting old chunks to keep things clean.

To see the actual `ffmpeg` command, you can look at `build_live_hls.sh`

# Check out the VCL

Open `conf/default.vcl`, and see if you have any questions.

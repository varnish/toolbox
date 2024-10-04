# Clustered push-based objectstore

This is an example with live video pushed to the objectstore

# How to test:

Push and fetch files:

1. `docker compose up`
   * starts 3 varnishes, and a loadbalancing varnish (just for reaching the varnishes)
2. `curl http://localhost:6081/hello`
   * get 404
3. `curl -X POST --data-ascii "hello world" -H 'Content-Type: text/plain' -H 'Authorization: secret' -v http://localhost:6081/hello`
   * get a good status
4. `curl -v http://localhost:6081/hello`
   * get "Hello world" and the Content-Type header you pushed

Live video:

1. `docker compose up`

2. open http://localhost:6081/master.m3u8 in your favorite video player
   * look at compose.yaml to see how ffmpeg is pushing live video to varnish


# Things you probably want to change

* Invalidation not implemented. Purge should "just work", VOD purging will be easier with ykey.
* Host header is set to localhost, this is not ideal..
* TTL is set statically in VCL

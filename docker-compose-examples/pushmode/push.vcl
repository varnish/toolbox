vcl 4.1;

import activedns;
import kvstore;
import std;
import synthbackend;
import udo;
import utils;

include "vha6/vha_auto.vcl";

backend default none;

sub vcl_init {
    vha6_opts.set("broadcaster_host", "broadcaster");
    vha6_opts.set("token", "secret123");
    call vha6_token_init;
}

sub vcl_init {
    new push_group = activedns.dns_group("push-origin:6081");
    push_group.set_ttl_rule(force);
    push_group.set_ttl(1s);

    new push_cluster = udo.director();
    push_cluster.subscribe(push_group.get_tag());

    new push_opts = kvstore.init();
    push_opts.set("token",  "abcde");
}


sub vcl_synth {
    // This synth is just for delivering an empty response
    if (resp.status == 1200) {
        synthetic("");
        set resp.body = {"
{"status": true }
"};
        set resp.status = 200;
        return(deliver);
    }
}
sub vcl_recv {
    set req.hash_ignore_busy = true; // FIXME: always?
    // ffmpeg workaround:
    if (req.http.user-agent == "secret") {
        // set req.method = "POST";
        set req.http.authorization = "secret";
    }
    set req.http.host = "localhost";
    if (req.http.authorization == "secret") { // FIXME: pretend-authentication
        if (req.method == "POST" || req.http.post-method == "true") {
            set req.http.method = "GET";
            set req.http.post-method = "true";
            set req.hash_always_miss = true;
            return (hash);
        } else {
            // Return a 404 if the cluster node reaches itself
            if (push_cluster.self_identify(req.http.X-Cluster-Identifier)) {
                return (synth(404));
            }
        }
    }
    // Block unhandled request methods. Invalidation logic goes above this block.
    if (req.method != "GET" &&
        req.method != "HEAD" &&
        req.method != "POST") {
        return(synth(405, "Method not allowed"));
    }

    unset req.http.authorization;
}

sub vcl_miss {
    if (req.http.x-push-searching) {
      return (synth(404));
    }
}

sub vcl_backend_fetch {
    // if the request was a POST, set the "mirror" backend 
    // that will create a temporary backend 
    // which will respond with the request body and headers to insert it into cache.
    if (bereq.http.post-method == "true") {
        std.log("Should insert object here");
        set bereq.backend = synthbackend.mirror();
        return(fetch);
    }

    // try to find the object within the cluster
    if (push_cluster.self_is_next()) {
        utils.resolve_backend(push_cluster.backend());
        std.log("exhausted myself");
    }
    set bereq.backend = push_cluster.backend();
    set bereq.http.x-push-searching = "true";
    set bereq.http.X-Cluster-Identifier = push_cluster.get_identifier();
    return (fetch);
}

sub vcl_backend_response {
    if (bereq.http.post-method == "true") {
        set beresp.ttl = 10m; // FIXME: This can be set with -t or -p default_ttl, but for more complex
    } else if (bereq.http.x-push-searching && beresp.status != 200) {
        return (retry);
    }
}

sub vcl_deliver {
    // If the request was a POST, then this response contains the original request
    // We don't need the original data mirrored back at us, so instead we synth an empty response.
    if (req.http.post-method == "true") {
        return(synth(1200));
    }
    set resp.http.X-ttl = obj.ttl;
}

sub vcl_backend_error {
    if (bereq.http.x-push-searching && std.healthy(push_cluster.backend())) {
        return(retry);
    }
    // Give a 404 instead of a backend fetch failed since we don't have a backend.
    set beresp.status = 404;
    set beresp.http.Content-Type = "text/plain";
    set beresp.http.Cache-Control = "no-store; no-cache";
    set beresp.body   = """
404 not found
""";
    return(deliver);
}

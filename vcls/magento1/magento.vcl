#
# Magento 1.x VCL configuration
#
# Copyright (c) 2018 Varnish Software AS
#
# This VCL allows for Varnish to cache Magento product pages by
# decomposing and recomposing content using JSON and Mustache.
#
# v1.2
#

vcl 4.0;

import cookieplus;
import edgestash;
import kvstore;
import std;
import urlplus;
import xbody;

include "letsencrypt.vcl";
include "total-encryption/random_key.vcl";
include "vha_40.vcl";

backend default
{
    .host = "0.0.0.0";
    .port = "0";
}

sub vcl_init
{
    // User json cache
    new user_json = kvstore.init();

    // VHA token
    vha_opts.set("token", "magento1");
}

sub vcl_recv
{
    // Setup
    unset req.http.X-frontend;
    unset req.http.X-capture;
    set req.http.X-status = "NONE";

    // Health check
    if (req.url == "/varnish_health") {
        return (synth(200, "HEALTH"));
    }

    // HTTPS
    if (std.port(server.ip) == 80) {
        set req.http.Location = "https://" + req.http.Host + req.url;
        return (synth(301));
    }

    // Never cache these requests
    if (req.method != "HEAD" && req.method != "GET") {
        return (pass);
    }

    // Never cache these pages
    if (req.url ~ "^/customer/" ||
        req.url ~ "^/checkout/" ||
        req.url ~ "^/admin/") {
            return (pass);
    }

    // Always cache for crawlers
    if (req.http.User-Agent ~ "Googlebot|curl|bingbot|YandexBot|Baiduspider") {
        return (hash);
    }

    // VHA
    if (req.http.vha-origin) {
        return (hash);
    }

    // We have no Magento session in Varnish, get one
    if (!user_json.get(cookieplus.get("frontend"))) {
        return (pass);
    }

    return (hash);
}

// What are we, hit, miss, or pass?
sub vcl_hit
{
    set req.http.X-status = "HIT";
}
sub vcl_miss
{
    set req.http.X-status = "MISS";
}
sub vcl_pass
{
    set req.http.X-status = "PASS";

    // Do JSON capture when we pass
    set req.http.X-capture = "true";
}

sub vcl_backend_fetch
{
    // Clear request cookies for caching
    if (bereq.http.X-status ~ "HIT|MISS") {
        // Keep cookies that are needed for basic site functionality
        cookieplus.keep("");
        cookieplus.write();
    }
}

sub vcl_backend_response
{
    // Magento TTL override
    set beresp.ttl = 1d;
    set beresp.grace = 1w;

    // Only template text responses
    //if (beresp.http.Content-Type ~ "text") {
    if (bereq.url == "/" || urlplus.get_extension() == "html") {
        if (bereq.http.X-capture) {
            // Capture the form_key
            // Format: <input name="form_key" type="hidden" value="XXXX" />
            xbody.capture("form_key", {"name=\"form_key\"[^>]+value=\"([\w]+)\""}, "\1");

            // Do other captures here
        } else {
            // Template the form_key
            // Format: /form_key/XXXX/
            xbody.regsub({"\/form_key\/([^\/]*)\/"}, "/form_key/{{form_key}}/");
            // Format: \/form_key\/XXXX\/
            xbody.regsub({"\\\/form_key\\\/([^\/]*)\\\/"}, "\/form_key\/{{form_key}}\/");
            // Format: <input name="form_key" type="hidden" value="XXXX" />
            xbody.regsub({"(name="form_key"[^>]+value=)"(\w*)""}, {"\1"{{form_key}}""});
            // Format: "form_key": "XXXX"
            xbody.regsub({"("form_key"\s*:\s*)"(\w)*""}, {"\1"{{form_key}}""});

            // Do other manipulations here

            // Enable Edgestash
            edgestash.parse_response();
        }
    }

    // Clear cookies
    if (bereq.http.X-status ~ "HIT|MISS") {
        unset beresp.http.Set-Cookie;

        // Setup ban headers
        set beresp.http.X-url = bereq.url;
        set beresp.http.X-host = bereq.http.Host;
    }

    // VHA
    if (bereq.http.vha-origin) {
        xbody.set(beresp.http.X-body);
    }
    unset beresp.http.X-body;

    return (deliver);
}

sub vcl_deliver
{
    // Get the frontend id
    if (cookieplus.get("frontend")) {
        set req.http.X-frontend = cookieplus.get("frontend");
    } else if (cookieplus.setcookie_get("frontend")) {
        set req.http.X-frontend = cookieplus.setcookie_get("frontend");
    }

    // Set and store the user JSON
    if (req.http.X-frontend && xbody.get("form_key")) {
        user_json.set(req.http.X-frontend, xbody.get_all(), 1h);
    }

    // Template the form_key back in
    if (edgestash.is_edgestash()) {
        edgestash.add_json(user_json.get(req.http.X-frontend));
        edgestash.execute();
    }

    // Response headers
    set resp.http.X-cache = req.http.X-status + " (" + server.identity + ")";
    set resp.http.X-hits = obj.hits;
    unset resp.http.X-url;
    unset resp.http.X-host;

    // VHA
    if (req.http.vha-fetch) {
        set resp.http.X-body = xbody.get_all();
        unset resp.http.X-cache;
        unset resp.http.X-hits;
    }
}

sub vcl_synth
{
    if (resp.status == 200 && resp.reason == "HEALTH") {
        synthetic(server.identity);
        return (deliver);
    }

    if (resp.status == 301) {
        set resp.http.Location = req.http.Location;
        return (deliver);
    }
}

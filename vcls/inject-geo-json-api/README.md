# Inject Geo + JSON API

[`inject-geo-json-api.vcl`](inject-geo-json-api.vcl) is an example VCL for
**[Varnish Cache](https://www.varnish.org/)** that shows how Varnish
can enrich a cached response by combining **geolocation data** with a
**third-party JSON API**, and inject the result straight into the response
body, without ever changing the origin.

The example uses [example.com](https://example.com) as the base web page.
Varnish Cache fetches it as a dynamic backend, looks up the client's location
in a local MaxMind GeoLite2 database, calls the
[Open-Meteo](https://open-meteo.com) weather API for the current temperature
at that location, and rewrites the HTML body so that the visitor sees a
personalised "weather information" page instead of the default
`Example Domain` content.

## What it does, step by step

1. **`vcl_init`** — performs the intial setup of VMODs:
    - a generic HTTP client (`reqwest`) used to call the Open-Meteo API;
    - a dynamic backend (`reqwest`) that proxies to `https://example.com`;
    - the GeoIP2 database loaded from `/etc/varnish/GeoLite2-City.mmdb`;
    - a regex replacement cache (`rers`) used to rewrite the response body.
2. **`vcl_backend_fetch`** — points the request at `example.com` via the
   dynamic backend, so Varnish Cache has an HTML page to cache and modify.
3. **`vcl_deliver`** — peforms content personalizaztion for every delivered response:
    - resolves the client's IP address (`client.ip`) against `GeoLite2-City.mmdb` to get latitude,
      longitude, country and city;
    - if the location is known, calls
      `https://api.open-meteo.com/v1/forecast?latitude=…&longitude=…&hourly=temperature_2m&timezone=auto&forecast_days=1`;
    - parses the JSON response with `vmod_jq` and extracts
      `.hourly.temperature_2m[0]`;
    - uses `vmod_rers` to rewrite the cached HTML body:
        - replaces the title `Example Domain` with `Weather Information`,
        - replaces the first `<p>…</p>` paragraph with a sentence that
          mentions the visitor's location and the current temperature,
        - strips the `<a>` link that points to IANA;
    - applies the response body rewrites by enabling the `rers` delivery filter in Varnish Cache (`resp.filters = "rers";`).

The whole transformation happens **at delivery time**, so the cached object
itself is untouched. Each visitor gets a body tailored to their location
without invalidating the cache or going back to the origin.

## Required VMODs

This VCL uses the following VMODs, all available for Varnish Cache:

| VMOD | Purpose |
| --- | --- |
| `vmod_reqwest` | HTTP client used both as a dynamic backend to `example.com` and to call the Open-Meteo API |
| `vmod_jq` | Parses the JSON returned by Open-Meteo using `jq` syntax |
| `vmod_geoip2` | Looks up the client IP in the MaxMind GeoLite2 database |
| `vmod_rers` | Regex-based response body rewriting, used as a delivery filter |
| `vmod_var` | Stores intermediate values (lat/lon, country, city, location string) across the subroutine |
| `vmod_std` | Standard logging via `std.log()` |

### Getting the VMODs

The required VMODs are packaged for [Varnish Cache 9](https://www.varnish.org/docs/extra-features/), and there are a couple of ways to get them.

#### 1. Install on Debian/Ubuntu

The example targets *Varnish Cache 9*, so make sure you enable the
corresponding APT repository. Follow [the official install guide](https://www.varnish.org/docs/install-guide/install-debian-ubuntu/index.html) and have a look at [the extra VMODs installation section](https://www.varnish.org/docs/install-guide/install-debian-ubuntu/#install-extra-vmods-optional).

Once Varnish Cache is installed, install the VMOD
packages by running the following `apt-get` command:

```bash
sudo apt-get install \
    vmod-reqwest \
    vmod-jq \
    vmod-geoip2 \
    vmod-rers \
    vmod-var
```

#### 2. Install on Red Hat Enterprise Linux and compatible distributions

As mentioned earlier, the VCL example targets *Varnish Cache 9*. Make sure you enable the
corresponding Yum repository on RHEL-compatible distributions. Follow [the official install guide](https://www.varnish.org/docs/install-guide/install-rhel-compatible/) and have a look at [the extra VMODs installation section](https://www.varnish.org/docs/install-guide/install-rhel-compatible/#install-extra-vmods-optional).

Once Varnish Cache is installed, install the VMOD
packages by running the following `dnf` command:

```bash
sudo dnf install \
    vmod-reqwest \
    vmod-jq \
    vmod-geoip2 \
    vmod-rers \
    vmod-var
```

#### 3. Use the official Varnish Cache Docker image

The [official Varnish Cache Docker image](https://hub.docker.com/_/varnish) **already includes all the VMODs** listed above. You don't need to install anything extra: just mount your VCL
and the GeoIP database and run the container. This is the easiest way to try
the example VCL.

The [Docker install guide](https://www.varnish.org/docs/install-guide/install-docker/) explains all the details, but the following command should already do the job:

```bash
docker run --rm -it \
    -v $(pwd)/inject-geo-json-api.vcl:/etc/varnish/default.vcl:ro \
    -v $(pwd)/GeoLite2-City.mmdb:/etc/varnish/GeoLite2-City.mmdb:ro \
	--tmpfs /var/lib/varnish:exec \
	--name varnish \
    -p 8080:80 \
    -e VARNISH_SIZE=2G \
    varnish:latest
```

## Getting `GeoLite2-City.mmdb`

The GeoIP lookups depend on MaxMind's free `GeoLite2-City` database.

1. Create a free MaxMind account at
   <https://www.maxmind.com/en/geolite2/signup>.
2. Generate a license key from the account dashboard.
3. Download the **GeoLite2 City** database (`.mmdb` format) from the
   [download page](https://www.maxmind.com/en/accounts/current/geoip/downloads),
   either manually or via `geoipupdate`.

The VCL expects the file at:

```
/etc/varnish/GeoLite2-City.mmdb
```

That path is hard-coded on line 18 of the VCL:

```vcl
new geo = geoip2.geoip2("/etc/varnish/GeoLite2-City.mmdb");
```

If you change the path, update the `geoip2.geoip2(...)` call accordingly.

## How the location drives the Open-Meteo call

Open-Meteo's forecast endpoint takes raw latitude/longitude, which is exactly
what `vmod_geoip2` returns. The VCL builds the request URL from the values it
just looked up:

```vcl
client.init("sync", "https://api.open-meteo.com/v1/forecast?"
    + "latitude="  + var.get("latitude")
    + "&longitude=" + var.get("longitude")
    + "&hourly=temperature_2m&timezone=auto&forecast_days=1");
```

A few details worth noting:

- The call is **synchronous** (`"sync"`), so `vcl_deliver` waits for the
  response before rewriting the body.
- `timezone=auto` ensures the hourly buckets are aligned to the visitor's
  local timezone.
- `forecast_days=1` keeps the JSON payload small and only returns today's hourly
  temperatures.
- If the API call fails (`client.status("sync") != 200`), the VCL logs and
  bails out via `return(deliver)`, so the page is still served unmodified.

The temperature is then extracted from the JSON with `vmod_jq`:

```vcl
jq.parse(string, client.body_as_string("sync"));
jq.get(".hourly.temperature_2m[0]", "N/A");
```

`.hourly.temperature_2m[0]` is the first hourly bucket of the day, used here
as a "current temperature" approximation. The `"N/A"` argument is the default
returned if the key is missing.

If geolocation is unavailable (for instance, for private IPs or unknown
ranges), the VCL also (gracefully) bails out before calling the API:

```vcl
if(var.get("latitude") == "" || var.get("longitude") == "" || var.get("country_code") == "") {
    std.log("Geolocation data not available for IP: " + client.ip);
    return(deliver);
}
```

## How the response body is rewritten at delivery time

Body rewriting is handled by `vmod_rers`, which exposes a regex-based
**delivery filter**. The pattern is:

1. Stage the replacements during `vcl_deliver` by calling
   `re_cache.replace_resp_body(<pattern>, <replacement>)` one or more times.
2. Activate the filter by setting `resp.filters = "rers";`.

When `resp.filters` includes `rers`, Varnish Cache streams the cached body
through the regex engine on its way to the client and applies the
replacements on-the-fly. The cached object is **not** modified, so:

- Different clients can get different rewrites of the same cached object
  (e.g. a visitor in Tokyo and one in Paris see different sentences without
  doubling the cache footprint).
- The origin is hit only once for `example.com`.

In this VCL, three replacements are queued:

```vcl
// Modify the response body title
re_cache.replace_resp_body("Example Domain","Weather Information");

// Modify the response body to include weather information
re_cache.replace_resp_body("<p>[^<]+<p>", "<p>The temperature in "
    + var.get("location") + " is "
    + jq.get(".hourly.temperature_2m[0]","N/A")
    + " &deg;C today.</p>");

// Remove hyperlink from the response body
re_cache.replace_resp_body("<a [^>]+>[^<]+</a>","");

// Apply the response body modifications
set resp.filters = "rers";
```

The result, as seen by the client, is the original `example.com` HTML with a
new title and a sentence such as:

> The temperature in Brussels (BE) is 14.3 &deg;C today.
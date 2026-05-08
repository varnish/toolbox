vcl 4.1;

import reqwest;
import jq;
import geoip2;
import rers;
import std;
import var;

backend default none;

sub vcl_init {
    // API client
    new client = reqwest.client();
    // Dynamic backend to example.com
	new be = reqwest.client(base_url = "https://example.com", follow = 5, auto_brotli = true);
    // Loads GeoIP2 database
    new geo = geoip2.geoip2("/etc/varnish/GeoLite2-City.mmdb");
    // Regex-based response body replacer
    new re_cache = rers.init(100);
}

sub vcl_backend_fetch {
    // Direct request to example.com
    set bereq.http.Host = "example.com";
    // Use the dynamic backend
	set bereq.backend = be.backend();
}

sub vcl_deliver {
    // Lookup geolocation data based on client IP
    // and prepare variables geo-related variables
    var.set("latitude", geo.lookup("location/latitude", client.ip));
    var.set("longitude", geo.lookup("location/longitude", client.ip));
    var.set("country_name", geo.lookup("country/names/en", client.ip));
    var.set("country_code", geo.lookup("country/iso_code", client.ip));
    var.set("city", geo.lookup("city/names/en", client.ip));

    // If geolocation data is not available, skip weather API call
    if(var.get("latitude") == "" || var.get("longitude") == "" || var.get("country_code") == "") {
        std.log("Geolocation data not available for IP: " + client.ip);
        return(deliver);

    }

    // Log geolocation data
    std.log("Latitude: " + var.get("latitude"));
    std.log("Longitude: " + var.get("longitude"));
    std.log("Country: " + var.get("country_name") + "(" + var.get("country_code") + ")");
    std.log("City: " + var.get("city"));

    // Prepare location string
    if(var.get("city") == "") {
        var.set("location", var.get("country_name"));
    } else {
        var.set("location", var.get("city") + " (" + var.get("country_code") + ")");
    }

    // Call Open-Meteo API to get weather data for the detected location
    client.init("sync", "https://api.open-meteo.com/v1/forecast?"
        + "latitude=" + var.get("latitude")
        + "&longitude=" + var.get("longitude")
        + "&hourly=temperature_2m&timezone=auto&forecast_days=1");

    // If the API call fails, skip response modification
	if (client.status("sync") != 200) {
        std.log("Failed to get weather data, status: " + client.status("sync"));
        return(deliver);
    }

    // Parse JSON response
    jq.parse(string, client.body_as_string("sync"));
    // Log temperature information
    std.log("Temperature: " + jq.get(".hourly.temperature_2m[0]", "N/A") + " °C");

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
}
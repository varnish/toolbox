import std;
import redis;

# EDIT initialize vmod_redis, telling it where your redis database is
sub vcl_init {
    new db = redis.db(location="127.0.01:6379");
}

sub vcl_recv {
    # here we ask redis to run a function for us, returning either "ok" or "denied"
    # the logic is implemented using keys that expire, we just need to set:
    # - KEY: what we are throttling, it can be a URL (req.url), and IP (client.ip), or maybe a specific cookie
    #        it can be any string you need
    # - PERIOD: how long do you throttle for (e.g. if you want to rate-limit to 5 calls per 4 seconds, PERIOD would be 4),
    #           the value is expressed in seconds
    # - THRESHOLD: how many accesses do you allow per periods (in the previous example, THRESHOLD is 5)
    db.command("EVAL");
    db.push("""redis.call("set", KEYS[1], 0, "NX", "EX", ARGV[1]); if (redis.call("incr", KEYS[1]) > tonumber(ARGV[2])) then return "denied" else return "ok" end ;""");
    db.push(1);
    db.push(KEY);       # EDIT replace "KEY"
    db.push(PERIOD);    # EDIT replace "PERIOD"
    db.push(THRESHOLD); # EDIT replace "THRESHOLD"  
    db.execute();

    # depending on the function return, we can either log it's ok, or generate an error response 
    if (db.reply_is_string() && db.get_reply() == "ok") {
    	std.log("request is allowed");
    } else {
    	return(synth(429));
    }
}

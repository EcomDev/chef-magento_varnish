import std;
import header;
import cookie;
import ipcast;
import querystring;

include "devicedetect.vcl";

# Balancers
probe healthcheck {
    .url = "/status";
    .interval = 30s;
    .timeout = 0.3s;
    .window = 8;
    .threshold = 3;
    .initial = 3;
    .expected_response = 200;
}

backend node1 {
    .host = "127.0.0.1";
    .port = "8080";
    .probe = healthcheck;
    .first_byte_timeout = 300s;
    .connect_timeout = 5s;
    .between_bytes_timeout = 2s;
}

backend admin {
    .host = "127.0.0.1";
    .port = "8080";
    .first_byte_timeout = 6000s;
    .connect_timeout = 1000s;
    .between_bytes_timeout = 2s;
}

director balancer client {
    {
      .backend = node1;
      .weight = 1;
    }
}

# Acls
acl allow_refresh {
   "127.0.0.1";
   "localhost";
   "192.168.4.1";
}

acl is_local {
   "127.0.0.1";
   "localhost";
   "192.168.6.1";
}

acl allow_admin {
   "127.0.0.1";
   "localhost";
   "192.168.5.1";
}

# Admin detect
sub detect_admin {
    unset req.http.is-admin;

    if (req.url ~ "^(/index.php)?/admin") {
        set req.http.is-admin = "1";
    }
}

# Custom functions
sub normalize_url {
    # Some generic URL manipulation, useful for all templates that follow
    # First remove the Google Analytics added parameters, useless for our backend
    set req.url = querystring.regfilter(req.url, "utm_source|utm_medium|utm_campaign|gclid|cx|ie|cof|siteurl");

    # Strip a trailing ? if it exists
    if (req.url ~ "\?$") {
        set req.url = regsub(req.url, "\?$", "");
    } else {
        set req.url = querystring.sort(req.url);
    }
}

sub normalize_cookie {
    cookie.parse(req.http.cookie);
    # Some generic cookie manipulation, useful for all templates that follow
    # Remove the "has_js" cookie
    cookie.delete("has_js");
    # Remove any Google Analytics based cookies
    cookie.delete("_ga");
    cookie.delete("__utma");
    cookie.delete("__utmb");
    cookie.delete("__utmc");
    cookie.delete("__utmz");
    cookie.delete("__utmx");
    # Remove the AddThis cookies
    cookie.delete("__atuvc");

    set req.http.cookie = cookie.get_string();

    # Are there cookies left with only spaces or that are empty?
    if (req.http.cookie ~ "^\s*$") {
        remove req.http.cookie;
    }
}

sub normalize_gzip_ua {
    # Normalize Accept-Encoding header
    # straight from the manual: https://www.varnish-cache.org/docs/3.0/tutorial/vary.html
    if (req.http.Accept-Encoding) {
        if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
            # No point in compressing these
            remove req.http.Accept-Encoding;
        } elsif (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        } elsif (req.http.Accept-Encoding ~ "deflate") {
            set req.http.Accept-Encoding = "deflate";
        } else {
            # unkown algorithm
            remove req.http.Accept-Encoding;
        }
    }

    # Send Surrogate-Capability headers to announce ESI support to backend
    set req.http.Surrogate-Capability = "key=ESI/1.0";
    set req.http.User-Agent = req.http.User-Agent + " " + req.http.X-UA-Device;
}

sub normalize_customer_segment {
    unset req.http.X-Cache-Segment;
    if( cookie.isset("segment_checksum")) {
        set req.http.X-Cache-Segment = cookie.get("segment_checksum");
        if (req.http.X-Cache-Segment) {
            set client.identity = client.identity + req.http.X-Cache-Segment;
        }
    }
}

sub normalize_ip_address {
    if (req.http.X-Forwarded-For ) {
        set req.http.X-Forwarded-For = regsub(req.http.X-Forwarded-For, "^(^[^,]+),?.*$", "\1");
        if (ipcast.ip(req.http.X-Forwarded-For, "127.0.0.1") == "127.0.0.1" ) {
            error 400 "Bad request";
        }

        if (client.ip !~ is_local) {
            unset req.http.X-Forwarded-For;
        }
    }
}

# Handle the HTTP request received by the client
sub vcl_recv {
    # shortcut for DFind requests
    if (req.url ~ "^/w00tw00t") {
        error 404 "Not Found";
    }

    call detect_admin;

    set client.identity = req.http.User-Agent + " " + client.ip;

    call normalize_url;
    call normalize_cookie;
    call normalize_gzip_ua;
    call normalize_customer_segment;
    call normalize_ip_address;

    call devicedetect;

    # Deny access to admin, if not in list of allowed ip
    if (req.http.is-admin && client.ip !~ allow_admin) {
        error 403 "Forbidden";
    } elsif (req.http.is-admin) {
        if (req.http.X-Forwarded-For && ipcast.ip(req.http.X-Forwarded-For, "127.0.0.1") !~ allow_admin) {
            error 403 "Forbidden";
        }
        set req.backend = admin;
        unset req.http.is-admin;
        return (pass);
    } else {
        set req.backend = balancer;
    }

    if (req.http.X-Forwarded-Proto && client.ip !~ is_local) {
        unset req.http.X-Forwarded-Proto;
    }

    if (req.restarts == 0) {
        if (client.ip !~ is_local) {
            set req.http.X-Forwarded-For = client.ip;
        }
    }

    # Normalize the header, remove the port (in case you're testing this on various TCP ports)
    set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");

    # Accept pages purge from authorized browsers' CTRl+F5
    if (req.http.Cache-Control ~ "no-cache" && client.ip ~ allow_refresh) {
        if (!req.http.X-Forwarded-For || ipcast.ip(req.http.X-Forwarded-For, "127.0.0.1") ~ allow_refresh) {
            # Forces current page to have a cache miss
            set req.hash_always_miss = true;
        }
    }

    # Only deal with "normal" types
    if (req.request != "GET" &&
            req.request != "HEAD" &&
            req.request != "PUT" &&
            req.request != "POST" &&
            req.request != "TRACE" &&
            req.request != "OPTIONS" &&
            req.request != "PATCH" &&
            req.request != "DELETE") {
        /* Non-RFC2616 or CONNECT which is weird. */
        return (pipe);
    }

    # Large static files should be piped, so they are delivered directly to the end-user without
    # waiting for Varnish to fully read the file first.
    # TODO: once the Varnish Streaming branch merges with the master branch, use streaming here to avoid locking.
    if (req.url ~ "^[^?]*\.(mp[34]|rar|tar|tgz|gz|wav|zip)(\?.*)?$") {
        return (pipe);
    }

    # Remove all cookies for static files
    # Static files are cached by default
    if (req.url ~ "^[^?]*\.(bmp|bz2|css|doc|eot|flv|gif|gz|ico|jpeg|jpg|js|less|pdf|png|rtf|swf|txt|woff|xml|css\.map)(\?.*)?$") {
        unset req.http.Cookie;
        return (lookup);
    }

    if (req.http.Authorization) {
        # Not cacheable by default
        return (pass);
    }

    if (req.request == "POST") {
        return (pass);
    }

    return (lookup);
}

# The data on which the hashing will take place
sub vcl_hash {
    hash_data(req.url);

    if (req.http.host) {
        hash_data(req.http.host);
    } else {
        hash_data(server.ip);
    }

    # hash device for request
    if (req.http.X-UA-Device) {
        hash_data(req.http.X-UA-Device);
    }

    if (req.http.X-Forwarded-Proto) {
        hash_data(req.http.X-Forwarded-Proto);
    }

    if (req.http.X-Cache-Segment) {
        hash_data(req.http.X-Cache-Segment);
    }

    if (req.http.X-Geo-Country) {
        hash_data(req.http.X-Geo-Country);
    }

    return (hash);
}


# Handle the HTTP request coming from our backend
sub vcl_fetch {

    # Parse ESI request and remove Surrogate-Control header
    if (beresp.http.Surrogate-Control ~ "ESI/1.0") {
        set beresp.do_esi = true;
    }

    # Enable gzip compression, if header for it is specified
    if (beresp.http.X-Cache-Gzip) {
        remove beresp.http.X-Cache-Gzip;
        set beresp.do_gzip = true;
    }

    # Sometimes, a 301 or 302 redirect formed via Apache's mod_rewrite can mess with the HTTP port that is being passed along.
    # This often happens with simple rewrite rules in a scenario where Varnish runs on :80 and Apache on :8080 on the same box.
    # A redirect can then often redirect the end-user to a URL on :8080, where it should be :80.
    # This may need finetuning on your setup.
    #
    # To prevent accidental replace, we only filter the 301/302 redirects for now.
    if (beresp.status == 301 || beresp.status == 302) {
        set beresp.http.Location = regsub(beresp.http.Location, ":[0-9]+", "");
        return (hit_for_pass);
    }

    if (beresp.status == 404) {
        unset beresp.http.Set-Cookie;
        return (hit_for_pass);
    }

    set beresp.http.X-UA-Device = req.http.X-UA-Device;
    set beresp.http.X-Cache-Segment = req.http.X-Cache-Segment;

    # Remove all cookies for static files and cache them for 1hour
    if (req.url ~ "^[^?]*\.(bmp|bz2|css|doc|eot|flv|gif|gz|ico|jpeg|jpg|js|less|pdf|png|rtf|swf|txt|woff|xml|css\.map)(\?.*)?$") {
        unset req.http.Cookie;
        set beresp.ttl = 1h;
        return (deliver);
    }

    if (beresp.http.X-Cache-Ttl) {
        set beresp.ttl = std.duration(beresp.http.X-Cache-Ttl, 0s);
        unset beresp.http.Set-Cookie;
    } else {
        return (hit_for_pass);
    }

    return (deliver);
}

# The routine when we deliver the HTTP request to the user
# Last chance to modify headers that are sent to the client
sub vcl_deliver {
    if (obj.hits > 0) {
        set resp.http.X-Cache = "cached";
    } else {
        set resp.http.X-Cache = "uncached";
    }

    # Remove some headers: Apache version & OS
    if (!resp.http.X-Debug) {
        remove resp.http.X-Cache;
        remove resp.http.X-UA-Device;
        remove resp.http.X-Cache-Segment;
        remove resp.http.X-Secure;
        remove resp.http.X-Powered-By;
        remove resp.http.Server;
        remove resp.http.Via;
        remove resp.http.Link;
        remove resp.http.X-Header-Additional;
    }

    return (deliver);
}

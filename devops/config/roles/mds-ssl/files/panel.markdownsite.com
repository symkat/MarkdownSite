upstream myapp {
  server 127.0.0.1:8080;
}

server {
    server_name www.markdownsite.com markdownsite.com;

    if ($host = www.markdownsite.com) {
        return 301 https://markdownsite.com$request_uri;
    }

    location = /js/script.js {
        # Change this if you use a different variant of the script
        proxy_pass https://plausible.io/js/plausible.js;

        # Tiny, negligible performance improvement. Very optional.
        proxy_buffering on;

        # Cache the script for 6 hours, as long as plausible.io returns a valid response
        # Only needed if you cache the plausible script. Speeds things up.
        # Note: to use the `proxy_cache` setup, you'll need to make sure the `/var/run/nginx-cache`
        # directory exists (e.g. creating it in a build step with `mkdir -p /var/run/nginx-cache`)
        # proxy_cache_path /var/run/nginx-cache/jscache levels=1:2 keys_zone=jscache:100m inactive=30d  use_temp_path=off max_size=100m;
        # proxy_cache jscache;
        # proxy_cache_valid 200 6h;
        # proxy_cache_use_stale updating error timeout invalid_header http_500;

        # Optional. Adds a header to tell if you got a cache hit or miss
        add_header X-Cache $upstream_cache_status;
    }

    location = /api/event {
        proxy_pass https://plausible.io/api/event;
        proxy_buffering on;
        proxy_http_version 1.1;

        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host  $host;
    }

    location / {
        proxy_pass http://myapp;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }



    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/markdownsite.com/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/markdownsite.com/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot


}


server {
    if ($host = www.markdownsite.com) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


    if ($host = markdownsite.com) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


    server_name www.markdownsite.com markdownsite.com;
    listen 80;
    return 404; # managed by Certbot


}

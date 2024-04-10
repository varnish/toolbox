#!/bin/sh

send_request() {
	URL=$1
	curl -qs -w "%{http_code} $URL\n" -o /dev/null http://varnish:80$URL
}

# probe varnish every second
health_check() {
	while true; do
		send_request /healthcheck
		sleep 1
	done
}

random_content() {
	while true; do
		# get a random integer between 0 and 99, influence by the 
		# current date for some extra fun. we'll use it in the
		# querystring to simulate different content
		i=$(( $RANDOM % ( $(( $(date +%s) % 100 )) + 1 ) ))
		# independently, give ourselves a 1%  chance of uncacheability
		# (check conf/default.vcl for more context)
		if [ $(( $RANDOM % 100 )) -lt 1 ]; then
			u=uncacheable
		else
			u=cacheable
		fi
		send_request /?$u-$i
		sleep 0.01
	done
}

health_check &
random_content &
wait

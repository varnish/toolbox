# Varnish for ElasticSearch
This repository contains the necessary configuration files to deploy ElasticSearch and Varnish Plus on Docker, and use Varnish as a security gateway in front of ElasticSearch.

ElasticSearch is managed via a *RESTful API*, which you don't want to expose to the outside world. By putting a Varnish instance in front of ElasticSearch, the API is protected from malicious requests, and the search results can be cached.

This repository is specifically built to simplify and protect the search results of [https://docs.varnish-software.com](https://docs.varnish-software.com).

The complexity of ElasticSearch's DSL are abstracted, and a simple search key is ingested by Varnish, which it parses into `search.json`.

The `default.vcl` contains the VCL logic that is required to make this happen.

And finally, you can spin up both instances in Docker through the `docker-compose.yml` file.

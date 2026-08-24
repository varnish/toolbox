FROM varnish/varnish-enterprise

USER root

# varnish-go's log/adm/stat packages are cgo bindings against libvarnishapi,
# hence building on top of varnish-enterprise itself (with -dev headers)
# rather than a generic golang image.
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		varnish-plus-deviceatlas3 varnish-plus-dev pkg-config curl ca-certificates \
	&& rm -rf /var/lib/apt/lists/* \
	&& curl -fsSL https://go.dev/dl/go1.27.0.linux-amd64.tar.gz | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"

WORKDIR /src
COPY . .
RUN go mod download && go build -o /usr/local/bin/deviceatlas3-tester .

COPY default.vcl /etc/varnish/default.vcl

USER varnish

ENTRYPOINT ["/usr/local/bin/deviceatlas3-tester"]

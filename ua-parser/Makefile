all: uap2vcl uap2vcl-test uap-enterprise.vcl uap-oss.vcl

.PHONY: clean check check-oss check-enterprise

clean:
	rm -rf uap2vcl uap2vcl-test test_*.yaml regexes.yaml uap-oss.vcl uap-enterprise.vcl

uap2vcl: cmd/uap2vcl/uap2vcl.go
	go build ./cmd/$@/

uap2vcl-test: cmd/uap2vcl-test/uap2vcl-test.go
	go build ./cmd/$@/

regexes.yaml:
	curl -sLO https://raw.githubusercontent.com/ua-parser/uap-core/master/$@

uap-enterprise.vcl: regexes.yaml uap2vcl
	./uap2vcl --regex regexes.yaml            > $@

uap-oss.vcl: regexes.yaml uap2vcl
	./uap2vcl --regex regexes.yaml --pure-vcl > $@

check-enterprise: uap2vcl-test uap-enterprise.vcl test_ua.yaml test_os.yaml test_device.yaml
	varnishtest uap-enterprise.vtc

check-oss: uap2vcl-test uap-oss.vcl test_ua.yaml test_os.yaml test_device.yaml
	varnishtest uap-oss.vtc -t 120

test_ua.yaml test_os.yaml test_device.yaml:
	curl -sLO https://raw.githubusercontent.com/ua-parser/uap-core/master/tests/$@

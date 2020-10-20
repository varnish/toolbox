all: build

build: *.go
	go build -o prometheus-vstat

check: build
	go test -v

clean:
	rm -f prometheus-vstat *.log

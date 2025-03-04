package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"slices"

	"gopkg.in/yaml.v3"
)

type Url struct {
	Uri     string `yaml:"url"`
	Env     string `yaml:"env"`
	Returns []int  `yaml:"returns"`
	Host    string
	Headers map[string]string `yaml:"headers"`
}

type Edge struct {
	Name   string        `yaml:"name"`
	IPv4   net.IP        `yaml:"ipv4,omitempty"`
	IPv6   net.IP        `yaml:"ipv6,omitempty"`
	Errors []ErrorReport `yaml:"errors"`
}

type ErrorReport struct {
	Reproducer string
	Error      string
}

func getEdges(path string) []string {
	var edges []string
	yamlFile, err := os.ReadFile(path)
	if err != nil {
		log.Fatalf("yamlFile.Get err   #%v ", err)
	}
	err = yaml.Unmarshal(yamlFile, &edges)
	if err != nil {
		log.Fatalf("Unmarshal: %v", err)
	}

	return edges

}

func getUrls(path string) []Url {
	var urls []Url
	yamlFile, err := os.ReadFile(path)
	if err != nil {
		log.Fatalf("yamlFile.Get err   #%v ", err)
	}
	err = yaml.Unmarshal(yamlFile, &urls)
	if err != nil {
		log.Fatalf("Unmarshal: %v", err)
	}

	for i := range urls {
		parsedURL, err := url.Parse(urls[i].Uri)
		if err != nil {
			panic(err)
		}
		urls[i].Host = parsedURL.Host
	}
	return urls
}

func testEdgeDNS(edgeString string) (Edge, ErrorReport) {
	edge := Edge{Name: edgeString}
	ips, err := net.LookupIP(edgeString)
	if err != nil {
		return edge,
			ErrorReport{
				Reproducer: fmt.Sprintf("dig %s A %s AAAA +short", edgeString, edgeString),
				Error:      err.Error(),
			}
	}

	for _, ip := range ips {
		if ip.To4() != nil {
			edge.IPv4 = ip
		} else {
			edge.IPv6 = ip
		}
	}
	reproducer := ""
	errString := ""
	if edge.IPv4 == nil {
		errString = "missing IPv4"
		reproducer = fmt.Sprintf("dig %s AAAA", edgeString)
		reproducer = ("dig %s A")
	}
	if edge.IPv6 == nil {
		errString = "missing IPv6"
		reproducer = fmt.Sprintf("dig %s AAAA", edgeString)
	}
	return edge, ErrorReport{
		Reproducer: reproducer,
		Error:      errString,
	}
}

func testUrlWithIp(url Url, ip net.IP) ErrorReport {
	ipString := ip.String()
	if ip.To4() == nil {
		ipString = "[" + ipString + "]"
	}
	reproducer := fmt.Sprintf(`curl -o /dev/null -qsv "%s" --connect-to "%s:443:%s:443"`, url.Uri, url.Host, ipString)

	dialer := &net.Dialer{}
	tr := &http.Transport{DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
		return dialer.DialContext(ctx, network, ipString+":443")
	}}
	client := &http.Client{Transport: tr}

	req, err := http.NewRequest("GET", url.Uri, nil)
	if err != nil {
		return ErrorReport{
			Reproducer: reproducer,
			Error:      err.Error(),
		}
	}

	for key, value := range url.Headers {
		req.Header.Add(key, value)
		reproducer += fmt.Sprintf(` -H "%s: %s"`, key, value)
	}

	resp, err := client.Do(req)
	if err != nil {
		return ErrorReport{
			Reproducer: reproducer,
			Error:      err.Error(),
		}
	}
	defer resp.Body.Close()
	_, err = io.ReadAll(resp.Body)
	if err != nil {
		return ErrorReport{
			Reproducer: reproducer,
			Error:      err.Error(),
		}
	}

	if !slices.Contains(url.Returns, resp.StatusCode) {
		err = fmt.Errorf("status code %d not in %v", resp.StatusCode, url.Returns)
		return ErrorReport{
			Reproducer: reproducer,
			Error:      err.Error(),
		}
	}
	return ErrorReport{}
}

func testEdge(edgeString string, urls []Url) Edge {
	edge, rerr := testEdgeDNS(edgeString)
	if rerr.Error != "" {
		edge.Errors = append(edge.Errors, rerr)
	}

	testN := 0
	chTestUrl := make(chan ErrorReport, len(urls))
	for _, url := range urls {
		for _, ip := range []net.IP{edge.IPv4, edge.IPv6} {
			if ip == nil {
				continue
			}

			testN += 1
			go func() {
				chTestUrl <- testUrlWithIp(url, ip)
			}()
		}
	}

	for range testN {
		rerr := <-chTestUrl
		if rerr.Error != "" {
			edge.Errors = append(edge.Errors, rerr)
		}
	}

	return edge
}

func main() {
	edges := getEdges(os.Args[1])
	urls := getUrls(os.Args[2])

	ch := make(chan Edge, len(edges))
	edgeReport := []Edge{}
	for _, edgeString := range edges {
		go func() {
			ch <- testEdge(edgeString, urls)
		}()
	}
	for range edges {
		edge := <-ch
		edgeReport = append(edgeReport, edge)
	}

	all_good := true
	for _, er := range edgeReport {
		if len(er.Errors) > 0 {
			all_good = false
		}
	}
	if all_good {
		fmt.Printf("all clear\n")
		os.Exit(0)
	} else {
		report, err := yaml.Marshal(edgeReport)
		if err != nil {
			panic(err)
		} else {
			fmt.Printf("%s\n", string(report))
		}

		os.Exit(1)
	}
}

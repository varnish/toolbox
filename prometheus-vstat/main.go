package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"os/exec"
	"regexp"
	"sort"
	"strings"
)

type PType struct {
	Name     string
	Help     string
	Type     string
	Counters []PCounter
}

type PCounter struct {
	Labels string
	Value  uint64
}

type VCounter struct {
	Description string `json:"description"`
	Flag        string `json:"flag"`
	Format      string `json:"format"`
	Value       uint64 `json:"value"`
}

func check(e error, format string, args ...interface{}) { // Check the error for all the functions that return one
	if e != nil {
		fmt.Printf("error: "+format, args...)
		fmt.Printf(" (%s)\n", e)
		os.Exit(1)
	}
}

func main() {
	var reader io.Reader
	var varnishstatPath, inputSource string

	flag.StringVar(&inputSource, "input", "", "Empty use varnishstat as source, \"-\" use stdin, anything else assumes it's a readable file")
	flag.StringVar(&varnishstatPath, "bin-path", "/usr/bin/varnishstat", "Supply the varnishstat path.")
	flag.Parse()

	counters := make(map[string](json.RawMessage))

	if inputSource == "-" {
		reader = os.Stdin
	} else if inputSource == "" {
		out, err := exec.Command(varnishstatPath, "-j").Output()
		check(err, "Could not run the supplied varnishstat file \"%v\".", varnishstatPath)
		reader = bytes.NewReader(out)

	} else {
		content, err := ioutil.ReadFile(inputSource)
		check(err, "Could not read the input file \"%v\".", inputSource)
		reader = bytes.NewReader(content)
	}
	err := json.NewDecoder(reader).Decode(&counters)
	check(err, "Could not decode json data.")
	fmt.Print(counter2prometheusWrapper(counters))
}

func counter2prometheusWrapper(counters map[string](json.RawMessage)) (returnString string) {
	var err error
	var pts []PType

	for k, o := range counters {
		if k == "timestamp" {
			continue
		}

		var c VCounter
		err = json.Unmarshal(o, &c)
		check(err, "Could not unmarshal json data.")
		pt := counter2prometheus(k, c)
		found := false
		for i, _ := range pts {
			if pts[i].Name != pt.Name {
				continue
			}
			pts[i].Counters = append(pts[i].Counters, pt.Counters[0])
			found = true
			break
		}
		if !found {
			pts = append(pts, pt)
		}
	}

	sort.SliceStable(pts, func(i, j int) bool { return pts[i].Name < pts[j].Name })

	var returnStr string
	for _, pt := range pts {
		sort.SliceStable(pt.Counters, func(i, j int) bool { return pt.Counters[i].Labels < pt.Counters[j].Labels })
		returnStr += fmt.Sprintf("# HELP %v %v\n# TYPE %v %v\n", pt.Name, pt.Help, pt.Name, pt.Type)
		for _, pc := range pt.Counters {
			returnStr += fmt.Sprintf("%v%v %d\n", pt.Name, pc.Labels, pc.Value)
		}
	}

	return (returnStr)
}

func flag2type(f string) string {
	var t string

	switch f {
	case "c":
		t = "counter"
	case "g", "b":
		t = "gauge"
	default:
		t = "untyped" // This also covers the "b" for binary case.
	}
	return t
}

// https://prometheus.io/docs/concepts/data_model defines the valid regex syntax as "[a-zA-Z_:][a-zA-Z0-9_:]*".
// Note colons, ':', are removed below from the regex as the input does not contain user defined recording rules.
func counter2prometheus(k string, c VCounter) PType {
	cleanRe := regexp.MustCompile(`[^a-zA-Z0-9_]+`) // Replace non syntax allowed characters with underscores.

	splits := strings.SplitN(k, ".", 2)
	section := ""
	name := ""
	labels := ""
	if len(splits) == 1 {
		section = "unknown"
		name = splits[0]
	} else {
		section = strings.ToLower(splits[0])
		name = splits[1]
	}

	switch section {
	case "kvstore":
		sub := strings.SplitN(name, ".", 3)
		name = "counter"
		labels = fmt.Sprintf(`{vcl="%s",space="%s",name="%s"}`, sub[1], sub[0], sub[2])
	case "lck":
		section = "lock"
		sub := strings.SplitN(name, ".", 2)
		obj := sub[0]
		t := sub[1]
		switch t {
		case "creat":
			t = "created"
		case "destroy":
			t = "destroyed"
		case "locks":
			t = "operations"
		}
		name = obj
		labels = fmt.Sprintf("{target=\"%s\"}", t)
	case "main":
		switch name {
		case "s_sess":
			name = "sessions_total"
		case "s_fetch":
			name = "fetch_total"
		default:
			if strings.HasPrefix(name, "sess_") || strings.HasPrefix(name, "fetch_") {
				split := strings.SplitN(name, "_", 2)
				subsection := split[0]
				if subsection == "sess_" {
					subsection = "session"
				}
				name = subsection
				labels = fmt.Sprintf("{type=\"%s\"}", split[1])
			}
		}
	case "mse", "mse_book", "mse_store", "sma", "smf":
		extra := ""
		switch section {
		case "mse":
			extra = `,type="env"`
		case "mse_book":
			section = "mse"
			extra = `,type="book"`
		case "mse_store":
			section = "mse"
			extra = `,type="store"`
		}
		split := strings.SplitN(name, ".", 2)
		name = split[1]
		labels = fmt.Sprintf("{%s=\"%s\"%s}", "id", split[0], extra)

	case "vbe":
		section = "backend"
		// looking for "{vcl}.goto.{id}.({ip}).({url}).(ttl:{ttl}).{domain}"
		// e.g. default.goto.00000000.(8.8.8.8).(http://example.com:80).(ttl:10.000000).bereq_bodybytes
		gotoRe := regexp.MustCompile(`^(.*).goto.([0-9]+)\.\((.+)\)\.\((.*)\)\.\(ttl:([0-9]+\.[0-9]+)\)\.(.+)`)
		matches := gotoRe.FindStringSubmatch(name)
		if matches != nil {
			name = matches[6]
			labels = fmt.Sprintf(`{backend="goto",vcl="%s",domain="%s",ip="%s",ttl="%s",id="%s"}`, matches[1], matches[4], matches[3], matches[5], matches[2])
		} else {
			split := strings.SplitN(name, ".", 3)
			name = cleanRe.ReplaceAllLiteralString(split[2], "_")
			labels = fmt.Sprintf("{backend=\"%s\",vcl=\"%s\"}", split[1], split[0])
		}
	case "mempool":
		split := strings.SplitN(name, ".", 2)
		name = split[1]
		labels = fmt.Sprintf("{id=\"%s\"}", split[0])
	default:
		name = cleanRe.ReplaceAllLiteralString(name, "_")
	}

	pt := PType{
		Name: fmt.Sprintf("varnish_%s_%s", section, name),
		Help: c.Description,
		Type: flag2type(c.Flag),
		Counters: []PCounter{
			PCounter{
				Labels: labels,
				Value:  c.Value,
			},
		},
	}

	return pt
}

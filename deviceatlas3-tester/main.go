package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"sort"
	"sync"

	"github.com/varnish/varnish-go/vtest"
	"gopkg.in/yaml.v3"
)

const vclPath = "/etc/varnish/default.vcl"

type RequestSpec struct {
	Headers map[string]string `yaml:"headers"`
}

type TestCase struct {
	Name       string            `yaml:"name"`
	Request    RequestSpec       `yaml:"request"`
	Expected   map[string]string `yaml:"expected"`
	FullLookup bool              `yaml:"full_lookup"`
}

// check is one property lookup within a TestCase: TestCase.Expected fans out
// into one check (and one request) per property.
type check struct {
	caseName   string
	request    RequestSpec
	property   string
	expected   string
	fullLookup bool
}

type result struct {
	check
	actual string
	err    error
}

func main() {
	dbPath := flag.String("db", "", "path to the DeviceAtlas database file")
	testsPath := flag.String("tests", "", "path to the YAML test suite file")
	parallelism := flag.Int("parallelism", 128, "number of tests to run concurrently")
	flag.Parse()

	if *dbPath == "" || *testsPath == "" {
		flag.Usage()
		os.Exit(2)
	}

	cases, err := loadTestCases(*testsPath)
	if err != nil {
		log.Fatalf("loading test cases: %v", err)
	}
	checks := expand(cases)

	v, err := vtest.New().
		VclFile(vclPath).
		SetEnv("DEVICEATLAS_DB_PATH", *dbPath).
		// deviceatlas3 requires a stack of at least 256KB, see
		// https://docs.varnish-software.com/varnish-enterprise/vmods/deviceatlas3/
		Parameter("thread_pool_stack", "256k").
		Start()
	if err != nil {
		log.Fatalf("starting varnish: %v", err)
	}
	defer v.Stop()

	results := runChecks(v.URL, checks, *parallelism)
	failed := report(results)

	if hasRequestError(results) {
		fmt.Fprintln(os.Stderr, "\n--- varnishd output ---")
		for _, line := range v.SysLogs() {
			fmt.Fprintln(os.Stderr, line)
		}
	}

	if failed > 0 {
		os.Exit(1)
	}
}

func hasRequestError(results []result) bool {
	for _, r := range results {
		if r.err != nil {
			return true
		}
	}
	return false
}

func loadTestCases(path string) ([]TestCase, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var cases []TestCase
	if err := yaml.Unmarshal(data, &cases); err != nil {
		return nil, err
	}
	return cases, nil
}

// expand fans each TestCase out into one check per entry in its Expected map,
// since each property lookup needs its own request (deviceatlas-property is
// a single header value).
func expand(cases []TestCase) []check {
	var checks []check
	for _, tc := range cases {
		for property, expected := range tc.Expected {
			checks = append(checks, check{
				caseName:   tc.Name,
				request:    tc.Request,
				property:   property,
				expected:   expected,
				fullLookup: tc.FullLookup,
			})
		}
	}
	return checks
}

func runChecks(baseURL string, checks []check, parallelism int) []result {
	in := make(chan check)
	out := make(chan result)

	var wg sync.WaitGroup
	for i := 0; i < parallelism; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for c := range in {
				out <- runCheck(baseURL, c)
			}
		}()
	}

	go func() {
		for _, c := range checks {
			in <- c
		}
		close(in)
	}()

	go func() {
		wg.Wait()
		close(out)
	}()

	results := make([]result, 0, len(checks))
	for r := range out {
		results = append(results, r)
	}
	return results
}

func runCheck(baseURL string, c check) result {
	req, err := http.NewRequest(http.MethodGet, baseURL+"/", nil)
	if err != nil {
		return result{check: c, err: err}
	}
	for k, v := range c.request.Headers {
		req.Header.Set(k, v)
	}
	req.Header.Set("deviceatlas-property", c.property)
	req.Header.Set("deviceatlas-full-lookup", fmt.Sprintf("%t", c.fullLookup))

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return result{check: c, err: err}
	}
	defer resp.Body.Close()
	io.Copy(io.Discard, resp.Body)

	return result{check: c, actual: resp.Header.Get("deviceatlas-results")}
}

func report(results []result) int {
	sort.Slice(results, func(i, j int) bool {
		if results[i].caseName != results[j].caseName {
			return results[i].caseName < results[j].caseName
		}
		return results[i].property < results[j].property
	})

	failed := 0
	for _, r := range results {
		label := fmt.Sprintf("%s[%s]", r.caseName, r.property)
		switch {
		case r.err != nil:
			failed++
			fmt.Printf("FAIL %s: request error: %v\n", label, r.err)
		case r.actual != r.expected:
			failed++
			fmt.Printf("FAIL %s: expected %q, got %q\n", label, r.expected, r.actual)
		default:
			fmt.Printf("PASS %s\n", label)
		}
	}
	fmt.Printf("\n%d/%d passed\n", len(results)-failed, len(results))
	return failed
}

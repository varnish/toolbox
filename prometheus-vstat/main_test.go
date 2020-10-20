package main

import (
	"encoding/json"
	"testing"
	//"fmt"
)

func Test_counter2prometheusWrapper(t *testing.T) {
	type CounterTestData struct {
		testCaseDesc  string
		jsonRawMsg    map[string]json.RawMessage
		correctOutput string
	}

	ctds := []CounterTestData{

		CounterTestData{"Test of one properly formatted output string.",
			map[string]json.RawMessage{"MAIN.shm_records": json.RawMessage(`{"description":"SHM records","flag":"c","format":"i","value":29382}`)},
			`# HELP varnish_main_shm_records SHM records
# TYPE varnish_main_shm_records counter
varnish_main_shm_records 29382
`},

		CounterTestData{"Test of multiple properly formatted output strings.",
			map[string]json.RawMessage{
				"SMA.s0.c_req":         json.RawMessage(`{"description":"Allocator requests","flag":"c","format":"i","value":0}`),
				"SMA.Transient.c_req":  json.RawMessage(`{"description":"Allocator requests","flag":"c","format":"i","value":0}`),
				"MAIN.shm_records":     json.RawMessage(`{"description":"SHM records","flag":"c","format":"i","value":29382}`),
				"MAIN.shm_writes":      json.RawMessage(`{"description":"SHM writes","flag":"c","format":"i","value":29382}`),
				"MEMPOOL.busyobj.live": json.RawMessage(`{"description":"In use","flag":"g","format":"i","value":0}`),
				"MEMPOOL.req0.live":    json.RawMessage(`{"description":"In use","flag":"g","format":"i","value":0}`),
				"MEMPOOL.sess0.live":   json.RawMessage(`{"description":"In use","flag":"g","format":"i","value":0}`),
				"MEMPOOL.req1.live":    json.RawMessage(`{"description":"In use","flag":"g","format":"i","value":0}`),
				"MEMPOOL.sess1.live":   json.RawMessage(`{"description":"In use","flag":"g","format":"i","value":0}`),
			},
			`# HELP varnish_main_shm_records SHM records
# TYPE varnish_main_shm_records counter
varnish_main_shm_records 29382
# HELP varnish_main_shm_writes SHM writes
# TYPE varnish_main_shm_writes counter
varnish_main_shm_writes 29382
# HELP varnish_mempool_live In use
# TYPE varnish_mempool_live gauge
varnish_mempool_live{id="busyobj"} 0
varnish_mempool_live{id="req0"} 0
varnish_mempool_live{id="req1"} 0
varnish_mempool_live{id="sess0"} 0
varnish_mempool_live{id="sess1"} 0
# HELP varnish_sma_c_req Allocator requests
# TYPE varnish_sma_c_req counter
varnish_sma_c_req{id="Transient"} 0
varnish_sma_c_req{id="s0"} 0
`},
		CounterTestData{"Testing valid flag value g which needs to translate to \"gauge\" in the TYPE line.",
			map[string]json.RawMessage{"MGT.uptime": json.RawMessage(`{"description":"Management process uptime","flag":"b","format":"d","value":17067}`)},
			`# HELP varnish_mgt_uptime Management process uptime
# TYPE varnish_mgt_uptime gauge
varnish_mgt_uptime 17067
`},

		CounterTestData{"Testing valid flag value b which needs to translate to \"gauge\" in the TYPE line.",
			map[string]json.RawMessage{"MGT.uptime": json.RawMessage(`{"description":"Management process uptime","flag":"b","format":"d","value":17067}`)},
			`# HELP varnish_mgt_uptime Management process uptime
# TYPE varnish_mgt_uptime gauge
varnish_mgt_uptime 17067
`},

		CounterTestData{"Testing invalid flag value x which needs to translate to \"untyped\" in the TYPE line.",
			map[string]json.RawMessage{"MGT.uptime": json.RawMessage(`{"description":"Management process uptime","flag":"x","format":"d","value":17067}`)},
			`# HELP varnish_mgt_uptime Management process uptime
# TYPE varnish_mgt_uptime untyped
varnish_mgt_uptime 17067
`},

		CounterTestData{"Testing invalid multiple letter flag value yy which needs to translate to \"untyped\" in the TYPE line.",
			map[string]json.RawMessage{"MGT.uptime": json.RawMessage(`{"description":"Management process uptime","flag":"yy","format":"d","value":17067}`)},
			`# HELP varnish_mgt_uptime Management process uptime
# TYPE varnish_mgt_uptime untyped
varnish_mgt_uptime 17067
`},

		CounterTestData{"Largest uint64",
			map[string]json.RawMessage{"MGT.uptime": json.RawMessage(`{"description":"Management process uptime","flag":"c","format":"d","value":18446744073709551615}`)},
			`# HELP varnish_mgt_uptime Management process uptime
# TYPE varnish_mgt_uptime counter
varnish_mgt_uptime 18446744073709551615
`},

		CounterTestData{"Test for missing string values and zero number values.",
			map[string]json.RawMessage{"MGT.uptime": json.RawMessage(`{"description":"Management process uptime","flag":"","format":"","value":0}`)},
			`# HELP varnish_mgt_uptime Management process uptime
# TYPE varnish_mgt_uptime untyped
varnish_mgt_uptime 0
`},

	} // Closing brace for CounterTestData array

	for _, ctd := range ctds { // ctds is an array of CounterTestData.
		if ctd.correctOutput != counter2prometheusWrapper(ctd.jsonRawMsg) {
			t.Errorf("Error: correct output != CounterTestData test case\n\n=Test case description=\n%s\n\n=correctOutput=\n%s\n=test result=\n%+v\n\n",
				ctd.testCaseDesc, ctd.correctOutput, counter2prometheusWrapper(ctd.jsonRawMsg))
		}
	}
}

func Test_counter2prometheus(t *testing.T) {
	type tc struct {
		in string
		out string
	}

	tcs := []tc{
		{"foo", "varnish_unknown_foo"},
		{"foo.Bar.baZ", "varnish_foo_Bar_baZ"},
		{"MGT.uptime", "varnish_mgt_uptime"},
		{"VBE.default.goto.00000000.(8.8.8.8).(http://example.com:80).(ttl:10.000000).bereq_bodybytes", `varnish_backend_bereq_bodybytes{backend="goto",vcl="default",domain="http://example.com:80",ip="8.8.8.8",ttl="10.000000",id="00000000"}`},
		{"KVSTORE.vha6_stats.boot.broadcast_candidates", `varnish_kvstore_counter{vcl="boot",space="vha6_stats",name="broadcast_candidates"}`},
		{"KVSTORE.vha6_stats.boot.broadcast_candidates", `varnish_kvstore_counter{vcl="boot",space="vha6_stats",name="broadcast_candidates"}`},
		{"SMA.Transient.c_ykey_purged", `varnish_sma_c_ykey_purged{id="Transient"}`},
		{"MSE_BOOK.NamedBook.c_insert_timeout", `varnish_mse_c_insert_timeout{id="NamedBook",type="book"}`},
		{"MSE_STORE.NamedStore.c_insert_timeout", `varnish_mse_c_insert_timeout{id="NamedStore",type="store"}`},
		{"MSE.mse.n_lru_nuked", `varnish_mse_n_lru_nuked{id="mse",type="env"}`},
	}
	for _, tc := range tcs {
	counter := counter2prometheus(tc.in, VCounter{})
		fullName := counter.Name + counter.Counters[0].Labels
		if tc.out != fullName {
			t.Errorf("for %s:\n\texpected %s\n\tgot      %s", tc.in, tc.out, fullName)
		}
	}
}

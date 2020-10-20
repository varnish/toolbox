/* prometheus-vstat vcl
 *
 * This file allows you to expose the prometheus metrics created by
 * prometheus-vstat directly in varnish.
 *
 * to use:
 * - make sure varnishd is started with "-p allow_exec=true"
 * - include pvstat.vcl in your vcl
 * - in vcl_init, optionally call pvstat_opts.set("variable", "value") to set:
 *   - binary_path: directory containing prometheus-vstat [/etc/varnish]
 *   - binary_name: name of the binary, if you changed it [prometheus-vstat]
 *   - metrics_path: URL used to retrieve the metrics [/metrics]
 * - in vcl_init, call pvstat_init
 *
 * For example:
 *
 *   vcl 4.0;
 *
 *   include "/path/to/pvstat.vcl";
 *
 *   sub vcl_init {
 *     pvstat_opts.set("binary_path", "/opt/bin");
 *     call pvstat_init;
 *   }
 *   ...
 *
 * Load your vcl and you should be able to fetch metrics from varnish with
 *
 *   curl VARNISH_ADDRESS/metrics
 *
 * If you have any question, please contact support@varnish-software.com
 */

vcl 4.0;

import file;
import kvstore;

sub vcl_init {
	# create a store for our variables and set sensible defaults
	new pvstat_opts = kvstore.init();
	pvstat_opts.set("binary_path", "/etc/varnish");
	pvstat_opts.set("binary_name", "prometheus-vstat");
	pvstat_opts.set("metrics_path", "/metrics");
}

sub pvstat_init {
	new fs = file.init(pvstat_opts.get("binary_path"));
	fs.allow(pvstat_opts.get("binary_name"), mode = "x");
}

sub vcl_recv {
	if (req.url == pvstat_opts.get("metrics_path")) {
		return (synth(200));
	}
}

sub vcl_synth {
	if (req.url == pvstat_opts.get("metrics_path")) {
		synthetic(fs.exec(pvstat_opts.get("binary_path") + "/" + pvstat_opts.get("binary_name")));
		if (fs.exec_get_errorcode() != 0) {
			set resp.status = 503;
		}
		return (deliver);
	}
}

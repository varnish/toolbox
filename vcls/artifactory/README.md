Find the full documentation on the [Varnish Dev Portal](https://www.varnish-software.com/developers/tutorials/caching-authenticated-artifactory-requests-varnish-enterprise/).

[Artifactory](https://jfrog.com/artifactory) is a package repository covering an impressive range of platforms (`docker`, `npm`, `maven`, etc.) and [artifactory.vcl](artifactory.vcl) offers to complement its intelligence and versatility with `varnish`'s speed.

The code is minimal but it ensures that authentication calls are cached and respected thanks to [vmod-http](https://docs.varnish-software.com/varnish-enterprise/vmods/http/). The file is a template and can be combine will all the other `varnish` features, such as [disk caching](https://docs.varnish-software.com/varnish-enterprise/features/mse/) and [sharding](https://docs.varnish-software.com/varnish-enterprise/vmods/udo/).

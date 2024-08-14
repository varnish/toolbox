// this is a slightly modified version of github.com/open-telemetry/opentelemetry-collector-contrib/examples/demo/server

// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Sample contains a simple http server that exports to the OpenTelemetry agent.

package main

import (
	"context"
	"log"
	"math/rand"
	"os"
	"net/http"
	"semconv"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/baggage"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/propagation"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"
)

var rng = rand.New(rand.NewSource(time.Now().UnixNano()))

// Initializes an OTLP exporter, and configures the corresponding trace and
// metric providers.
func initProvider() func() {
	ctx := context.Background()

	res, err := resource.New(ctx,
		resource.WithFromEnv(),
		resource.WithProcess(),
		resource.WithTelemetrySDK(),
		resource.WithHost(),
		resource.WithAttributes(
			// the service name used to display traces in backends
			semconv.ServiceNameKey.String(os.Args[1]),
		),
	)
	handleErr(err, "failed to create resource")

	metricExp, err := otlpmetrichttp.New(
		ctx,
		otlpmetrichttp.WithInsecure(),
	)
	handleErr(err, "Failed to create the collector metric exporter")

	meterProvider := sdkmetric.NewMeterProvider(
		sdkmetric.WithResource(res),
		sdkmetric.WithReader(
			sdkmetric.NewPeriodicReader(
				metricExp,
				sdkmetric.WithInterval(2*time.Second),
			),
		),
	)
	otel.SetMeterProvider(meterProvider)

	traceClient := otlptracehttp.NewClient(
		otlptracehttp.WithInsecure(),
	)
	traceExp, err := otlptrace.New(ctx, traceClient)
	handleErr(err, "Failed to create the collector trace exporter")

	bsp := sdktrace.NewBatchSpanProcessor(traceExp)
	tracerProvider := sdktrace.NewTracerProvider(
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
		sdktrace.WithResource(res),
		sdktrace.WithSpanProcessor(bsp),
	)

	// set global propagator to tracecontext (the default is no-op).
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(propagation.TraceContext{}, propagation.Baggage{}))
	otel.SetTracerProvider(tracerProvider)

	return func() {
		cxt, cancel := context.WithTimeout(ctx, time.Second)
		defer cancel()
		if err := traceExp.Shutdown(cxt); err != nil {
			otel.Handle(err)
		}
		// pushes any last exports to the receiver
		if err := meterProvider.Shutdown(cxt); err != nil {
			otel.Handle(err)
		}
	}
}

func handleErr(err error, message string) {
	if err != nil {
		log.Fatalf("%s: %v", message, err)
	}
}

func main() {
	shutdown := initProvider()
	defer shutdown()

	meter := otel.Meter("demo-server-meter")
	serverAttribute := attribute.String("server-attribute", "foo")
	commonLabels := []attribute.KeyValue{serverAttribute}
	requestCount, _ := meter.Int64Counter(
		"demo_server/request_counts",
		metric.WithDescription("The number of requests received"),
	)

	// create a handler wrapped in OpenTelemetry instrumentation
	handler := http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		h := map[string]string{
			"/esi_top": `<esi:include src="/esi_sub1"/><esi:include src="/esi_sub2"/>`,
			"/esi_sub1": `Hello, `,
			"/esi_sub2": `World`,
		}

		if req.URL.Path == "/esi_sub2" && rand.Int31n(20) == 0 {
			time.Sleep(955 * time.Millisecond)
		}
		ctx := req.Context()
		requestCount.Add(ctx, 1, metric.WithAttributes(commonLabels...))
		span := trace.SpanFromContext(ctx)
		bag := baggage.FromContext(ctx)

		var baggageAttributes []attribute.KeyValue
		baggageAttributes = append(baggageAttributes, serverAttribute)
		for _, member := range bag.Members() {
			baggageAttributes = append(baggageAttributes, attribute.String("baggage key:"+member.Key(), member.Value()))
		}
		span.SetAttributes(baggageAttributes...)

		if _, err := w.Write([]byte(h[req.URL.Path])); err != nil {
			http.Error(w, "write operation failed.", http.StatusInternalServerError)
			return
		}

	})

	mux := http.NewServeMux()
	mux.Handle("/", otelhttp.NewHandler(http.FileServer(http.Dir(".")), "files"))
	mux.Handle("/esi_top", otelhttp.NewHandler(handler, "esi_top"))
	mux.Handle("/esi_sub1", otelhttp.NewHandler(handler, "esi_sub"))
	mux.Handle("/esi_sub2", otelhttp.NewHandler(handler, "esi_sub"))
	server := &http.Server{
		Addr:              ":80",
		Handler:           mux,
		ReadHeaderTimeout: 20 * time.Second,
	}
	if err := server.ListenAndServe(); err != http.ErrServerClosed {
		handleErr(err, "server failed to serve")
	}
}

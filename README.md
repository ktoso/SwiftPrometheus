[![Build Status](https://travis-ci.com/MrLotU/SwiftPrometheus.svg?branch=master)](https://travis-ci.com/MrLotU/SwiftPrometheus) [![Swift 5.0](https://img.shields.io/badge/swift-5.0-orange.svg?style=flat)](http://swift.org)

# SwiftPrometheus, Prometheus client for Swift

A prometheus client for Swift supporting counters, gauges, histograms, summaries and info.

# Usage

For examples, see [main.swift](./Sources/PrometheusExample/main.swift)

## Counter

Counters go up, and reset when the process restarts.

```swift
let prom = PrometheusClient()

let counter = prom.createCounter(forType: Int.self, named: "my_counter")
counter.inc() // Increment by 1
counter.inc(12) // Increment by given value 
```

## Gauge

Gauges can go up and down

```swift
let prom = PrometheusClient()

let gauge = prom.createGauge(forType: Int.self, named: "my_gauge")
gauge.inc() // Increment by 1
gauge.dec(19) // Decrement by given value
gauge.set(12) // Set to a given value
```

## Histogram

Histograms track the size and number of events in buckets. This allows for aggregatable calculation of quantiles.

```swift
let prom = PrometheusClient()

let histogram = prom.createHistogram(forType: Double.self, named: "my_histogram")
histogram.observe(4.7) // Observe the given value
```

## Summary

Summaries track the size and number of events

```swift
let prom = PrometheusClient()

let summary = prom.createSummary(forType: Double.self, named: "my_summary")
summary.observe(4.7) // Observe the given value
```

## Info

Info tracks key-value information, usually about a whole target.

```swift
struct MyInfoStruct: MetricLabels {
   let value: String
   
   init() {
       self.value = "abc"
   }
   
   init(_ v: String) {
       self.value = v
   }
}

let prom = PrometheusClient()

let info = prom.createInfo(named: "my_info", helpText: "Just some info", labelType: MyInfoStruct.self)

info.info(MyInfoStruct("def"))
```

## Labels
All metric types support adding labels, allowing for grouping of related metrics.

Example with a counter:
```swift
struct RouteLabels: MetricLabels {
   var route: String = "*"
}

let prom = PrometheusClient()

let counter = prom.createCounter(forType: Int.self, named: "my_counter", helpText: "Just a counter", withLabelType: RouteLabels.self)

counter.inc(12, .init(route: "/"))
```

# Exporting

To keep SwiftPrometheus as clean and lightweight as possible, there is no way of exporting metrics directly to Prometheus. Instead, retrieve a formatted string that Prometheus can use, so you can integrate it in your own Serverside Swift application

This could look something like this:
```swift
router.get("/metrics") { request -> Future<String> in
    let promise = req.eventLoop.newPromise(String.self)
    prom.getMetrics {
        promise.succeed(result: $0)
    }
    return promise.futureResult
}
```
Here, I used [Vapor](https://github.com/vapor/vapor) syntax, but this will work with any web framework, since it's just returning a plain String.

# Contributing

All contributions are most welcome!

If you think of some cool new feature that should be included, please [create an issue](https://github.com/MrLotU/SwiftPrometheus/issues/new/choose). Or, if you want to implement it yourself, [fork this repo](https://github.com/MrLotU/SwiftPrometheus/fork) and submit a PR!

If you find a bug or have issues, please [create an issue](https://github.com/MrLotU/SwiftPrometheus/issues/new/choose) explaining your problems. Please include as much information as possible, so it's easier for me to reproduce (Framework, OS, Swift version, terminal output, etc.)

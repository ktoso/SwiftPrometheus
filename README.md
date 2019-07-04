[![CircleCI](https://circleci.com/gh/MrLotU/SwiftPrometheus.svg?style=svg)](https://circleci.com/gh/MrLotU/SwiftPrometheus)[![Swift 5.0](https://img.shields.io/badge/swift-5.0-orange.svg?style=flat)](http://swift.org)

# SwiftPrometheus, Prometheus client for Swift

A prometheus client for Swift supporting counters, gauges, histograms, summaries and info.

# Usage

For examples, see [main.swift](./Sources/PrometheusExample/main.swift)

First, we have to create an instance of our `PrometheusClient`:
```swift
import Prometheus
let myProm = PrometheusClient()
```

## Usage with Swift-Metrics
_For more details about swift-metrics, check the GitHub repo [here](https://github.com/apple/swift-metrics)_

To use SwiftPrometheus with swift-metrics, all the setup required is this:
```swift
import PrometheusMetrics // Auto imports Prometheus too, but adds the swift-metrics compatibility
let myProm = PrometheusClient()
MetricsSystem.bootstrap(myProm)
```

To use prometheus specific features in a later stage of your program, or to get your metrics out of the system, there is a convenience method added to `MetricsSystem`:
```swift
// This is the same instance was used in `.bootstrap()` earlier.
let promInstance = try MetricsSystem.prometheus()
```
You can than use the same APIs that are layed out in the rest of this README

## Counter

Counters go up, and reset when the process restarts.

```swift
let counter = myProm.createCounter(forType: Int.self, named: "my_counter")
counter.inc() // Increment by 1
counter.inc(12) // Increment by given value 
```

## Gauge

Gauges can go up and down

```swift
let gauge = myProm.createGauge(forType: Int.self, named: "my_gauge")
gauge.inc() // Increment by 1
gauge.dec(19) // Decrement by given value
gauge.set(12) // Set to a given value
```

## Histogram

Histograms track the size and number of events in buckets. This allows for aggregatable calculation of quantiles.

```swift
let histogram = myProm.createHistogram(forType: Double.self, named: "my_histogram")
histogram.observe(4.7) // Observe the given value
```

## Summary

Summaries track the size and number of events

```swift
let summary = myProm.createSummary(forType: Double.self, named: "my_summary")
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

let info = myProm.createInfo(named: "my_info", helpText: "Just some info", labelType: MyInfoStruct.self)

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

let counter = myProm.createCounter(forType: Int.self, named: "my_counter", helpText: "Just a counter", withLabelType: RouteLabels.self)

let counter = prom.createCounter(forType: Int.self, named: "my_counter", helpText: "Just a counter", withLabelType: RouteLabels.self)

counter.inc(12, .init(route: "/"))
```

# Exporting

To keep SwiftPrometheus as clean and lightweight as possible, there is no way of exporting metrics directly to Prometheus. Instead, retrieve a formatted string that Prometheus can use, so you can integrate it in your own Serverside Swift application

This could look something like this:
```swift
router.get("/metrics") { request -> String in
    return myProm.getMetrics()
}
```
Here, I used [Vapor](https://github.com/vapor/vapor) syntax, but this will work with any web framework, since it's just returning a plain String.

# Contributing

All contributions are most welcome!

-If you think of some cool new feature that should be included, please [create an issue](https://github.com/MrLotU/SwiftPrometheus/issues/new/choose). Or, if you want to implement it yourself, [fork this repo](https://github.com/MrLotU/SwiftPrometheus/fork) and submit a PR!

If you find a bug or have issues, please [create an issue](https://github.com/MrLotU/SwiftPrometheus/issues/new/choose) explaining your problems. Please include as much information as possible, so it's easier for me to reproduce (Framework, OS, Swift version, terminal output, etc.)

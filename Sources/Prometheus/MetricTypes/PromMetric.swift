/// Different types of metrics supported by SwiftPrometheus
public enum MetricType: String {
    /// See `PromCounter`
    case counter
    /// See `PromGauge`
    case gauge
    /// See `PromHistogram`
    case histogram
    /// See `PromSummary`
    case summary
}

/// Metric protocol
///
/// See https://prometheus.io/docs/concepts/metric_types/
public protocol PromMetric {
    /// Name of the metric
    var name: String { get }
    /// Optional help of the metric
    var help: String? { get }

    /// Retrieves the Prometheus-formatted
    /// metric data
    func getMetric() -> String
}

/// Adding a prometheus instance to all
/// metrics
internal protocol PrometheusHandled {
    /// Promtheus client handling this metric
    var prometheus: PrometheusClient? { get }
}

/// Base MetricLabels protocol
public protocol MetricLabels: Encodable, Hashable {
    /// Create empty labels
    init()
}

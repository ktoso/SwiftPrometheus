/// Default quantiles used by Summaries
public var defaultQuantiles = [0.01, 0.05, 0.5, 0.9, 0.95, 0.99, 0.999]

/// Label type Summaries can use
public protocol SummaryLabels: MetricLabels {
    var quantile: String { get set }
}

extension SummaryLabels {
    /// Creates empty SummaryLabels
    init() {
        self.init()
        self.quantile = ""
    }
}

/// Prometheus Counter metric
///
/// See https://prometheus.io/docs/concepts/metric_types/#summary
public class Summary<NumType: DoubleRepresentable, Labels: SummaryLabels>: Metric, PrometheusHandled {
    /// Prometheus instance that created this Summary
    internal let prometheus: PrometheusClient
    
    /// Name of this Summary, required
    public let name: String
    /// Help text of this Summary, optional
    public let help: String?
    
    /// Type of the metric, used for formatting
    public let _type: MetricType = .summary
    
    /// Labels for this Summary
    internal private(set) var labels: Labels
    
    /// Sum of the values in this Summary
    private let sum: Counter<NumType, EmptyLabels>
    
    /// Amount of values in this Summary
    private let count: Counter<NumType, EmptyLabels>
    
    /// Values in this Summary
    private var values: [NumType] = []
    
    /// Quantiles used by this Summary
    internal let quantiles: [Double]
    
    /// Sub Summaries for this Summary
    fileprivate var subSummaries: [Summary<NumType, Labels>] = []
    
    /// Creates a new Summary
    ///
    /// - Parameters:
    ///     - name: Name of the Summary
    ///     - help: Help text of the Summary
    ///     - labels: Labels for the Summary
    ///     - quantiles: Quantiles to use for the Summary
    ///     - p: Prometheus instance creating this Summary
    internal init(_ name: String, _ help: String? = nil, _ labels: Labels = Labels(), _ quantiles: [Double] = defaultQuantiles, _ p: PrometheusClient) {
        self.name = name
        self.help = help
        
        self.prometheus = p
        
        self.sum = .init("\(self.name)_sum", nil, 0, p)
        
        self.count = .init("\(self.name)_count", nil, 0, p)
        
        self.quantiles = quantiles
        
        self.labels = labels
    }
    
    /// Gets the metric string for this Summary
    ///
    /// - Parameters:
    ///     - done: Completion handler
    ///     - metric: String value in prom-format
    ///
    public func getMetric(_ done: @escaping (_ metric: String) -> Void) {
        prometheusQueue.async(flags: .barrier) {
            var output = [String]()
            
            if let help = self.help {
                output.append("# HELP \(self.name) \(help)")
            }
            output.append("# TYPE \(self.name) \(self._type)")

            calculateQuantiles(quantiles: self.quantiles, values: self.values.map { $0.doubleValue }).sorted { $0.key < $1.key }.forEach { (arg) in
                let (q, v) = arg
                self.labels.quantile = "\(q)"
                let labelsString = encodeLabels(self.labels)
                output.append("\(self.name)\(labelsString) \(v)")
            }
            
            let labelsString = encodeLabels(self.labels, ["quantile"])
            output.append("\(self.name)_count\(labelsString) \(self.count.get())")
            output.append("\(self.name)_sum\(labelsString) \(self.sum.get())")
            
            self.subSummaries.forEach { subSum in
                calculateQuantiles(quantiles: self.quantiles, values: subSum.values.map { $0.doubleValue }).sorted { $0.key < $1.key }.forEach { (arg) in
                    let (q, v) = arg
                    subSum.labels.quantile = "\(q)"
                    let labelsString = encodeLabels(subSum.labels)
                    output.append("\(subSum.name)\(labelsString) \(v)")
                }
                
                let labelsString = encodeLabels(subSum.labels, ["quantile"])
                output.append("\(subSum.name)_count\(labelsString) \(subSum.count.get())")
                output.append("\(subSum.name)_sum\(labelsString) \(subSum.sum.get())")
                subSum.labels.quantile = ""
            }
            
            self.labels.quantile = ""

            done(output.joined(separator: "\n"))
        }
    }
    
    /// Observe a value
    ///
    /// - Parameters:
    ///     - value: Value to observe
    ///     - labels: Labels to attach to the observed value
    ///     - done: Completion handler
    ///
    public func observe(_ value: NumType, _ labels: Labels? = nil, _ done: @escaping () -> Void = { }) {
        prometheusQueue.async(flags: .barrier) {
            func completion() {
                self.count.inc(1)
                self.sum.inc(value)
                self.values.append(value)
                done()
            }
            
            if let labels = labels, type(of: labels) != type(of: EmptySummaryLabels()) {
                let sum = self.prometheus.getOrCreateSummary(withLabels: labels, forSummary: self)
                sum.observe(value) {
                    completion()
                }
            } else {
                completion()
            }
        }
    }
}

extension PrometheusClient {
    fileprivate func getOrCreateSummary<T: Numeric, U: SummaryLabels>(withLabels labels: U, forSummary sum: Summary<T, U>) -> Summary<T, U> {
        let summaries = sum.subSummaries.filter { (metric) -> Bool in
            guard metric.name == sum.name, metric.help == sum.help, metric.labels == labels else { return false }
            return true
        }
        if summaries.count > 2 { fatalError("Somehow got 2 summaries with the same data type") }
        if let summary = summaries.first {
            return summary
        } else {
            let summary = Summary<T, U>(sum.name, sum.help, labels, sum.quantiles, self)
            sum.subSummaries.append(summary)
            return summary
        }
    }
}

/// Calculates values per quantile
///
/// - Parameters:
///     - quantiles: Quantiles to divide values over
///     - values: Values to divide over quantiles
///
/// - Returns: Dictionary of type [Quantile: Value]
func calculateQuantiles(quantiles: [Double], values: [Double]) -> [Double: Double] {
    let values = values.sorted()
    var quantilesMap: [Double: Double] = [:]
    quantiles.forEach { (q) in
        quantilesMap[q] = quantile(q, values)
    }
    return quantilesMap
}

/// Calculates value for quantile
///
/// - Parameters:
///     - q: Quantile to calculate value for
///     - values: Values to calculate quantile from
///
/// - Returns: Calculated quantile
func quantile(_ q: Double, _ values: [Double]) -> Double {
    if values.count == 0 {
        return 0
    }
    if values.count == 1 {
        return values[0]
    }
    
    let n = Double(values.count)
    if let pos = Int(exactly: n*q) {
        if pos < 2 {
            return values[0]
        } else if pos == values.count {
            return values[pos - 1]
        }
        return (values[pos - 1] + values[pos]) / 2.0
    } else {
        let pos = Int((n*q).rounded(.up))
        return values[pos - 1]
    }
}

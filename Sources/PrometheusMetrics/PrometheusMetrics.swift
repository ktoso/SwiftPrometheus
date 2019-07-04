private class MetricsCounter: CounterHandler {
    let counter: PromCounter<Int64, DimensionLabels>
    let labels: DimensionLabels?
    
    internal init(counter: PromCounter<Int64, DimensionLabels>, dimensions: [(String, String)]) {
        self.counter = counter
        guard !dimensions.isEmpty else {
            labels = nil
            return
        }
        self.labels = DimensionLabels(dimensions)
    }
    
    func increment(by: Int64) {
        self.counter.inc(by, labels)
    }
    
    func reset() { }
}

private class MetricsGauge: RecorderHandler {
    let gauge: PromGauge<Double, DimensionLabels>
    let labels: DimensionLabels?
    
    internal init(gauge: PromGauge<Double, DimensionLabels>, dimensions: [(String, String)]) {
        self.gauge = gauge
        guard !dimensions.isEmpty else {
            labels = nil
            return
        }
        self.labels = DimensionLabels(dimensions)
    }
    
    func record(_ value: Int64) {
        self.record(value.doubleValue)
    }
    
    func record(_ value: Double) {
        gauge.inc(value, labels)
    }
}

private class MetricsHistogram: RecorderHandler {
    let histogram: PromHistogram<Double, DimensionHistogramLabels>
    let labels: DimensionHistogramLabels?
    
    internal init(histogram: PromHistogram<Double, DimensionHistogramLabels>, dimensions: [(String, String)]) {
        self.histogram = histogram
        guard !dimensions.isEmpty else {
            labels = nil
            return
        }
        self.labels = DimensionHistogramLabels(dimensions)
    }
    
    func record(_ value: Int64) {
        histogram.observe(value.doubleValue, labels)
    }
    
    func record(_ value: Double) {
        histogram.observe(value, labels)
    }
}

private class MetricsSummary: TimerHandler {
    let summary: PromSummary<Int64, DimensionSummaryLabels>
    let labels: DimensionSummaryLabels?
    
    internal init(summary: PromSummary<Int64, DimensionSummaryLabels>, dimensions: [(String, String)]) {
        self.summary = summary
        guard !dimensions.isEmpty else {
            labels = nil
            return
        }
        self.labels = DimensionSummaryLabels(dimensions)
    }
    
    func recordNanoseconds(_ duration: Int64) {
        summary.observe(duration, labels)
    }
}

extension PrometheusClient: MetricsFactory {
    public func destroyCounter(_ handler: CounterHandler) {
        guard let handler = handler as? MetricsCounter else { return }
        self.removeMetric(handler.counter)
    }
    
    public func destroyRecorder(_ handler: RecorderHandler) {
        if let handler = handler as? MetricsGauge {
            self.removeMetric(handler.gauge)
        }
        if let handler = handler as? MetricsHistogram {
            self.removeMetric(handler.histogram)
        }
    }
    
    public func destroyTimer(_ handler: TimerHandler) {
        guard let handler = handler as? MetricsSummary else { return }
        self.removeMetric(handler.summary)
    }
    
    /// Makes a counter
    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        let createHandler = { (counter: PromCounter) -> CounterHandler in
            MetricsCounter(counter: counter, dimensions: dimensions)
        }
        if let counter: PromCounter<Int64, DimensionLabels> = self.getMetricInstance(with: label) {
            return createHandler(counter)
        }
        return createHandler(self.createCounter(forType: Int64.self, named: label, withLabelType: DimensionLabels.self))
    }
    
    /// Makes a recorder
    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        return aggregate ? makeHistogram(label: label, dimensions: dimensions) : makeGauge(label: label, dimensions: dimensions)
    }
    
    private func makeGauge(label: String, dimensions: [(String, String)]) -> RecorderHandler {
        let createHandler = { (gauge: PromGauge) -> RecorderHandler in
            MetricsGauge(gauge: gauge, dimensions: dimensions)
        }
        if let gauge: PromGauge<Double, DimensionLabels> = self.getMetricInstance(with: label) {
            return createHandler(gauge)
        }
        return createHandler(createGauge(forType: Double.self, named: label, withLabelType: DimensionLabels.self))
    }
    
    private func makeHistogram(label: String, dimensions: [(String, String)]) -> RecorderHandler {
        let createHandler = { (histogram: PromHistogram) -> RecorderHandler in
            MetricsHistogram(histogram: histogram, dimensions: dimensions)
        }
        if let histogram: PromHistogram<Double, DimensionHistogramLabels> = self.getMetricInstance(with: label) {
            return createHandler(histogram)
        }
        return createHandler(createHistogram(forType: Double.self, named: label, labels: DimensionHistogramLabels.self))
    }
    
    /// Makes a timer
    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        let createHandler = { (summary: PromSummary) -> TimerHandler in
            MetricsSummary(summary: summary, dimensions: dimensions)
        }
        if let summary: PromSummary<Int64, DimensionSummaryLabels> = self.getMetricInstance(with: label) {
            return createHandler(summary)
        }
        return createHandler(createSummary(forType: Int64.self, named: label, labels: DimensionSummaryLabels.self))
    }
}

public extension MetricsSystem {
    /// Get the bootstrapped `MetricsSystem` as `PrometheusClient`
    ///
    /// - Returns: `PrometheusClient` used to bootstrap `MetricsSystem`
    /// - Throws: `PrometheusError.PrometheusFactoryNotBootstrapped`
    ///             if no `PrometheusClient` was used to bootstrap `MetricsSystem`
    static func prometheus() throws -> PrometheusClient {
        guard let prom = self.factory as? PrometheusClient else {
            throw PrometheusError.PrometheusFactoryNotBootstrapped
        }
        return prom
    }
}

// MARK: - Labels

/// A generic `String` based `CodingKey` implementation.
private struct StringCodingKey: CodingKey {
    public var stringValue: String

    public init(_ string: String) {
        self.stringValue = string
    }
    
    public init(stringValue: String) {
        self.stringValue = stringValue
    }
    
    public init(intValue: Int) {
        self.stringValue = intValue.description
    }

    public var intValue: Int? {
        return Int(self.stringValue)
    }

}



/// Helper for dimensions
private struct DimensionLabels: MetricLabels {
    let dimensions: [(String, String)]
    
    init() {
        self.dimensions = []
    }
    
    init(_ dimensions: [(String, String)]) {
        self.dimensions = dimensions
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try self.dimensions.forEach {
            try container.encode($0.1, forKey: .init($0.0))
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(dimensions.map { "\($0.0)-\($0.1)"})
    }
    
    fileprivate var identifiers: String {
        return dimensions.map { $0.0 }.joined(separator: "-")
    }
    
    static func == (lhs: DimensionLabels, rhs: DimensionLabels) -> Bool {
        return lhs.dimensions.map { "\($0.0)-\($0.1)"} == rhs.dimensions.map { "\($0.0)-\($0.1)"}
    }
}

/// Helper for dimensions
private struct DimensionHistogramLabels: HistogramLabels {
    /// Bucket
    var le: String
    /// Dimensions
    let dimensions: [(String, String)]
    
    /// Empty init
    init() {
        self.le = ""
        self.dimensions = []
    }
    
    /// Init with dimensions
    init(_ dimensions: [(String, String)]) {
        self.le = ""
        self.dimensions = dimensions
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try self.dimensions.forEach {
            try container.encode($0.1, forKey: .init($0.0))
        }
        try container.encode(le, forKey: .init("le"))
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(dimensions.map { "\($0.0)-\($0.1)"})
        hasher.combine(le)
    }
    
    fileprivate var identifiers: String {
        return dimensions.map { $0.0 }.joined(separator: "-")
    }
    
    static func == (lhs: DimensionHistogramLabels, rhs: DimensionHistogramLabels) -> Bool {
        return lhs.dimensions.map { "\($0.0)-\($0.1)"} == rhs.dimensions.map { "\($0.0)-\($0.1)"} && rhs.le == lhs.le
    }
}

/// Helper for dimensions
private struct DimensionSummaryLabels: SummaryLabels {
    /// Quantile
    var quantile: String
    /// Dimensions
    let dimensions: [(String, String)]
    
    /// Empty init
    init() {
        self.quantile = ""
        self.dimensions = []
    }
    
    /// Init with dimensions
    init(_ dimensions: [(String, String)]) {
        self.quantile = ""
        self.dimensions = dimensions
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try self.dimensions.forEach {
            try container.encode($0.1, forKey: .init($0.0))
        }
        try container.encode(quantile, forKey: .init("quantile"))
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(dimensions.map { "\($0.0)-\($0.1)"})
        hasher.combine(quantile)
    }
    
    fileprivate var identifiers: String {
        return dimensions.map { $0.0 }.joined(separator: "-")
    }
    
    static func == (lhs: DimensionSummaryLabels, rhs: DimensionSummaryLabels) -> Bool {
        return lhs.dimensions.map { "\($0.0)-\($0.1)"} == rhs.dimensions.map { "\($0.0)-\($0.1)"} && rhs.quantile == lhs.quantile
    }
}

///|
/// Severity of a corpus validation finding.
pub(all) enum ValidationSeverity {
  Info
  Warning
  Error
}

///|
pub fn ValidationSeverity::label(self : ValidationSeverity) -> String {
  match self {
    Info => "info"
    Warning => "warning"
    Error => "error"
  }
}

///|
/// A structured validation finding that can be rendered by a CLI or CI job.
pub(all) struct ValidationFinding {
  severity : ValidationSeverity
  code : String
  message : String
  token : String?
}

///|
pub fn ValidationFinding::describe(self : ValidationFinding) -> String {
  match self.token {
    Some(value) =>
      "[\{self.severity.label()}] \{self.code}: \{self.message} token=\{value}"
    None => "[\{self.severity.label()}] \{self.code}: \{self.message}"
  }
}

///|
/// A complete validation result with a stable error count.
pub(all) struct ValidationReport {
  findings : Array[ValidationFinding]
  mut checked_records : Int
  mut checked_dimensions : Int
}

///|
pub fn ValidationReport::new() -> ValidationReport {
  { findings: [], checked_records: 0, checked_dimensions: 0 }
}

///|
pub fn ValidationReport::add(
  self : ValidationReport,
  finding : ValidationFinding,
) -> Unit {
  self.findings.push(finding)
}

///|
pub fn ValidationReport::errors(self : ValidationReport) -> Int {
  let mut total = 0
  for finding in self.findings {
    if finding.severity is Error {
      total = total + 1
    }
  }
  total
}

///|
pub fn ValidationReport::warnings(self : ValidationReport) -> Int {
  let mut total = 0
  for finding in self.findings {
    if finding.severity is Warning {
      total = total + 1
    }
  }
  total
}

///|
pub fn ValidationReport::is_valid(self : ValidationReport) -> Bool {
  self.errors() == 0
}

///|
pub fn ValidationReport::summary(self : ValidationReport) -> String {
  "records=\{self.checked_records}, dimensions=\{self.checked_dimensions}, errors=\{self.errors()}, warnings=\{self.warnings()}"
}

///|
pub fn ValidationReport::messages(self : ValidationReport) -> Array[String] {
  let result = []
  for finding in self.findings {
    result.push(finding.describe())
  }
  result
}

///|
/// Validate a vector without throwing, for ingestion pipelines.
pub fn validate_vector(
  vector : Array[Double],
  expected_dimension : Int,
) -> ValidationReport {
  let report = ValidationReport::new()
  report.checked_records = 1
  report.checked_dimensions = vector.length()
  if vector.length() == 0 {
    report.add({
      severity: Error,
      code: "empty-vector",
      message: "vector has no coordinates",
      token: None,
    })
    return report
  }
  if expected_dimension > 0 && vector.length() != expected_dimension {
    report.add({
      severity: Error,
      code: "dimension-mismatch",
      message: "vector dimension does not match corpus",
      token: None,
    })
  }
  let mut norm = 0.0
  for value in vector {
    norm = norm + value * value
  }
  if norm == 0.0 {
    report.add({
      severity: Warning,
      code: "zero-vector",
      message: "zero vectors never match semantically",
      token: None,
    })
  }
  report
}

///|
/// Validate every record and identify duplicate or empty keys.
pub fn validate_corpus(corpus : EmbeddingCorpus) -> ValidationReport {
  let report = ValidationReport::new()
  report.checked_records = corpus.size()
  report.checked_dimensions = corpus.dim
  let seen : Map[String, Bool] = Map([])
  for record in corpus.records {
    if record.token.is_empty() {
      report.add({
        severity: Error,
        code: "empty-token",
        message: "embedding token is empty",
        token: None,
      })
    }
    if seen.contains(record.token) {
      report.add({
        severity: Warning,
        code: "duplicate-token",
        message: "later record shadows an earlier token",
        token: Some(record.token),
      })
    }
    seen.set(record.token, true)
    let vector_report = validate_vector(record.vector, corpus.dim)
    for finding in vector_report.findings {
      report.add({ ..finding, token: Some(record.token) })
    }
  }
  report
}

///|
/// Validate a query before passing it to an index.
pub fn validate_query(
  query : Array[Double],
  dimension : Int,
) -> ValidationReport {
  validate_vector(query, dimension)
}

///|
/// Compare two corpora for compatibility before loading a new model.
pub(all) struct CorpusCompatibility {
  compatible : Bool
  same_dimension : Bool
  shared_tokens : Int
  left_only : Int
  right_only : Int
}

///|
pub fn CorpusCompatibility::describe(self : CorpusCompatibility) -> String {
  "compatible=\{self.compatible}, same_dimension=\{self.same_dimension}, shared=\{self.shared_tokens}, left_only=\{self.left_only}, right_only=\{self.right_only}"
}

///|
pub fn compare_corpora(
  left : EmbeddingCorpus,
  right : EmbeddingCorpus,
) -> CorpusCompatibility {
  let left_tokens = TokenSet::new()
  let right_tokens = TokenSet::new()
  for token in left.tokens() {
    let _ = left_tokens.add(token)
  }
  for token in right.tokens() {
    let _ = right_tokens.add(token)
  }
  let shared = left_tokens.intersection(right_tokens).size()
  let only_left = left_tokens.difference(right_tokens).size()
  let only_right = right_tokens.difference(left_tokens).size()
  let same_dimension = left.dim == right.dim
  {
    compatible: same_dimension,
    same_dimension,
    shared_tokens: shared,
    left_only: only_left,
    right_only: only_right,
  }
}

///|
/// A query plan chooses exact or approximate retrieval explicitly.
pub(all) enum RetrievalMode {
  Exact
  Approximate
  Auto
}

///|
pub fn RetrievalMode::label(self : RetrievalMode) -> String {
  match self {
    Exact => "exact"
    Approximate => "approximate"
    Auto => "auto"
  }
}

///|
pub(all) struct QueryPlan {
  mode : RetrievalMode
  k : Int
  threshold : Double?
  explain : Bool
}

///|
pub fn QueryPlan::new(
  mode? : RetrievalMode = Auto,
  k? : Int = 10,
  threshold? : Double,
  explain? : Bool = false,
) -> QueryPlan {
  { mode, k, threshold, explain }
}

///|
pub fn QueryPlan::valid(self : QueryPlan) -> Bool {
  self.k > 0
}

///|
pub fn QueryPlan::describe(self : QueryPlan) -> String {
  "mode=\{self.mode.label()}, k=\{self.k}, explain=\{self.explain}"
}

///|
/// Execute a query plan while preserving the selected retrieval semantics.
pub fn MoonEmbedIndex::execute_plan(
  self : MoonEmbedIndex,
  query : Array[Double],
  plan : QueryPlan,
) -> SearchReport {
  if !plan.valid() {
    return { hits: [], scanned: 0, candidates: 0 }
  }
  let report = match plan.mode {
    Exact => self.search_exact(query, plan.k)
    Approximate => self.search(query, plan.k)
    Auto =>
      if self.corpus.size() < 64 {
        self.search_exact(query, plan.k)
      } else {
        self.search(query, plan.k)
      }
  }
  match plan.threshold {
    Some(value) =>
      { ..report, hits: report.hits.filter(hit => hit.score >= value) }
    None => report
  }
}

///|
/// A stable snapshot of index configuration for diagnostics.
pub(all) struct IndexDiagnostics {
  records : Int
  dimension : Int
  signature_bits : Int
  nonempty_buckets : Int
  largest_bucket : Int
}

///|
pub fn IndexDiagnostics::describe(self : IndexDiagnostics) -> String {
  "records=\{self.records}, dimension=\{self.dimension}, signature_bits=\{self.signature_bits}, nonempty_buckets=\{self.nonempty_buckets}, largest_bucket=\{self.largest_bucket}"
}

///|
pub fn MoonEmbedIndex::diagnostics(self : MoonEmbedIndex) -> IndexDiagnostics {
  let mut nonempty = 0
  let mut largest = 0
  for bucket in self.buckets {
    if !bucket.is_empty() {
      nonempty = nonempty + 1
    }
    if bucket.length() > largest {
      largest = bucket.length()
    }
  }
  {
    records: self.corpus.size(),
    dimension: self.corpus.dim,
    signature_bits: self.signature_bits,
    nonempty_buckets: nonempty,
    largest_bucket: largest,
  }
}

///|
pub fn MoonEmbedIndex::safe_search(
  self : MoonEmbedIndex,
  query : Array[Double],
  plan : QueryPlan,
) -> (ValidationReport, SearchReport) {
  let validation = validate_query(query, self.corpus.dim)
  if !validation.is_valid() {
    return (validation, { hits: [], scanned: 0, candidates: 0 })
  }
  (validation, self.execute_plan(query, plan))
}

///|
pub fn corpus_health(corpus : EmbeddingCorpus) -> String {
  let report = validate_corpus(corpus)
  report.summary()
}

///|
test "validation and query plans" {
  let corpus = demo_corpus()
  let report = validate_corpus(corpus)
  inspect(report.is_valid(), content="true")
  inspect(validate_query([1.0, 0.0], 3).is_valid(), content="false")
  let compatibility = compare_corpora(corpus, demo_corpus())
  inspect(compatibility.shared_tokens, content="6")
  let plan = QueryPlan::new(mode=Exact, k=2, threshold=0.5)
  inspect(plan.valid(), content="true")
  let result = demo_index().execute_plan([1.0, 0.0, 0.0], plan)
  inspect(result.hits.length(), content="2")
  inspect(demo_index().diagnostics().records, content="6")
  let safe = demo_index().safe_search([1.0, 0.0], plan)
  inspect(safe.1.hits.length(), content="0")
}

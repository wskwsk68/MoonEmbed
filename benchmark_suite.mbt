///|
/// A labelled benchmark document used for repeatable retrieval evaluation.
pub(all) struct BenchmarkDocument {
  id : String
  category : String
  text : String
  expected_tokens : Array[String]
}

///|
pub fn BenchmarkDocument::describe(self : BenchmarkDocument) -> String {
  "\{self.id} [\{self.category}] \{self.text}"
}

///|
/// A deterministic benchmark corpus with no network or model download.
pub(all) struct BenchmarkSuite {
  name : String
  documents : Array[BenchmarkDocument]
  queries : Array[RetrievalCase]
}

///|
pub fn BenchmarkSuite::new(name : String) -> BenchmarkSuite {
  { name, documents: [], queries: [] }
}

///|
pub fn BenchmarkSuite::add_document(
  self : BenchmarkSuite,
  document : BenchmarkDocument,
) -> Unit {
  self.documents.push(document)
}

///|
pub fn BenchmarkSuite::add_query(
  self : BenchmarkSuite,
  query : RetrievalCase,
) -> Unit {
  self.queries.push(query)
}

///|
pub fn BenchmarkSuite::document_count(self : BenchmarkSuite) -> Int {
  self.documents.length()
}

///|
pub fn BenchmarkSuite::query_count(self : BenchmarkSuite) -> Int {
  self.queries.length()
}

///|
pub fn BenchmarkSuite::categories(self : BenchmarkSuite) -> Array[String] {
  let seen : Map[String, Bool] = Map([])
  for document in self.documents {
    seen.set(document.category, true)
  }
  let result = []
  for category, _ in seen {
    result.push(category)
  }
  result
}

///|
pub fn BenchmarkSuite::describe(self : BenchmarkSuite) -> String {
  "name=\{self.name}, documents=\{self.document_count()}, queries=\{self.query_count()}, categories=\{self.categories().length()}"
}

///|
/// A generated report that can be printed in CI logs.
pub(all) struct BenchmarkReport {
  suite : String
  documents : Int
  queries : Int
  passed : Int
  mean_recall : Double
  mean_candidates : Double
  filtered_documents : Int
}

///|
pub fn BenchmarkReport::describe(self : BenchmarkReport) -> String {
  "suite=\{self.suite}, documents=\{self.documents}, queries=\{self.queries}, passed=\{self.passed}, mean_recall=\{self.mean_recall.to_string()}, mean_candidates=\{self.mean_candidates.to_string()}, filtered_documents=\{self.filtered_documents}"
}

///|
pub fn BenchmarkSuite::run(
  self : BenchmarkSuite,
  index : MoonEmbedIndex,
  k : Int,
) -> BenchmarkReport {
  let metrics = index.evaluate(self.queries, k)
  let filtered = self.documents.length() - metrics.mean_candidates.to_int()
  {
    suite: self.name,
    documents: self.documents.length(),
    queries: self.queries.length(),
    passed: metrics.passed,
    mean_recall: metrics.mean_recall,
    mean_candidates: metrics.mean_candidates,
    filtered_documents: if filtered < 0 {
      0
    } else {
      filtered
    },
  }
}

///|
fn benchmark_vectors() -> EmbeddingCorpus {
  EmbeddingCorpus::from_records(
    [
      EmbeddingRecord::new("search", [1.0, 0.0, 0.0, 0.0]),
      EmbeddingRecord::new("query", [0.95, 0.05, 0.0, 0.0]),
      EmbeddingRecord::new("retrieval", [0.9, 0.1, 0.0, 0.0]),
      EmbeddingRecord::new("database", [0.0, 1.0, 0.0, 0.0]),
      EmbeddingRecord::new("storage", [0.0, 0.95, 0.05, 0.0]),
      EmbeddingRecord::new("cache", [0.0, 0.9, 0.1, 0.0]),
      EmbeddingRecord::new("browser", [0.0, 0.0, 1.0, 0.0]),
      EmbeddingRecord::new("wasm", [0.0, 0.0, 0.95, 0.05]),
      EmbeddingRecord::new("runtime", [0.0, 0.0, 0.9, 0.1]),
      EmbeddingRecord::new("testing", [0.0, 0.0, 0.0, 1.0]),
      EmbeddingRecord::new("quality", [0.0, 0.0, 0.05, 0.95]),
      EmbeddingRecord::new("coverage", [0.0, 0.0, 0.1, 0.9]),
    ],
    GloVeText,
  )
}

///|
pub fn standard_benchmark_suite() -> BenchmarkSuite {
  let suite = BenchmarkSuite::new("moonembed-local-baseline")
  suite.add_document({
    id: "d-search",
    category: "retrieval",
    text: "search query retrieval",
    expected_tokens: ["search"],
  })
  suite.add_document({
    id: "d-storage",
    category: "storage",
    text: "database storage cache",
    expected_tokens: ["database"],
  })
  suite.add_document({
    id: "d-runtime",
    category: "runtime",
    text: "browser wasm runtime",
    expected_tokens: ["browser"],
  })
  suite.add_document({
    id: "d-quality",
    category: "quality",
    text: "testing quality coverage",
    expected_tokens: ["testing"],
  })
  suite.add_query({
    name: "search",
    query: [1.0, 0.0, 0.0, 0.0],
    expected: ["search"],
  })
  suite.add_query({
    name: "storage",
    query: [0.0, 1.0, 0.0, 0.0],
    expected: ["database"],
  })
  suite.add_query({
    name: "runtime",
    query: [0.0, 0.0, 1.0, 0.0],
    expected: ["browser"],
  })
  suite.add_query({
    name: "quality",
    query: [0.0, 0.0, 0.0, 1.0],
    expected: ["testing"],
  })
  suite
}

///|
/// A simple deterministic latency sample accumulator.
pub(all) struct SampleStats {
  mut count : Int
  mut total : Double
  mut minimum : Double
  mut maximum : Double
}

///|
pub fn SampleStats::new() -> SampleStats {
  { count: 0, total: 0.0, minimum: 0.0, maximum: 0.0 }
}

///|
pub fn SampleStats::add(self : SampleStats, value : Double) -> Unit {
  if self.count == 0 {
    self.minimum = value
    self.maximum = value
  } else {
    if value < self.minimum {
      self.minimum = value
    }
    if value > self.maximum {
      self.maximum = value
    }
  }
  self.count = self.count + 1
  self.total = self.total + value
}

///|
pub fn SampleStats::mean(self : SampleStats) -> Double {
  if self.count == 0 {
    0.0
  } else {
    self.total / self.count.to_double()
  }
}

///|
pub fn SampleStats::describe(self : SampleStats) -> String {
  "count=\{self.count}, mean=\{self.mean().to_string()}, min=\{self.minimum.to_string()}, max=\{self.maximum.to_string()}"
}

///|
pub fn BenchmarkSuite::sample_search(
  self : BenchmarkSuite,
  index : MoonEmbedIndex,
  repeats : Int,
  k : Int,
) -> SampleStats {
  let stats = SampleStats::new()
  if repeats <= 0 {
    return stats
  }
  for _ in 0..<repeats {
    for query in self.queries {
      let report = index.search(query.query, k)
      stats.add(report.scanned.to_double())
    }
  }
  stats
}

///|
pub fn BenchmarkSuite::expected_category(
  self : BenchmarkSuite,
  id : String,
) -> String? {
  for document in self.documents {
    if document.id == id {
      return Some(document.category)
    }
  }
  None
}

///|
pub fn BenchmarkSuite::documents_in_category(
  self : BenchmarkSuite,
  category : String,
) -> Array[BenchmarkDocument] {
  let result = []
  for document in self.documents {
    if document.category == category {
      result.push(document)
    }
  }
  result
}

///|
pub fn BenchmarkSuite::query_names(self : BenchmarkSuite) -> Array[String] {
  let result = []
  for query in self.queries {
    result.push(query.name)
  }
  result
}

///|
test "benchmark suite" {
  let corpus = benchmark_vectors()
  let index = MoonEmbedIndex::from_corpus(corpus, 3)
  let suite = standard_benchmark_suite()
  inspect(suite.document_count(), content="4")
  inspect(suite.query_count(), content="4")
  inspect(suite.categories().length(), content="4")
  let report = suite.run(index, 3)
  inspect(report.queries, content="4")
  inspect(report.passed, content="4")
  debug_inspect(
    suite.expected_category("d-storage"),
    content="Some(\"storage\")",
  )
  inspect(suite.documents_in_category("runtime").length(), content="1")
  inspect(suite.sample_search(index, 2, 2).count > 0, content="true")
}

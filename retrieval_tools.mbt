///|
/// Search a query and keep only hits at or above a score threshold.
pub fn MoonEmbedIndex::search_threshold(
  self : MoonEmbedIndex,
  query : Array[Double],
  k : Int,
  threshold : Double,
) -> SearchReport {
  let report = self.search(query, k)
  let hits = []
  for hit in report.hits {
    if hit.score >= threshold {
      hits.push(hit)
    }
  }
  { ..report, hits, }
}

///|
/// Search with a sentence average embedding. Unknown terms are ignored.
pub fn MoonEmbedIndex::search_text(
  self : MoonEmbedIndex,
  text : String,
  k : Int,
) -> SearchReport {
  self.search_terms(text, k)
}

///|
/// Search several queries in one call. The output order matches the input order.
pub fn MoonEmbedIndex::search_many(
  self : MoonEmbedIndex,
  queries : Array[Array[Double]],
  k : Int,
) -> Array[SearchReport] {
  let result = []
  for query in queries {
    result.push(self.search(query, k))
  }
  result
}

///|
/// Search a token prefix and score each matching vector exactly.
pub fn MoonEmbedIndex::search_prefix(
  self : MoonEmbedIndex,
  prefix : String,
  k : Int,
) -> SearchReport {
  if k <= 0 {
    return { hits: [], scanned: 0, candidates: 0 }
  }
  let hits = []
  let mut scanned = 0
  for record in self.corpus.prefix(prefix, self.corpus.size()) {
    insert_hit(hits, { token: record.token, score: 1.0 }, k)
    scanned = scanned + 1
  }
  { hits, scanned, candidates: scanned }
}

///|
/// Compute recall against an exact result for a query.
pub fn recall_at_k(
  approx : SearchReport,
  exact : SearchReport,
  k : Int,
) -> Double {
  if k <= 0 || exact.hits.is_empty() {
    return 0.0
  }
  let limit = if k < exact.hits.length() { k } else { exact.hits.length() }
  let mut found = 0
  for i in 0..<limit {
    let expected = exact.hits[i].token
    for hit in approx.hits {
      if hit.token == expected {
        found = found + 1
        break
      }
    }
  }
  found.to_double() / limit.to_double()
}

///|
/// A deterministic query case used by benchmark and regression reports.
pub(all) struct RetrievalCase {
  name : String
  query : Array[Double]
  expected : Array[String]
}

///|
pub(all) struct RetrievalMetrics {
  cases : Int
  passed : Int
  mean_recall : Double
  mean_candidates : Double
}

///|
pub fn RetrievalMetrics::describe(self : RetrievalMetrics) -> String {
  "cases=\{self.cases}, passed=\{self.passed}, mean_recall=\{self.mean_recall.to_string()}, mean_candidates=\{self.mean_candidates.to_string()}"
}

///|
/// Evaluate top-k membership with exact search as the reference.
pub fn MoonEmbedIndex::evaluate(
  self : MoonEmbedIndex,
  cases : Array[RetrievalCase],
  k : Int,
) -> RetrievalMetrics {
  if cases.is_empty() || k <= 0 {
    return {
      cases: cases.length(),
      passed: 0,
      mean_recall: 0.0,
      mean_candidates: 0.0,
    }
  }
  let mut passed = 0
  let mut recall_total = 0.0
  let mut candidate_total = 0.0
  for case in cases {
    let exact = self.search_exact(case.query, k)
    let approx = self.search(case.query, k)
    let recall = recall_at_k(approx, exact, k)
    recall_total = recall_total + recall
    candidate_total = candidate_total + approx.candidates.to_double()
    let mut case_passed = true
    for expected in case.expected {
      if !approx.tokens().contains(expected) {
        case_passed = false
      }
    }
    if case_passed {
      passed = passed + 1
    }
  }
  {
    cases: cases.length(),
    passed,
    mean_recall: recall_total / cases.length().to_double(),
    mean_candidates: candidate_total / cases.length().to_double(),
  }
}

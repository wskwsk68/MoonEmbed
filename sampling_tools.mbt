///|
/// A deterministic reservoir of representative search queries.
pub(all) struct QuerySampler {
  queries : Array[Array[Double]]
  labels : Array[String]
  limit : Int
}

///|
pub fn QuerySampler::new(limit : Int) -> QuerySampler {
  { queries: [], labels: [], limit }
}

///|
pub fn QuerySampler::add(
  self : QuerySampler,
  label : String,
  query : Array[Double],
) -> Bool {
  if self.limit <= 0 || self.queries.length() >= self.limit {
    return false
  }
  self.labels.push(label)
  self.queries.push(copy_vector(query))
  true
}

///|
pub fn QuerySampler::size(self : QuerySampler) -> Int {
  self.queries.length()
}

///|
pub fn QuerySampler::is_full(self : QuerySampler) -> Bool {
  self.limit > 0 && self.size() >= self.limit
}

///|
pub fn QuerySampler::query(self : QuerySampler, index : Int) -> Array[Double]? {
  match self.queries.get(index) {
    Some(value) => Some(copy_vector(value))
    None => None
  }
}

///|
pub fn QuerySampler::label(self : QuerySampler, index : Int) -> String? {
  self.labels.get(index)
}

///|
pub fn QuerySampler::clear(self : QuerySampler) -> Unit {
  while !self.queries.is_empty() {
    let _ = self.queries.pop()
  }
  while !self.labels.is_empty() {
    let _ = self.labels.pop()
  }
}

///|
pub fn QuerySampler::evaluate(
  self : QuerySampler,
  index : MoonEmbedIndex,
  k : Int,
) -> RetrievalMetrics {
  let cases = []
  for i in 0..<self.queries.length() {
    let label = self.labels[i]
    cases.push({ name: label, query: self.queries[i], expected: [] })
  }
  index.evaluate(cases, k)
}

///|
/// Quantize a normalized coordinate into a small integer range for compact telemetry.
pub fn quantize_coordinate(value : Double, levels : Int) -> Int {
  if levels <= 1 {
    return 0
  }
  let bounded = if value < -1.0 {
    -1.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
  ((bounded + 1.0) * 0.5 * (levels - 1).to_double()).to_int()
}

///|
pub fn dequantize_coordinate(value : Int, levels : Int) -> Double {
  if levels <= 1 {
    return 0.0
  }
  let bounded = if value < 0 {
    0
  } else if value >= levels {
    levels - 1
  } else {
    value
  }
  bounded.to_double() / (levels - 1).to_double() * 2.0 - 1.0
}

///|
pub fn quantize_vector(vector : Array[Double], levels : Int) -> Array[Int] {
  let result = []
  for value in vector {
    result.push(quantize_coordinate(value, levels))
  }
  result
}

///|
pub fn dequantize_vector(vector : Array[Int], levels : Int) -> Array[Double] {
  let result = []
  for value in vector {
    result.push(dequantize_coordinate(value, levels))
  }
  result
}

///|
/// Estimate mean absolute error introduced by coordinate quantization.
pub fn quantization_error(vector : Array[Double], levels : Int) -> Double {
  if vector.is_empty() {
    return 0.0
  }
  let quantized = dequantize_vector(quantize_vector(vector, levels), levels)
  let mut total = 0.0
  for i in 0..<vector.length() {
    let difference = vector[i] - quantized[i]
    let absolute = if difference < 0.0 { -difference } else { difference }
    total = total + absolute
  }
  total / vector.length().to_double()
}

///|
pub fn corpus_quantization_error(
  corpus : EmbeddingCorpus,
  levels : Int,
) -> Double {
  if corpus.size() == 0 {
    return 0.0
  }
  let mut total = 0.0
  for record in corpus.records {
    total = total + quantization_error(record.vector, levels)
  }
  total / corpus.size().to_double()
}

///|
pub fn SearchReport::is_confident(
  self : SearchReport,
  threshold : Double,
) -> Bool {
  match self.best_score() {
    Some(score) => score >= threshold
    None => false
  }
}

///|
pub fn SearchReport::unique_tokens(self : SearchReport) -> Array[String] {
  let set = TokenSet::new()
  for hit in self.hits {
    let _ = set.add(hit.token)
  }
  set.to_array()
}

///|
test "sampling and quantization" {
  let sampler = QuerySampler::new(2)
  inspect(sampler.add("first", [1.0, 0.0]), content="true")
  inspect(sampler.add("second", [0.0, 1.0]), content="true")
  inspect(sampler.add("third", [0.5, 0.5]), content="false")
  inspect(sampler.size(), content="2")
  inspect(quantize_coordinate(0.0, 9), content="4")
  inspect(dequantize_coordinate(4, 9) == 0.0, content="true")
  inspect(quantization_error([0.0, 0.5, -0.5], 9) < 0.2, content="true")
  let report = demo_index().search([1.0, 0.0, 0.0], 2)
  inspect(report.is_confident(0.5), content="true")
  inspect(report.unique_tokens().length(), content="2")
}

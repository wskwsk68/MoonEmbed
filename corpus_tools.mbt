///|
/// A compact summary useful for diagnostics, monitoring, and benchmark output.
pub(all) struct CorpusStats {
  records : Int
  dimension : Int
  zero_vectors : Int
  duplicate_tokens : Int
  min_norm : Double
  max_norm : Double
}

///|
pub fn CorpusStats::describe(self : CorpusStats) -> String {
  "records=\{self.records}, dimension=\{self.dimension}, zero_vectors=\{self.zero_vectors}, duplicate_tokens=\{self.duplicate_tokens}, min_norm=\{self.min_norm.to_string()}, max_norm=\{self.max_norm.to_string()}"
}

///|
pub fn EmbeddingCorpus::stats(self : EmbeddingCorpus) -> CorpusStats {
  let seen : Map[String, Bool] = Map([])
  let mut duplicates = 0
  let mut zero_vectors = 0
  let mut min_norm = 0.0
  let mut max_norm = 0.0
  for i, record in self.records {
    if seen.contains(record.token) {
      duplicates = duplicates + 1
    }
    seen.set(record.token, true)
    let mut norm = 0.0
    for value in record.vector {
      norm = norm + value * value
    }
    norm = norm.sqrt()
    if norm == 0.0 {
      zero_vectors = zero_vectors + 1
    }
    if i == 0 || norm < min_norm {
      min_norm = norm
    }
    if norm > max_norm {
      max_norm = norm
    }
  }
  {
    records: self.records.length(),
    dimension: self.dim,
    zero_vectors,
    duplicate_tokens: duplicates,
    min_norm,
    max_norm,
  }
}

///|
/// Return the normalized vector for a token, if it exists.
pub fn EmbeddingCorpus::vector(
  self : EmbeddingCorpus,
  token : String,
) -> Array[Double]? {
  self.lookup(token)
}

///|
/// Return all records whose token starts with `prefix`, preserving corpus order.
pub fn EmbeddingCorpus::prefix(
  self : EmbeddingCorpus,
  prefix : String,
  limit : Int,
) -> Array[EmbeddingRecord] {
  let result = []
  if limit <= 0 {
    return result
  }
  for record in self.records {
    if result.length() >= limit {
      break
    }
    if record.token.has_prefix(prefix) {
      result.push(record)
    }
  }
  result
}

///|
/// Return a copy of every vector, suitable for callers that need to mutate it.
pub fn EmbeddingCorpus::vectors(self : EmbeddingCorpus) -> Array[Array[Double]] {
  let result = []
  for record in self.records {
    result.push(copy_vector(record.vector))
  }
  result
}

///|
/// Validate structural invariants without exposing internal maps.
pub fn EmbeddingCorpus::validate(self : EmbeddingCorpus) -> Bool {
  for record in self.records {
    if record.token.is_empty() || record.vector.length() != self.dim {
      return false
    }
  }
  true
}

///|
pub fn cosine_similarity(left : Array[Double], right : Array[Double]) -> Double {
  let mut left_norm = 0.0
  let mut right_norm = 0.0
  let mut numerator = 0.0
  let length = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  for i in 0..<length {
    numerator = numerator + left[i] * right[i]
    left_norm = left_norm + left[i] * left[i]
    right_norm = right_norm + right[i] * right[i]
  }
  if left_norm == 0.0 || right_norm == 0.0 {
    return 0.0
  }
  numerator / (left_norm.sqrt() * right_norm.sqrt())
}

///|
pub fn cosine_distance(left : Array[Double], right : Array[Double]) -> Double {
  1.0 - cosine_similarity(left, right)
}

///|
fn format_embedding_value(value : Double) -> String {
  if value == 0.0 {
    "0.0"
  } else {
    value.to_string()
  }
}

///|
/// Serialize a corpus to a portable GloVe-style text representation.
pub fn EmbeddingCorpus::to_glove_text(self : EmbeddingCorpus) -> String {
  let mut output = ""
  for record in self.records {
    output = output + record.token
    for value in record.vector {
      output = output + " " + format_embedding_value(value)
    }
    output = output + "\n"
  }
  output
}

///|
/// Serialize a corpus to word2vec text with an explicit header.
pub fn EmbeddingCorpus::to_word2vec_text(self : EmbeddingCorpus) -> String {
  let mut output = "\{self.records.length()} \{self.dim}\n"
  for record in self.records {
    output = output + record.token
    for value in record.vector {
      output = output + " " + format_embedding_value(value)
    }
    output = output + "\n"
  }
  output
}

///|
pub fn SearchHit::above(self : SearchHit, threshold : Double) -> Bool {
  self.score >= threshold
}

///|
pub fn SearchReport::best_score(self : SearchReport) -> Double? {
  if self.hits.is_empty() {
    None
  } else {
    Some(self.hits[0].score)
  }
}

///|
pub fn SearchReport::tokens(self : SearchReport) -> Array[String] {
  let result = []
  for hit in self.hits {
    result.push(hit.token)
  }
  result
}

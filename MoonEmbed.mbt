///|
pub(all) enum SourceFormat {
  Word2VecText
  Word2VecBinary
  GloVeText
}

///|
pub fn SourceFormat::label(self : SourceFormat) -> String {
  match self {
    Word2VecText => "word2vec-text"
    Word2VecBinary => "word2vec-binary"
    GloVeText => "glove-text"
  }
}

///|
pub(all) struct EmbeddingRecord {
  token : String
  vector : Array[Double]
}

///|
pub(all) struct EmbeddingCorpus {
  records : Array[EmbeddingRecord]
  token_index : Map[String, Int]
  dim : Int
  source : SourceFormat
}

///|
pub(all) struct SearchHit {
  token : String
  score : Double
}

///|
pub(all) struct SearchReport {
  hits : Array[SearchHit]
  scanned : Int
  candidates : Int
}

///|
pub(all) struct MoonEmbedIndex {
  corpus : EmbeddingCorpus
  buckets : Array[Array[Int]]
  signature_bits : Int
}

///|
fn trim_line(line : StringView) -> StringView {
  line.trim()
}

///|
fn parse_float(token : StringView) -> Double raise {
  @strconv.from_str(token)
}

///|
fn parse_int(token : StringView) -> Int raise {
  @strconv.from_str(token)
}

///|
fn split_tokens(line : StringView) -> Array[StringView] {
  let parts = []
  for part in line.split(" ") {
    let token = part.trim()
    if !token.is_empty() {
      parts.push(token)
    }
  }
  parts
}

///|
fn is_header_line(parts : Array[StringView]) -> Bool raise {
  if parts.length() != 2 {
    return false
  }
  let _ = parse_int(parts[0])
  let _ = parse_int(parts[1])
  true
}

///|
fn normalize_in_place(vector : Array[Double]) -> Unit {
  let mut sum = 0.0
  for value in vector {
    sum = sum + value * value
  }
  if sum <= 0.0 {
    return
  }
  let inv = 1.0 / sum.sqrt()
  for i in 0..<vector.length() {
    vector[i] = vector[i] * inv
  }
}

///|
fn dot(left : Array[Double], right : Array[Double]) -> Double {
  let mut total = 0.0
  for i in 0..<left.length() {
    total = total + left[i] * right[i]
  }
  total
}

///|
fn signature_bits_count(signature_bits : Int, vector : Array[Double]) -> Int {
  let mut signature = 0
  let limit = if signature_bits < vector.length() {
    signature_bits
  } else {
    vector.length()
  }
  for i in 0..<limit {
    if vector[i] >= 0.0 {
      signature = signature | (1 << i)
    }
  }
  signature
}

///|
fn build_bucket_table(bucket_count : Int) -> Array[Array[Int]] {
  Array::makei(bucket_count, _ => [])
}

///|
fn copy_vector(vector : Array[Double]) -> Array[Double] {
  let out = []
  for value in vector {
    out.push(value)
  }
  out
}

///|
pub fn EmbeddingRecord::new(
  token : String,
  vector : Array[Double],
) -> EmbeddingRecord {
  { token, vector }
}

///|
pub fn EmbeddingCorpus::from_records(
  records : Array[EmbeddingRecord],
  source : SourceFormat,
) -> EmbeddingCorpus {
  let token_index : Map[String, Int] = Map([])
  let mut dim = 0
  for i in 0..<records.length() {
    let record = records[i]
    if i == 0 {
      dim = record.vector.length()
    } else if record.vector.length() != dim {
      panic()
    }
    token_index.set(record.token, i)
  }
  { records, token_index, dim, source }
}

///|
pub fn EmbeddingCorpus::size(self : EmbeddingCorpus) -> Int {
  self.records.length()
}

///|
pub fn EmbeddingCorpus::describe(self : EmbeddingCorpus) -> String {
  "size=\{self.size()}, dim=\{self.dim}, source=\{self.source.label()}"
}

///|
pub fn EmbeddingCorpus::lookup(
  self : EmbeddingCorpus,
  token : String,
) -> Array[Double]? {
  match self.token_index.get(token) {
    Some(index) => Some(self.records[index].vector)
    None => None
  }
}

///|
pub fn EmbeddingCorpus::has_token(self : EmbeddingCorpus, token : String) -> Bool {
  self.token_index.get(token) is Some(_)
}

///|
pub fn EmbeddingCorpus::tokens(self : EmbeddingCorpus) -> Array[String] {
  let tokens = []
  for record in self.records {
    tokens.push(record.token)
  }
  tokens
}

///|
pub fn EmbeddingCorpus::record(
  self : EmbeddingCorpus,
  index : Int,
) -> EmbeddingRecord {
  self.records[index]
}

///|
pub fn EmbeddingCorpus::from_word2vec_text(
  text : String,
) -> EmbeddingCorpus raise {
  let records = []
  let mut dim = 0
  let mut is_first_line = true
  for raw_line in text.split("\n") {
    let line = trim_line(raw_line)
    if line.is_empty() {
      continue
    }
    let parts = split_tokens(line)
    if parts.is_empty() {
      continue
    }
    if is_first_line && is_header_line(parts) {
      dim = parse_int(parts[1])
      is_first_line = false
      continue
    }
    is_first_line = false
    let token = parts[0].to_owned()
    let vector = []
    for i in 1..<parts.length() {
      vector.push(parse_float(parts[i]))
    }
    if dim == 0 {
      dim = vector.length()
    } else if vector.length() != dim {
      panic()
    }
    normalize_in_place(vector)
    records.push(EmbeddingRecord::new(token, vector))
  }
  EmbeddingCorpus::from_records(records, Word2VecText)
}

///|
pub fn EmbeddingCorpus::from_glove_text(text : String) -> EmbeddingCorpus raise {
  let records = []
  let mut dim = 0
  for raw_line in text.split("\n") {
    let line = trim_line(raw_line)
    if line.is_empty() {
      continue
    }
    let parts = split_tokens(line)
    if parts.length() < 2 {
      continue
    }
    let token = parts[0].to_owned()
    let vector = []
    for i in 1..<parts.length() {
      vector.push(parse_float(parts[i]))
    }
    if dim == 0 {
      dim = vector.length()
    } else if vector.length() != dim {
      panic()
    }
    normalize_in_place(vector)
    records.push(EmbeddingRecord::new(token, vector))
  }
  EmbeddingCorpus::from_records(records, GloVeText)
}

///|
pub fn EmbeddingCorpus::from_word2vec_binary(
  bytes : Bytes,
) -> EmbeddingCorpus raise {
  let mut i = 0
  let len = bytes.length()
  let header = []
  while i < len {
    let b = bytes[i]
    i = i + 1
    if b == b'\n' {
      break
    }
    header.push(b)
  }
  let header_text = Bytes::from_array(header).to_string()
  let header_parts = split_tokens(header_text.view())
  if header_parts.length() != 2 {
    panic()
  }
  let _ = parse_int(header_parts[0])
  let dim = parse_int(header_parts[1])
  let records = []
  while i < len {
    if bytes[i] == b'\n' {
      i = i + 1
      continue
    }
    let token_bytes = []
    while i < len && bytes[i] != b' ' {
      token_bytes.push(bytes[i])
      i = i + 1
    }
    if i < len && bytes[i] == b' ' {
      i = i + 1
    }
    let token = Bytes::from_array(token_bytes).to_string()
    let vector = []
    for _ in 0..<dim {
      if i + 3 >= len {
        break
      }
      let b0 = bytes[i].to_int()
      let b1 = bytes[i + 1].to_int()
      let b2 = bytes[i + 2].to_int()
      let b3 = bytes[i + 3].to_int()
      i = i + 4
      let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
      vector.push(Float::reinterpret_from_int(bits).to_double())
    }
    normalize_in_place(vector)
    records.push(EmbeddingRecord::new(token, vector))
    while i < len && bytes[i] != b'\n' {
      i = i + 1
    }
    if i < len && bytes[i] == b'\n' {
      i = i + 1
    }
  }
  EmbeddingCorpus::from_records(records, Word2VecBinary)
}

///|
pub fn MoonEmbedIndex::new(
  corpus : EmbeddingCorpus,
  signature_bits : Int,
) -> MoonEmbedIndex {
  let bucket_count = 1 << signature_bits
  let buckets = build_bucket_table(bucket_count)
  for i in 0..<corpus.records.length() {
    let signature = signature_bits_count(
      signature_bits,
      corpus.records[i].vector,
    )
    buckets[signature].push(i)
  }
  { corpus, buckets, signature_bits }
}

///|
pub fn MoonEmbedIndex::from_corpus(
  corpus : EmbeddingCorpus,
  signature_bits : Int,
) -> MoonEmbedIndex {
  MoonEmbedIndex::new(corpus, signature_bits)
}

///|
pub fn MoonEmbedIndex::describe(self : MoonEmbedIndex) -> String {
  "\{self.corpus.describe()}, signature_bits=\{self.signature_bits}"
}

///|
pub fn MoonEmbedIndex::corpus(self : MoonEmbedIndex) -> EmbeddingCorpus {
  self.corpus
}

///|
fn normalize_query(query : Array[Double]) -> Array[Double] {
  let out = copy_vector(query)
  normalize_in_place(out)
  out
}

///|
fn append_bucket_candidates(
  visited : Array[Bool],
  buckets : Array[Array[Int]],
  signature : Int,
  candidates : Array[Int],
) -> Unit {
  if signature < 0 || signature >= buckets.length() {
    return
  }
  for id in buckets[signature] {
    if !visited[id] {
      visited[id] = true
      candidates.push(id)
    }
  }
}

///|
fn MoonEmbedIndex::collect_candidates(
  self : MoonEmbedIndex,
  signature : Int,
  min_candidates : Int,
) -> Array[Int] {
  let corpus_size = self.corpus.records.length()
  let visited = Array::make(corpus_size, false)
  let candidates = []
  append_bucket_candidates(visited, self.buckets, signature, candidates)
  if candidates.length() < min_candidates {
    for bit in 0..<self.signature_bits {
      append_bucket_candidates(
        visited,
        self.buckets,
        signature ^ (1 << bit),
        candidates,
      )
    }
  }
  if candidates.length() < min_candidates {
    for id in 0..<corpus_size {
      if !visited[id] {
        visited[id] = true
        candidates.push(id)
      }
    }
  }
  candidates
}

///|
fn insert_hit(hits : Array[SearchHit], hit : SearchHit, limit : Int) -> Unit {
  let mut pos = hits.length()
  while pos > 0 && hits[pos - 1].score < hit.score {
    pos = pos - 1
  }
  hits.insert(pos, hit)
  if hits.length() > limit {
    let _ = hits.pop()
  }
}

///|
pub fn MoonEmbedIndex::search_exact(
  self : MoonEmbedIndex,
  query : Array[Double],
  k : Int,
) -> SearchReport {
  let q = normalize_query(query)
  let hits = []
  let mut scanned = 0
  for i in 0..<self.corpus.records.length() {
    let record = self.corpus.records[i]
    insert_hit(hits, { token: record.token, score: dot(q, record.vector) }, k)
    scanned = scanned + 1
  }
  { hits, scanned, candidates: scanned }
}

///|
pub fn MoonEmbedIndex::search(
  self : MoonEmbedIndex,
  query : Array[Double],
  k : Int,
) -> SearchReport {
  let q = normalize_query(query)
  let signature = signature_bits_count(self.signature_bits, q)
  let candidates = self.collect_candidates(signature, 32)
  let hits = []
  let mut scanned = 0
  for id in candidates {
    let record = self.corpus.records[id]
    insert_hit(hits, { token: record.token, score: dot(q, record.vector) }, k)
    scanned = scanned + 1
  }
  { hits, scanned, candidates: candidates.length() }
}

///|
pub fn MoonEmbedIndex::search_token(
  self : MoonEmbedIndex,
  token : String,
  k : Int,
) -> SearchReport {
  match self.corpus.lookup(token) {
    Some(vector) => self.search(vector, k)
    None => { hits: [], scanned: 0, candidates: 0 }
  }
}

///|
pub fn MoonEmbedIndex::search_terms(
  self : MoonEmbedIndex,
  terms : String,
  k : Int,
) -> SearchReport {
  let mut query = []
  let mut seen = 0
  for term in terms.split(" ") {
    let token = term.trim()
    if token.is_empty() {
      continue
    }
    match self.corpus.lookup(token.to_owned()) {
      Some(vector) => {
        if query.is_empty() {
          query = copy_vector(vector)
        } else {
          for i in 0..<query.length() {
            query[i] = query[i] + vector[i]
          }
        }
        seen = seen + 1
      }
      None => ()
    }
  }
  if seen == 0 {
    return { hits: [], scanned: 0, candidates: 0 }
  }
  for i in 0..<query.length() {
    query[i] = query[i] / seen.to_double()
  }
  self.search(query, k)
}

///|
pub fn format_report(report : SearchReport) -> String {
  let mut out = ""
  out = out + "candidates=\{report.candidates}, scanned=\{report.scanned}\n"
  for hit in report.hits {
    out = out + "\{hit.token}\t\{hit.score.to_string()}\n"
  }
  out
}

///|
pub fn demo_corpus() -> EmbeddingCorpus {
  let records = [
    EmbeddingRecord::new("king", [0.92, 0.10, 0.00]),
    EmbeddingRecord::new("queen", [0.90, 0.14, 0.00]),
    EmbeddingRecord::new("apple", [0.00, 0.92, 0.10]),
    EmbeddingRecord::new("orange", [0.00, 0.88, 0.14]),
    EmbeddingRecord::new("code", [0.10, 0.00, 0.95]),
    EmbeddingRecord::new("bug", [0.08, 0.00, 0.92]),
  ]
  let corpus = EmbeddingCorpus::from_records(records, GloVeText)
  corpus
}

///|
pub fn demo_index() -> MoonEmbedIndex {
  MoonEmbedIndex::from_corpus(demo_corpus(), 3)
}

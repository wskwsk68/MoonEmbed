///|
/// A token with its position and normalized text.
pub(all) struct TextToken {
  text : String
  position : Int
  original_length : Int
}

///|
pub fn TextToken::describe(self : TextToken) -> String {
  "\{self.position}:\{self.text}(\{self.original_length})"
}

///|
/// A deterministic, dependency-free tokenizer for small local search systems.
pub(all) struct TextTokenizer {
  lowercase : Bool
  keep_numbers : Bool
  min_length : Int
  stop_words : Map[String, Bool]
}

///|
pub fn TextTokenizer::new(
  lowercase? : Bool = true,
  keep_numbers? : Bool = true,
  min_length? : Int = 1,
  stop_words? : Map[String, Bool] = Map([]),
) -> TextTokenizer {
  { lowercase, keep_numbers, min_length, stop_words }
}

///|
fn is_ascii_digit(value : StringView) -> Bool {
  if value.is_empty() {
    return false
  }
  for ch in value {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}

///|
fn normalize_token(token : StringView, lowercase : Bool) -> String {
  let value = token.trim().to_owned()
  if lowercase {
    value.to_lower()
  } else {
    value
  }
}

///|
pub fn TextTokenizer::tokenize(
  self : TextTokenizer,
  text : String,
) -> Array[TextToken] {
  let result = []
  let mut position = 0
  for part in text.split(" ") {
    let trimmed = part.trim()
    if trimmed.is_empty() {
      continue
    }
    let normalized = normalize_token(trimmed, self.lowercase)
    let numeric = is_ascii_digit(normalized.view())
    if !self.keep_numbers && numeric {
      position = position + 1
      continue
    }
    if normalized.length() < self.min_length {
      position = position + 1
      continue
    }
    if self.stop_words.contains(normalized) {
      position = position + 1
      continue
    }
    result.push({
      text: normalized,
      position,
      original_length: trimmed.length(),
    })
    position = position + 1
  }
  result
}

///|
pub fn TextTokenizer::tokens(
  self : TextTokenizer,
  text : String,
) -> Array[String] {
  let result = []
  for token in self.tokenize(text) {
    result.push(token.text)
  }
  result
}

///|
pub fn TextTokenizer::count(self : TextTokenizer, text : String) -> Int {
  self.tokenize(text).length()
}

///|
pub fn TextTokenizer::contains(
  self : TextTokenizer,
  text : String,
  token : String,
) -> Bool {
  for item in self.tokenize(text) {
    if item.text == token {
      return true
    }
  }
  false
}

///|
/// A weighted bag of tokens used for deterministic query expansion.
pub(all) struct TokenWeights {
  values : Map[String, Double]
  mut total : Double
}

///|
pub fn TokenWeights::new() -> TokenWeights {
  { values: Map([]), total: 0.0 }
}

///|
pub fn TokenWeights::add(
  self : TokenWeights,
  token : String,
  weight : Double,
) -> Unit {
  let current = match self.values.get(token) {
    Some(value) => value
    None => 0.0
  }
  self.values.set(token, current + weight)
  self.total = self.total + weight
}

///|
pub fn TokenWeights::get(self : TokenWeights, token : String) -> Double {
  match self.values.get(token) {
    Some(value) => value
    None => 0.0
  }
}

///|
pub fn TokenWeights::size(self : TokenWeights) -> Int {
  self.values.length()
}

///|
pub fn TokenWeights::normalize(self : TokenWeights) -> TokenWeights {
  if self.total == 0.0 {
    return self
  }
  let output = TokenWeights::new()
  for key, value in self.values {
    output.values.set(key, value / self.total)
  }
  output.total = 1.0
  output
}

///|
pub fn TextTokenizer::weighted_tokens(
  self : TextTokenizer,
  text : String,
) -> TokenWeights {
  let weights = TokenWeights::new()
  let tokens = self.tokenize(text)
  for token in tokens {
    weights.add(token.text, 1.0)
  }
  weights.normalize()
}

///|
/// A phrase query configuration with deterministic token weighting.
pub(all) struct PhraseQuery {
  text : String
  tokens : Array[String]
  weights : Array[Double]
}

///|
pub fn PhraseQuery::new(
  text : String,
  tokenizer : TextTokenizer,
) -> PhraseQuery {
  let tokens = tokenizer.tokens(text)
  let weights = []
  if tokens.is_empty() {
    return { text, tokens, weights }
  }
  let weight = 1.0 / tokens.length().to_double()
  for _ in tokens {
    weights.push(weight)
  }
  { text, tokens, weights }
}

///|
pub fn PhraseQuery::size(self : PhraseQuery) -> Int {
  self.tokens.length()
}

///|
pub fn PhraseQuery::is_empty(self : PhraseQuery) -> Bool {
  self.tokens.is_empty()
}

///|
pub fn PhraseQuery::weight(self : PhraseQuery, index : Int) -> Double {
  match self.weights.get(index) {
    Some(value) => value
    None => 0.0
  }
}

///|
pub fn EmbeddingCorpus::sentence_embedding_with_tokenizer(
  self : EmbeddingCorpus,
  text : String,
  tokenizer : TextTokenizer,
) -> Array[Double]? {
  let tokens = tokenizer.tokens(text)
  if tokens.is_empty() {
    return None
  }
  let output = Array::make(self.dim, 0.0)
  let mut found = 0
  for token in tokens {
    match self.lookup(token) {
      Some(vector) => {
        for i in 0..<self.dim {
          output[i] = output[i] + vector[i]
        }
        found = found + 1
      }
      None => ()
    }
  }
  if found == 0 {
    return None
  }
  for i in 0..<self.dim {
    output[i] = output[i] / found.to_double()
  }
  normalize_in_place(output)
  Some(output)
}

///|
pub fn EmbeddingCorpus::phrase_embedding(
  self : EmbeddingCorpus,
  phrase : PhraseQuery,
) -> Array[Double]? {
  if phrase.is_empty() {
    return None
  }
  let output = Array::make(self.dim, 0.0)
  let mut found = 0.0
  for i in 0..<phrase.tokens.length() {
    match self.lookup(phrase.tokens[i]) {
      Some(vector) => {
        let weight = phrase.weight(i)
        for j in 0..<self.dim {
          output[j] = output[j] + vector[j] * weight
        }
        found = found + weight
      }
      None => ()
    }
  }
  if found == 0.0 {
    return None
  }
  normalize_in_place(output)
  Some(output)
}

///|
pub fn MoonEmbedIndex::search_phrase(
  self : MoonEmbedIndex,
  phrase : PhraseQuery,
  k : Int,
) -> SearchReport {
  match self.corpus.phrase_embedding(phrase) {
    Some(vector) => self.search(vector, k)
    None => { hits: [], scanned: 0, candidates: 0 }
  }
}

///|
pub fn MoonEmbedIndex::search_tokenized(
  self : MoonEmbedIndex,
  text : String,
  tokenizer : TextTokenizer,
  k : Int,
) -> SearchReport {
  match self.corpus.sentence_embedding_with_tokenizer(text, tokenizer) {
    Some(vector) => self.search(vector, k)
    None => { hits: [], scanned: 0, candidates: 0 }
  }
}

///|
/// A compact text preprocessing report for observability.
pub(all) struct TextReport {
  characters : Int
  raw_terms : Int
  retained_terms : Int
  unique_terms : Int
  stop_words : Int
}

///|
pub fn TextReport::describe(self : TextReport) -> String {
  "characters=\{self.characters}, raw_terms=\{self.raw_terms}, retained_terms=\{self.retained_terms}, unique_terms=\{self.unique_terms}, stop_words=\{self.stop_words}"
}

///|
pub fn TextTokenizer::report(self : TextTokenizer, text : String) -> TextReport {
  let unique : Map[String, Bool] = Map([])
  let mut raw = 0
  for part in text.split(" ") {
    if !part.trim().is_empty() {
      raw = raw + 1
    }
  }
  let retained = self.tokenize(text)
  for token in retained {
    unique.set(token.text, true)
  }
  {
    characters: text.length(),
    raw_terms: raw,
    retained_terms: self.count(text),
    unique_terms: unique.length(),
    stop_words: raw - self.count(text),
  }
}

///|
test "text pipeline" {
  let tokenizer = TextTokenizer::new(
    min_length=3,
    stop_words=Map([("the", true)]),
  )
  debug_inspect(
    tokenizer.tokens("the quick fox 42"),
    content="[\"quick\", \"fox\"]",
  )
  inspect(tokenizer.contains("the quick fox", "quick"), content="true")
  inspect(PhraseQuery::new("quick fox", tokenizer).size(), content="2")
  inspect(tokenizer.report("the quick fox").unique_terms, content="2")
}

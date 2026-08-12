///|
/// A configurable score combiner for applications that need explainable ranking.
pub(all) struct ScoreProfile {
  lexical_weight : Double
  semantic_weight : Double
  freshness_weight : Double
  popularity_weight : Double
}

///|
pub fn ScoreProfile::balanced() -> ScoreProfile {
  {
    lexical_weight: 0.25,
    semantic_weight: 0.55,
    freshness_weight: 0.10,
    popularity_weight: 0.10,
  }
}

///|
pub fn ScoreProfile::semantic_only() -> ScoreProfile {
  {
    lexical_weight: 0.0,
    semantic_weight: 1.0,
    freshness_weight: 0.0,
    popularity_weight: 0.0,
  }
}

///|
pub fn ScoreProfile::sum(self : ScoreProfile) -> Double {
  self.lexical_weight +
  self.semantic_weight +
  self.freshness_weight +
  self.popularity_weight
}

///|
pub fn ScoreProfile::normalized(self : ScoreProfile) -> ScoreProfile {
  let total = self.sum()
  if total == 0.0 {
    return ScoreProfile::semantic_only()
  }
  {
    lexical_weight: self.lexical_weight / total,
    semantic_weight: self.semantic_weight / total,
    freshness_weight: self.freshness_weight / total,
    popularity_weight: self.popularity_weight / total,
  }
}

///|
/// A bounded, explainable component score.
pub(all) struct ScoreComponents {
  lexical : Double
  semantic : Double
  freshness : Double
  popularity : Double
}

///|
pub fn ScoreComponents::clamp(self : ScoreComponents) -> ScoreComponents {
  {
    lexical: if self.lexical < 0.0 {
      0.0
    } else if self.lexical > 1.0 {
      1.0
    } else {
      self.lexical
    },
    semantic: if self.semantic < 0.0 {
      0.0
    } else if self.semantic > 1.0 {
      1.0
    } else {
      self.semantic
    },
    freshness: if self.freshness < 0.0 {
      0.0
    } else if self.freshness > 1.0 {
      1.0
    } else {
      self.freshness
    },
    popularity: if self.popularity < 0.0 {
      0.0
    } else if self.popularity > 1.0 {
      1.0
    } else {
      self.popularity
    },
  }
}

///|
pub fn ScoreComponents::combine(
  self : ScoreComponents,
  profile : ScoreProfile,
) -> Double {
  let value = self.clamp()
  let weights = profile.normalized()
  value.lexical * weights.lexical_weight +
  value.semantic * weights.semantic_weight +
  value.freshness * weights.freshness_weight +
  value.popularity * weights.popularity_weight
}

///|
pub fn ScoreComponents::describe(self : ScoreComponents) -> String {
  "lexical=\{self.lexical.to_string()}, semantic=\{self.semantic.to_string()}, freshness=\{self.freshness.to_string()}, popularity=\{self.popularity.to_string()}"
}

///|
/// A ranked token with its component-level explanation.
pub(all) struct ExplainedHit {
  token : String
  score : Double
  components : ScoreComponents
}

///|
pub fn ExplainedHit::describe(self : ExplainedHit) -> String {
  "\{self.token}\t\{self.score.to_string()}\t\{self.components.describe()}"
}

///|
pub fn MoonEmbedIndex::search_explained(
  self : MoonEmbedIndex,
  query : Array[Double],
  k : Int,
  profile : ScoreProfile,
) -> Array[ExplainedHit] {
  let report = self.search(query, k)
  let result = []
  for hit in report.hits {
    let components = {
      lexical: 0.0,
      semantic: hit.score,
      freshness: 0.0,
      popularity: 0.0,
    }
    result.push({
      token: hit.token,
      score: components.combine(profile),
      components,
    })
  }
  result
}

///|
/// A reusable score threshold policy.
pub(all) struct ThresholdPolicy {
  minimum_score : Double
  maximum_results : Int
  require_nonempty : Bool
}

///|
pub fn ThresholdPolicy::new(
  minimum_score? : Double = 0.0,
  maximum_results? : Int = 10,
  require_nonempty? : Bool = false,
) -> ThresholdPolicy {
  { minimum_score, maximum_results, require_nonempty }
}

///|
pub fn ThresholdPolicy::accept(self : ThresholdPolicy, score : Double) -> Bool {
  score >= self.minimum_score
}

///|
pub fn ThresholdPolicy::valid(self : ThresholdPolicy) -> Bool {
  self.maximum_results > 0 &&
  self.minimum_score >= -1.0 &&
  self.minimum_score <= 1.0
}

///|
pub fn SearchReport::apply_policy(
  self : SearchReport,
  policy : ThresholdPolicy,
) -> SearchReport {
  let hits = []
  if !policy.valid() {
    return { ..self, hits: [] }
  }
  for hit in self.hits {
    if hits.length() >= policy.maximum_results {
      break
    }
    if policy.accept(hit.score) {
      hits.push(hit)
    }
  }
  if policy.require_nonempty && hits.is_empty() {
    return { ..self, hits: [] }
  }
  { ..self, hits, }
}

///|
/// A list of token ids with stable insertion order and duplicate suppression.
pub(all) struct TokenSet {
  values : Map[String, Bool]
  order : Array[String]
}

///|
pub fn TokenSet::new() -> TokenSet {
  { values: Map([]), order: [] }
}

///|
pub fn TokenSet::add(self : TokenSet, token : String) -> Bool {
  if self.values.contains(token) {
    return false
  }
  self.values.set(token, true)
  self.order.push(token)
  true
}

///|
pub fn TokenSet::remove(self : TokenSet, token : String) -> Bool {
  if !self.values.contains(token) {
    return false
  }
  self.values.remove(token)
  for i in 0..<self.order.length() {
    if self.order[i] == token {
      let _ = self.order.remove(i)
      break
    }
  }
  true
}

///|
pub fn TokenSet::contains(self : TokenSet, token : String) -> Bool {
  self.values.contains(token)
}

///|
pub fn TokenSet::size(self : TokenSet) -> Int {
  self.order.length()
}

///|
pub fn TokenSet::to_array(self : TokenSet) -> Array[String] {
  let result = []
  for token in self.order {
    result.push(token)
  }
  result
}

///|
pub fn TokenSet::union(self : TokenSet, other : TokenSet) -> TokenSet {
  let result = TokenSet::new()
  for token in self.order {
    let _ = result.add(token)
  }
  for token in other.order {
    let _ = result.add(token)
  }
  result
}

///|
pub fn TokenSet::intersection(self : TokenSet, other : TokenSet) -> TokenSet {
  let result = TokenSet::new()
  for token in self.order {
    if other.contains(token) {
      let _ = result.add(token)
    }
  }
  result
}

///|
pub fn TokenSet::difference(self : TokenSet, other : TokenSet) -> TokenSet {
  let result = TokenSet::new()
  for token in self.order {
    if !other.contains(token) {
      let _ = result.add(token)
    }
  }
  result
}

///|
/// A document-level filter that can combine category and token predicates.
pub(all) struct DocumentFilter {
  category : String?
  required_tokens : Array[String]
  excluded_tokens : Array[String]
}

///|
pub fn DocumentFilter::empty() -> DocumentFilter {
  { category: None, required_tokens: [], excluded_tokens: [] }
}

///|
pub fn DocumentFilter::with_category(
  self : DocumentFilter,
  category : String,
) -> DocumentFilter {
  { ..self, category: Some(category) }
}

///|
pub fn DocumentFilter::require(
  self : DocumentFilter,
  token : String,
) -> DocumentFilter {
  let required = []
  for value in self.required_tokens {
    required.push(value)
  }
  required.push(token)
  { ..self, required_tokens: required }
}

///|
pub fn DocumentFilter::exclude(
  self : DocumentFilter,
  token : String,
) -> DocumentFilter {
  let excluded = []
  for value in self.excluded_tokens {
    excluded.push(value)
  }
  excluded.push(token)
  { ..self, excluded_tokens: excluded }
}

///|
pub fn DocumentFilter::describe(self : DocumentFilter) -> String {
  let category = match self.category {
    Some(value) => value
    None => "*"
  }
  "category=\{category}, required=\{self.required_tokens.length()}, excluded=\{self.excluded_tokens.length()}"
}

///|
pub fn DocumentFilter::matches(
  self : DocumentFilter,
  document : Document,
  tokenizer : TextTokenizer,
) -> Bool {
  match self.category {
    Some(value) =>
      match document.metadata.get("category") {
        Some(actual) => if actual != value { return false }
        None => return false
      }
    None => ()
  }
  let tokens = TokenSet::new()
  for token in tokenizer.tokens(document.text) {
    let _ = tokens.add(token)
  }
  for token in self.required_tokens {
    if !tokens.contains(token) {
      return false
    }
  }
  for token in self.excluded_tokens {
    if tokens.contains(token) {
      return false
    }
  }
  true
}

///|
pub fn DocumentStore::filter(
  self : DocumentStore,
  filter : DocumentFilter,
  tokenizer : TextTokenizer,
) -> Array[Document] {
  let result = []
  for document in self.docs {
    if filter.matches(document, tokenizer) {
      result.push(document)
    }
  }
  result
}

///|
/// A ranked document result for applications that need stable ids.
pub(all) struct RankedDocument {
  id : String
  score : Double
  category : String
}

///|
pub fn RankedDocument::describe(self : RankedDocument) -> String {
  "\{self.id}\t\{self.score.to_string()}\t\{self.category}"
}

///|
pub fn DocumentStore::ranked_search(
  self : DocumentStore,
  query : Array[Double],
  filter_key : String?,
  filter_value : String?,
  k : Int,
) -> Array[RankedDocument] {
  let result = []
  if k <= 0 {
    return result
  }
  let normalized = normalize_query(query)
  for document in self.docs {
    let allowed = match (filter_key, filter_value) {
      (Some(key), Some(value)) =>
        match document.metadata.get(key) {
          Some(actual) => actual == value
          None => false
        }
      _ => true
    }
    if !allowed {
      continue
    }
    match document.vector {
      Some(vector) => {
        let score = dot(normalized, vector)
        let category = match document.metadata.get("category") {
          Some(value) => value
          None => "uncategorized"
        }
        let item = { id: document.id, score, category }
        let mut position = result.length()
        while position > 0 && result[position - 1].score < score {
          position = position - 1
        }
        result.insert(position, item)
        if result.length() > k {
          let _ = result.pop()
        }
      }
      None => ()
    }
  }
  result
}

///|
pub fn DocumentStore::categories(self : DocumentStore) -> Array[String] {
  let result = TokenSet::new()
  for document in self.docs {
    match document.metadata.get("category") {
      Some(value) => {
        let _ = result.add(value)
      }
      None => ()
    }
  }
  result.to_array()
}

///|
pub fn DocumentStore::count_category(
  self : DocumentStore,
  category : String,
) -> Int {
  let mut total = 0
  for document in self.docs {
    match document.metadata.get("category") {
      Some(value) => if value == category { total = total + 1 }
      None => ()
    }
  }
  total
}

///|
pub fn DocumentStore::texts(self : DocumentStore) -> Array[String] {
  let result = []
  for document in self.docs {
    result.push(document.text)
  }
  result
}

///|
pub fn DocumentStore::metadata_values(
  self : DocumentStore,
  key : String,
) -> Array[String] {
  let result = []
  for document in self.docs {
    match document.metadata.get(key) {
      Some(value) => result.push(value)
      None => ()
    }
  }
  result
}

///|
pub(all) struct RankingSummary {
  total : Int
  nonempty : Int
  top_score : Double
  average_score : Double
}

///|
pub fn RankingSummary::describe(self : RankingSummary) -> String {
  "total=\{self.total}, nonempty=\{self.nonempty}, top_score=\{self.top_score.to_string()}, average_score=\{self.average_score.to_string()}"
}

///|
pub fn summarize_reports(reports : Array[SearchReport]) -> RankingSummary {
  let mut nonempty = 0
  let mut top = 0.0
  let mut total = 0.0
  for report in reports {
    if !report.hits.is_empty() {
      nonempty = nonempty + 1
      if report.hits[0].score > top {
        top = report.hits[0].score
      }
      total = total + report.hits[0].score
    }
  }
  {
    total: reports.length(),
    nonempty,
    top_score: top,
    average_score: if nonempty == 0 {
      0.0
    } else {
      total / nonempty.to_double()
    },
  }
}

///|
test "ranking and filter tools" {
  let profile = ScoreProfile::balanced()
  inspect(profile.normalized().sum() > 0.99, content="true")
  inspect(
    ScoreComponents::combine(
      { lexical: 1.0, semantic: 0.5, freshness: 0.0, popularity: 0.0 },
      profile,
    ) >
    0.0,
    content="true",
  )
  let policy = ThresholdPolicy::new(minimum_score=0.5, maximum_results=1)
  inspect(policy.valid(), content="true")
  inspect(
    demo_index().search([1.0, 0.0, 0.0], 3).apply_policy(policy).hits.length(),
    content="1",
  )
  let left = TokenSet::new()
  let _ = left.add("a")
  let _ = left.add("b")
  let right = TokenSet::new()
  let _ = right.add("b")
  let _ = right.add("c")
  inspect(left.union(right).size(), content="3")
  inspect(left.intersection(right).size(), content="1")
  inspect(left.difference(right).size(), content="1")
  let tokenizer = TextTokenizer::new()
  let filter = DocumentFilter::empty().require("king")
  let document = Document::new("one", "king queen")
  inspect(filter.matches(document, tokenizer), content="true")
}

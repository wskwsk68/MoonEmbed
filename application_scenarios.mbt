///|
/// Application-level ingestion status.
pub(all) enum IngestionStatus {
  Accepted
  Rejected
  Skipped
}

///|
pub fn IngestionStatus::label(self : IngestionStatus) -> String {
  match self {
    Accepted => "accepted"
    Rejected => "rejected"
    Skipped => "skipped"
  }
}

///|
/// A single ingestion diagnostic that can be shown to an operator.
pub(all) struct IngestionIssue {
  code : String
  message : String
  document_id : String
}

///|
pub fn IngestionIssue::describe(self : IngestionIssue) -> String {
  "\{self.document_id}: \{self.code}: \{self.message}"
}

///|
/// Result for one document entering an application knowledge base.
pub(all) struct IngestionResult {
  document_id : String
  status : IngestionStatus
  token_count : Int
  known_token_count : Int
  issues : Array[IngestionIssue]
}

///|
pub fn IngestionResult::accepted(self : IngestionResult) -> Bool {
  self.status is Accepted
}

///|
pub fn IngestionResult::describe(self : IngestionResult) -> String {
  "\{self.document_id}: \{self.status.label()}, tokens=\{self.token_count}, known=\{self.known_token_count}, issues=\{self.issues.length()}"
}

///|
/// Rules for deterministic, bounded document ingestion.
pub(all) struct IngestionPolicy {
  max_documents : Int
  min_tokens : Int
  require_category : Bool
  reject_unknown_only : Bool
  replace_existing : Bool
}

///|
pub fn IngestionPolicy::conservative() -> IngestionPolicy {
  {
    max_documents: 10000,
    min_tokens: 1,
    require_category: false,
    reject_unknown_only: true,
    replace_existing: true,
  }
}

///|
pub fn IngestionPolicy::demo() -> IngestionPolicy {
  {
    max_documents: 100,
    min_tokens: 1,
    require_category: false,
    reject_unknown_only: false,
    replace_existing: true,
  }
}

///|
pub fn IngestionPolicy::valid(self : IngestionPolicy) -> Bool {
  self.max_documents > 0 && self.min_tokens >= 0
}

///|
pub fn IngestionPolicy::describe(self : IngestionPolicy) -> String {
  "max_documents=\{self.max_documents}, min_tokens=\{self.min_tokens}, require_category=\{self.require_category}, reject_unknown_only=\{self.reject_unknown_only}, replace_existing=\{self.replace_existing}"
}

///|
/// A query submitted by an application user.
pub(all) struct ApplicationQuery {
  text : String
  k : Int
  filter : DocumentFilter
  threshold : Double?
}

///|
pub fn ApplicationQuery::new(
  text : String,
  k? : Int = 5,
  filter? : DocumentFilter = DocumentFilter::empty(),
  threshold? : Double,
) -> ApplicationQuery {
  { text, k, filter, threshold }
}

///|
pub fn ApplicationQuery::valid(self : ApplicationQuery) -> Bool {
  !self.text.trim().is_empty() && self.k > 0
}

///|
pub fn ApplicationQuery::describe(self : ApplicationQuery) -> String {
  let threshold = match self.threshold {
    Some(value) => value.to_string()
    None => "none"
  }
  "text=\"\{self.text}\", k=\{self.k}, threshold=\{threshold}, \{self.filter.describe()}"
}

///|
/// A stable result returned by an application knowledge base.
pub(all) struct ApplicationHit {
  document : Document
  score : Double
  rank : Int
}

///|
pub fn ApplicationHit::id(self : ApplicationHit) -> String {
  self.document.id
}

///|
pub fn ApplicationHit::text(self : ApplicationHit) -> String {
  self.document.text
}

///|
pub fn ApplicationHit::score(self : ApplicationHit) -> Double {
  self.score
}

///|
pub fn ApplicationHit::category(self : ApplicationHit) -> String {
  match self.document.metadata.get("category") {
    Some(value) => value
    None => "uncategorized"
  }
}

///|
pub fn ApplicationHit::describe(self : ApplicationHit) -> String {
  "\{self.rank}. \{self.id()} score=\{self.score.to_string()} category=\{self.category()}"
}

///|
/// A complete application query report with observability fields.
pub(all) struct ApplicationSearchReport {
  query : ApplicationQuery
  hits : Array[ApplicationHit]
  candidates : Int
  scanned : Int
  unknown_terms : Int
  filtered_documents : Int
}

///|
pub fn ApplicationSearchReport::is_empty(
  self : ApplicationSearchReport,
) -> Bool {
  self.hits.is_empty()
}

///|
pub fn ApplicationSearchReport::top(
  self : ApplicationSearchReport,
) -> ApplicationHit? {
  self.hits.get(0)
}

///|
pub fn ApplicationSearchReport::ids(
  self : ApplicationSearchReport,
) -> Array[String] {
  let result = []
  for hit in self.hits {
    result.push(hit.id())
  }
  result
}

///|
pub fn ApplicationSearchReport::describe(
  self : ApplicationSearchReport,
) -> String {
  let mut output = "query={self.query.describe()}\n"
  output = output +
    "hits={self.hits.length()}, candidates={self.candidates}, scanned={self.scanned}, unknown_terms={self.unknown_terms}, filtered_documents={self.filtered_documents}\n"
  for hit in self.hits {
    output = output + hit.describe() + "\n"
  }
  output
}

///|
/// Query history record used by CLI and embedded application shells.
pub(all) struct QueryEvent {
  sequence : Int
  query : ApplicationQuery
  result_count : Int
  top_score : Double
  candidates : Int
}

///|
pub fn QueryEvent::describe(self : QueryEvent) -> String {
  "#\{self.sequence} results=\{self.result_count}, top_score=\{self.top_score.to_string()}, candidates=\{self.candidates}, text=\"\{self.query.text}\""
}

///|
/// A bounded query history with usage counters.
pub(all) struct QuerySession {
  name : String
  max_events : Int
  events : Array[QueryEvent]
  mut next_sequence : Int
}

///|
pub fn QuerySession::new(
  name : String,
  max_events? : Int = 100,
) -> QuerySession {
  { name, max_events, events: [], next_sequence: 1 }
}

///|
pub fn QuerySession::record(
  self : QuerySession,
  query : ApplicationQuery,
  report : ApplicationSearchReport,
) -> Unit {
  let top_score = match report.top() {
    Some(hit) => hit.score()
    None => 0.0
  }
  self.events.push({
    sequence: self.next_sequence,
    query,
    result_count: report.hits.length(),
    top_score,
    candidates: report.candidates,
  })
  self.next_sequence = self.next_sequence + 1
  if self.max_events > 0 {
    while self.events.length() > self.max_events {
      let _ = self.events.remove(0)
    }
  }
}

///|
pub fn QuerySession::size(self : QuerySession) -> Int {
  self.events.length()
}

///|
pub fn QuerySession::clear(self : QuerySession) -> Unit {
  while !self.events.is_empty() {
    let _ = self.events.pop()
  }
}

///|
pub fn QuerySession::last(self : QuerySession) -> QueryEvent? {
  if self.events.is_empty() {
    None
  } else {
    self.events.get(self.events.length() - 1)
  }
}

///|
pub fn QuerySession::history(self : QuerySession) -> Array[QueryEvent] {
  let result = []
  for event in self.events {
    result.push(event)
  }
  result
}

///|
pub fn QuerySession::describe(self : QuerySession) -> String {
  let mut output = "session={self.name}, events={self.events.length()}\n"
  for event in self.events {
    output = output + event.describe() + "\n"
  }
  output
}

///|
/// Counters exposed to a health endpoint or CLI status command.
pub(all) struct UsageCounters {
  mut ingestion_attempts : Int
  mut accepted_documents : Int
  mut rejected_documents : Int
  mut skipped_documents : Int
  mut query_attempts : Int
  mut empty_queries : Int
  mut returned_hits : Int
  mut scanned_candidates : Int
}

///|
pub fn UsageCounters::new() -> UsageCounters {
  {
    ingestion_attempts: 0,
    accepted_documents: 0,
    rejected_documents: 0,
    skipped_documents: 0,
    query_attempts: 0,
    empty_queries: 0,
    returned_hits: 0,
    scanned_candidates: 0,
  }
}

///|
pub fn UsageCounters::record_ingestion(
  self : UsageCounters,
  result : IngestionResult,
) -> Unit {
  self.ingestion_attempts = self.ingestion_attempts + 1
  match result.status {
    Accepted => self.accepted_documents = self.accepted_documents + 1
    Rejected => self.rejected_documents = self.rejected_documents + 1
    Skipped => self.skipped_documents = self.skipped_documents + 1
  }
}

///|
pub fn UsageCounters::record_query(
  self : UsageCounters,
  report : ApplicationSearchReport,
) -> Unit {
  self.query_attempts = self.query_attempts + 1
  if report.hits.is_empty() {
    self.empty_queries = self.empty_queries + 1
  }
  self.returned_hits = self.returned_hits + report.hits.length()
  self.scanned_candidates = self.scanned_candidates + report.scanned
}

///|
pub fn UsageCounters::describe(self : UsageCounters) -> String {
  "ingestion=\{self.ingestion_attempts}, accepted=\{self.accepted_documents}, rejected=\{self.rejected_documents}, skipped=\{self.skipped_documents}, queries=\{self.query_attempts}, empty_queries=\{self.empty_queries}, returned_hits=\{self.returned_hits}, scanned=\{self.scanned_candidates}"
}

///|
/// A small application knowledge base built on the core embedding index.
pub(all) struct ApplicationKnowledgeBase {
  corpus : EmbeddingCorpus
  index : MoonEmbedIndex
  store : DocumentStore
  tokenizer : TextTokenizer
  policy : IngestionPolicy
  session : QuerySession
  counters : UsageCounters
}

///|
pub fn ApplicationKnowledgeBase::new(
  corpus : EmbeddingCorpus,
  signature_bits? : Int = 3,
  tokenizer? : TextTokenizer = TextTokenizer::new(),
  policy? : IngestionPolicy = IngestionPolicy::conservative(),
  session_name? : String = "default",
) -> ApplicationKnowledgeBase {
  {
    corpus,
    index: MoonEmbedIndex::from_corpus(corpus, signature_bits),
    store: DocumentStore::new(),
    tokenizer,
    policy,
    session: QuerySession::new(session_name),
    counters: UsageCounters::new(),
  }
}

///|
fn count_known_tokens(
  corpus : EmbeddingCorpus,
  tokenizer : TextTokenizer,
  text : String,
) -> (Int, Int) {
  let tokens = tokenizer.tokens(text)
  let mut known = 0
  for token in tokens {
    if corpus.has_token(token) {
      known = known + 1
    }
  }
  (tokens.length(), known)
}

///|
fn make_ingestion_issue(
  document : Document,
  code : String,
  message : String,
) -> IngestionIssue {
  { code, message, document_id: document.id }
}

///|
/// Validate a document against the current policy before adding it.
pub fn ApplicationKnowledgeBase::validate_document(
  self : ApplicationKnowledgeBase,
  document : Document,
) -> IngestionResult {
  let counts = count_known_tokens(self.corpus, self.tokenizer, document.text)
  let issues = []
  if document.id.trim().is_empty() {
    issues.push(
      make_ingestion_issue(document, "empty-id", "document id is required"),
    )
  }
  if counts.0 < self.policy.min_tokens {
    issues.push(
      make_ingestion_issue(
        document, "too-short", "document has too few retained tokens",
      ),
    )
  }
  if self.policy.require_category && document.metadata.get("category") is None {
    issues.push(
      make_ingestion_issue(
        document, "missing-category", "category metadata is required",
      ),
    )
  }
  if self.policy.reject_unknown_only && counts.0 > 0 && counts.1 == 0 {
    issues.push(
      make_ingestion_issue(
        document, "unknown-only", "no document tokens exist in the embedding corpus",
      ),
    )
  }
  let status = if issues.is_empty() { Accepted } else { Rejected }
  {
    document_id: document.id,
    status,
    token_count: counts.0,
    known_token_count: counts.1,
    issues,
  }
}

///|
/// Add or skip one document according to policy and return an audit result.
pub fn ApplicationKnowledgeBase::ingest(
  self : ApplicationKnowledgeBase,
  document : Document,
) -> IngestionResult {
  let validation = self.validate_document(document)
  if validation.status is Rejected {
    self.counters.record_ingestion(validation)
    return validation
  }
  if self.store.size() >= self.policy.max_documents {
    let skipped = {
      ..validation,
      status: Skipped,
      issues: [
        make_ingestion_issue(
          document, "capacity", "document policy capacity reached",
        ),
      ],
    }
    self.counters.record_ingestion(skipped)
    return skipped
  }
  if !self.policy.replace_existing && self.store.get(document.id) is Some(_) {
    let skipped = {
      ..validation,
      status: Skipped,
      issues: [
        make_ingestion_issue(
          document, "duplicate", "existing document is preserved",
        ),
      ],
    }
    self.counters.record_ingestion(skipped)
    return skipped
  }
  let _ = self.store.upsert(document, self.corpus)
  self.counters.record_ingestion(validation)
  validation
}

///|
/// Ingest a batch while preserving input order and returning per-document audit records.
pub fn ApplicationKnowledgeBase::ingest_many(
  self : ApplicationKnowledgeBase,
  documents : Array[Document],
) -> Array[IngestionResult] {
  let results = []
  for document in documents {
    results.push(self.ingest(document))
  }
  results
}

///|
/// Run a filtered semantic query through the application layer.
pub fn ApplicationKnowledgeBase::search(
  self : ApplicationKnowledgeBase,
  query : ApplicationQuery,
) -> ApplicationSearchReport {
  self.counters.query_attempts = self.counters.query_attempts + 1
  if !query.valid() {
    self.counters.empty_queries = self.counters.empty_queries + 1
    return {
      query,
      hits: [],
      candidates: 0,
      scanned: 0,
      unknown_terms: 0,
      filtered_documents: self.store.size(),
    }
  }
  let phrase = PhraseQuery::new(query.text, self.tokenizer)
  let embedding = self.corpus.phrase_embedding(phrase)
  match embedding {
    None => {
      self.counters.empty_queries = self.counters.empty_queries + 1
      {
        query,
        hits: [],
        candidates: 0,
        scanned: 0,
        unknown_terms: phrase.size(),
        filtered_documents: self.store.size(),
      }
    }
    Some(vector) => {
      let filtered = self.store.filter(query.filter, self.tokenizer)
      let hits = self.store.ranked_search(vector, None, None, self.store.size())
      let allowed : Map[String, Bool] = Map([])
      for document in filtered {
        allowed.set(document.id, true)
      }
      let application_hits = []
      for ranked in hits {
        if !allowed.contains(ranked.id) {
          continue
        }
        let document = match self.store.get(ranked.id) {
          Some(value) => value
          None => continue
        }
        if query.threshold is Some(threshold) && ranked.score < threshold {
          continue
        }
        if application_hits.length() < query.k {
          application_hits.push({
            document,
            score: ranked.score,
            rank: application_hits.length() + 1,
          })
        }
      }
      self.counters.returned_hits = self.counters.returned_hits +
        application_hits.length()
      self.counters.scanned_candidates = self.counters.scanned_candidates +
        hits.length()
      let report = {
        query,
        hits: application_hits,
        candidates: hits.length(),
        scanned: hits.length(),
        unknown_terms: phrase.size() - filtered.length(),
        filtered_documents: self.store.size() - filtered.length(),
      }
      self.session.record(query, report)
      report
    }
  }
}

///|
/// Retrieve a query history snapshot for an operator.
pub fn ApplicationKnowledgeBase::history(
  self : ApplicationKnowledgeBase,
) -> Array[QueryEvent] {
  self.session.history()
}

///|
/// Retrieve usage counters for diagnostics.
pub fn ApplicationKnowledgeBase::usage(
  self : ApplicationKnowledgeBase,
) -> UsageCounters {
  self.counters
}

///|
/// Return a health summary for a readiness or liveness command.
pub fn ApplicationKnowledgeBase::health(
  self : ApplicationKnowledgeBase,
) -> String {
  let corpus_report = validate_corpus(self.corpus)
  let diagnostics = self.index.diagnostics()
  "corpus=\{corpus_report.summary()}\nindex=\{diagnostics.describe()}\nstore_documents=\{self.store.size()}\npolicy=\{self.policy.describe()}\nusage=\{self.counters.describe()}"
}

///|
/// Export application documents as a deterministic line-oriented snapshot.
pub fn ApplicationKnowledgeBase::export_documents(
  self : ApplicationKnowledgeBase,
) -> String {
  let mut output = "id\tcategory\ttext\n"
  for document in self.store.docs {
    let category = match document.metadata.get("category") {
      Some(value) => value
      None => ""
    }
    output = output +
      document.id +
      "\t" +
      category +
      "\t" +
      document.text +
      "\n"
  }
  output
}

///|
/// Return the current document ids for administration and audit views.
pub fn ApplicationKnowledgeBase::document_ids(
  self : ApplicationKnowledgeBase,
) -> Array[String] {
  self.store.ids()
}

///|
/// Return the current number of accepted documents.
pub fn ApplicationKnowledgeBase::document_count(
  self : ApplicationKnowledgeBase,
) -> Int {
  self.store.size()
}

///|
/// Return sorted-by-insertion category labels used by the knowledge base.
pub fn ApplicationKnowledgeBase::categories(
  self : ApplicationKnowledgeBase,
) -> Array[String] {
  self.store.categories()
}

///|
/// Execute independent queries while keeping their input order.
pub fn ApplicationKnowledgeBase::search_many(
  self : ApplicationKnowledgeBase,
  queries : Array[ApplicationQuery],
) -> Array[ApplicationSearchReport] {
  let reports = []
  for query in queries {
    reports.push(self.search(query))
  }
  reports
}

///|
/// Clear only the interactive session while retaining the indexed documents.
pub fn ApplicationKnowledgeBase::reset_session(
  self : ApplicationKnowledgeBase,
) -> Unit {
  self.session.clear()
}

///|
/// Return a compact health flag suitable for a readiness probe.
pub fn ApplicationKnowledgeBase::ready(self : ApplicationKnowledgeBase) -> Bool {
  self.policy.valid() &&
  self.corpus.validate() &&
  self.index.corpus().validate()
}

///|
/// Aggregate the outcome of multiple independent acceptance scenarios.
pub(all) struct ScenarioMatrixReport {
  scenarios : Int
  passed : Int
  total_documents : Int
  total_queries : Int
  total_rejected : Int
  total_skipped : Int
}

///|
pub fn ScenarioMatrixReport::all_passed(self : ScenarioMatrixReport) -> Bool {
  self.scenarios > 0 && self.passed == self.scenarios
}

///|
pub fn ScenarioMatrixReport::describe(self : ScenarioMatrixReport) -> String {
  "scenarios=\{self.scenarios}, passed=\{self.passed}, documents=\{self.total_documents}, queries=\{self.total_queries}, rejected=\{self.total_rejected}, skipped=\{self.total_skipped}, all_passed=\{self.all_passed()}"
}

///|
pub fn run_scenario_matrix() -> ScenarioMatrixReport {
  let reports = run_application_scenarios()
  let mut passed = 0
  let mut documents = 0
  let mut queries = 0
  let mut rejected = 0
  let mut skipped = 0
  for report in reports {
    if report.passed() {
      passed = passed + 1
    }
    documents = documents + report.ingested
    queries = queries + report.queries
    rejected = rejected + report.rejected
    skipped = skipped + report.skipped
  }
  {
    scenarios: reports.length(),
    passed,
    total_documents: documents,
    total_queries: queries,
    total_rejected: rejected,
    total_skipped: skipped,
  }
}

///|
/// Create a compact report for a reproducible application scenario.
pub(all) struct ScenarioReport {
  name : String
  ingested : Int
  rejected : Int
  skipped : Int
  queries : Int
  nonempty_queries : Int
  expected_matches : Int
  observed_matches : Int
  expected_rejected : Int
  expected_skipped : Int
}

///|
pub fn ScenarioReport::passed(self : ScenarioReport) -> Bool {
  self.rejected == self.expected_rejected &&
  self.skipped == self.expected_skipped &&
  self.expected_matches == self.observed_matches
}

///|
pub fn ScenarioReport::describe(self : ScenarioReport) -> String {
  "\{self.name}: ingested=\{self.ingested}, rejected=\{self.rejected}, skipped=\{self.skipped}, queries=\{self.queries}, nonempty=\{self.nonempty_queries}, expected=\{self.expected_matches}, observed=\{self.observed_matches}, passed=\{self.passed()}"
}

///|
/// Build a realistic product-support knowledge base with metadata filters.
pub fn support_knowledge_base() -> ApplicationKnowledgeBase {
  let policy = IngestionPolicy::conservative()
  let tokenizer = TextTokenizer::new(
    lowercase=true,
    min_length=2,
    stop_words=Map([("the", true), ("and", true), ("is", true)]),
  )
  ApplicationKnowledgeBase::new(
    demo_corpus(),
    signature_bits=3,
    tokenizer~,
    policy~,
    session_name="support-demo",
  )
}

///|
pub fn run_support_scenario() -> ScenarioReport {
  let knowledge = support_knowledge_base()
  let documents = [
    Document::new(
      "support-royal",
      "king queen",
      metadata=Map([("category", "account")]),
    ),
    Document::new(
      "support-fruit",
      "apple orange",
      metadata=Map([("category", "billing")]),
    ),
    Document::new(
      "support-code",
      "code bug",
      metadata=Map([("category", "technical")]),
    ),
  ]
  let ingested = knowledge.ingest_many(documents)
  let mut accepted = 0
  let mut rejected = 0
  let mut skipped = 0
  for result in ingested {
    match result.status {
      Accepted => accepted = accepted + 1
      Rejected => rejected = rejected + 1
      Skipped => skipped = skipped + 1
    }
  }
  let queries = [
    ApplicationQuery::new(
      "king",
      k=1,
      filter=DocumentFilter::empty().with_category("account"),
    ),
    ApplicationQuery::new(
      "apple",
      k=1,
      filter=DocumentFilter::empty().with_category("billing"),
    ),
    ApplicationQuery::new(
      "code",
      k=1,
      filter=DocumentFilter::empty().with_category("technical"),
    ),
  ]
  let mut nonempty = 0
  let mut observed = 0
  for query in queries {
    let report = knowledge.search(query)
    if !report.is_empty() {
      nonempty = nonempty + 1
    }
    observed = observed + report.hits.length()
  }
  {
    name: "support-knowledge-base",
    ingested: accepted,
    rejected,
    skipped,
    queries: 3,
    nonempty_queries: nonempty,
    expected_matches: 3,
    observed_matches: observed,
    expected_rejected: 0,
    expected_skipped: 0,
  }
}

///|
/// Build a realistic local documentation search scenario.
pub fn run_documentation_scenario() -> ScenarioReport {
  let knowledge = ApplicationKnowledgeBase::new(
    demo_corpus(),
    tokenizer=TextTokenizer::new(min_length=2),
    policy={ ..IngestionPolicy::demo(), reject_unknown_only: true },
    session_name="docs-demo",
  )
  let documents = [
    Document::new("docs-1", "king queen", metadata=Map([("category", "guide")])),
    Document::new(
      "docs-2",
      "apple orange",
      metadata=Map([("category", "reference")]),
    ),
    Document::new(
      "docs-3",
      "code bug",
      metadata=Map([("category", "troubleshooting")]),
    ),
    Document::new(
      "docs-4",
      "unknown words",
      metadata=Map([("category", "invalid")]),
    ),
  ]
  let results = knowledge.ingest_many(documents)
  let mut accepted = 0
  let mut rejected = 0
  let mut skipped = 0
  for result in results {
    match result.status {
      Accepted => accepted = accepted + 1
      Rejected => rejected = rejected + 1
      Skipped => skipped = skipped + 1
    }
  }
  let q1 = knowledge.search(ApplicationQuery::new("king", k=2))
  let q2 = knowledge.search(ApplicationQuery::new("unknown words", k=2))
  let observed = q1.hits.length() + q2.hits.length()
  {
    name: "documentation-search",
    ingested: accepted,
    rejected,
    skipped,
    queries: 2,
    nonempty_queries: if q1.is_empty() {
      0
    } else {
      1
    },
    expected_matches: 2,
    observed_matches: observed,
    expected_rejected: 1,
    expected_skipped: 0,
  }
}

///|
/// Build a realistic regression scenario for invalid input and capacity policy.
pub fn run_ingestion_guard_scenario() -> ScenarioReport {
  let policy = {
    ..IngestionPolicy::demo(),
    max_documents: 2,
    require_category: true,
    reject_unknown_only: true,
  }
  let knowledge = ApplicationKnowledgeBase::new(
    demo_corpus(),
    policy~,
    session_name="guard-demo",
  )
  let results = knowledge.ingest_many([
    Document::new("valid-1", "king queen", metadata=Map([("category", "ok")])),
    Document::new("missing-category", "apple orange"),
    Document::new("valid-2", "code bug", metadata=Map([("category", "ok")])),
    Document::new("over-capacity", "king", metadata=Map([("category", "ok")])),
    Document::new(
      "unknown-only",
      "unseen terms",
      metadata=Map([("category", "ok")]),
    ),
  ])
  let mut accepted = 0
  let mut rejected = 0
  let mut skipped = 0
  for result in results {
    match result.status {
      Accepted => accepted = accepted + 1
      Rejected => rejected = rejected + 1
      Skipped => skipped = skipped + 1
    }
  }
  {
    name: "ingestion-guards",
    ingested: accepted,
    rejected,
    skipped,
    queries: 0,
    nonempty_queries: 0,
    expected_matches: 0,
    observed_matches: 0,
    expected_rejected: 2,
    expected_skipped: 1,
  }
}

///|
/// Run all application scenarios used by the acceptance checklist.
pub fn run_application_scenarios() -> Array[ScenarioReport] {
  [
    run_support_scenario(),
    run_documentation_scenario(),
    run_ingestion_guard_scenario(),
  ]
}

///|
pub fn all_application_scenarios_pass() -> Bool {
  for scenario in run_application_scenarios() {
    if !scenario.passed() {
      return false
    }
  }
  true
}

///|
test "support application scenario" {
  let report = run_support_scenario()
  inspect(report.passed(), content="true")
  inspect(report.ingested, content="3")
  inspect(report.nonempty_queries, content="3")
}

///|
test "documentation application scenario" {
  let report = run_documentation_scenario()
  inspect(report.rejected, content="1")
  inspect(report.ingested, content="3")
  inspect(report.observed_matches, content="2")
}

///|
test "ingestion guard scenario" {
  let report = run_ingestion_guard_scenario()
  inspect(report.ingested, content="2")
  inspect(report.rejected, content="2")
  inspect(report.skipped, content="1")
}

///|
test "application session and export" {
  let knowledge = support_knowledge_base()
  let _ = knowledge.ingest(
    Document::new("one", "king queen", metadata=Map([("category", "account")])),
  )
  let _ = knowledge.search(ApplicationQuery::new("king", k=1))
  inspect(knowledge.history().length(), content="1")
  inspect(knowledge.export_documents().contains("one\taccount"), content="true")
  inspect(knowledge.health().contains("store_documents=1"), content="true")
  inspect(knowledge.usage().accepted_documents, content="1")
}

///|
test "application boundary behavior" {
  let knowledge = support_knowledge_base()
  let empty = knowledge.search(ApplicationQuery::new("", k=3))
  inspect(empty.is_empty(), content="true")
  let invalid = knowledge.ingest(Document::new("", "king"))
  inspect(invalid.status is Rejected, content="true")
  let session = QuerySession::new("bounded", max_events=2)
  for _ in 0..<4 {
    let query = ApplicationQuery::new("king", k=1)
    let report : ApplicationSearchReport = {
      query,
      hits: [],
      candidates: 0,
      scanned: 0,
      unknown_terms: 0,
      filtered_documents: 0,
    }
    session.record(query, report)
  }
  inspect(session.size(), content="2")
}

///|
test "knowledge base administration" {
  let knowledge = support_knowledge_base()
  let results = knowledge.ingest_many([
    Document::new("a", "king", metadata=Map([("category", "account")])),
    Document::new("b", "apple", metadata=Map([("category", "billing")])),
  ])
  inspect(results.length(), content="2")
  inspect(knowledge.document_count(), content="2")
  inspect(knowledge.document_ids().length(), content="2")
  inspect(knowledge.categories().length(), content="2")
  let reports = knowledge.search_many([
    ApplicationQuery::new("king", k=1),
    ApplicationQuery::new("apple", k=1),
  ])
  inspect(reports.length(), content="2")
  inspect(knowledge.history().length(), content="2")
  inspect(knowledge.ready(), content="true")
  knowledge.reset_session()
  inspect(knowledge.history().length(), content="0")
}

///|
test "scenario matrix" {
  let matrix = run_scenario_matrix()
  inspect(matrix.scenarios, content="3")
  inspect(matrix.passed, content="3")
  inspect(matrix.all_passed(), content="true")
  inspect(matrix.total_documents > 0, content="true")
  inspect(matrix.total_queries > 0, content="true")
}

///|
test "all application scenarios" {
  inspect(run_application_scenarios().length(), content="3")
  inspect(all_application_scenarios_pass(), content="true")
}

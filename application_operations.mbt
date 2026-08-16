///|
/// A reasoned admission decision for a query arriving from an application.
pub(all) struct QueryAdmission {
  accepted : Bool
  normalized : String
  token_count : Int
  known_token_count : Int
  reason : String
}

///|
pub fn QueryAdmission::accepted(self : QueryAdmission) -> Bool {
  self.accepted
}

///|
pub fn QueryAdmission::known_ratio(self : QueryAdmission) -> Double {
  if self.token_count <= 0 {
    0.0
  } else {
    self.known_token_count.to_double() / self.token_count.to_double()
  }
}

///|
pub fn QueryAdmission::describe(self : QueryAdmission) -> String {
  "accepted=\{self.accepted}, tokens=\{self.token_count}, known=\{self.known_token_count}, ratio=\{self.known_ratio()}, reason=\{self.reason}"
}

///|
/// A compact, stable summary used by document inventory screens.
pub(all) struct ApplicationDocumentSummary {
  id : String
  category : String
  token_count : Int
  known_token_count : Int
  vector_ready : Bool
}

///|
pub fn ApplicationDocumentSummary::describe(
  self : ApplicationDocumentSummary,
) -> String {
  "id=\{self.id}, category=\{self.category}, tokens=\{self.token_count}, known=\{self.known_token_count}, vector_ready=\{self.vector_ready}"
}

///|
/// The outcome of a batch ingestion operation, including every diagnostic.
pub(all) struct IngestionBatchReport {
  attempted : Int
  accepted : Int
  rejected : Int
  skipped : Int
  diagnostics : Array[IngestionIssue]
}

///|
pub fn IngestionBatchReport::complete(self : IngestionBatchReport) -> Bool {
  self.attempted > 0 &&
  self.accepted == self.attempted &&
  self.rejected == 0 &&
  self.skipped == 0
}

///|
pub fn IngestionBatchReport::acceptance_rate(
  self : IngestionBatchReport,
) -> Double {
  if self.attempted <= 0 {
    0.0
  } else {
    self.accepted.to_double() / self.attempted.to_double()
  }
}

///|
pub fn IngestionBatchReport::describe(self : IngestionBatchReport) -> String {
  "attempted=\{self.attempted}, accepted=\{self.accepted}, rejected=\{self.rejected}, skipped=\{self.skipped}, diagnostics=\{self.diagnostics.length()}, rate=\{self.acceptance_rate()}, complete=\{self.complete()}"
}

///|
/// A top-hit response suitable for a command-line or embedded UI preview.
pub(all) struct ApplicationAnswer {
  found : Bool
  query : String
  document_id : String
  text : String
  category : String
  score : Double
}

///|
pub fn ApplicationAnswer::found(self : ApplicationAnswer) -> Bool {
  self.found
}

///|
pub fn ApplicationAnswer::describe(self : ApplicationAnswer) -> String {
  if self.found {
    "found=true, query=\"\{self.query}\", id=\{self.document_id}, category=\{self.category}, score=\{self.score}, text=\"\{self.text}\""
  } else {
    "found=false, query=\"\{self.query}\", reason=no-matching-document"
  }
}

///|
/// Decide whether a query has enough known vocabulary to enter retrieval.
pub fn ApplicationKnowledgeBase::admit_query(
  self : ApplicationKnowledgeBase,
  query : ApplicationQuery,
) -> QueryAdmission {
  let tokens = self.tokenizer.tokens(query.text)
  let mut known = 0
  for token in tokens {
    if self.corpus.has_token(token) {
      known = known + 1
    }
  }
  let normalized = query.text.trim().to_owned()
  if !query.valid() {
    {
      accepted: false,
      normalized,
      token_count: tokens.length(),
      known_token_count: known,
      reason: "invalid-query",
    }
  } else if tokens.is_empty() {
    {
      accepted: false,
      normalized,
      token_count: 0,
      known_token_count: 0,
      reason: "no-retained-token",
    }
  } else if known == 0 {
    {
      accepted: false,
      normalized,
      token_count: tokens.length(),
      known_token_count: 0,
      reason: "no-known-token",
    }
  } else {
    {
      accepted: true,
      normalized,
      token_count: tokens.length(),
      known_token_count: known,
      reason: "accepted",
    }
  }
}

///|
/// Produce a top-document answer while preserving the full search API.
pub fn ApplicationKnowledgeBase::answer(
  self : ApplicationKnowledgeBase,
  query : ApplicationQuery,
) -> ApplicationAnswer {
  let query_text = query.text
  let report = self.search(query)
  match report.top() {
    Some(hit) =>
      {
        found: true,
        query: query_text,
        document_id: hit.id(),
        text: hit.text(),
        category: hit.category(),
        score: hit.score(),
      }
    None =>
      {
        found: false,
        query: query_text,
        document_id: "",
        text: "",
        category: "",
        score: 0.0,
      }
  }
}

///|
/// Ingest a batch and aggregate per-document operator diagnostics.
pub fn ApplicationKnowledgeBase::ingest_with_report(
  self : ApplicationKnowledgeBase,
  documents : Array[Document],
) -> IngestionBatchReport {
  let results = self.ingest_many(documents)
  let diagnostics = []
  let mut accepted = 0
  let mut rejected = 0
  let mut skipped = 0
  for result in results {
    match result.status {
      Accepted => accepted = accepted + 1
      Rejected => rejected = rejected + 1
      Skipped => skipped = skipped + 1
    }
    for issue in result.issues {
      diagnostics.push(issue)
    }
  }
  { attempted: results.length(), accepted, rejected, skipped, diagnostics }
}

///|
/// Return whether an id is currently present in the application store.
pub fn ApplicationKnowledgeBase::has_document(
  self : ApplicationKnowledgeBase,
  id : String,
) -> Bool {
  self.store.get(id) is Some(_)
}

///|
/// Remove an accepted document without touching the embedding corpus.
pub fn ApplicationKnowledgeBase::remove_document(
  self : ApplicationKnowledgeBase,
  id : String,
) -> Bool {
  self.store.remove(id)
}

///|
/// Return the documents in one category in insertion order.
pub fn ApplicationKnowledgeBase::documents_for_category(
  self : ApplicationKnowledgeBase,
  category : String,
) -> Array[Document] {
  let result = []
  for document in self.store.docs {
    if document.metadata.get("category") == Some(category) {
      result.push(document)
    }
  }
  result
}

///|
/// Count documents by category, retaining deterministic insertion order.
pub fn ApplicationKnowledgeBase::category_counts(
  self : ApplicationKnowledgeBase,
) -> Map[String, Int] {
  let counts : Map[String, Int] = Map([])
  for document in self.store.docs {
    let category = match document.metadata.get("category") {
      Some(value) => value
      None => "uncategorized"
    }
    let next = match counts.get(category) {
      Some(value) => value + 1
      None => 1
    }
    counts.set(category, next)
  }
  counts
}

///|
/// Return one-line inventory summaries for operational inspection.
pub fn ApplicationKnowledgeBase::document_summaries(
  self : ApplicationKnowledgeBase,
) -> Array[ApplicationDocumentSummary] {
  let result = []
  for document in self.store.docs {
    let category = match document.metadata.get("category") {
      Some(value) => value
      None => "uncategorized"
    }
    let counts = count_known_tokens(self.corpus, self.tokenizer, document.text)
    result.push({
      id: document.id,
      category,
      token_count: counts.0,
      known_token_count: counts.1,
      vector_ready: document.vector is Some(_),
    })
  }
  result
}

///|
/// Export only one category for handoff to a downstream offline tool.
pub fn ApplicationKnowledgeBase::export_category(
  self : ApplicationKnowledgeBase,
  category : String,
) -> String {
  let mut output = "id\tcategory\ttext\n"
  for document in self.documents_for_category(category) {
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
/// Search one category without requiring callers to construct a filter.
pub fn ApplicationKnowledgeBase::search_category(
  self : ApplicationKnowledgeBase,
  category : String,
  text : String,
  k? : Int = 5,
) -> ApplicationSearchReport {
  let query = ApplicationQuery::new(
    text,
    k~,
    filter=DocumentFilter::empty().with_category(category),
  )
  self.search(query)
}

///|
/// Return a stable operational snapshot for a readiness endpoint or CLI.
pub fn ApplicationKnowledgeBase::snapshot(
  self : ApplicationKnowledgeBase,
) -> String {
  let admission = self.admit_query(ApplicationQuery::new("king", k=1))
  "ready=\{self.ready()}\n" +
  "documents=\{self.document_count()}\n" +
  "categories=\{self.categories().length()}\n" +
  "history=\{self.history().length()}\n" +
  "query_probe=\{admission.describe()}\n" +
  "usage=\{self.usage().describe()}"
}

///|
/// Verify the application lifecycle invariants used by the examples.
pub fn ApplicationKnowledgeBase::workflow_ready(
  self : ApplicationKnowledgeBase,
) -> Bool {
  if !self.ready() {
    return false
  }
  for summary in self.document_summaries() {
    if !summary.vector_ready || summary.known_token_count <= 0 {
      return false
    }
  }
  true
}

///|
/// Return a query report plus an explicit admission decision for diagnostics.
pub(all) struct ApplicationQueryTrace {
  admission : QueryAdmission
  report : ApplicationSearchReport
}

///|
pub fn ApplicationQueryTrace::describe(self : ApplicationQueryTrace) -> String {
  "admission=\{self.admission.describe()}\n\{self.report.describe()}"
}

///|
pub fn ApplicationKnowledgeBase::trace_query(
  self : ApplicationKnowledgeBase,
  query : ApplicationQuery,
) -> ApplicationQueryTrace {
  let admission = self.admit_query(query)
  let report = self.search(query)
  { admission, report }
}

///|
/// Build an operator-facing summary for a completed scenario.
pub fn scenario_operations_summary(
  knowledge : ApplicationKnowledgeBase,
) -> String {
  "workflow_ready=\{knowledge.workflow_ready()}\n" +
  "documents=\{knowledge.document_count()}\n" +
  "categories=\{knowledge.categories().length()}\n" +
  "export_bytes=\{knowledge.export_documents().length()}\n" +
  "snapshot=\n\{knowledge.snapshot()}"
}

///|
/// Use the application operations as a deterministic smoke path.
pub fn application_operations_smoke() -> Bool {
  let knowledge = support_knowledge_base()
  let report = knowledge.ingest_with_report([
    Document::new(
      "ops-smoke",
      "king queen",
      metadata=Map([("category", "support")]),
    ),
  ])
  report.complete() &&
  knowledge.workflow_ready() &&
  knowledge.answer(ApplicationQuery::new("king", k=1)).found()
}

///|
test "application operations smoke" {
  let knowledge = support_knowledge_base()
  let batch = knowledge.ingest_with_report([
    Document::new(
      "ops-one",
      "king queen",
      metadata=Map([("category", "support")]),
    ),
    Document::new(
      "ops-two",
      "apple orange",
      metadata=Map([("category", "billing")]),
    ),
  ])
  inspect(batch.complete(), content="true")
  inspect(batch.acceptance_rate(), content="1")
  inspect(knowledge.has_document("ops-one"), content="true")
  inspect(knowledge.documents_for_category("billing").length(), content="1")
  inspect(knowledge.document_summaries().length(), content="2")
  inspect(
    knowledge.answer(ApplicationQuery::new("king", k=1)).found(),
    content="true",
  )
}

///|
test "application operations rejection and administration" {
  let knowledge = ApplicationKnowledgeBase::new(demo_corpus(), policy={
    ..IngestionPolicy::conservative(),
    require_category: true,
  })
  let batch = knowledge.ingest_with_report([
    Document::new("valid", "king queen", metadata=Map([("category", "ok")])),
    Document::new("missing", "king queen"),
    Document::new(
      "unknown",
      "not-in-corpus",
      metadata=Map([("category", "ok")]),
    ),
  ])
  inspect(batch.accepted, content="1")
  inspect(batch.rejected, content="2")
  inspect(batch.diagnostics.length(), content="2")
  inspect(knowledge.category_counts().get("ok") is Some(1), content="true")
  inspect(knowledge.remove_document("valid"), content="true")
  inspect(knowledge.has_document("valid"), content="false")
}

///|
test "application query admission and trace" {
  let knowledge = support_knowledge_base()
  let accepted = knowledge.admit_query(ApplicationQuery::new("king", k=1))
  let unknown = knowledge.admit_query(
    ApplicationQuery::new("not-in-corpus", k=1),
  )
  inspect(accepted.accepted(), content="true")
  inspect(unknown.accepted(), content="false")
  inspect(unknown.reason, content="no-known-token")
  let trace = knowledge.trace_query(ApplicationQuery::new("king", k=1))
  inspect(trace.report.is_empty(), content="true")
}

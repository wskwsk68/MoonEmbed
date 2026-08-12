///|
/// A small result type that keeps a score beside a document without exposing
/// the internal ranking tuple used by DocumentStore.
pub(all) struct DocumentHit {
  document : Document
  score : Double
}

///|
pub fn DocumentHit::id(self : DocumentHit) -> String {
  self.document.id
}

///|
pub fn DocumentHit::score(self : DocumentHit) -> Double {
  self.score
}

///|
pub fn DocumentStore::size(self : DocumentStore) -> Int {
  self.docs.length()
}

///|
pub fn DocumentStore::is_empty(self : DocumentStore) -> Bool {
  self.docs.is_empty()
}

///|
pub fn DocumentStore::get(self : DocumentStore, id : String) -> Document? {
  for doc in self.docs {
    if doc.id == id {
      return Some(doc)
    }
  }
  None
}

///|
/// Add a batch of documents and return the number that produced a vector.
pub fn DocumentStore::add_documents(
  self : DocumentStore,
  documents : Array[Document],
  corpus : EmbeddingCorpus,
) -> Int {
  let mut added = 0
  for doc in documents {
    if corpus.sentence_embedding(doc.text) is Some(_) {
      added = added + 1
    }
    self.add_document(doc, corpus)
  }
  added
}

///|
/// Search text directly, avoiding a repeated query-vector boilerplate.
pub fn DocumentStore::search_text(
  self : DocumentStore,
  corpus : EmbeddingCorpus,
  text : String,
  filter_key : String?,
  filter_value : String?,
  k : Int,
) -> Array[Document] {
  match corpus.sentence_embedding(text) {
    Some(query) => self.search(query, filter_key, filter_value, k)
    None => []
  }
}

///|
/// Search all documents and retain scores for explainable applications.
pub fn DocumentStore::search_scored(
  self : DocumentStore,
  query_vector : Array[Double],
  filter_key : String?,
  filter_value : String?,
  k : Int,
  threshold : Double,
) -> Array[DocumentHit] {
  let result : Array[DocumentHit] = []
  if k <= 0 {
    return result
  }
  let q = normalize_query(query_vector)
  for doc in self.docs {
    let mut pass = true
    match (filter_key, filter_value) {
      (Some(key), Some(value)) =>
        match doc.metadata.get(key) {
          Some(actual) => if actual != value { pass = false }
          None => pass = false
        }
      _ => ()
    }
    if pass {
      match doc.vector {
        Some(vector) => {
          let score = dot(q, vector)
          if score >= threshold {
            let hit = { document: doc, score }
            let mut pos = result.length()
            while pos > 0 && result[pos - 1].score < score {
              pos = pos - 1
            }
            result.insert(pos, hit)
            if result.length() > k {
              let _ = result.pop()
            }
          }
        }
        None => ()
      }
    }
  }
  result
}

///|
/// Remove a document by id and report whether it existed.
pub fn DocumentStore::remove(self : DocumentStore, id : String) -> Bool {
  for i in 0..<self.docs.length() {
    if self.docs[i].id == id {
      let _ = self.docs.remove(i)
      return true
    }
  }
  false
}

///|
/// Replace an existing document, or append it when the id is new.
pub fn DocumentStore::upsert(
  self : DocumentStore,
  document : Document,
  corpus : EmbeddingCorpus,
) -> Bool {
  let enriched = {
    ..document,
    vector: corpus.sentence_embedding(document.text),
  }
  for i in 0..<self.docs.length() {
    if self.docs[i].id == document.id {
      self.docs[i] = enriched
      return true
    }
  }
  self.docs.push(enriched)
  false
}

///|
/// Return a snapshot of document ids in insertion order.
pub fn DocumentStore::ids(self : DocumentStore) -> Array[String] {
  let result = []
  for doc in self.docs {
    result.push(doc.id)
  }
  result
}

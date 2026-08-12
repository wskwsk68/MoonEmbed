///|
test "empty and invalid query boundaries" {
  let index = demo_index()
  inspect(index.search([], 0).hits.length(), content="0")
  inspect(index.search_exact([], -1).scanned, content="0")
  inspect(index.search_terms("   ", 3).hits.length(), content="0")
  inspect(index.search_text("missing token", 3).candidates, content="0")
}

///|
test "corpus round trip and statistics" {
  let original = demo_corpus()
  inspect(original.validate(), content="true")
  inspect(original.stats().records, content="6")
  inspect(original.stats().dimension, content="3")
  let glove = original.to_glove_text()
  inspect(glove.contains("king"), content="true")
  let word2vec = original.to_word2vec_text()
  inspect(word2vec.contains("6 3"), content="true")
}

///|
test "prefix threshold and batch search" {
  let index = demo_index()
  inspect(index.corpus().prefix("k", 10).length(), content="1")
  inspect(index.search_prefix("q", 3).hits[0].token, content="queen")
  inspect(
    index.search_threshold([1.0, 0.0, 0.0], 10, 0.99).hits.length() > 0,
    content="true",
  )
  let reports = index.search_many([[1.0, 0.0, 0.0], [0.0, 1.0, 0.0]], 1)
  inspect(reports.length(), content="2")
}

///|
test "retrieval evaluation" {
  let index = demo_index()
  let cases : Array[RetrievalCase] = [
    { name: "royalty", query: [1.0, 0.0, 0.0], expected: ["king"] },
    { name: "fruit", query: [0.0, 1.0, 0.0], expected: ["apple"] },
  ]
  let metrics = index.evaluate(cases, 2)
  inspect(metrics.cases, content="2")
  inspect(metrics.passed, content="2")
  inspect(metrics.mean_recall > 0.0, content="true")
}

///|
test "document lifecycle and scored filtering" {
  let corpus = demo_corpus()
  let store = DocumentStore::new()
  inspect(store.is_empty(), content="true")
  let _ = store.add_documents(
    [
      Document::new("a", "king queen", metadata=Map([("kind", "royal")])),
      Document::new("b", "apple orange", metadata=Map([("kind", "fruit")])),
    ],
    corpus,
  )
  inspect(store.size(), content="2")
  inspect(store.get("a") is Some(_), content="true")
  let query = corpus.sentence_embedding("king")
  match query {
    Some(vector) => {
      let hits = store.search_scored(vector, None, None, 2, 0.0)
      inspect(hits[0].id(), content="a")
      inspect(
        store
        .search_text(corpus, "apple", Some("kind"), Some("fruit"), 2)
        .length(),
        content="1",
      )
    }
    None => panic()
  }
  inspect(store.upsert(Document::new("a", "code bug"), corpus), content="true")
  inspect(store.remove("b"), content="true")
  inspect(store.ids().length(), content="1")
}

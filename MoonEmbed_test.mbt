///|
test {
  let corpus = EmbeddingCorpus::from_glove_text(
    "king 0.92 0.10 0.00\nqueen 0.90 0.14 0.00\napple 0.00 0.92 0.10\norange 0.00 0.88 0.14\ncode 0.10 0.00 0.95\nbug 0.08 0.00 0.92\n",
  )
  inspect(corpus.size(), content="6")
  inspect(corpus.dim, content="3")
  match corpus.lookup("king") {
    Some(_) => inspect(true, content="true")
    None => panic()
  }
}

///|
test {
  let index = demo_index()
  let report = index.search_terms("king", 3)
  inspect(report.hits.length(), content="3")
  inspect(report.hits[0].token, content="king")
  inspect(report.hits[1].token, content="queen")
  inspect(report.scanned <= report.candidates, content="true")
}

///|
test {
  let corpus = EmbeddingCorpus::from_word2vec_text(
    "2 3\nalpha 1.0 0.0 0.0\nbeta 0.0 1.0 0.0\n",
  )
  inspect(corpus.size(), content="2")
  let index = MoonEmbedIndex::from_corpus(corpus, 2)
  let report = index.search([1.0, 0.0, 0.0], 1)
  inspect(report.hits[0].token, content="alpha")
}

test {
  inspect(SourceFormat::GloVeText.label(), content="glove-text")
  inspect(demo_index().describe().contains("signature_bits=3"), content="true")
}

test {
  let report = demo_index().search_terms("not-a-real-token", 3)
  inspect(report.hits.length(), content="0")
  inspect(report.scanned, content="0")
}

test {
  let corpus = demo_corpus()
  inspect(corpus.has_token("king"), content="true")
  inspect(corpus.tokens().length(), content="6")
  inspect(demo_index().search_token("queen", 2).hits.length(), content="2")
}

# MoonEmbed

MoonEmbed is a MoonBit-native library for loading word embeddings and running
lightweight local semantic retrieval without Python, a database, or a network
service. It is suitable for browser/Wasm examples, embedded tools, and small
offline search pipelines.

## Install and verify

Clone the repository, then run:

```bash
moon fmt --check
moon check --deny-warn
moon test --deny-warn
moon build
moon run cmd/main
```

The demo uses a deterministic built-in corpus, so it does not download model
weights or require credentials.

## Supported capabilities

- Word2vec text, GloVe text, and word2vec binary ingestion.
- Normalized cosine search with exact and bucketed approximate modes.
- Token, phrase, prefix, threshold, batch, and tokenizer-aware queries.
- Sentence embeddings and a metadata-filtered document store.
- Corpus validation, index diagnostics, benchmark/recall reports, explainable
  score profiles, query plans, and deterministic quantization helpers.

## Minimal API example

```mbt check
///|
test "README minimal search" {
  let corpus = EmbeddingCorpus::from_glove_text(
    "king 0.92 0.10 0.00\nqueen 0.90 0.14 0.00\n",
  )
  let index = MoonEmbedIndex::from_corpus(corpus, 3)
  let report = index.search_token("king", 1)
  inspect(report.hits[0].token, content="king")
}
```

Unknown tokens and empty queries return empty reports. `k <= 0` returns no
results. Input records are copied and normalized; inconsistent dimensions are
rejected. Use `search_exact` as a correctness baseline and `evaluate` to
measure approximate-search recall on a domain corpus.

## Project and license

The source is primarily MoonBit and is distributed under Apache-2.0. The
repository contains no bundled model weights or third-party fixtures. See the
root `README.md` for repository links, architecture, API boundaries, and source
notes.

# MoonEmbed

MoonEmbed is a MoonBit-first library for working with word embeddings locally.

Repository links:

- GitHub: [https://github.com/wskwsk68/MoonEmbed](https://github.com/wskwsk68/MoonEmbed)
- GitLink: [https://gitlink.org.cn/wskwsk68/MoonEmbed](https://gitlink.org.cn/wskwsk68/MoonEmbed)

## What it does

- Load word2vec text embeddings
- Load GloVe-style text embeddings
- Load word2vec binary embeddings
- Normalize vectors for cosine search
- Search with a tiny bucketed approximate index and exact fallback
- Search by token, phrase, prefix, threshold, or batch query
- Build sentence embeddings and a metadata-filtered document store
- Export normalized corpora as GloVe-style or word2vec text
- Report corpus health, recall, scanned candidates, and benchmark metrics
- Provide a small CLI demo and regression/edge-case test coverage

## Why this shape

The contest page encourages a public repository, clear README, runnable example, CI, tests, and an OSI license. MoonEmbed stays focused on one practical niche: semantic word lookup without depending on Python or a database.

Contest readiness:

- single contributor
- commit history expanded into multiple meaningful steps
- public-source-only implementation
- clear source notes and OSI license

I deliberately kept it narrower than a general vector database so it does not overlap too closely with existing MoonBit ecosystem work such as broader ANN/vector DB packages.

## Repository layout

- `MoonEmbed.mbt` library code
- `MoonEmbed_test.mbt` tests
- `cmd/main/main.mbt` CLI demo
- `LICENSE` Apache-2.0
- `.github/workflows/ci.yml` basic build/test CI

## Usage

Build and test:

```bash
moon test
moon run cmd/main
```

The CLI is intentionally dependency-free and uses the built-in demo corpus. It
prints the corpus description and a top-k search result, so a fresh checkout
has a reproducible smoke test without downloading a model.

Example API:

```moonbit
let corpus = EmbeddingCorpus::from_glove_text(
  "king 0.92 0.10 0.00\nqueen 0.90 0.14 0.00\n",
)
let index = MoonEmbedIndex::from_corpus(corpus, signature_bits=3)
let report = index.search_token("king", 3)
println(format_report(report))
```

For application code, `search_text` averages known token vectors, while
`DocumentStore::search_text` adds optional metadata filtering. `search_exact`
is available as a correctness reference for evaluating the bucket index with
`RetrievalCase` and `MoonEmbedIndex::evaluate`.

### Input and boundary behavior

- Text parsers accept blank lines and validate consistent vector dimensions.
- Word2vec text accepts an optional `count dimension` header.
- Binary word2vec input uses little-endian IEEE-754 32-bit values.
- Empty or unknown queries return an empty report; `k <= 0` returns no hits.
- Records are copied and normalized when entering a corpus.
- Tokens containing spaces are not valid embedding keys.
- A zero vector is retained but contributes a zero similarity.

### Validation and performance evidence

The repository includes deterministic tests for all three input formats,
normalization, exact and approximate search, phrase aggregation, prefix and
threshold search, serialization shape, document lifecycle, metadata filters,
unknown terms, empty inputs, invalid `k`, and retrieval evaluation. Run the
following before publishing:

```bash
moon fmt --check
moon check --deny-warn
moon test --deny-warn
moon build
moon info
```

`SearchReport.candidates` and `scanned` make approximate-search tradeoffs
observable. Use exact search as the baseline and `evaluate` to record recall
on a domain corpus rather than relying on a synthetic timing claim.

## Source notes

This repository is original MoonBit code written for the contest. No model
weights, private code, or third-party fixtures are bundled. If the project is
extended with upstream data, ports, or borrowed algorithms, document the
source, license, and porting scope in `THIRD_PARTY_NOTICES.md` before release.

## License

Apache-2.0

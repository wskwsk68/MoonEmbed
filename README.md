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
- Provide explainable ranking profiles, query plans, validation reports, and
  deterministic quantization helpers
- Provide an application knowledge-base layer with ingestion policies,
  operator diagnostics, bounded query sessions, batch search, exports, health
  reports, and reproducible support/documentation scenarios
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

The repository also includes a dependency-free `BenchmarkSuite`,
`TextTokenizer`, `DocumentFilter`, `QueryPlan`, and `ValidationReport` API for
building repeatable application-level checks around the core index.

### Real application workflow

`ApplicationKnowledgeBase` demonstrates the complete offline workflow used by
an embedded support or documentation tool: validate and ingest documents,
reject unknown-only or malformed input with an audit record, run filtered
semantic queries, retain bounded session history, export accepted documents,
and inspect health/usage counters. Operational helpers add query admission
traces, batch acceptance reports, document inventory summaries, category
exports, top-hit answers, and readiness snapshots. The built-in scenarios are
deterministic and exercise normal, rejected, skipped, filtered, empty-query,
and export paths without downloading model weights or contacting a service.

```moonbit
let knowledge = support_knowledge_base()
let results = knowledge.ingest_many([
  Document::new(
    "faq-login",
    "king queen",
    metadata=Map([("category", "support")]),
  ),
])
let report = knowledge.search(ApplicationQuery::new("king", k=3))
println(report.describe())
```

Run `run_application_scenarios()` or `run_scenario_matrix()` from MoonBit
tests/tools to verify the same end-to-end behavior across support,
documentation, and ingestion-guard cases.

## Source notes

This repository is original MoonBit code written for the contest. No model
weights, private code, or third-party fixtures are bundled. If the project is
extended with upstream data, ports, or borrowed algorithms, document the
source, license, and porting scope in `THIRD_PARTY_NOTICES.md` before release.

## License

Apache-2.0

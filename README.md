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
- Provide a small CLI demo and test coverage

## Why this shape

The contest page encourages a public repository, clear README, runnable example, CI, tests, and an OSI license. MoonEmbed stays focused on one practical niche: semantic word lookup without depending on Python or a database.

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

Example API:

```moonbit
let corpus = EmbeddingCorpus::from_glove_text(
  "king 0.92 0.10 0.00\nqueen 0.90 0.14 0.00\n",
)
let index = MoonEmbedIndex::from_corpus(corpus, signature_bits=3)
let report = index.search_terms("king", 3)
println(format_report(report))
```

## Source notes

This repository is original MoonBit code written for the contest. If you later extend it with upstream data, ports, or borrowed algorithms, document the source, license, and porting scope clearly in this section before submission.

## License

Apache-2.0

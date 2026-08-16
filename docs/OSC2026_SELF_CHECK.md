# OSC2026 Self Check

This file tracks the items the contest page explicitly cares about.

## Repository shape

- [x] MoonBit source in the repository root
- [x] Runnable entry point in `cmd/main`
- [x] Tests in `MoonEmbed_test.mbt`
- [x] CI workflow in `.github/workflows/ci.yml`
- [x] README present in both MoonBit and GitHub-friendly form
- [x] Single contributor only, no virtual or extra contributors
- [x] Commit count is above 10 before this local update (new local work remains uncommitted until review)

## Submission quality

- [x] OSI license: Apache-2.0
- [x] Runnable demo
- [x] Automated tests, including edge and regression cases
- [x] Public-source-only code
- [x] Source notes in README

## Contest alignment

- [x] Main language is MoonBit
- [x] Focused on local word embedding loading and retrieval
- [x] Differs from a general vector database
- [x] Includes a lightweight approximate index and an exact evaluation baseline
- [x] Corpus validation, serialization, document store, thresholds, prefixes, and batch search

## Remaining contest steps

- [x] Push the reviewed commits to the public GitHub repository
- [x] GitHub default branch is `main` and contains the latest commit
- [x] GitLink default branch is `master` and contains the same latest commit
- [x] GitHub and GitLink contain the same source tree on their default branches
- [x] Publish the package to mooncakes.io
- [ ] Export the proposal as the required one-page PDF (submission-material task; proposal files are intentionally not modified here)

## Local evidence

- `moon check --deny-warn`: pass
- `moon test --deny-warn`: pass
- 23 deterministic tests pass on Wasm and Wasm-GC targets
- `moon build`: pass
- `moon info`: generated interface updated locally
- Local MoonBit sources: approximately 3k effective lines after the production-feature expansion; the contest's 4k~10k figure remains a scale reference, not a license to add filler.
- `mooncakes.io`: package `wskwsk68/MoonEmbed` version `0.1.4` contains the acceptance-pass update.
- The root and `docs/SUBMISSION_ONE_PAGE.md` proposal materials are intentionally left unchanged in this review.

## Source notes

The implementation in this repository is original MoonBit code.
If we later pull in upstream data, ports, or algorithm references, the README should list:

- upstream project or paper
- license
- porting scope
- any files copied or adapted

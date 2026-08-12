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

- [ ] Push the reviewed local commit(s) to a public GitHub repository (requires explicit authorization)
- [ ] Add the final GitHub repo URL to the submission materials
- [ ] Export the proposal as the required one-page PDF
- [ ] Verify the remote default branch is `main`
- [ ] Confirm the mooncakes.io publication link if you choose to publish the package
- [ ] Make sure the GitLink repository is synchronized from the same source tree (requires explicit authorization)

## Local evidence

- `moon check --deny-warn`: pass
- `moon test --deny-warn`: pass
- `moon build`: pass
- `moon info`: generated interface updated locally
- Local MoonBit sources: approximately 1.3k lines after this pass; the contest's 4k~10k figure is a scale reference, not a license to add filler. Further scale should come from additional production features or real benchmark fixtures.
- `mooncakes.io` publication cannot be verified or performed from this local-only pass.

## Source notes

The implementation in this repository is original MoonBit code.
If we later pull in upstream data, ports, or algorithm references, the README should list:

- upstream project or paper
- license
- porting scope
- any files copied or adapted

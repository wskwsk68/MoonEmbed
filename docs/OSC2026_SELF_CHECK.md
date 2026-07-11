# OSC2026 Self Check

This file tracks the items the contest page explicitly cares about.

## Repository shape

- [x] MoonBit source in the repository root
- [x] Runnable entry point in `cmd/main`
- [x] Tests in `MoonEmbed_test.mbt`
- [x] CI workflow in `.github/workflows/ci.yml`
- [x] README present in both MoonBit and GitHub-friendly form

## Submission quality

- [x] OSI license: Apache-2.0
- [x] Runnable demo
- [x] Automated tests
- [x] Public-source-only code
- [x] Source notes in README

## Contest alignment

- [x] Main language is MoonBit
- [x] Focused on local word embedding loading and retrieval
- [x] Differs from a general vector database
- [x] Includes a lightweight approximate index

## Remaining contest steps

- [ ] Push to a public GitHub repository
- [ ] Add the final GitHub repo URL to the submission materials
- [ ] Export the proposal as the required one-page PDF
- [ ] Verify the remote default branch is `main`
- [ ] Confirm the mooncakes.io publication link if you choose to publish the package

## Source notes

The implementation in this repository is original MoonBit code.
If we later pull in upstream data, ports, or algorithm references, the README should list:

- upstream project or paper
- license
- porting scope
- any files copied or adapted

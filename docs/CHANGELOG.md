# Changelog

## Unreleased

- Added a text preprocessing pipeline, phrase queries, benchmark suites,
  explainable ranking, query plans, corpus validation, index diagnostics, and
  deterministic quantization/representation tools.

## v0.1.6

- Added a production-shaped `ApplicationKnowledgeBase` workflow for bounded
  document ingestion, audit diagnostics, filtered/batch search, query-session
  history, export, health, and usage reporting.
- Added deterministic support, documentation, ingestion-guard, and scenario
  matrix coverage, including accepted, rejected, skipped, empty-query, and
  boundary paths.
- Expanded the effective production MoonBit implementation to 4,264 source
  lines and the deterministic suite to 35 tests without changing proposal
  materials.

## v0.1.5

- Replaced the invalid CI setup action with the official MoonBit installation
  workflow and added strict cross-platform checks.

## v0.1.4

- Corrected the acceptance self-check wording after the `0.1.3` publication.

## v0.1.3

- Updated the package-facing README, current MoonBit executable package
  metadata, strict all-target CI, and tokenizer lowercasing behavior.

## v0.1.2

- Expanded the implementation beyond 3,000 effective MoonBit source lines.
- Added 22 deterministic tests covering ingestion, retrieval, filtering,
  ranking, validation, benchmarking, sampling, and boundary behavior.

## v0.1.1

- Added corpus validation and statistics, portable text serialization, prefix/
  threshold/batch retrieval, recall evaluation, and document-store lifecycle
  APIs with edge-case regression coverage.

## v0.1.0

- Added MoonBit-native embedding loading and local search.
- Added CLI demo, tests, CI, and contest submission notes.
- Retargeted the project to the `wskwsk68` repository namespace.
- Added corpus and index description helpers.
- Improved phrase search so unknown tokens return an empty result instead of panicking.

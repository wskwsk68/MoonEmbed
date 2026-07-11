# MoonEmbed Proposal Draft

## Title

MoonEmbed: Native word embedding loading and lightweight vector retrieval in MoonBit

Repository links:

- GitHub: https://github.com/wskwsk68/MoonEmbed
- GitLink: https://gitlink.org.cn/wskwsk68/MoonEmbed

## Problem

Many embedding demos depend on Python, SQLite, or a full vector database.
That makes them awkward for browser demos, embedded scenarios, or small MoonBit projects.

## Goal

Build a MoonBit-native library that can:

- load word2vec text embeddings
- load GloVe-style text embeddings
- load word2vec binary embeddings
- normalize vectors for cosine search
- provide fast local semantic lookup with a lightweight bucket index

## Why this is a good contest fit

- It is practical and easy to demonstrate.
- It stays within MoonBit rather than leaning on foreign runtimes.
- It can grow later into richer retrieval features.
- It is distinct from a generic vector database.

## Deliverables

- MoonBit library
- CLI demo
- tests
- CI
- documentation

## Planned extension points

- phrase embedding from multiple tokens
- optional metadata filters
- more sophisticated ANN indexing
- browser-facing demo

## Submission note

The implementation is kept to one main contributor and a public MoonBit codebase, with the goal of matching the contest's expectations around readable source, tests, CI, and a reproducible demo.

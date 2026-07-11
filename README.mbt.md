# MoonEmbed

MoonEmbed is a small MoonBit library for loading word embeddings and running lightweight semantic search locally.

It is designed for the 2026 MoonBit open source contest and keeps the scope focused:

- load word2vec text files
- load GloVe-style text files
- load word2vec binary files
- search with cosine similarity
- provide a light bucketed index for fast local lookup

The project intentionally stays away from a full vector database stack. That keeps the implementation compact, browser-friendly, and easier to audit.

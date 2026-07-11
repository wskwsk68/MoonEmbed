///|
/// Tiny showcase for MoonEmbed.
/// Run with `moon run cmd/main` from the project root.
fn main {
  let index = @MoonEmbed.demo_index()
  let corpus = index.corpus()
  let report = index.search_token("king", 3)
  println("MoonEmbed demo")
  println(corpus.describe())
  println("token_count=\{corpus.tokens().length()}")
  println(@MoonEmbed.format_report(report))
}

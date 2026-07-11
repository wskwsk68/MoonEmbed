///|
/// Tiny showcase for MoonEmbed.
/// Run with `moon run cmd/main` from the project root.
fn main {
  let index = @MoonEmbed.demo_index()
  let report = index.search_terms("king", 3)
  println("MoonEmbed demo")
  println(index.describe())
  println(@MoonEmbed.format_report(report))
}

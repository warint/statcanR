## Update

This is a maintenance and feature update from the current CRAN release (0.3.0).
The three long-standing public functions and their required arguments are
unchanged. Since 0.3.0 the package:

* adds `statcan_chat()`, an optional layer over `statcan_find()` that asks a
  user-configured, OpenAI-compatible chat endpoint to explain the ranked
  candidates. It never invents or chooses a table number; those always come
  from `statcan_find()`.
* fixes `statcan_data()` and `statcan_download_data()` for tables whose
  `_MetaData.csv` file has several sections with differing column counts, which
  could previously cause a valid table to be reported as empty.
* returns stable column types: a column left blank for a whole table (for
  example `DGUID`, `STATUS`, `SYMBOL`, or `TERMINATED`) is now an empty
  character column rather than a logical, all-`NA` column whose type varied
  between tables.
* speeds up `statcan_find()` by caching per-title tokens and streamlining the
  ranking, without changing the ranking results.

## Internet access

As in 0.3.0, the package performs no Internet access during installation,
package loading, examples, tests, or vignette builds. Network requests occur
only when a user explicitly calls one of the data-discovery or data-access
functions; each request uses a timeout and fails gracefully with an informative
error when the service is unavailable or returns an unexpected response.
Catalogue and metadata lookups reuse the most recent valid user cache when the
service is unavailable.

`statcan_chat()` follows the same rule: it makes no request unless the user
calls it directly, and it requires a user-supplied endpoint, API key, and
model. No third-party service is contacted automatically. For safety the
endpoint must use `https://` (except loopback hosts for a local model), and the
API key is read only from the `STATCANR_LLM_API_KEY` environment variable or an
argument, never from `options()`.

Thierry Warin is the sole author and maintainer. There is no change of
maintainer or maintainer email address from the last CRAN release.

## Test environments

* Local: Ubuntu 24.04.4 LTS, R 4.6.0
* Planned before submission: win-builder (R-release and R-devel) and R-hub
  across macOS, Windows, and Linux.

## R CMD check results

Local `R CMD check --as-cran` reported 0 errors and, aside from artifacts of
the local check machine, no package issues. The one warning and two notes are
all caused by a missing local toolchain, not by the package, and do not occur
on CRAN's build systems:

* WARNING: the PDF manual failed to build because the LaTeX package
  `inconsolata` is not installed on the local machine.
* NOTE: HTML manual validation was skipped because `tidy` is not installed
  locally.
* NOTE: a leftover `statcanR-manual.tex` file, a byproduct of the failed local
  PDF build above.

`checking CRAN incoming feasibility` returned OK, and all code, documentation,
example, test, and vignette checks passed.

## Downstream dependencies

statcanR has no reverse dependencies on CRAN (checked with
`tools::package_dependencies(reverse = TRUE)` against the current CRAN
snapshot), so this update affects no other package. The public function names
and existing required arguments are unchanged.

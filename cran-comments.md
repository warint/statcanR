## Update

This is version 0.3.9, a maintenance and feature update from the current CRAN
release (0.3.0). The three long-standing public functions and their required
arguments are unchanged. Since 0.3.0 the package:

* adds `statcan_chat()`, an optional layer over `statcan_find()` that asks a
  user-configured language-model provider to explain the ranked candidates. It
  never invents or chooses a table number; those always come from
  `statcan_find()`. A `provider` argument selects the provider: `"openai"` (the
  default, which also covers any OpenAI-compatible or local server) or
  `"anthropic"` (Claude).
* adds `statcan_chat_continue()`, which continues a `statcan_chat()` result as
  a multi-turn conversation. Follow-ups stay scoped to the candidate tables the
  first call found; they do not re-run `statcan_find()`, and the API key is
  re-resolved per call rather than stored in the result object.
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
calls it directly, and it requires a user-supplied API key and model (the
endpoint defaults to the chosen provider). No third-party service is contacted
automatically. For safety the endpoint must use `https://` (except loopback
hosts for a local model), and the API key is read only from an argument or an
environment variable (`STATCANR_LLM_API_KEY`, or the provider's native
`OPENAI_API_KEY` / `ANTHROPIC_API_KEY`), never from `options()`.

Thierry Warin is the sole author and maintainer. There is no change of
maintainer or maintainer email address from the last CRAN release.

## Test environments

* Local: Ubuntu 24.04 LTS, R 4.6.0 (`R CMD check --as-cran`)
* GitHub Actions: macOS (release), Windows (release), and Ubuntu
  (R-devel, release, and oldrel-1) -- all passing
* win-builder (R-release and R-devel): to be run immediately before submission

## R CMD check results

0 errors | 0 warnings | 0 notes on the GitHub Actions runners listed above.

The local Linux `R CMD check --as-cran` reports 1 warning and 2 notes, all of
which are artifacts of that machine's incomplete manual-building toolchain, not
package issues, and do not occur on the GitHub Actions runners or on CRAN:

* WARNING when building the PDF manual: LaTeX package `inconsolata.sty` is not
  installed on the local machine.
* NOTE that HTML manual validation is skipped because no `tidy` binary is
  present.
* NOTE about a leftover `statcanR-manual.tex`, a byproduct of the failed local
  PDF build above.

`checking CRAN incoming feasibility` returned OK, and all substantive checks
(R code, examples, tests, and vignette re-building) pass cleanly.

## Downstream dependencies

statcanR has no reverse dependencies on CRAN (checked with
`tools::package_dependencies(reverse = TRUE)` against the current CRAN
snapshot), so this update affects no other package. The public function names
and existing required arguments are unchanged.

## Pre-submission checklist (maintainer note -- remove before submitting)

Everything below is already done: version bumped to 0.3.9, NEWS complete,
local `R CMD check --as-cran` clean apart from the documented LaTeX/`tidy`
artifacts, GitHub Actions R-CMD-check passing, URLs verified (the DOI 403 is a
false positive that resolves in a browser), and no reverse dependencies.

Remaining steps to run at actual submission time:

1. **win-builder** -- `devtools::check_win_devel()` and
   `devtools::check_win_release()`; update the "Test environments" and
   "R CMD check results" sections above with the outcome.
2. **Spell check** -- `devtools::spell_check()`.
3. **Submit** -- `devtools::release()` (runs its interactive checklist,
   submits, and writes the `CRAN-SUBMISSION` record).

Then delete this checklist section so CRAN sees only the submission comments.
</content>

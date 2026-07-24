# statcanR 0.3.8

## Data

* `statcan_data()` and `statcan_download_data()` now return stable column
  types. A column that Statistics Canada leaves blank for a whole table
  (often `DGUID`, `STATUS`, `SYMBOL`, or `TERMINATED`) was previously read
  as a logical, all-`NA` column, so its type changed from table to table
  and could break `rbind()`/`dplyr::bind_rows()` or code expecting text.
  Such columns are now returned as empty character columns. Columns that
  carry real values, including reliability flags such as `"E"`, `"F"`, or
  `"t"`, are unchanged.

## Security

* `statcan_chat()` now refuses to send your API key over an unencrypted
  connection. The endpoint must use `https://`, except for loopback
  hosts (for example, `http://localhost` for a local model), so a
  mistyped `http://` endpoint can no longer leak the key in cleartext.

* **Breaking:** the API key is no longer read from
  `options(statcanR.llm_api_key = )`. A secret placed in `options()` can
  be dumped with `options()`, saved with a session, or recorded in
  `.Rhistory`, so the key is now taken only from the
  `STATCANR_LLM_API_KEY` environment variable or the `api_key` argument.
  If you previously configured the option, switch to
  `Sys.setenv(STATCANR_LLM_API_KEY = "...")` (or pass `api_key =`); a
  stale option is ignored with a warning. The `endpoint` and `model`
  settings are unchanged and may still be set through `options()`.

# statcanR 0.3.7

## Bug fixes

* `statcan_data()` and `statcan_download_data()` again work for tables
  whose `_MetaData.csv` file contains several sections with differing
  column counts (for example, table 13-10-0837-01). The metadata reader
  now parses only the first section (the header and cube row), so
  `data.table::fread()` no longer stops early and reports the table as
  an empty data or metadata file (#8).

## Performance

* `statcan_find()` ranking is faster: the per-title term matching hoists
  its long-token filter out of the inner loop and vectorizes the prefix
  test, so it no longer scales with titles times query terms. Combined
  with the token cache from 0.3.6, a warm search dropped from roughly
  2.4s to about 0.15s on the current catalogue.
* Decoding HTML entities in catalogue titles now skips titles that
  contain no entity, avoiding repeated substitutions over the whole
  catalogue on every cache read.
* Downloading a table no longer scans the reference-date column twice to
  detect fiscal-year periods.

# statcanR 0.3.6

## Performance

* `statcan_find()` no longer re-tokenizes the entire table catalogue on
  every call. The per-title tokens are computed once and reused, both
  within a session and across sessions via a new cache file
  (`statcan_catalogue_tokens.rds`) stored alongside the cached catalogue.
  Repeat searches are roughly four times faster (about 2.4s to 0.6s on
  the current catalogue). The token cache is keyed on both the catalogue
  titles and the package version, so it is rebuilt automatically whenever
  the catalogue refreshes or the package is updated.

# statcanR 0.3.5

## Documentation

* Documented how to access the candidates returned by `statcan_chat()`.
  A new README subsection and expanded `statcan_chat()` examples explain
  that the result carries the full ranked `statcan_find()` data frame in
  `$candidates`, and show how to feed `result$candidates$id[1]` straight
  into `statcan_data()` without retyping a table number.

# statcanR 0.3.4

## Chat (optional)

* `statcan_chat()` now resolves its LLM endpoint, API key, and model
  before calling `statcan_find()`, so a missing configuration fails
  immediately instead of after a full catalogue lookup.

# statcanR 0.3.3

## Package and documentation

* Documented `statcan_chat()` in the README: added it to the function
  overview table and a short "Optional: ask a language model for help"
  section, mirroring the vignette's coverage.

# statcanR 0.3.2

## Chat (optional)

* Added `statcan_chat()`, an optional layer over `statcan_find()` that sends
  the query and its ranked candidates to a user-configured,
  OpenAI-compatible chat-completions endpoint. The model explains the best
  match and asks a clarifying question when the query is ambiguous, but it
  can never invent a table number or reason over downloaded data — those
  always come from `statcan_find()` itself.
* This feature adds no new package dependencies and makes no network
  request unless `statcan_chat()` is called directly. Configure the
  endpoint, API key, and model via function arguments,
  `options(statcanR.llm_endpoint = , statcanR.llm_api_key = ,
  statcanR.llm_model = )`, or `Sys.setenv(STATCANR_LLM_ENDPOINT = ,
  STATCANR_LLM_API_KEY = , STATCANR_LLM_MODEL = )`.

# statcanR 0.3.1

## Data access

* Fixed `statcan_data()` and `statcan_download_data()` failing on real
  Statistics Canada tables with `"Statistics Canada returned an empty data or
  metadata file"`. The metadata CSV's trailing comma and multi-section
  structure confused column detection; parsing is now tolerant of the extra
  field.

## Search

* Table titles returned by `statcan_find()` and `statcan_search()` now display HTML/XML characters normally (for example, `R&D` instead of `R&amp;D`).
* Existing catalogue caches are corrected automatically when they are read.
* `statcan_find()` recognizes Canada's major Census Metropolitan Areas (for
  example, Toronto, Montreal, Vancouver) as geography constraints, in
  addition to provinces and territories.
* `statcan_find()` expands common acronyms (`GDP`, `CPI`, `PPI`/`IPPI`, and
  the French `PIB`, `IPC`) to their spelled-out form so queries such as
  `"GDP by industry"` match tables whose titles spell the term out in full.

# statcanR 0.3.0

## Compatibility

* Existing calls to `statcan_search()`, `statcan_data()`, and
  `statcan_download_data()` remain supported.
* `statcan_data()` and `statcan_download_data()` now accept either a
  hyphenated table number such as `"27-10-0014-01"` or an eight-digit Product
  ID such as `"27100014"`.
* `statcan_download_data()` gains an optional `path` argument. Its original
  two-argument form continues to save a CSV file in the working directory.

## Data access

* Complete tables are now located through Statistics Canada's official
  `getFullTableDownloadCSV` Web Data Service method.
* English and French downloads use one shared implementation and the same
  stable processing rules.
* Fixed `statcan_download_data()` returning before its CSV file was written.
* Fixed French downloads overwriting the first data column instead of naming
  it `REF_DATE`.
* Only files created by the active download are removed. Earlier versions
  attempted to delete the entire R session temporary directory.
* Network, HTTP, API, ZIP, and input failures now produce informative errors.
* Reference periods are parsed consistently and `COORDINATE` remains a
  character column.

## Search

* Added `statcan_find()`, which interprets an English or French description of
  a subject, Canadian geography, and date range and returns ranked table
  candidates with an explanation of each match.
* Geography constraints are checked against official WDS table metadata. This
  metadata is cached for seven days, with graceful fallback when it cannot be
  refreshed.
* `statcan_search()` retrieves the official table catalogue from Statistics
  Canada's Web Data Service instead of shipping a static data file.
* The catalogue is cached as an RDS file for 24 hours in the platform-specific
  user cache directory. A valid stale cache is used when WDS is temporarily
  unavailable.
* Searches are case-insensitive, require all supplied keywords, and return an
  empty table when there are no matches.
* Corrupt or incompatible catalogue caches are ignored and rebuilt.

## Package and documentation

* Thierry Warin is the sole author and maintainer of this release.
* Removed unused package dependencies and the obsolete bundled catalogue.
* Moved tests into the standard `tests/testthat` structure and expanded unit
  coverage for Product IDs, dates, languages, catalogue responses, and search.
* Rebuilt the README, vignette, reference documentation, citation metadata,
  and pkgdown website.
* Added current GitHub Actions workflows for multi-platform `R CMD check` and
  automatic pkgdown deployment.

# statcanR 0.2.6

* Fixed a server issue.

# statcanR 0.2.5

* Removed top-level network access so the package can be installed offline.

# statcanR 0.2.4

* Added `statcan_search()` to identify tables available from Statistics
  Canada.

# statcanR 0.2.3

* Added an informative message when a table is unavailable.

# statcanR 0.2.2

* Used `readr::read_csv()` for metadata tables.

# statcanR 0.2.1

* Renamed the public functions to remove the previous `sqs` wording.

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

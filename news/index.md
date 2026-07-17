# Changelog

## statcanR 0.3.0

### Compatibility

- Existing calls to
  [`statcan_search()`](https://warint.github.io/statcanR/reference/statcan_search.md),
  [`statcan_data()`](https://warint.github.io/statcanR/reference/statcan_data.md),
  and
  [`statcan_download_data()`](https://warint.github.io/statcanR/reference/statcan_download_data.md)
  remain supported.
- [`statcan_data()`](https://warint.github.io/statcanR/reference/statcan_data.md)
  and
  [`statcan_download_data()`](https://warint.github.io/statcanR/reference/statcan_download_data.md)
  now accept either a hyphenated table number such as `"27-10-0014-01"`
  or an eight-digit Product ID such as `"27100014"`.
- [`statcan_download_data()`](https://warint.github.io/statcanR/reference/statcan_download_data.md)
  gains an optional `path` argument. Its original two-argument form
  continues to save a CSV file in the working directory.

### Data access

- Complete tables are now located through Statistics Canada’s official
  `getFullTableDownloadCSV` Web Data Service method.
- English and French downloads use one shared implementation and the
  same stable processing rules.
- Fixed
  [`statcan_download_data()`](https://warint.github.io/statcanR/reference/statcan_download_data.md)
  returning before its CSV file was written.
- Fixed French downloads overwriting the first data column instead of
  naming it `REF_DATE`.
- Only files created by the active download are removed. Earlier
  versions attempted to delete the entire R session temporary directory.
- Network, HTTP, API, ZIP, and input failures now produce informative
  errors.
- Reference periods are parsed consistently and `COORDINATE` remains a
  character column.

### Search

- Added
  [`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md),
  which interprets an English or French description of a subject,
  Canadian geography, and date range and returns ranked table candidates
  with an explanation of each match.
- Geography constraints are checked against official WDS table metadata.
  This metadata is cached for seven days, with graceful fallback when it
  cannot be refreshed.
- [`statcan_search()`](https://warint.github.io/statcanR/reference/statcan_search.md)
  retrieves the official table catalogue from Statistics Canada’s Web
  Data Service instead of shipping a static data file.
- The catalogue is cached as an RDS file for 24 hours in the
  platform-specific user cache directory. A valid stale cache is used
  when WDS is temporarily unavailable.
- Searches are case-insensitive, require all supplied keywords, and
  return an empty table when there are no matches.
- Corrupt or incompatible catalogue caches are ignored and rebuilt.

### Package and documentation

- Thierry Warin is the sole author and maintainer of this release.
- Removed unused package dependencies and the obsolete bundled
  catalogue.
- Moved tests into the standard `tests/testthat` structure and expanded
  unit coverage for Product IDs, dates, languages, catalogue responses,
  and search.
- Rebuilt the README, vignette, reference documentation, citation
  metadata, and pkgdown website.
- Added current GitHub Actions workflows for multi-platform
  `R CMD check` and automatic pkgdown deployment.

## statcanR 0.2.6

CRAN release: 2023-08-17

- Fixed a server issue.

## statcanR 0.2.5

CRAN release: 2023-08-10

- Removed top-level network access so the package can be installed
  offline.

## statcanR 0.2.4

CRAN release: 2023-03-03

- Added
  [`statcan_search()`](https://warint.github.io/statcanR/reference/statcan_search.md)
  to identify tables available from Statistics Canada.

## statcanR 0.2.3

CRAN release: 2021-12-14

- Added an informative message when a table is unavailable.

## statcanR 0.2.2

- Used `readr::read_csv()` for metadata tables.

## statcanR 0.2.1

CRAN release: 2021-03-03

- Renamed the public functions to remove the previous `sqs` wording.

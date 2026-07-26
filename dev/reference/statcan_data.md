# Download a Statistics Canada data table

Downloads a complete table from Statistics Canada's Web Data Service
(WDS) and returns it as a data frame. Product IDs can be supplied in the
familiar hyphenated form (for example, `"27-10-0014-01"`) or as an
eight-digit PID (for example, `"27100014"`).

## Usage

``` r
statcan_data(tableNumber, lang, refresh = FALSE)
```

## Arguments

- tableNumber:

  A Statistics Canada table number or Product ID. Both `"27-10-0014-01"`
  and `"27100014"` are accepted.

- lang:

  Language of the downloaded table: `"eng"` or `"fra"`.

- refresh:

  Logical; if `TRUE`, ignore any cached copy and download the table from
  Statistics Canada again.

## Value

A data frame containing the complete Statistics Canada table.

## Details

The function keeps the interface used by earlier statcanR releases.
English and French downloads share the same processing rules. In
particular, the first column is named `REF_DATE`, coordinates are stored
as character, and the table title from the metadata file is added as
`INDICATOR`.

Downloaded tables are cached on disk in the directory returned by
[`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html), so
repeated calls for the same table are served without downloading again.
A cached copy is used only while Statistics Canada has not republished
the table (its release date is unchanged), so the data returned is the
same as a fresh download. When the release date cannot be determined
offline, a cached copy is reused for 24 hours instead. Pass
`refresh = TRUE` to ignore any cached copy and download the table again.
The cache is capped at 500 MB and evicts least-recently-used tables to
stay under that ceiling; set `options(statcanR.cache_max_bytes = ...)`
to change the ceiling, or to `0` to disable table caching.

## Examples

``` r
if (FALSE) { # \dontrun{
science <- statcan_data("27-10-0014-01", "eng")
science_fr <- statcan_data("27100014", "fra")
fresh <- statcan_data("27-10-0014-01", "eng", refresh = TRUE)
} # }
```

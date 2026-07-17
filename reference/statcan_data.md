# Download a Statistics Canada data table

Downloads a complete table from Statistics Canada's Web Data Service
(WDS) and returns it as a data frame. Product IDs can be supplied in the
familiar hyphenated form (for example, `"27-10-0014-01"`) or as an
eight-digit PID (for example, `"27100014"`).

## Usage

``` r
statcan_data(tableNumber, lang)
```

## Arguments

- tableNumber:

  A Statistics Canada table number or Product ID. Both `"27-10-0014-01"`
  and `"27100014"` are accepted.

- lang:

  Language of the downloaded table: `"eng"` or `"fra"`.

## Value

A data frame containing the complete Statistics Canada table.

## Details

The function keeps the interface used by earlier statcanR releases.
English and French downloads share the same processing rules. In
particular, the first column is named `REF_DATE`, coordinates are stored
as character, and the table title from the metadata file is added as
`INDICATOR`.

## Examples

``` r
if (FALSE) { # \dontrun{
science <- statcan_data("27-10-0014-01", "eng")
science_fr <- statcan_data("27100014", "fra")
} # }
```

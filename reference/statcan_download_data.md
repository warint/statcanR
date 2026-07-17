# Download a Statistics Canada table and save a CSV file

Calls
[`statcan_data()`](https://warint.github.io/statcanR/reference/statcan_data.md)
and also writes the returned table to a CSV file. Existing calls with
only `tableNumber` and `lang` remain supported; `path` can be used to
select a different output directory.

## Usage

``` r
statcan_download_data(tableNumber, lang, path = ".")
```

## Arguments

- tableNumber:

  A Statistics Canada table number or Product ID. Both `"27-10-0014-01"`
  and `"27100014"` are accepted.

- lang:

  Language of the downloaded table: `"eng"` or `"fra"`.

- path:

  Directory in which to save the CSV file. The directory must already
  exist. Defaults to the current working directory.

## Value

The downloaded table. The CSV path is available in the `statcan_file`
attribute of the returned data frame.

## Examples

``` r
if (FALSE) { # \dontrun{
science <- statcan_download_data("27-10-0014-01", "eng")
science <- statcan_download_data(
  "27-10-0014-01", "eng", path = tempdir()
)
attr(science, "statcan_file")
} # }
```

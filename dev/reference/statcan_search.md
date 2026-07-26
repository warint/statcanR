# Search Statistics Canada data tables

Searches the catalogue of tables published through Statistics Canada's
Web Data Service (WDS). The catalogue is cached for 24 hours in the
user's cache directory. If WDS is temporarily unavailable, the most
recent valid cache is used.

## Usage

``` r
statcan_search(keywords, lang = c("eng", "fra"), refresh = FALSE)
```

## Arguments

- keywords:

  Character vector of words that must appear in the table title.
  Matching is case-insensitive.

- lang:

  Language of the returned titles: `"eng"` or `"fra"`.

- refresh:

  Logical; if `TRUE`, ignore a fresh cache and request the catalogue
  from WDS.

## Value

A [`DT::datatable`](https://rdrr.io/pkg/DT/man/datatable.html)
containing matching table titles, Product IDs, release dates, and
language.

## Examples

``` r
if (FALSE) { # \dontrun{
statcan_search(c("economy", "export"), "eng")
statcan_search("population", "fra")
} # }
```

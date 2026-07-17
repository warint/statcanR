# Find Statistics Canada tables using a natural-language query

Interprets a short description of the data needed and returns ranked
Statistics Canada table candidates. The query can contain a topic,
Canadian geography, and reference year or range. For example,
`"R&D expenditures in Quebec since 2020"` is interpreted as a research
and development expenditure topic, a Quebec geography constraint, and
coverage beginning in 2020.

## Usage

``` r
statcan_find(query, lang = c("eng", "fra"), n = 5L, refresh = FALSE)
```

## Arguments

- query:

  One non-empty character string describing the desired data.

- lang:

  Language of the table titles: `"eng"` or `"fra"`.

- n:

  Maximum number of candidates to return, from 1 to 20.

- refresh:

  Logical; if `TRUE`, request a fresh catalogue and fresh candidate
  metadata from WDS.

## Value

A data frame of ranked candidates. `id` contains the table number,
`score` is the relevance score, and `match_reason` explains the ranking.
Coverage dates describe the table as a whole. `geography_match` is
`TRUE` when WDS metadata confirms every geography in the query, `FALSE`
when it does not, and `NA` when no geography was requested or validation
was not possible.

## Details

This function finds tables; it does not download or filter their
observations. Use the returned `id` with
[`statcan_data()`](https://warint.github.io/statcanR/reference/statcan_data.md),
then apply any required geography and date filters to the downloaded
data. Rankings are a discovery aid, so review the candidate title before
downloading a large table.

The catalogue is cached for 24 hours. When a geography is present in the
query, metadata for a small set of leading candidates is retrieved
through WDS to confirm that the geography is a table member. That
metadata is cached for seven days. If metadata is temporarily
unavailable, candidates can still be returned with
`geography_match = NA`.

## Examples

``` r
if (FALSE) { # \dontrun{
matches <- statcan_find(
  "R&D expenditures in Quebec since 2020",
  lang = "eng"
)
matches[, c("title", "id", "match_reason")]
} # }
```

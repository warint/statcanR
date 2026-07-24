# statcanR

`statcanR` helps you find and download data tables published by
Statistics Canada. It connects to the official [Web Data Service
(WDS)](https://www.statcan.gc.ca/en/developers/wds), works in English or
French, and returns ordinary data frames that can be analysed with base
R or your preferred R packages.

The package has four main functions, plus one optional one:

| If you want to… | Use… | What you get |
|----|----|----|
| Describe the data you need in ordinary language | [`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md) | Ranked table choices, identifiers, and an explanation of each match |
| Search for exact words in table titles | [`statcan_search()`](https://warint.github.io/statcanR/reference/statcan_search.md) | An interactive table of matching titles and identifiers |
| Load a complete table into R | [`statcan_data()`](https://warint.github.io/statcanR/reference/statcan_data.md) | A data frame |
| Load a table and also save a CSV copy | [`statcan_download_data()`](https://warint.github.io/statcanR/reference/statcan_download_data.md) | A data frame and a UTF-8 CSV file |
| Get a language model’s help interpreting a [`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md) query *(optional, requires configuration)* | [`statcan_chat()`](https://warint.github.io/statcanR/reference/statcan_chat.md) | An explanation of the best match and a clarifying question when needed |

`statcanR` downloads the **complete** Statistics Canada table. Some
tables are large, so check that the table is appropriate for your needs
before downloading it.

## Installation and upgrades

Install or upgrade the released package with the same command:

``` r

install.packages("statcanR")
```

To install the development version from GitHub:

``` r

install.packages("remotes")
remotes::install_github("warint/statcanR")
```

If you upgrade while `statcanR` is already loaded, restart your R
session before loading it again. You can confirm the installed version
with:

``` r

packageVersion("statcanR")
```

Version 0.3.0 keeps the established calls to
[`statcan_search()`](https://warint.github.io/statcanR/reference/statcan_search.md),
[`statcan_data()`](https://warint.github.io/statcanR/reference/statcan_data.md),
and
[`statcan_download_data()`](https://warint.github.io/statcanR/reference/statcan_download_data.md),
so scripts written for earlier releases continue to work. The new
[`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md)
function adds a more conversational way to discover a table without
changing those functions.

## A first workflow

Start by loading the package:

``` r

library(statcanR)
```

### 1. Find a table

Describe the subject, place, and period you need when you do not yet
know the table identifier:

``` r

matches <- statcan_find(
  "R&D expenditures in Quebec since 2020",
  lang = "eng",
  n = 5
)

matches[, c("title", "id", "score", "match_reason")]
```

[`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md)
interprets this request as three clues:

1.  **Subject:** research and development expenditures;
2.  **Geography:** Quebec; and
3.  **Coverage:** a table containing data for 2020.

It returns an ordinary data frame, ranked from the strongest match to
the weakest. The `id` column contains the identifier needed by the
download functions. The `match_reason` column explains why each table
was included, so read the titles before selecting one. Several tables
can answer different interpretations of the same request.

The geography and date are used to check the **table as a whole**. They
do not filter the observations that will later be downloaded. After
downloading, select Quebec and the years from 2020 onward using the
relevant columns in that particular table.

If you already know the exact words used in a Statistics Canada title,
use
[`statcan_search()`](https://warint.github.io/statcanR/reference/statcan_search.md)
instead:

``` r

statcan_search(
  c("federal", "expenditures", "objectives"),
  lang = "eng"
)
```

Searches are case-insensitive. When you supply several keywords,
**every** keyword must appear in the title. If a search is too narrow,
try fewer or more general words. To search French titles, use
`lang = "fra"`.

### Optional: ask a language model for help

[`statcan_chat()`](https://warint.github.io/statcanR/reference/statcan_chat.md)
wraps
[`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md)
with a language model you configure. It explains which candidate best
matches your query and asks a clarifying question when the query is
ambiguous — it never invents a table number or reasons over the
downloaded data itself, so
[`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md)
remains the authoritative source of candidates.

This is entirely optional: it adds no new package dependencies, and it
makes no network request unless you call
[`statcan_chat()`](https://warint.github.io/statcanR/reference/statcan_chat.md)
yourself. It works with any OpenAI-compatible chat-completions endpoint.
Configure it once per session:

``` r

options(
  statcanR.llm_endpoint = "https://api.openai.com/v1/chat/completions",
  statcanR.llm_api_key = "sk-...",
  statcanR.llm_model = "gpt-4o-mini"
)
```

``` r

statcan_chat("R&D expenditures in Quebec since 2020")
```

### 2. Download the table into R

Copy an identifier from the search result and pass it to
[`statcan_data()`](https://warint.github.io/statcanR/reference/statcan_data.md).
The example below uses a small table so it is convenient to try:

``` r

table_data <- statcan_data("10-10-0001-01", lang = "eng")
```

The result is a data frame. Inspect its size, column names, and first
rows before beginning an analysis:

``` r

dim(table_data)
names(table_data)
head(table_data)
```

`REF_DATE` contains the reference period and is converted to a `Date`
when the source format can be interpreted safely. Coordinate columns
remain character values, and `INDICATOR` contains the official table
title.

### 3. Understand table identifiers and languages

Statistics Canada displays identifiers such as `10-10-0001-01`. The
corresponding eight-digit Product ID (PID) is `10100001`. `statcanR`
accepts either form, so these calls request the same table:

``` r

table_data <- statcan_data("10-10-0001-01", "eng")
table_data <- statcan_data("10100001", "eng")
```

Use `lang = "eng"` for English or `lang = "fra"` for French:

``` r

table_fr <- statcan_data("10-10-0001-01", "fra")
```

Column labels supplied by Statistics Canada may differ between the
English and French tables.

## Save a CSV file

Use
[`statcan_data()`](https://warint.github.io/statcanR/reference/statcan_data.md)
when you only need the data in R. Use
[`statcan_download_data()`](https://warint.github.io/statcanR/reference/statcan_download_data.md)
when you also want a CSV copy. Earlier two-argument calls remain valid
and save into the current working directory:

``` r

table_data <- statcan_download_data("10-10-0001-01", "eng")
getwd()
```

For clearer file management, create an output directory and provide it
with `path`:

``` r

output_dir <- file.path(tempdir(), "statcanR-data")
dir.create(output_dir, showWarnings = FALSE)

table_data <- statcan_download_data(
  "10-10-0001-01",
  "eng",
  path = output_dir
)

attr(table_data, "statcan_file")
```

The function still returns the data frame. The `statcan_file` attribute
records the exact path of the saved CSV file.

## Catalogue and metadata caching

The table catalogue is cached for 24 hours so repeated searches are
fast.
[`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md)
also caches the candidate metadata used to verify a geography for seven
days. Use `refresh = TRUE` only when you need the newest catalogue and
metadata:

``` r

statcan_find(
  "population in Alberta since 2021",
  lang = "eng",
  refresh = TRUE
)
```

Downloading and refreshing require an internet connection. If Statistics
Canada’s service is temporarily unavailable, searches can use an
existing valid cache. A natural-language search can still return
candidates when geography metadata is unavailable; in that case,
`geography_match` is `NA` and the explanation says that the geography
could not be verified. Confirm the table title, identifier, language,
and output directory before retrying.

For the complete walkthrough, open the installed vignette:

``` r

vignette("getting-started", package = "statcanR")
```

## Licence and citation

Statistics Canada data are provided under the [Statistics Canada Open
Licence](https://www.statcan.gc.ca/en/terms-conditions/open-licence).
The `statcanR` package is released under the MIT licence.

To cite the package and its methodology, run:

``` r

citation("statcanR")
```

The preferred methodological reference is:

> Warin, T. (2024). Access Statistics Canada’s Open Economic Data for
> Statistics and Data Science Courses. *Technology Innovations in
> Statistics Education*, 15(1). <https://doi.org/10.5070/T5.1868>

## Acknowledgements

The author thanks the Center for Interuniversity Research and Analysis
of Organizations (CIRANO) for its support, along with Thibault Senegas,
Jeremy Schneider, Marine Leroi, Martin Paquette, and contributors to
earlier versions of the package. Errors and omissions remain the
author’s.

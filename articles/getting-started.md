# Getting started with statcanR

## Overview

`statcanR` connects R to [Statistics Canada’s Web Data Service
(WDS)](https://www.statcan.gc.ca/en/developers/wds). This vignette walks
through a complete workflow: finding a table, understanding its
identifier, downloading it, inspecting the result, and optionally saving
a CSV copy.

The package supports three common tasks:

1.  Search the official catalogue of Statistics Canada tables.
2.  Download a complete table in English or French into R.
3.  Save the downloaded table as a CSV file.

The three public functions have distinct purposes:

| Function | Use it when… | Result |
|----|----|----|
| [`statcan_search()`](https://warint.github.io/statcanR/reference/statcan_search.md) | You know the topic but not the table identifier | An interactive table of matching catalogue entries |
| [`statcan_data()`](https://warint.github.io/statcanR/reference/statcan_data.md) | You want the complete table in R | A data frame |
| [`statcan_download_data()`](https://warint.github.io/statcanR/reference/statcan_download_data.md) | You want the data frame and a CSV copy | A data frame with the saved file path attached |

The download functions retrieve a **complete table**, not a filtered
selection of observations. A Statistics Canada table can be large. It is
therefore useful to identify the right table before starting the
download.

## Two concepts to know first

### Table number and Product ID

Statistics Canada displays table numbers such as `10-10-0001-01`. The
first eight digits form the WDS Product ID (PID), `10100001`; the final
`01` identifies the displayed view. `statcanR` accepts either the
displayed table number or the eight-digit PID:

``` r

table_data <- statcan_data("10-10-0001-01", "eng")
table_data <- statcan_data("10100001", "eng")
```

These two calls request the same table.

### Language

Use `lang = "eng"` for an English table and `lang = "fra"` for a French
table. The language controls the table contents and labels returned by
Statistics Canada; it is not a translation performed by `statcanR`.

## Install or upgrade

The command used for a first installation also upgrades an older CRAN
installation:

``` r

install.packages("statcanR")
```

Then load the package:

``` r

library(statcanR)
```

If the package was loaded while you upgraded it, restart the R session
before calling [`library(statcanR)`](https://warint.github.io/statcanR/)
again. Check which version R will use with:

``` r

packageVersion("statcanR")
```

Version 0.3.0 preserves the familiar calls from earlier releases. In
particular, code that supplies a table number and a language to
[`statcan_data()`](https://warint.github.io/statcanR/reference/statcan_data.md)
or
[`statcan_download_data()`](https://warint.github.io/statcanR/reference/statcan_download_data.md)
continues to work.

## Step 1: search the table catalogue

Use
[`statcan_search()`](https://warint.github.io/statcanR/reference/statcan_search.md)
when you know the subject you need but not the table number. It searches
titles without regard to letter case:

``` r

statcan_search(
  c("federal", "expenditures", "objectives"),
  lang = "eng"
)
```

The result is an interactive table displayed in the RStudio Viewer or a
browser. The most important columns are:

- `title`: the official table title;
- `id`: the table number to pass to a download function;
- `release_date`: the catalogue release date; and
- `lang`: the language searched.

When several keywords are supplied, **all** of them must occur in the
title. This makes searches precise, but it can also produce no matches.
If that happens, remove one keyword or use a broader term:

``` r

statcan_search("expenditures", lang = "eng")
```

Search French titles by using `lang = "fra"`:

``` r

statcan_search(c("dépenses", "fédérales"), lang = "fra")
```

The catalogue is cached for 24 hours in R’s platform-appropriate user
cache directory. The cache makes repeated searches faster and avoids
unnecessary requests to Statistics Canada. Set `refresh = TRUE` only
when you specifically need a fresh catalogue:

``` r

statcan_search("population", lang = "eng", refresh = TRUE)
```

If WDS is temporarily unavailable,
[`statcan_search()`](https://warint.github.io/statcanR/reference/statcan_search.md)
uses the most recent valid cache and issues a warning. If no valid cache
exists, it stops with an informative error.

## Step 2: download a complete table

After choosing an identifier, pass it and the desired language to
[`statcan_data()`](https://warint.github.io/statcanR/reference/statcan_data.md).
This example uses a relatively small table that is convenient for
learning:

``` r

table_data <- statcan_data("10-10-0001-01", lang = "eng")
```

The function downloads and unpacks the current full-table CSV archive,
then returns a data frame. Start by examining its dimensions, names, and
first observations:

``` r

dim(table_data)
names(table_data)
head(table_data)
```

The exact columns depend on the table selected. `statcanR` applies a few
consistent rules:

- the first column is named `REF_DATE`;
- annual, monthly, daily, and fiscal reference periods are converted to
  `Date` values when they can be interpreted safely;
- coordinate columns remain character values so leading zeros and
  compound coordinates are not lost; and
- `INDICATOR` contains the official table title read from its metadata.

For example, you can select observations from 2020 onward with ordinary
R subsetting:

``` r

recent_data <- table_data[
  !is.na(table_data$REF_DATE) &
    table_data$REF_DATE >= as.Date("2020-01-01"),
]
```

To download the French version of the table, change the language:

``` r

table_fr <- statcan_data("10-10-0001-01", lang = "fra")
```

Most source column names remain in the selected language, so do not
assume that every English column name has an identical French
equivalent.

## Step 3: save a CSV copy when needed

If you only need to analyse the data in the current R session,
[`statcan_data()`](https://warint.github.io/statcanR/reference/statcan_data.md)
is sufficient. Use
[`statcan_download_data()`](https://warint.github.io/statcanR/reference/statcan_download_data.md)
when you also need a CSV file.

Existing two-argument calls save the file in the current working
directory:

``` r

table_data <- statcan_download_data("10-10-0001-01", "eng")
getwd()
```

This creates `statcan_10100001_eng.csv`. To keep project files
organized, create a dedicated directory and pass it through `path`:

``` r

output_dir <- file.path(tempdir(), "statcanR-data")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

table_data <- statcan_download_data(
  "10-10-0001-01",
  "eng",
  path = output_dir
)

attr(table_data, "statcan_file")
```

The output directory must already exist. The function returns the same
data frame as
[`statcan_data()`](https://warint.github.io/statcanR/reference/statcan_data.md)
and stores the exact CSV path in its `statcan_file` attribute. The CSV
uses UTF-8 encoding, excludes R row names, and writes missing values as
empty fields.

## Compatibility with earlier statcanR scripts

The update does not require you to rewrite established calls:

``` r

# This familiar two-argument form remains valid.
table_data <- statcan_data("10-10-0001-01", "eng")

# This also remains valid and saves into the working directory.
table_data <- statcan_download_data("10-10-0001-01", "eng")
```

The optional `path` argument extends
[`statcan_download_data()`](https://warint.github.io/statcanR/reference/statcan_download_data.md)
without changing the meaning of the original arguments. Both hyphenated
table numbers and eight-digit PIDs are accepted.

## Troubleshooting

The package validates inputs before downloading and reports network or
service problems explicitly. Common issues include:

| Message or symptom | What to check |
|----|----|
| No search results | Try fewer keywords, check the selected language, or use a broader term |
| Invalid `tableNumber` | Use a displayed number such as `10-10-0001-01` or an eight-digit PID such as `10100001` |
| Invalid `lang` | Use exactly `"eng"` or `"fra"` |
| Output directory does not exist | Create the directory before supplying it through `path` |
| WDS is unavailable | Check the internet connection and try again later; catalogue search may use a valid cache |
| Download takes a long time | The function retrieves the complete table, which may be large |

Network failures, invalid tables, unexpected API responses, and
malformed archives stop with messages that identify the affected Product
ID. Temporary files created by a call are removed when it finishes;
other files in the R session’s temporary directory are left untouched.

## Reproducible use

WDS provides the current version of a Statistics Canada table, and
published observations may be revised. For work that must be reproduced
later:

1.  record the table identifier, language, package version, and
    retrieval date;
2.  save a local CSV copy of the data used in the analysis; and
3.  cite the table and Statistics Canada according to the applicable
    data licence.

## Data licence and citation

Review the [Statistics Canada Open
Licence](https://www.statcan.gc.ca/en/terms-conditions/open-licence)
before redistributing downloaded data. To obtain the package’s current
citation, run:

``` r

citation("statcanR")
```

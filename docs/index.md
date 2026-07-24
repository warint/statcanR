# statcanR

`statcanR` helps you find and download data tables published by
Statistics Canada. It connects to the official [Web Data Service
(WDS)](https://www.statcan.gc.ca/en/developers/wds), works in English or
French, and returns ordinary data frames that can be analysed with base
R or your preferred R packages.

The package has four main functions, plus one optional one:

| If you want to…                                                                                                                                                       | Use…                                                                                              | What you get                                                           |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------|------------------------------------------------------------------------|
| Describe the data you need in ordinary language                                                                                                                       | [`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md)                   | Ranked table choices, identifiers, and an explanation of each match    |
| Search for exact words in table titles                                                                                                                                | [`statcan_search()`](https://warint.github.io/statcanR/reference/statcan_search.md)               | An interactive table of matching titles and identifiers                |
| Load a complete table into R                                                                                                                                          | [`statcan_data()`](https://warint.github.io/statcanR/reference/statcan_data.md)                   | A data frame                                                           |
| Load a table and also save a CSV copy                                                                                                                                 | [`statcan_download_data()`](https://warint.github.io/statcanR/reference/statcan_download_data.md) | A data frame and a UTF-8 CSV file                                      |
| Get a language model’s help interpreting a [`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md) query *(optional, requires configuration)* | [`statcan_chat()`](https://warint.github.io/statcanR/reference/statcan_chat.md)                   | An explanation of the best match and a clarifying question when needed |

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

Version 0.3.x keeps the established calls to
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

#### Who is this function for?

[`statcan_chat()`](https://warint.github.io/statcanR/reference/statcan_chat.md)
is **not** required to use `statcanR`. Finding and downloading data —
[`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md),
[`statcan_search()`](https://warint.github.io/statcanR/reference/statcan_search.md),
[`statcan_data()`](https://warint.github.io/statcanR/reference/statcan_data.md)
— works with no account, no key, and no configuration.
[`statcan_chat()`](https://warint.github.io/statcanR/reference/statcan_chat.md)
is a convenience layer on top of
[`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md)
for people who prefer to *describe* the data they want in plain language
and get a short explanation of the shortlist, rather than skim the
ranked titles themselves. Think of it as an optional research assistant,
useful when:

- you are new to the Statistics Canada catalogue and don’t yet know
  which table numbers to look for;
- a query is ambiguous and you’d like a nudge (a clarifying question)
  before committing;
- you’re teaching or demonstrating and want the reasoning spelled out.

Because it talks to a language model, it needs *one* of three things, in
decreasing order of setup effort and cost:

1.  an **API key** from a commercial provider (OpenAI or
    Anthropic/Claude) — pay-as-you-go, billed separately from any
    ChatGPT Plus or Claude Pro subscription;
2.  a **free-tier key** from an OpenAI-compatible provider (for example
    Groq or Google Gemini);
3.  **nothing at all** — a model you run yourself, locally, on your own
    computer (see [No API key? Run a model on your own
    computer](#no-api-key-run-a-model-on-your-own-computer) below).

> **A subscription is not API access.** A ChatGPT Plus or Claude Pro
> subscription lets you chat on the provider’s website; it does *not*
> give you a programmatic key that R can use. There is no supported “log
> in through the website” flow for a package like this. If you don’t
> want to create a billed API account, use option 2 or 3.

This is entirely optional: it adds no new package dependencies, and it
makes no network request unless you call
[`statcan_chat()`](https://warint.github.io/statcanR/reference/statcan_chat.md)
yourself. Choose a provider with the `provider` argument — `"openai"`
(the default) or `"anthropic"` (Claude). The endpoint must use
`https://` (plain `http://` is accepted only for a loopback host such as
`http://localhost`, for a local model), so the key is never sent in
cleartext. Set your provider’s API key once per session (the endpoint
follows from the provider; you pass the `model` you want):

``` r
# The API key is a secret, so it is read from an environment variable rather
# than options() (which can be dumped, saved with a session, or land in
# .Rhistory).
Sys.setenv(OPENAI_API_KEY = "sk-...")        # OpenAI
Sys.setenv(ANTHROPIC_API_KEY = "sk-ant-...") # Anthropic (Claude)
```

[`library(statcanR)`](https://warint.github.io/statcanR/) never asks for
these settings, and no key is needed for
[`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md)
or
[`statcan_data()`](https://warint.github.io/statcanR/reference/statcan_data.md)
— they are read only when you call
[`statcan_chat()`](https://warint.github.io/statcanR/reference/statcan_chat.md).
To set the key once and reuse it in every session without retyping it,
add it to your `~/.Renviron` file (open it with
[`usethis::edit_r_environ()`](https://usethis.r-lib.org/reference/edit.html),
then restart R) rather than calling
[`Sys.setenv()`](https://rdrr.io/r/base/Sys.setenv.html) each time:

    OPENAI_API_KEY=sk-...
    ANTHROPIC_API_KEY=sk-ant-...

R reads `.Renviron` automatically at startup, so the key stays out of
your scripts and `.Rhistory`.

``` r
# OpenAI (the default provider)
statcan_chat("R&D expenditures in Quebec since 2020", model = "gpt-4o-mini")

# Anthropic (Claude)
statcan_chat(
  "R&D expenditures in Quebec since 2020",
  provider = "anthropic", model = "claude-opus-4-8"
)
```

#### No API key? Run a model on your own computer

If you don’t have — and don’t want to pay for — an API key, you can run
an open-source language model **locally**. The model lives on your own
machine, so there is no account to create, nothing to pay, and your
queries never leave your computer. This is often the best choice for
teaching, for privacy-sensitive work, or simply for trying the feature
out.

The most beginner-friendly option is [**Ollama**](https://ollama.com):
install it, then in a terminal run `ollama pull llama3.1` once to
download a model and `ollama serve` to start it. Ollama exposes an
OpenAI-compatible endpoint at `http://localhost:11434`, so
[`statcan_chat()`](https://warint.github.io/statcanR/reference/statcan_chat.md)
reaches it through the default `"openai"` provider — you just point
`endpoint` at your local server:

``` r
statcan_chat(
  "R&D expenditures in Quebec since 2020",
  endpoint = "http://localhost:11434/v1/chat/completions",
  api_key = "ollama",   # a placeholder; a local server ignores the key
  model = "llama3.1"    # any model you have pulled with `ollama pull`
)
```

A few things worth knowing:

- **`http://localhost` is allowed on purpose.** Normally
  [`statcan_chat()`](https://warint.github.io/statcanR/reference/statcan_chat.md)
  refuses plain `http://` so your key can never travel unencrypted, but
  a loopback address (`localhost`) never leaves your machine, so it is
  safe and permitted.
- **The `api_key` is a placeholder.** Local servers don’t check it, but
  the argument is still required, so pass any non-empty string
  (`"ollama"` is a convention).
- **`model` must be one you have downloaded** — whatever you pulled with
  `ollama pull` (for example `"llama3.1"`, `"mistral"`, `"qwen2.5"`).

The same pattern works for [LM Studio](https://lmstudio.ai) and other
OpenAI-compatible local servers, as well as free hosted options like
Groq or Google Gemini — point `endpoint` (and, for hosted ones,
`api_key`) at the service and keep `provider = "openai"`.

#### What `statcan_chat()` gives back

[`statcan_chat()`](https://warint.github.io/statcanR/reference/statcan_chat.md)
does **not** narrow your query down to a single table. Like
[`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md),
it returns *several* ranked candidates — the language model only
explains them; it never picks or invents one for you. When you print the
result you see the whole shortlist:

``` r
Query: R&D expenditures in Quebec since 2020

  rank                                                 title       id
1    1 Gross domestic expenditures on research and develo... 27100359
2    2 Personnel engaged in research and development (R&D...  27100341
3    3 ...                                                    ...

<the model's explanation of which candidate fits best>

Clarifying question: Do you want spending totals, or the number of personnel?
```

The value it returns is a list with four named parts, so you can reach
any piece of it directly instead of copying identifiers by hand:

``` r
result <- statcan_chat("R&D expenditures in Quebec since 2020")

result$query               # the query you asked, unchanged
result$candidates          # the full data frame from statcan_find()
result$explanation         # the model's plain-language explanation
result$clarifying_question # a follow-up question, or NA when the query was clear
```

The important part is `result$candidates`: it is the **same data frame**
that
[`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md)
produces, already containing every identifier and its ranking. You
therefore never need to retype a table number — just index into that
data frame:

``` r
result$candidates$id       # every candidate identifier, best-ranked first
result$candidates$id[1]    # just the top-ranked identifier
```

That last value is exactly what
[`statcan_data()`](https://warint.github.io/statcanR/reference/statcan_data.md)
expects, so a full workflow — describe, choose, download — becomes three
short lines with nothing copied by hand:

``` r
result     <- statcan_chat("R&D expenditures in Quebec since 2020")
top_id     <- result$candidates$id[1]
table_data <- statcan_data(top_id, lang = "eng")
```

If more than one candidate looks plausible, read `result$explanation`
and the `title` column of `result$candidates`, then pick the row you
want (for example `result$candidates$id[2]`) before calling
[`statcan_data()`](https://warint.github.io/statcanR/reference/statcan_data.md).

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

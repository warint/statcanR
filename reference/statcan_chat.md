# Get an LLM's help interpreting a natural-language table search

Sends the query and the ranked candidates from
[`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md)
to a user-configured, OpenAI-compatible chat-completion endpoint, which
explains which candidate(s) best match and asks a clarifying question
when the query is ambiguous. The candidate table numbers and rankings
always come from
[`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md)
itself; the language model only interprets and explains them, and is
never allowed to propose a table number of its own.

## Usage

``` r
statcan_chat(
  query,
  lang = c("eng", "fra"),
  n = 5L,
  refresh = FALSE,
  endpoint = NULL,
  api_key = NULL,
  model = NULL
)
```

## Arguments

- query:

  One non-empty character string describing the desired data. Passed to
  [`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md).

- lang:

  Language of the table titles and of the model's reply: `"eng"` or
  `"fra"`.

- n:

  Maximum number of candidates to request from
  [`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md).

- refresh:

  Logical; forwarded to
  [`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md).

- endpoint:

  Chat-completions endpoint URL. Defaults to
  `getOption("statcanR.llm_endpoint")`, then
  `Sys.getenv("STATCANR_LLM_ENDPOINT")`.

- api_key:

  API key sent as an `Authorization: Bearer` header. Defaults to
  `getOption("statcanR.llm_api_key")`, then
  `Sys.getenv("STATCANR_LLM_API_KEY")`.

- model:

  Model name sent to the endpoint. Defaults to
  `getOption("statcanR.llm_model")`, then
  `Sys.getenv("STATCANR_LLM_MODEL")`.

## Value

A `statcan_chat_result` object: a list with `query`, `candidates` (the
[`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md)
data frame), `explanation`, and `clarifying_question` (`NA` when the
model had none).

## Details

This is an optional feature. It requires no additional packages beyond
what statcanR already imports, but it does require you to configure an
LLM endpoint, API key, and model, either as arguments or through
[`options()`](https://rdrr.io/r/base/options.html) / environment
variables:

- `endpoint`: `options(statcanR.llm_endpoint = ...)` or
  `Sys.setenv(STATCANR_LLM_ENDPOINT = ...)`

- `api_key`: `options(statcanR.llm_api_key = ...)` or
  `Sys.setenv(STATCANR_LLM_API_KEY = ...)`

- `model`: `options(statcanR.llm_model = ...)` or
  `Sys.setenv(STATCANR_LLM_MODEL = ...)`

No network request is made unless `statcan_chat()` is called directly.

## Examples

``` r
if (FALSE) { # \dontrun{
options(
  statcanR.llm_endpoint = "https://api.openai.com/v1/chat/completions",
  statcanR.llm_api_key = "sk-...",
  statcanR.llm_model = "gpt-4o-mini"
)
statcan_chat("R&D expenditures in Quebec since 2020")
} # }
```

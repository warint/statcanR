# Get an LLM's help interpreting a natural-language table search

Sends the query and the ranked candidates from
[`statcan_find()`](https://warint.github.io/statcanR/dev/reference/statcan_find.md)
to a user-configured language-model provider, which explains which
candidate(s) best match and asks a clarifying question when the query is
ambiguous. The candidate table numbers and rankings always come from
[`statcan_find()`](https://warint.github.io/statcanR/dev/reference/statcan_find.md)
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
  model = NULL,
  provider = c("openai", "anthropic")
)
```

## Arguments

- query:

  One non-empty character string describing the desired data. Passed to
  [`statcan_find()`](https://warint.github.io/statcanR/dev/reference/statcan_find.md).

- lang:

  Language of the table titles and of the model's reply: `"eng"` or
  `"fra"`.

- n:

  Maximum number of candidates to request from
  [`statcan_find()`](https://warint.github.io/statcanR/dev/reference/statcan_find.md).

- refresh:

  Logical; forwarded to
  [`statcan_find()`](https://warint.github.io/statcanR/dev/reference/statcan_find.md).

- endpoint:

  Provider endpoint URL. Defaults to
  `getOption("statcanR.llm_endpoint")`, then
  `Sys.getenv("STATCANR_LLM_ENDPOINT")`, then the chosen provider's own
  endpoint. Must be `https://`, except for loopback hosts (for example,
  `http://localhost`).

- api_key:

  API key. Defaults to `Sys.getenv("STATCANR_LLM_API_KEY")`, then the
  provider's native variable (`OPENAI_API_KEY` for `"openai"`,
  `ANTHROPIC_API_KEY` for `"anthropic"`). For safety it is not read from
  [`options()`](https://rdrr.io/r/base/options.html). It is sent as an
  `Authorization: Bearer` header for `"openai"` and as an `x-api-key`
  header for `"anthropic"`.

- model:

  Model name sent to the provider (for example, `"gpt-4o-mini"` for
  OpenAI or `"claude-opus-4-8"` for Anthropic). Defaults to
  `getOption("statcanR.llm_model")`, then
  `Sys.getenv("STATCANR_LLM_MODEL")`.

- provider:

  Which LLM provider to use: `"openai"` (the default, also covering
  OpenAI-compatible and local servers) or `"anthropic"` (Claude).

## Value

A `statcan_chat_result` object: a list with `query`, `candidates` (the
[`statcan_find()`](https://warint.github.io/statcanR/dev/reference/statcan_find.md)
data frame), `explanation`, and `clarifying_question` (`NA` when the
model had none).

## Details

Two providers ship built in, selected with the `provider` argument:

- `"openai"` (the default): the OpenAI chat-completions format, using an
  `Authorization: Bearer` API key. This also covers any
  OpenAI-compatible server – Groq, Together, OpenRouter, Mistral, vLLM,
  or a local open-source model served by Ollama or LM Studio – by
  pointing `endpoint` at it (a loopback `http://localhost` endpoint is
  accepted for local models; pass any placeholder `api_key` for servers
  that ignore it).

- `"anthropic"`: the Claude Messages format, using an `x-api-key`
  header.

This is an optional feature. It requires no additional packages beyond
what statcanR already imports, but it does require you to configure an
API key and model (the endpoint defaults to the chosen provider), either
as arguments or through
[`options()`](https://rdrr.io/r/base/options.html) / environment
variables:

- `endpoint`: `options(statcanR.llm_endpoint = ...)` or
  `Sys.setenv(STATCANR_LLM_ENDPOINT = ...)`. Defaults to the provider's
  own endpoint when unset.

- `api_key`: `Sys.setenv(STATCANR_LLM_API_KEY = ...)` (or the `api_key`
  argument, or the provider's native variable – `OPENAI_API_KEY` /
  `ANTHROPIC_API_KEY`). Because it is a secret, the key is **not** read
  from [`options()`](https://rdrr.io/r/base/options.html), which can be
  dumped, saved with a session, or recorded in `.Rhistory`.

- `model`: `options(statcanR.llm_model = ...)` or
  `Sys.setenv(STATCANR_LLM_MODEL = ...)`

The endpoint must use `https://` so the key is never sent in cleartext;
plain `http://` is accepted only for loopback hosts (for example,
`http://localhost` for a local model).

No network request is made unless `statcan_chat()` is called directly.

## Examples

``` r
if (FALSE) { # \dontrun{
# OpenAI (the default provider)
Sys.setenv(OPENAI_API_KEY = "sk-...")
result <- statcan_chat(
  "R&D expenditures in Quebec since 2020",
  model = "gpt-4o-mini"
)

# Anthropic (Claude)
Sys.setenv(ANTHROPIC_API_KEY = "sk-ant-...")
result <- statcan_chat(
  "R&D expenditures in Quebec since 2020",
  provider = "anthropic", model = "claude-opus-4-8"
)

# A local open-source model served by Ollama (no key over loopback http)
result <- statcan_chat(
  "R&D expenditures in Quebec since 2020",
  endpoint = "http://localhost:11434/v1/chat/completions",
  api_key = "ollama", model = "llama3.1"
)

# statcan_chat() returns several ranked candidates, not a single table:
# the model explains them but never picks or invents one for you.
# The candidates are already a data frame, so you never retype an id.
result$candidates          # the full statcan_find() data frame
result$candidates$id       # every candidate id, best-ranked first
result$candidates$id[1]    # just the top-ranked id
result$explanation         # the model's plain-language explanation

# Feed the chosen id straight into statcan_data() -- nothing copied by hand.
table_data <- statcan_data(result$candidates$id[1], lang = "eng")
} # }
```

# Continue a `statcan_chat()` conversation

Sends a follow-up `message` – typically an answer to the
`clarifying_question` from a previous turn – and returns an updated
result. The follow-up stays scoped to the **same candidate tables** that
[`statcan_chat()`](https://warint.github.io/statcanR/reference/statcan_chat.md)
already found: it never re-runs
[`statcan_find()`](https://warint.github.io/statcanR/reference/statcan_find.md)
and the model still never proposes a table number of its own. To search
the catalogue again, start a new conversation with
[`statcan_chat()`](https://warint.github.io/statcanR/reference/statcan_chat.md).

## Usage

``` r
statcan_chat_continue(result, message, api_key = NULL)
```

## Arguments

- result:

  A `statcan_chat_result` returned by
  [`statcan_chat()`](https://warint.github.io/statcanR/reference/statcan_chat.md)
  (or by a previous `statcan_chat_continue()` call).

- message:

  One non-empty character string: your follow-up to the model.

- api_key:

  API key, re-resolved exactly as in
  [`statcan_chat()`](https://warint.github.io/statcanR/reference/statcan_chat.md).
  Defaults to `Sys.getenv("STATCANR_LLM_API_KEY")`, then the provider's
  native variable. Not read from
  [`options()`](https://rdrr.io/r/base/options.html).

## Value

An updated `statcan_chat_result` with the same `candidates`, a new
`explanation` and `clarifying_question`, and an extended conversation.

## Details

The returned object is itself continuable, so you can chain several
follow-ups. The API key is re-resolved on each call (from the `api_key`
argument, the `STATCANR_LLM_API_KEY` environment variable, or the
provider's native variable) because, for safety, it is never stored in
the result object.

## Examples

``` r
if (FALSE) { # \dontrun{
Sys.setenv(ANTHROPIC_API_KEY = "sk-ant-...")
chat <- statcan_chat(
  "R&D spending in Quebec",
  provider = "anthropic", model = "claude-opus-4-8"
)
chat$clarifying_question

# Answer it and keep the same shortlist of candidates. Reassigning the same
# variable keeps the latest turn; you never need r1/r2/r3-style names.
chat <- statcan_chat_continue(chat, "annual data, since 2015")
chat$explanation

# Chain another follow-up the same way:
chat <- statcan_chat_continue(chat, "just the total, not by industry")
} # }
```

#' Get an LLM's help interpreting a natural-language table search
#'
#' Sends the query and the ranked candidates from [statcan_find()] to a
#' user-configured language-model provider, which explains which
#' candidate(s) best match and asks a clarifying question when the query is
#' ambiguous. The candidate table numbers and rankings always come from
#' [statcan_find()] itself; the language model only interprets and explains
#' them, and is never allowed to propose a table number of its own.
#'
#' Two providers ship built in, selected with the `provider` argument:
#'
#' * `"openai"` (the default): the OpenAI chat-completions format, using an
#'   `Authorization: Bearer` API key. This also covers any OpenAI-compatible
#'   server -- Groq, Together, OpenRouter, Mistral, vLLM, or a local
#'   open-source model served by Ollama or LM Studio -- by pointing
#'   `endpoint` at it (a loopback `http://localhost` endpoint is accepted for
#'   local models; pass any placeholder `api_key` for servers that ignore
#'   it).
#' * `"anthropic"`: the Claude Messages format, using an `x-api-key` header.
#'
#' This is an optional feature. It requires no additional packages beyond
#' what statcanR already imports, but it does require you to configure an
#' API key and model (the endpoint defaults to the chosen provider), either
#' as arguments or through `options()` / environment variables:
#'
#' * `endpoint`: `options(statcanR.llm_endpoint = ...)` or
#'   `Sys.setenv(STATCANR_LLM_ENDPOINT = ...)`. Defaults to the provider's
#'   own endpoint when unset.
#' * `api_key`: `Sys.setenv(STATCANR_LLM_API_KEY = ...)` (or the `api_key`
#'   argument, or the provider's native variable -- `OPENAI_API_KEY` /
#'   `ANTHROPIC_API_KEY`). Because it is a secret, the key is **not** read
#'   from `options()`, which can be dumped, saved with a session, or
#'   recorded in `.Rhistory`.
#' * `model`: `options(statcanR.llm_model = ...)` or
#'   `Sys.setenv(STATCANR_LLM_MODEL = ...)`
#'
#' The endpoint must use `https://` so the key is never sent in cleartext;
#' plain `http://` is accepted only for loopback hosts (for example,
#' `http://localhost` for a local model).
#'
#' No network request is made unless `statcan_chat()` is called directly.
#'
#' @param query One non-empty character string describing the desired data.
#'   Passed to [statcan_find()].
#' @param lang Language of the table titles and of the model's reply:
#'   `"eng"` or `"fra"`.
#' @param n Maximum number of candidates to request from [statcan_find()].
#' @param refresh Logical; forwarded to [statcan_find()].
#' @param endpoint Provider endpoint URL. Defaults to
#'   `getOption("statcanR.llm_endpoint")`, then
#'   `Sys.getenv("STATCANR_LLM_ENDPOINT")`, then the chosen provider's own
#'   endpoint. Must be `https://`, except for loopback hosts (for example,
#'   `http://localhost`).
#' @param api_key API key. Defaults to `Sys.getenv("STATCANR_LLM_API_KEY")`,
#'   then the provider's native variable (`OPENAI_API_KEY` for `"openai"`,
#'   `ANTHROPIC_API_KEY` for `"anthropic"`). For safety it is not read from
#'   `options()`. It is sent as an `Authorization: Bearer` header for
#'   `"openai"` and as an `x-api-key` header for `"anthropic"`.
#' @param model Model name sent to the provider (for example, `"gpt-4o-mini"`
#'   for OpenAI or `"claude-opus-4-8"` for Anthropic). Defaults to
#'   `getOption("statcanR.llm_model")`, then
#'   `Sys.getenv("STATCANR_LLM_MODEL")`.
#' @param provider Which LLM provider to use: `"openai"` (the default,
#'   also covering OpenAI-compatible and local servers) or `"anthropic"`
#'   (Claude).
#'
#' @return A `statcan_chat_result` object: a list with `query`, `candidates`
#'   (the [statcan_find()] data frame), `explanation`, and
#'   `clarifying_question` (`NA` when the model had none).
#' @export
#'
#' @examples
#' \dontrun{
#' # OpenAI (the default provider)
#' Sys.setenv(OPENAI_API_KEY = "sk-...")
#' result <- statcan_chat(
#'   "R&D expenditures in Quebec since 2020",
#'   model = "gpt-4o-mini"
#' )
#'
#' # Anthropic (Claude)
#' Sys.setenv(ANTHROPIC_API_KEY = "sk-ant-...")
#' result <- statcan_chat(
#'   "R&D expenditures in Quebec since 2020",
#'   provider = "anthropic", model = "claude-opus-4-8"
#' )
#'
#' # A local open-source model served by Ollama (no key over loopback http)
#' result <- statcan_chat(
#'   "R&D expenditures in Quebec since 2020",
#'   endpoint = "http://localhost:11434/v1/chat/completions",
#'   api_key = "ollama", model = "llama3.1"
#' )
#'
#' # statcan_chat() returns several ranked candidates, not a single table:
#' # the model explains them but never picks or invents one for you.
#' # The candidates are already a data frame, so you never retype an id.
#' result$candidates          # the full statcan_find() data frame
#' result$candidates$id       # every candidate id, best-ranked first
#' result$candidates$id[1]    # just the top-ranked id
#' result$explanation         # the model's plain-language explanation
#'
#' # Feed the chosen id straight into statcan_data() -- nothing copied by hand.
#' table_data <- statcan_data(result$candidates$id[1], lang = "eng")
#' }
statcan_chat <- function(query, lang = c("eng", "fra"), n = 5L,
                         refresh = FALSE, endpoint = NULL, api_key = NULL,
                         model = NULL, provider = c("openai", "anthropic")) {
  lang <- match.arg(lang)
  provider <- match.arg(provider)
  config <- resolve_llm_config(endpoint, api_key, model, provider = provider)
  candidates <- statcan_find(query, lang = lang, n = n, refresh = refresh)

  if (!nrow(candidates)) {
    # No candidates: there is nothing for the model to explain, so we skip the
    # network call and return a result with no conversation state. Continuing
    # such a result is a clear error in statcan_chat_continue().
    contract <- list(
      explanation = if (lang == "eng") {
        "No matching tables were found for this query."
      } else {
        "Aucun tableau correspondant n'a \u00e9t\u00e9 trouv\u00e9 pour cette requ\u00eate."
      },
      clarifying_question = NA_character_
    )
    return(new_statcan_chat_result(query, candidates, contract, conversation = NULL))
  }

  messages <- build_llm_prompt(query, candidates, lang)
  parsed <- call_llm_chat(
    config$provider, config$endpoint, config$api_key, config$model, messages
  )
  reply <- parse_llm_reply(parsed, config$provider)
  contract <- parse_chat_contract(reply)
  messages <- c(messages, list(list(role = "assistant", content = reply)))

  new_statcan_chat_result(
    query = query,
    candidates = candidates,
    contract = contract,
    conversation = list(
      provider = provider,
      endpoint = config$endpoint,
      model = config$model,
      lang = lang,
      messages = messages
    )
  )
}


# Shared constructor for the statcan_chat_result object. `conversation` holds
# everything needed to continue the chat -- provider name, endpoint, model,
# lang, and the running message history -- but deliberately NOT the API key,
# which is a secret and must not be persisted in a saved object. It is NULL
# when there is no conversation to continue (an empty search).
new_statcan_chat_result <- function(query, candidates, contract,
                                    conversation = NULL) {
  structure(
    list(
      query = query,
      candidates = candidates,
      explanation = contract$explanation,
      clarifying_question = contract$clarifying_question,
      conversation = conversation
    ),
    class = "statcan_chat_result"
  )
}


#' Continue a `statcan_chat()` conversation
#'
#' Sends a follow-up `message` -- typically an answer to the
#' `clarifying_question` from a previous turn -- and returns an updated
#' result. The follow-up stays scoped to the **same candidate tables** that
#' [statcan_chat()] already found: it never re-runs [statcan_find()] and the
#' model still never proposes a table number of its own. To search the
#' catalogue again, start a new conversation with [statcan_chat()].
#'
#' The returned object is itself continuable, so you can chain several
#' follow-ups. The API key is re-resolved on each call (from the `api_key`
#' argument, the `STATCANR_LLM_API_KEY` environment variable, or the
#' provider's native variable) because, for safety, it is never stored in the
#' result object.
#'
#' @param result A `statcan_chat_result` returned by [statcan_chat()] (or by a
#'   previous `statcan_chat_continue()` call).
#' @param message One non-empty character string: your follow-up to the model.
#' @param api_key API key, re-resolved exactly as in [statcan_chat()]. Defaults
#'   to `Sys.getenv("STATCANR_LLM_API_KEY")`, then the provider's native
#'   variable. Not read from `options()`.
#'
#' @return An updated `statcan_chat_result` with the same `candidates`, a new
#'   `explanation` and `clarifying_question`, and an extended conversation.
#' @export
#'
#' @examples
#' \dontrun{
#' Sys.setenv(ANTHROPIC_API_KEY = "sk-ant-...")
#' r1 <- statcan_chat(
#'   "R&D spending in Quebec",
#'   provider = "anthropic", model = "claude-opus-4-8"
#' )
#' r1$clarifying_question
#'
#' # Answer it and keep the same shortlist of candidates:
#' r2 <- statcan_chat_continue(r1, "annual data, since 2015")
#' r2$explanation
#'
#' # Chain another follow-up:
#' r3 <- statcan_chat_continue(r2, "just the total, not by industry")
#' }
statcan_chat_continue <- function(result, message, api_key = NULL) {
  if (!inherits(result, "statcan_chat_result")) {
    stop(
      "statcan_chat_continue() expects a statcan_chat_result from ",
      "statcan_chat().",
      call. = FALSE
    )
  }
  if (is.null(result$conversation)) {
    stop(
      "statcan_chat_continue(): there is no conversation to continue; the ",
      "initial statcan_chat() search returned no candidate tables.",
      call. = FALSE
    )
  }
  if (!is.character(message) || length(message) != 1L ||
        is.na(message) || !nzchar(trimws(message))) {
    stop(
      "statcan_chat_continue() requires a single non-empty message.",
      call. = FALSE
    )
  }

  conv <- result$conversation
  # Reuse the same resolution path as statcan_chat() so the stale-option
  # warning, the key fallback order, and the https-only check all behave
  # identically. Only the key is re-resolved; endpoint/model/provider come
  # from the stored conversation.
  config <- resolve_llm_config(
    conv$endpoint, api_key, conv$model, provider = conv$provider
  )

  messages <- c(conv$messages, list(list(role = "user", content = message)))
  parsed <- call_llm_chat(
    config$provider, config$endpoint, config$api_key, config$model, messages
  )
  reply <- parse_llm_reply(parsed, config$provider)
  contract <- parse_chat_contract(reply)
  messages <- c(messages, list(list(role = "assistant", content = reply)))

  new_statcan_chat_result(
    query = result$query,
    candidates = result$candidates,
    contract = contract,
    conversation = list(
      provider = conv$provider,
      endpoint = conv$endpoint,
      model = conv$model,
      lang = conv$lang,
      messages = messages
    )
  )
}


#' @export
print.statcan_chat_result <- function(x, ...) {
  cat("Query:", x$query, "\n\n")
  print(x$candidates[, c("rank", "title", "id")])
  cat("\n", x$explanation, "\n", sep = "")
  if (!is.na(x$clarifying_question)) {
    cat("\nClarifying question:", x$clarifying_question, "\n")
  }
  invisible(x)
}


# The built-in provider registry. Each provider bundles the few things that
# actually differ between vendors: the default endpoint, the native API-key
# environment variable, how the API key is attached (auth scheme), how the
# request body is shaped, and how the reply is read back out. Everything else
# -- the statcan_find() ranking, the prompt text, the reply contract, and the
# https-only security check -- is provider-neutral.
llm_provider <- function(provider = c("openai", "anthropic")) {
  provider <- match.arg(provider)
  switch(
    provider,
    openai = list(
      name = "openai",
      endpoint = "https://api.openai.com/v1/chat/completions",
      key_env = "OPENAI_API_KEY",
      build_headers = function(api_key) {
        httr::add_headers(Authorization = paste("Bearer", api_key))
      },
      build_body = function(model, messages) {
        list(model = model, messages = messages)
      },
      parse_content = function(parsed) {
        parsed$choices[[1L]]$message$content
      }
    ),
    anthropic = list(
      name = "anthropic",
      endpoint = "https://api.anthropic.com/v1/messages",
      key_env = "ANTHROPIC_API_KEY",
      build_headers = function(api_key) {
        httr::add_headers(
          `x-api-key` = api_key,
          `anthropic-version` = "2023-06-01"
        )
      },
      build_body = function(model, messages) {
        # Claude takes the system prompt as a top-level field, not a message,
        # and requires max_tokens. Lift the neutral "system" message out and
        # keep the rest (the user turn) as messages.
        system_text <- NULL
        chat <- list()
        for (message in messages) {
          if (identical(message$role, "system")) {
            system_text <- message$content
          } else {
            chat[[length(chat) + 1L]] <- message
          }
        }
        body <- list(model = model, max_tokens = 4096L, messages = chat)
        if (!is.null(system_text)) {
          body$system <- system_text
        }
        body
      },
      parse_content = function(parsed) {
        parsed$content[[1L]]$text
      }
    )
  )
}


resolve_llm_config <- function(endpoint, api_key, model,
                               provider = c("openai", "anthropic")) {
  provider <- match.arg(provider)
  prov <- llm_provider(provider)

  endpoint <- first_nonempty(
    endpoint,
    getOption("statcanR.llm_endpoint"),
    Sys.getenv("STATCANR_LLM_ENDPOINT")
  )
  if (is.null(endpoint)) {
    endpoint <- prov$endpoint
  }
  # The API key is a secret, so it is deliberately not read from options():
  # options can be dumped with options(), captured in a saved session, or land
  # in .Rhistory when set inline. It comes only from the api_key argument, the
  # STATCANR_LLM_API_KEY environment variable, or the provider's native key
  # variable (OPENAI_API_KEY / ANTHROPIC_API_KEY). Earlier versions did read the
  # option, so warn if a stale one is set. Only its presence is checked with
  # nzchar(); the value itself is never read, so the key is not re-exposed.
  if (nzchar(getOption("statcanR.llm_api_key", ""))) {
    warning(
      "The statcanR.llm_api_key option is ignored for security. Set the API ",
      "key via Sys.setenv(STATCANR_LLM_API_KEY = ) or the api_key argument ",
      "instead.",
      call. = FALSE
    )
  }
  api_key <- first_nonempty(
    api_key,
    Sys.getenv("STATCANR_LLM_API_KEY"),
    Sys.getenv(prov$key_env)
  )
  model <- first_nonempty(
    model,
    getOption("statcanR.llm_model"),
    Sys.getenv("STATCANR_LLM_MODEL")
  )

  if (is.null(endpoint) || is.null(api_key) || is.null(model)) {
    stop(
      "statcan_chat() requires an LLM endpoint, API key, and model. The ",
      "endpoint defaults to the chosen provider, or set it via the endpoint ",
      "argument, options(statcanR.llm_endpoint = ), or STATCANR_LLM_ENDPOINT. ",
      "Set the model via the model argument, options(statcanR.llm_model = ), ",
      "or STATCANR_LLM_MODEL. Set the API key via the api_key argument, ",
      "Sys.setenv(STATCANR_LLM_API_KEY = ), or the provider's native ",
      "variable (OPENAI_API_KEY / ANTHROPIC_API_KEY); for safety it is not ",
      "read from options().",
      call. = FALSE
    )
  }

  validate_llm_endpoint(endpoint)

  list(provider = prov, endpoint = endpoint, api_key = api_key, model = model)
}


# Refuse to send the API key over an unencrypted connection. https is always
# allowed; plain http is allowed only for loopback hosts, so that local models
# (for example, an Ollama server on http://localhost) keep working while a
# mistyped public http:// endpoint cannot leak the key in cleartext.
validate_llm_endpoint <- function(endpoint) {
  parsed <- httr::parse_url(endpoint)
  scheme <- tolower(if (is.null(parsed$scheme)) "" else parsed$scheme)
  host <- tolower(if (is.null(parsed$hostname)) "" else parsed$hostname)

  if (scheme == "https") {
    return(invisible(endpoint))
  }

  is_loopback <- host %in% c("localhost", "127.0.0.1", "::1", "[::1]") ||
    startsWith(host, "127.")
  if (scheme == "http" && is_loopback) {
    return(invisible(endpoint))
  }

  if (scheme == "http") {
    stop(
      "statcan_chat() will not send the API key to an unencrypted http:// ",
      "endpoint (", host, "). Use an https:// endpoint, or a loopback host ",
      "such as http://localhost for a local model.",
      call. = FALSE
    )
  }

  stop(
    "statcan_chat() requires an https:// endpoint (or http:// on a loopback ",
    "host for a local model). Received: ", endpoint, ".",
    call. = FALSE
  )
}


first_nonempty <- function(...) {
  for (value in list(...)) {
    if (is.null(value) || length(value) != 1L || is.na(value)) {
      next
    }
    if (nzchar(value)) {
      return(value)
    }
  }
  NULL
}


build_llm_prompt <- function(query, candidates, lang) {
  candidate_lines <- paste0(
    "- ", candidates$id, ": \"", candidates$title, "\"",
    " (", candidates$start_date, " to ", candidates$end_date, ")"
  )
  candidate_block <- paste(candidate_lines, collapse = "\n")

  if (lang == "eng") {
    system_content <- paste(
      "You help a user pick the right Statistics Canada data table.",
      "You are given a user query and a ranked list of candidate tables",
      "with their official table numbers. You must only ever refer to",
      "the table numbers given to you; never invent or guess a table",
      "number. Reply in English using exactly this format, with no other",
      "text before or after it:\n",
      "EXPLANATION:\n<one or two short paragraphs>\n",
      "CLARIFYING_QUESTION:\n<a question, or the literal word NONE>"
    )
  } else {
    system_content <- paste(
      "Vous aidez un utilisateur \u00e0 choisir le bon tableau de donn\u00e9es",
      "de Statistique Canada. On vous donne une requ\u00eate et une liste",
      "class\u00e9e de tableaux candidats avec leurs num\u00e9ros officiels. Vous ne",
      "devez jamais inventer ou deviner un num\u00e9ro de tableau. R\u00e9pondez en",
      "fran\u00e7ais en utilisant exactement ce format, sans aucun autre",
      "texte avant ou apr\u00e8s :\n",
      "EXPLANATION:\n<un ou deux courts paragraphes>\n",
      "CLARIFYING_QUESTION:\n<une question, ou le mot NONE>"
    )
  }

  user_content <- paste0(
    "Query: ", query, "\n\nCandidate tables:\n", candidate_block
  )

  list(
    list(role = "system", content = system_content),
    list(role = "user", content = user_content)
  )
}


call_llm_chat <- function(provider, endpoint, api_key, model, messages) {
  response <- tryCatch(
    httr::POST(
      endpoint,
      provider$build_headers(api_key),
      body = provider$build_body(model, messages),
      encode = "json",
      httr::timeout(60),
      httr::user_agent(statcan_user_agent())
    ),
    error = function(error) {
      stop(
        "statcan_chat(): unable to contact the LLM endpoint. ",
        conditionMessage(error),
        call. = FALSE
      )
    }
  )
  stop_for_llm_status(response)

  tryCatch(
    jsonlite::fromJSON(
      httr::content(response, as = "text", encoding = "UTF-8"),
      simplifyVector = FALSE
    ),
    error = function(error) {
      stop(
        "statcan_chat(): the LLM endpoint returned invalid JSON. ",
        conditionMessage(error),
        call. = FALSE
      )
    }
  )
}


stop_for_llm_status <- function(response) {
  if (!httr::http_error(response)) {
    return(invisible(response))
  }

  status <- httr::status_code(response)
  detail <- tryCatch(
    httr::content(response, as = "text", encoding = "UTF-8"),
    error = function(error) ""
  )
  detail <- trimws(gsub("[\r\n]+", " ", detail))
  if (nchar(detail) > 200L) {
    detail <- paste0(substr(detail, 1L, 200L), "...")
  }
  suffix <- if (nzchar(detail)) paste0(" ", detail) else ""

  stop(
    "statcan_chat(): the LLM request failed with HTTP ", status, ".",
    suffix,
    call. = FALSE
  )
}


parse_llm_reply <- function(parsed, provider = llm_provider("openai")) {
  content <- tryCatch(
    provider$parse_content(parsed),
    error = function(error) NULL
  )
  if (is.null(content) || length(content) != 1L || !nzchar(content)) {
    stop(
      "statcan_chat(): the LLM endpoint's response did not include a ",
      "chat completion message.",
      call. = FALSE
    )
  }
  content
}


parse_chat_contract <- function(text) {
  match <- regmatches(
    text,
    regexec(
      "(?s)EXPLANATION:\\s*(.*?)\\s*CLARIFYING_QUESTION:\\s*(.*)",
      text,
      perl = TRUE
    )
  )[[1L]]

  if (length(match) != 3L) {
    return(list(
      explanation = trimws(text),
      clarifying_question = NA_character_
    ))
  }

  clarifying_question <- trimws(match[[3L]])
  list(
    explanation = trimws(match[[2L]]),
    clarifying_question = if (toupper(clarifying_question) == "NONE") {
      NA_character_
    } else {
      clarifying_question
    }
  )
}

#' Get an LLM's help interpreting a natural-language table search
#'
#' Sends the query and the ranked candidates from [statcan_find()] to a
#' user-configured, OpenAI-compatible chat-completion endpoint, which
#' explains which candidate(s) best match and asks a clarifying question
#' when the query is ambiguous. The candidate table numbers and rankings
#' always come from [statcan_find()] itself; the language model only
#' interprets and explains them, and is never allowed to propose a table
#' number of its own.
#'
#' This is an optional feature. It requires no additional packages beyond
#' what statcanR already imports, but it does require you to configure an
#' LLM endpoint, API key, and model, either as arguments or through
#' `options()` / environment variables:
#'
#' * `endpoint`: `options(statcanR.llm_endpoint = ...)` or
#'   `Sys.setenv(STATCANR_LLM_ENDPOINT = ...)`
#' * `api_key`: `Sys.setenv(STATCANR_LLM_API_KEY = ...)` (or the `api_key`
#'   argument). Because it is a secret, the key is **not** read from
#'   `options()`, which can be dumped, saved with a session, or recorded in
#'   `.Rhistory`.
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
#' @param endpoint Chat-completions endpoint URL. Defaults to
#'   `getOption("statcanR.llm_endpoint")`, then
#'   `Sys.getenv("STATCANR_LLM_ENDPOINT")`. Must be `https://`, except for
#'   loopback hosts (for example, `http://localhost`).
#' @param api_key API key sent as an `Authorization: Bearer` header. Defaults
#'   to `Sys.getenv("STATCANR_LLM_API_KEY")`. For safety it is not read from
#'   `options()`.
#' @param model Model name sent to the endpoint. Defaults to
#'   `getOption("statcanR.llm_model")`, then
#'   `Sys.getenv("STATCANR_LLM_MODEL")`.
#'
#' @return A `statcan_chat_result` object: a list with `query`, `candidates`
#'   (the [statcan_find()] data frame), `explanation`, and
#'   `clarifying_question` (`NA` when the model had none).
#' @export
#'
#' @examples
#' \dontrun{
#' options(
#'   statcanR.llm_endpoint = "https://api.openai.com/v1/chat/completions",
#'   statcanR.llm_model = "gpt-4o-mini"
#' )
#' Sys.setenv(STATCANR_LLM_API_KEY = "sk-...")
#'
#' # statcan_chat() returns several ranked candidates, not a single table:
#' # the model explains them but never picks or invents one for you.
#' result <- statcan_chat("R&D expenditures in Quebec since 2020")
#'
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
                         model = NULL) {
  lang <- match.arg(lang)
  config <- resolve_llm_config(endpoint, api_key, model)
  candidates <- statcan_find(query, lang = lang, n = n, refresh = refresh)

  if (!nrow(candidates)) {
    return(structure(
      list(
        query = query,
        candidates = candidates,
        explanation = if (lang == "eng") {
          "No matching tables were found for this query."
        } else {
          "Aucun tableau correspondant n'a \u00e9t\u00e9 trouv\u00e9 pour cette requ\u00eate."
        },
        clarifying_question = NA_character_
      ),
      class = "statcan_chat_result"
    ))
  }

  messages <- build_llm_prompt(query, candidates, lang)
  parsed <- call_llm_chat(
    config$endpoint, config$api_key, config$model, messages
  )
  reply <- parse_llm_reply(parsed)
  contract <- parse_chat_contract(reply)

  structure(
    list(
      query = query,
      candidates = candidates,
      explanation = contract$explanation,
      clarifying_question = contract$clarifying_question
    ),
    class = "statcan_chat_result"
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


resolve_llm_config <- function(endpoint, api_key, model) {
  endpoint <- first_nonempty(
    endpoint,
    getOption("statcanR.llm_endpoint"),
    Sys.getenv("STATCANR_LLM_ENDPOINT")
  )
  # The API key is a secret, so it is deliberately not read from options():
  # options can be dumped with options(), captured in a saved session, or land
  # in .Rhistory when set inline. It comes only from the api_key argument or the
  # STATCANR_LLM_API_KEY environment variable. Earlier versions did read the
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
    Sys.getenv("STATCANR_LLM_API_KEY")
  )
  model <- first_nonempty(
    model,
    getOption("statcanR.llm_model"),
    Sys.getenv("STATCANR_LLM_MODEL")
  )

  if (is.null(endpoint) || is.null(api_key) || is.null(model)) {
    stop(
      "statcan_chat() requires an LLM endpoint, API key, and model. Set the ",
      "endpoint and model via arguments, options(statcanR.llm_endpoint = , ",
      "statcanR.llm_model = ), or the STATCANR_LLM_ENDPOINT / ",
      "STATCANR_LLM_MODEL environment variables. Set the API key via the ",
      "api_key argument or Sys.setenv(STATCANR_LLM_API_KEY = ); for safety it ",
      "is not read from options().",
      call. = FALSE
    )
  }

  validate_llm_endpoint(endpoint)

  list(endpoint = endpoint, api_key = api_key, model = model)
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


call_llm_chat <- function(endpoint, api_key, model, messages) {
  response <- tryCatch(
    httr::POST(
      endpoint,
      httr::add_headers(Authorization = paste("Bearer", api_key)),
      body = list(model = model, messages = messages),
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


parse_llm_reply <- function(parsed) {
  content <- tryCatch(
    parsed$choices[[1L]]$message$content,
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

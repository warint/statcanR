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
#' * `api_key`: `options(statcanR.llm_api_key = ...)` or
#'   `Sys.setenv(STATCANR_LLM_API_KEY = ...)`
#' * `model`: `options(statcanR.llm_model = ...)` or
#'   `Sys.setenv(STATCANR_LLM_MODEL = ...)`
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
#'   `Sys.getenv("STATCANR_LLM_ENDPOINT")`.
#' @param api_key API key sent as an `Authorization: Bearer` header. Defaults
#'   to `getOption("statcanR.llm_api_key")`, then
#'   `Sys.getenv("STATCANR_LLM_API_KEY")`.
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
#'   statcanR.llm_api_key = "sk-...",
#'   statcanR.llm_model = "gpt-4o-mini"
#' )
#' statcan_chat("R&D expenditures in Quebec since 2020")
#' }
statcan_chat <- function(query, lang = c("eng", "fra"), n = 5L,
                         refresh = FALSE, endpoint = NULL, api_key = NULL,
                         model = NULL) {
  lang <- match.arg(lang)
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

  config <- resolve_llm_config(endpoint, api_key, model)
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
  api_key <- first_nonempty(
    api_key,
    getOption("statcanR.llm_api_key"),
    Sys.getenv("STATCANR_LLM_API_KEY")
  )
  model <- first_nonempty(
    model,
    getOption("statcanR.llm_model"),
    Sys.getenv("STATCANR_LLM_MODEL")
  )

  if (is.null(endpoint) || is.null(api_key) || is.null(model)) {
    stop(
      "statcan_chat() requires an LLM endpoint, API key, and model. Set ",
      "them via arguments, options(statcanR.llm_endpoint = , ",
      "statcanR.llm_api_key = , statcanR.llm_model = ), or ",
      "Sys.setenv(STATCANR_LLM_ENDPOINT = , STATCANR_LLM_API_KEY = , ",
      "STATCANR_LLM_MODEL = ).",
      call. = FALSE
    )
  }

  list(endpoint = endpoint, api_key = api_key, model = model)
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

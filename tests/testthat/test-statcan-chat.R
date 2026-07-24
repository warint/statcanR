sample_candidates <- function() {
  data.frame(
    rank = 1L,
    title = "Gross domestic expenditures on research and development",
    id = "27-10-0273-01",
    score = 90,
    match_reason = "3/3 topic terms matched",
    start_date = as.Date("1963-01-01"),
    end_date = as.Date("2025-01-01"),
    release_date = as.Date("2025-11-27"),
    geography = NA_character_,
    geography_match = NA,
    lang = "eng",
    stringsAsFactors = FALSE
  )
}


test_that("resolve_llm_config prefers arguments, then options, then env vars", {
  old_options <- options(
    statcanR.llm_endpoint = "https://option-endpoint",
    statcanR.llm_api_key = "option-key",
    statcanR.llm_model = "option-model"
  )
  old_env <- Sys.getenv(
    c("STATCANR_LLM_ENDPOINT", "STATCANR_LLM_API_KEY", "STATCANR_LLM_MODEL"),
    unset = NA
  )
  Sys.setenv(
    STATCANR_LLM_ENDPOINT = "https://env-endpoint",
    STATCANR_LLM_API_KEY = "env-key",
    STATCANR_LLM_MODEL = "env-model"
  )
  on.exit({
    options(old_options)
    for (name in names(old_env)) {
      if (is.na(old_env[[name]])) Sys.unsetenv(name) else {
        do.call(Sys.setenv, stats::setNames(list(old_env[[name]]), name))
      }
    }
  })

  config <- statcanR:::resolve_llm_config("https://arg-endpoint", NULL, NULL)
  expect_identical(config$endpoint, "https://arg-endpoint")
  expect_identical(config$api_key, "option-key")
  expect_identical(config$model, "option-model")

  options(
    statcanR.llm_endpoint = NULL,
    statcanR.llm_api_key = NULL,
    statcanR.llm_model = NULL
  )
  config <- statcanR:::resolve_llm_config(NULL, NULL, NULL)
  expect_identical(config$endpoint, "https://env-endpoint")
  expect_identical(config$api_key, "env-key")
  expect_identical(config$model, "env-model")
})


test_that("resolve_llm_config errors clearly when nothing is configured", {
  old_options <- options(
    statcanR.llm_endpoint = NULL,
    statcanR.llm_api_key = NULL,
    statcanR.llm_model = NULL
  )
  old_env <- Sys.getenv(
    c("STATCANR_LLM_ENDPOINT", "STATCANR_LLM_API_KEY", "STATCANR_LLM_MODEL"),
    unset = NA
  )
  Sys.setenv(
    STATCANR_LLM_ENDPOINT = "", STATCANR_LLM_API_KEY = "",
    STATCANR_LLM_MODEL = ""
  )
  on.exit({
    options(old_options)
    for (name in names(old_env)) {
      if (is.na(old_env[[name]])) Sys.unsetenv(name) else {
        do.call(Sys.setenv, stats::setNames(list(old_env[[name]]), name))
      }
    }
  })

  expect_error(
    statcanR:::resolve_llm_config(NULL, NULL, NULL),
    "requires an LLM endpoint"
  )
})


test_that("build_llm_prompt embeds the query and candidate table numbers", {
  messages <- statcanR:::build_llm_prompt(
    "R&D expenditures in Quebec since 2020", sample_candidates(), "eng"
  )
  expect_length(messages, 2L)
  expect_identical(messages[[1L]]$role, "system")
  expect_identical(messages[[2L]]$role, "user")
  expect_match(messages[[2L]]$content, "27-10-0273-01", fixed = TRUE)
  expect_match(
    messages[[2L]]$content, "R&D expenditures in Quebec since 2020",
    fixed = TRUE
  )
})


test_that("parse_llm_reply extracts the chat completion message", {
  parsed <- list(choices = list(list(message = list(content = "hello"))))
  expect_identical(statcanR:::parse_llm_reply(parsed), "hello")

  expect_error(
    statcanR:::parse_llm_reply(list(choices = list())),
    "did not include a chat completion message"
  )
})


test_that("parse_chat_contract splits a well-formed reply", {
  text <- paste(
    "EXPLANATION:",
    "Table 27-10-0273-01 covers Quebec since 2020.",
    "CLARIFYING_QUESTION:",
    "NONE",
    sep = "\n"
  )
  result <- statcanR:::parse_chat_contract(text)
  expect_match(result$explanation, "27-10-0273-01", fixed = TRUE)
  expect_true(is.na(result$clarifying_question))
})


test_that("parse_chat_contract keeps a real clarifying question", {
  text <- paste(
    "EXPLANATION:",
    "Two tables could work.",
    "CLARIFYING_QUESTION:",
    "Do you need monthly or annual data?",
    sep = "\n"
  )
  result <- statcanR:::parse_chat_contract(text)
  expect_identical(
    result$clarifying_question, "Do you need monthly or annual data?"
  )
})


test_that("parse_chat_contract falls back gracefully on a malformed reply", {
  result <- statcanR:::parse_chat_contract("just some free text")
  expect_identical(result$explanation, "just some free text")
  expect_true(is.na(result$clarifying_question))
})


test_that("statcan_chat skips the LLM call when statcan_find has no candidates", {
  local_mocked_bindings(
    statcan_find = function(...) statcanR:::empty_statcan_find_result(),
    call_llm_chat = function(...) stop("the LLM should not be called"),
    .package = "statcanR"
  )

  result <- statcan_chat(
    "an unmatched query", endpoint = "https://x", api_key = "k",
    model = "m"
  )
  expect_s3_class(result, "statcan_chat_result")
  expect_identical(nrow(result$candidates), 0L)
  expect_match(result$explanation, "No matching tables")
  expect_true(is.na(result$clarifying_question))
})


test_that("statcan_chat assembles a result from the mocked LLM reply", {
  local_mocked_bindings(
    statcan_find = function(...) sample_candidates(),
    call_llm_chat = function(...) {
      list(choices = list(list(message = list(content = paste(
        "EXPLANATION:",
        "Table 27-10-0273-01 is the best match.",
        "CLARIFYING_QUESTION:",
        "NONE",
        sep = "\n"
      )))))
    },
    .package = "statcanR"
  )

  result <- statcan_chat(
    "R&D expenditures in Quebec since 2020",
    endpoint = "https://x", api_key = "k", model = "m"
  )
  expect_s3_class(result, "statcan_chat_result")
  expect_identical(result$candidates, sample_candidates())
  expect_match(result$explanation, "27-10-0273-01", fixed = TRUE)
  expect_true(is.na(result$clarifying_question))
})

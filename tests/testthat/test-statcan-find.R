test_that("natural-language queries identify topic, geography, and date", {
  parsed <- statcanR:::parse_statcan_query(
    "R&D expenditures in Quebec since 2020",
    "eng"
  )

  expect_identical(
    parsed$topic_terms,
    c("research", "development", "expenditure")
  )
  expect_identical(parsed$geographies$eng, "Quebec")
  expect_identical(parsed$start_date, as.Date("2020-01-01"))
  expect_true(is.na(parsed$end_date))
  expect_identical(parsed$date_label, "since 2020")
})

test_that("French natural-language queries are normalized", {
  parsed <- statcanR:::parse_statcan_query(
    "Dépenses de R-D au Québec depuis 2020",
    "fra"
  )

  expect_identical(
    parsed$topic_terms,
    c("expenditure", "research", "development")
  )
  expect_identical(parsed$geographies$fra, "Québec")
  expect_identical(parsed$start_date, as.Date("2020-01-01"))
  expect_identical(parsed$date_label, "depuis 2020")
})

test_that("catalogue candidates are ranked by topic and date coverage", {
  parsed <- statcanR:::parse_statcan_query(
    "R&D expenditures since 2020",
    "eng"
  )
  result <- statcanR:::rank_statcan_catalogue(
    sample_catalogue(),
    parsed,
    "eng"
  )

  expect_identical(result$id[[1L]], "27-10-0273-01")
  expect_true(result$matched_count[[1L]] == 3L)
  expect_true(result$date_match[[1L]])
})

test_that("catalogue tokens are cached and invalidated when titles change", {
  catalogue <- sample_catalogue()

  first <- statcanR:::statcan_catalogue_tokens(catalogue, "eng")
  expect_identical(
    first,
    lapply(catalogue$title_eng, statcanR:::canonical_statcan_tokens)
  )

  cache_file <- file.path(
    tools::R_user_dir("statcanR", which = "cache"),
    "statcan_catalogue_tokens.rds"
  )
  expect_true(file.exists(cache_file))

  # A second call reuses the cache and returns the same tokens.
  expect_identical(
    statcanR:::statcan_catalogue_tokens(catalogue, "eng"),
    first
  )

  # Changing a title must invalidate the stale tokens for that row.
  changed <- catalogue
  changed$title_eng[[1L]] <- "Household spending on tomatoes"
  refreshed <- statcanR:::statcan_catalogue_tokens(changed, "eng")
  expect_identical(
    refreshed[[1L]],
    statcanR:::canonical_statcan_tokens(changed$title_eng[[1L]])
  )
  expect_false(identical(refreshed[[1L]], first[[1L]]))

  # A cache written by a different package version must be rebuilt, even when
  # the titles are unchanged (the tokenizer itself may have changed).
  rm(list = ls(statcanR:::statcan_token_cache), envir = statcanR:::statcan_token_cache)
  saveRDS(
    list(eng = list(
      version = "0.0.0",
      titles = catalogue$title_eng,
      tokens = rep(list("stale"), nrow(catalogue))
    )),
    cache_file,
    version = 3L
  )
  expect_identical(
    statcanR:::statcan_catalogue_tokens(catalogue, "eng"),
    lapply(catalogue$title_eng, statcanR:::canonical_statcan_tokens)
  )
})

test_that("cube metadata exposes geography members", {
  payload <- list(list(
    status = "SUCCESS",
    object = list(
      productId = "27100273",
      cubeTitleEn = "Gross domestic expenditures on research and development",
      cubeTitleFr = paste(
        "Dépenses intérieures brutes en recherche et développement"
      ),
      cubeStartDate = "1963-01-01",
      cubeEndDate = "2025-01-01",
      archiveStatusCode = "2",
      dimension = list(list(
        dimensionNameEn = "Geography",
        dimensionNameFr = "Géographie",
        member = list(
          list(memberNameEn = "Canada", memberNameFr = "Canada"),
          list(memberNameEn = "Quebec", memberNameFr = "Québec")
        )
      ))
    )
  ))

  result <- statcanR:::normalize_statcan_cube_metadata(payload)

  expect_named(result, "27100273")
  expect_identical(
    result[["27100273"]]$geographies_eng,
    c("Canada", "Quebec")
  )
  expect_false(result[["27100273"]]$archived)
  expect_true(statcanR:::is_valid_statcan_cube_metadata(
    result[["27100273"]]
  ))
})

test_that("statcan_find returns verified ranked candidates", {
  local_mocked_bindings(
    statcan_catalogue = function(refresh = FALSE) sample_catalogue(),
    statcan_metadata_for_tables = function(table_ids, refresh = FALSE) {
      list(
        `27100273` = list(
          id = "27100273",
          title_eng = "Gross domestic expenditures on research and development",
          title_fra = paste(
            "Dépenses intérieures brutes en recherche et développement"
          ),
          start_date = as.Date("1963-01-01"),
          end_date = as.Date("2025-01-01"),
          archived = FALSE,
          geographies_eng = c("Canada", "Quebec"),
          geographies_fra = c("Canada", "Québec")
        ),
        `27100015` = list(
          id = "27100015",
          title_eng = "Research and development personnel",
          title_fra = "Personnel affecté à la recherche et au développement",
          start_date = as.Date("2015-01-01"),
          end_date = as.Date("2025-01-01"),
          archived = FALSE,
          geographies_eng = "Canada",
          geographies_fra = "Canada"
        )
      )
    },
    .package = "statcanR"
  )

  result <- statcan_find(
    "R&D expenditures in Quebec since 2020",
    n = 5
  )

  expect_s3_class(result, "data.frame")
  expect_identical(result$id, "27-10-0273-01")
  expect_true(result$geography_match)
  expect_match(result$match_reason, "includes Quebec")
  expect_identical(result$rank, 1L)
})

test_that("statcan_find does not request metadata without a geography", {
  local_mocked_bindings(
    statcan_catalogue = function(refresh = FALSE) sample_catalogue(),
    statcan_metadata_for_tables = function(...) {
      stop("metadata should not be requested")
    },
    .package = "statcanR"
  )

  result <- statcan_find("international exports", n = 1)

  expect_identical(result$id, "36-10-0434-01")
  expect_true(is.na(result$geography_match))
})

test_that("statcan_find validates query and result count", {
  expect_error(statcan_find("Quebec since 2020"), "include a subject")
  expect_error(statcan_find("population", n = 0), "1 to 20")
  expect_error(statcan_find(character()), "one non-empty")
})

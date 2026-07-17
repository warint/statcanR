#' Search Statistics Canada data tables
#'
#' Search the catalogue of tables published through Statistics Canada's Web
#' Data Service (WDS). The catalogue is cached for 24 hours in the user's cache
#' directory. If WDS is temporarily unavailable, the most recent cache is used.
#'
#' @param keywords Character vector of words that must appear in the table
#'   title.
#' @param lang Language of the returned titles: `"eng"` or `"fra"`.
#' @param refresh Logical; if `TRUE`, ignore a fresh cache and request the
#'   catalogue from WDS.
#'
#' @return A `DT::datatable` containing matching table titles, identifiers,
#'   release dates, and language.
#' @export
#'
#' @examples
#' \dontrun{
#' statcan_search(c("economy", "export"), "eng")
#' }
statcan_search <- function(keywords, lang = c("eng", "fra"),
                           refresh = FALSE) {
  lang <- match.arg(lang)

  if (!is.character(keywords) || !length(keywords) ||
      anyNA(keywords) || any(!nzchar(keywords))) {
    stop("`keywords` must be a non-empty character vector.", call. = FALSE)
  }
  if (!is.logical(refresh) || length(refresh) != 1L || is.na(refresh)) {
    stop("`refresh` must be TRUE or FALSE.", call. = FALSE)
  }

  catalogue <- statcan_catalogue(refresh = refresh)
  title_column <- if (lang == "eng") "title_eng" else "title_fra"

  results <- filter_statcan_catalogue(catalogue, keywords, lang)

  DT::datatable(results, options = list(pageLength = 5))
}


# Retrieve and cache the WDS table catalogue.
statcan_catalogue <- function(refresh = FALSE) {
  cache_dir <- tools::R_user_dir("statcanR", which = "cache")
  cache_file <- file.path(cache_dir, "statcan_catalogue.qs2")
  cache_ttl <- 24 * 60 * 60

  cache_is_fresh <- file.exists(cache_file) &&
    as.numeric(difftime(Sys.time(), file.info(cache_file)$mtime,
                        units = "secs")) < cache_ttl

  if (!refresh && cache_is_fresh) {
    cached <- tryCatch(
      qs2::qs_read(cache_file, validate_checksum = TRUE),
      error = function(error) NULL
    )
    if (is_valid_statcan_catalogue(cached)) {
      return(cached)
    }
  }

  url <- paste0(
    "https://www150.statcan.gc.ca/",
    "t1/wds/rest/getAllCubesListLite"
  )

  downloaded <- tryCatch({
    response <- httr::GET(
      url,
      httr::timeout(60),
      httr::user_agent("statcanR (https://github.com/warint/statcanR)")
    )
    httr::stop_for_status(response)

    payload <- jsonlite::fromJSON(
      httr::content(response, as = "text", encoding = "UTF-8"),
      simplifyDataFrame = TRUE
    )
    normalize_statcan_catalogue(payload)
  }, error = function(error) {
    if (file.exists(cache_file)) {
      cached <- tryCatch(
        qs2::qs_read(cache_file, validate_checksum = TRUE),
        error = function(cache_error) NULL
      )
      if (is_valid_statcan_catalogue(cached)) {
        warning(
          "Statistics Canada WDS is unavailable; using the cached catalogue. ",
          conditionMessage(error),
          call. = FALSE
        )
        return(cached)
      }
    }

    stop(
      "Unable to retrieve the Statistics Canada table catalogue and no ",
      "cached catalogue is available. ", conditionMessage(error),
      call. = FALSE
    )
  })

  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  qs2::qs_save(downloaded, cache_file)
  downloaded
}


# Convert the WDS response to a stable, package-owned schema.
normalize_statcan_catalogue <- function(payload) {
  required <- c("productId", "cubeTitleEn", "cubeTitleFr", "releaseTime")
  missing <- setdiff(required, names(payload))
  if (length(missing)) {
    stop(
      "Unexpected response from Statistics Canada WDS; missing field(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  product_id <- sprintf("%08.0f", as.numeric(payload$productId))

  catalogue <- data.frame(
    title_eng = payload$cubeTitleEn,
    title_fra = payload$cubeTitleFr,
    id = paste0(
      substr(product_id, 1L, 2L), "-",
      substr(product_id, 3L, 4L), "-",
      substr(product_id, 5L, 8L), "-01"
    ),
    release_date = as.Date(substr(payload$releaseTime, 1L, 10L)),
    stringsAsFactors = FALSE
  )

  if (!is_valid_statcan_catalogue(catalogue)) {
    stop("Statistics Canada WDS returned an invalid catalogue.", call. = FALSE)
  }

  catalogue
}


# Filter a normalized catalogue without making a network request.
filter_statcan_catalogue <- function(catalogue, keywords, lang) {
  title_column <- if (lang == "eng") "title_eng" else "title_fra"
  searchable <- tolower(catalogue[[title_column]])
  keywords <- tolower(keywords)

  matches <- Reduce(`&`, lapply(keywords, function(keyword) {
    grepl(keyword, searchable, fixed = TRUE)
  }))
  number_of_matches <- sum(matches)

  data.frame(
    title = catalogue[[title_column]][matches],
    id = catalogue$id[matches],
    description = rep(NA_character_, number_of_matches),
    release_date = catalogue$release_date[matches],
    lang = rep(lang, number_of_matches),
    stringsAsFactors = FALSE
  )
}


# Reject corrupt caches and caches created with an incompatible schema.
is_valid_statcan_catalogue <- function(catalogue) {
  required <- c("title_eng", "title_fra", "id", "release_date")

  is.data.frame(catalogue) &&
    identical(names(catalogue), required) &&
    inherits(catalogue$release_date, "Date") &&
    all(grepl("^[0-9]{2}-[0-9]{2}-[0-9]{4}-01$", catalogue$id))
}

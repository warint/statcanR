#' Search Statistics Canada data tables
#'
#' Searches the catalogue of tables published through Statistics Canada's Web
#' Data Service (WDS). The catalogue is cached for 24 hours in the user's cache
#' directory. If WDS is temporarily unavailable, the most recent valid cache is
#' used.
#'
#' @param keywords Character vector of words that must appear in the table
#'   title. Matching is case-insensitive.
#' @param lang Language of the returned titles: `"eng"` or `"fra"`.
#' @param refresh Logical; if `TRUE`, ignore a fresh cache and request the
#'   catalogue from WDS.
#'
#' @return A `DT::datatable` containing matching table titles, Product IDs,
#'   release dates, and language.
#' @export
#'
#' @examples
#' \dontrun{
#' statcan_search(c("economy", "export"), "eng")
#' statcan_search("population", "fra")
#' }
statcan_search <- function(keywords, lang = c("eng", "fra"),
                           refresh = FALSE) {
  lang <- match.arg(lang)

  if (!is.character(keywords) || !length(keywords) || anyNA(keywords)) {
    stop("`keywords` must be a non-empty character vector.", call. = FALSE)
  }
  keywords <- trimws(keywords)
  if (any(!nzchar(keywords))) {
    stop("`keywords` must not contain empty strings.", call. = FALSE)
  }
  if (!is.logical(refresh) || length(refresh) != 1L || is.na(refresh)) {
    stop("`refresh` must be TRUE or FALSE.", call. = FALSE)
  }

  results <- filter_statcan_catalogue(
    statcan_catalogue(refresh = refresh),
    keywords,
    lang
  )

  DT::datatable(
    results,
    rownames = FALSE,
    options = list(pageLength = 10L, searchHighlight = TRUE)
  )
}


# Retrieve and cache the WDS table catalogue.
statcan_catalogue <- function(refresh = FALSE) {
  cache_dir <- tools::R_user_dir("statcanR", which = "cache")
  cache_file <- file.path(cache_dir, "statcan_catalogue.rds")
  cache_ttl <- 24 * 60 * 60

  cache_is_fresh <- file.exists(cache_file) &&
    as.numeric(difftime(Sys.time(), file.info(cache_file)$mtime,
                        units = "secs")) < cache_ttl

  if (!refresh && cache_is_fresh) {
    cached <- read_cached_catalogue(cache_file)
    if (is_valid_statcan_catalogue(cached)) {
      return(cached)
    }
  }

  endpoint <- paste0(
    "https://www150.statcan.gc.ca/",
    "t1/wds/rest/getAllCubesListLite"
  )
  downloaded <- tryCatch({
    response <- httr::GET(
      endpoint,
      httr::timeout(60),
      httr::user_agent(statcan_user_agent())
    )
    httr::stop_for_status(response)

    payload <- jsonlite::fromJSON(
      httr::content(response, as = "text", encoding = "UTF-8"),
      simplifyDataFrame = TRUE
    )
    normalize_statcan_catalogue(payload)
  }, error = function(error) {
    if (file.exists(cache_file)) {
      cached <- read_cached_catalogue(cache_file)
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
      "valid cache is available. ", conditionMessage(error),
      call. = FALSE
    )
  })

  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  tryCatch(
    saveRDS(downloaded, cache_file, version = 3L),
    error = function(error) {
      warning("Unable to cache the Statistics Canada catalogue: ",
              conditionMessage(error), call. = FALSE)
    }
  )
  downloaded
}


read_cached_catalogue <- function(cache_file) {
  catalogue <- tryCatch(readRDS(cache_file), error = function(error) NULL)
  if (is.data.frame(catalogue)) {
    title_columns <- intersect(c("title_eng", "title_fra"), names(catalogue))
    for (title_column in title_columns) {
      if (is.character(catalogue[[title_column]])) {
        catalogue[[title_column]] <- decode_statcan_entities(
          catalogue[[title_column]]
        )
      }
    }
  }
  catalogue
}


# Decode the XML entities used in some WDS catalogue titles. Ampersands are
# decoded last so text that was deliberately escaped twice is only decoded by
# one layer.
decode_statcan_entities <- function(text) {
  replacements <- c(
    "&quot;" = "\"",
    "&#34;" = "\"",
    "&apos;" = "'",
    "&#39;" = "'",
    "&#039;" = "'",
    "&lt;" = "<",
    "&gt;" = ">",
    "&nbsp;" = "\u00a0",
    "&amp;" = "&"
  )
  result <- as.character(text)
  for (entity in names(replacements)) {
    result <- gsub(entity, replacements[[entity]], result, fixed = TRUE)
  }
  result
}


# Convert the WDS response to a stable, package-owned schema.
normalize_statcan_catalogue <- function(payload) {
  if (is.list(payload) && !is.data.frame(payload) &&
      identical(payload$status, "SUCCESS") && !is.null(payload$object)) {
    payload <- payload$object
  }
  if (!is.data.frame(payload)) {
    stop("Statistics Canada WDS returned an unexpected catalogue format.",
         call. = FALSE)
  }

  required <- c("productId", "cubeTitleEn", "cubeTitleFr", "releaseTime")
  missing <- setdiff(required, names(payload))
  if (length(missing)) {
    stop(
      "Unexpected response from Statistics Canada WDS; missing field(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  product_id <- format_product_id_vector(payload$productId)
  release_date <- suppressWarnings(
    as.Date(substr(as.character(payload$releaseTime), 1L, 10L))
  )
  start_date <- catalogue_date_field(payload, "cubeStartDate")
  end_date <- catalogue_date_field(payload, "cubeEndDate")
  archived <- if ("archived" %in% names(payload)) {
    normalize_archive_status(payload$archived)
  } else {
    rep(NA, nrow(payload))
  }
  frequency_code <- if ("frequencyCode" %in% names(payload)) {
    suppressWarnings(as.integer(payload$frequencyCode))
  } else {
    rep(NA_integer_, nrow(payload))
  }
  catalogue <- data.frame(
    title_eng = decode_statcan_entities(payload$cubeTitleEn),
    title_fra = decode_statcan_entities(payload$cubeTitleFr),
    id = product_id,
    start_date = start_date,
    end_date = end_date,
    release_date = release_date,
    archived = archived,
    frequency_code = frequency_code,
    stringsAsFactors = FALSE
  )

  if (!is_valid_statcan_catalogue(catalogue)) {
    stop("Statistics Canada WDS returned an invalid catalogue.", call. = FALSE)
  }

  catalogue
}


catalogue_date_field <- function(payload, field) {
  if (!field %in% names(payload)) {
    return(rep(as.Date(NA), nrow(payload)))
  }

  value <- as.character(payload[[field]])
  value[!nzchar(value)] <- NA_character_
  suppressWarnings(as.Date(substr(value, 1L, 10L)))
}


# WDS currently uses code 2 for a current table and code 1 for an archive.
# Logical values are also accepted because the field is documented as Boolean.
normalize_archive_status <- function(value) {
  if (is.logical(value)) {
    return(value)
  }

  normalized <- tolower(trimws(as.character(value)))
  result <- rep(NA, length(normalized))
  result[normalized %in% c("1", "true", "archived")] <- TRUE
  result[normalized %in% c("0", "2", "false", "current")] <- FALSE
  result
}


format_product_id_vector <- function(product_id) {
  product_id <- if (is.numeric(product_id)) {
    sprintf("%08.0f", product_id)
  } else {
    gsub("[^0-9]", "", as.character(product_id))
  }
  product_id <- ifelse(
    nchar(product_id) == 10L,
    substr(product_id, 1L, 8L),
    product_id
  )

  valid <- grepl("^[0-9]{8}$", product_id)
  formatted <- rep(NA_character_, length(product_id))
  formatted[valid] <- paste0(
    substr(product_id[valid], 1L, 2L), "-",
    substr(product_id[valid], 3L, 4L), "-",
    substr(product_id[valid], 5L, 8L), "-01"
  )
  formatted
}


# Filter a normalized catalogue without making a network request.
filter_statcan_catalogue <- function(catalogue, keywords, lang) {
  title_column <- if (lang == "eng") "title_eng" else "title_fra"
  searchable <- tolower(catalogue[[title_column]])
  keywords <- unique(tolower(keywords))

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
  required <- c(
    "title_eng", "title_fra", "id", "start_date", "end_date",
    "release_date", "archived", "frequency_code"
  )

  is.data.frame(catalogue) &&
    identical(names(catalogue), required) &&
    is.character(catalogue$title_eng) &&
    is.character(catalogue$title_fra) &&
    is.character(catalogue$id) &&
    inherits(catalogue$start_date, "Date") &&
    inherits(catalogue$end_date, "Date") &&
    inherits(catalogue$release_date, "Date") &&
    is.logical(catalogue$archived) &&
    is.integer(catalogue$frequency_code) &&
    !anyNA(catalogue$id) &&
    all(grepl("^[0-9]{2}-[0-9]{2}-[0-9]{4}-01$", catalogue$id))
}

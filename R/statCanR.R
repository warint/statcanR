#' Download a Statistics Canada data table
#'
#' Downloads a complete table from Statistics Canada's Web Data Service (WDS)
#' and returns it as a data frame. Product IDs can be supplied in the familiar
#' hyphenated form (for example, `"27-10-0014-01"`) or as an eight-digit PID
#' (for example, `"27100014"`).
#'
#' The function keeps the interface used by earlier statcanR releases. English
#' and French downloads share the same processing rules. In particular, the
#' first column is named `REF_DATE`, coordinates are stored as character, and
#' the table title from the metadata file is added as `INDICATOR`.
#'
#' @param tableNumber A Statistics Canada table number or Product ID. Both
#'   `"27-10-0014-01"` and `"27100014"` are accepted.
#' @param lang Language of the downloaded table: `"eng"` or `"fra"`.
#'
#' @return A data frame containing the complete Statistics Canada table.
#' @export
#'
#' @examples
#' \dontrun{
#' science <- statcan_data("27-10-0014-01", "eng")
#' science_fr <- statcan_data("27100014", "fra")
#' }
statcan_data <- function(tableNumber, lang) {
  product_id <- normalize_product_id(tableNumber)
  lang <- normalize_language(lang)

  work_dir <- tempfile("statcanR-")
  if (!dir.create(work_dir, recursive = TRUE)) {
    stop("Unable to create a temporary directory for the download.",
         call. = FALSE)
  }
  on.exit(unlink(work_dir, recursive = TRUE, force = TRUE), add = TRUE)

  download_url <- statcan_download_url(product_id, lang)
  zip_file <- file.path(work_dir, paste0(product_id, ".zip"))

  message("statcanR: downloading table ", format_product_id(product_id), ".")
  response <- tryCatch(
    httr::GET(
      download_url,
      httr::timeout(300),
      httr::user_agent(statcan_user_agent()),
      httr::write_disk(zip_file, overwrite = TRUE)
    ),
    error = function(error) {
      stop(
        "Unable to download Statistics Canada table ",
        format_product_id(product_id), ". ", conditionMessage(error),
        call. = FALSE
      )
    }
  )
  stop_for_statcan_status(response, product_id)

  read_statcan_zip(zip_file, product_id, lang, work_dir)
}


#' Download a Statistics Canada table and save a CSV file
#'
#' Calls [statcan_data()] and also writes the returned table to a CSV file.
#' Existing calls with only `tableNumber` and `lang` remain supported; `path`
#' can be used to select a different output directory.
#'
#' @inheritParams statcan_data
#' @param path Directory in which to save the CSV file. The directory must
#'   already exist. Defaults to the current working directory.
#'
#' @return The downloaded table. The CSV path is available in the
#'   `statcan_file` attribute of the returned data frame.
#' @export
#'
#' @examples
#' \dontrun{
#' science <- statcan_download_data("27-10-0014-01", "eng")
#' science <- statcan_download_data(
#'   "27-10-0014-01", "eng", path = tempdir()
#' )
#' attr(science, "statcan_file")
#' }
statcan_download_data <- function(tableNumber, lang, path = ".") {
  product_id <- normalize_product_id(tableNumber)
  lang <- normalize_language(lang)
  path <- normalize_output_path(path)

  can_data <- statcan_data(product_id, lang)
  output_file <- file.path(
    path,
    paste0("statcan_", product_id, "_", lang, ".csv")
  )

  utils::write.csv(
    can_data,
    file = output_file,
    row.names = FALSE,
    na = "",
    fileEncoding = "UTF-8"
  )
  attr(can_data, "statcan_file") <- normalizePath(
    output_file,
    winslash = "/",
    mustWork = FALSE
  )
  message("statcanR: saved ", output_file, ".")

  can_data
}


# Convert supported table-number formats to the eight-digit WDS PID.
normalize_product_id <- function(table_number) {
  if (!is.character(table_number) || length(table_number) != 1L ||
      is.na(table_number) || !nzchar(trimws(table_number))) {
    stop("`tableNumber` must be one non-empty character string.",
         call. = FALSE)
  }

  product_id <- gsub("[^0-9]", "", trimws(table_number))
  if (nchar(product_id) == 10L) {
    product_id <- substr(product_id, 1L, 8L)
  }
  if (!grepl("^[0-9]{8}$", product_id)) {
    stop(
      "`tableNumber` must contain an eight-digit Product ID, optionally ",
      "followed by a two-digit view (for example, '27-10-0014-01').",
      call. = FALSE
    )
  }

  product_id
}


# Preserve the public eng/fra values while accepting the WDS aliases too.
normalize_language <- function(lang) {
  if (!is.character(lang) || length(lang) != 1L || is.na(lang)) {
    stop("`lang` must be one of 'eng' or 'fra'.", call. = FALSE)
  }

  aliases <- c(eng = "eng", en = "eng", fra = "fra", fr = "fra")
  normalized <- unname(aliases[tolower(trimws(lang))])
  if (length(normalized) != 1L || is.na(normalized)) {
    stop("`lang` must be one of 'eng' or 'fra'.", call. = FALSE)
  }

  normalized
}


normalize_output_path <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) ||
      !nzchar(path)) {
    stop("`path` must be one existing directory.", call. = FALSE)
  }
  if (!dir.exists(path)) {
    stop("Output directory does not exist: ", path, call. = FALSE)
  }

  path
}


format_product_id <- function(product_id) {
  paste0(
    substr(product_id, 1L, 2L), "-",
    substr(product_id, 3L, 4L), "-",
    substr(product_id, 5L, 8L), "-01"
  )
}


statcan_user_agent <- function() {
  version <- tryCatch(
    as.character(utils::packageVersion("statcanR")),
    error = function(error) "development"
  )
  paste0(
    "statcanR/", version,
    " (https://github.com/warint/statcanR)"
  )
}


# Ask WDS for the current full-table download URL.
statcan_download_url <- function(product_id, lang) {
  wds_language <- if (lang == "eng") "en" else "fr"
  endpoint <- paste0(
    "https://www150.statcan.gc.ca/t1/wds/rest/",
    "getFullTableDownloadCSV/", product_id, "/", wds_language
  )

  response <- tryCatch(
    httr::GET(
      endpoint,
      httr::timeout(60),
      httr::user_agent(statcan_user_agent())
    ),
    error = function(error) {
      stop(
        "Unable to contact Statistics Canada's Web Data Service for table ",
        format_product_id(product_id), ". ", conditionMessage(error),
        call. = FALSE
      )
    }
  )
  stop_for_statcan_status(response, product_id)

  payload <- tryCatch(
    jsonlite::fromJSON(
      httr::content(response, as = "text", encoding = "UTF-8"),
      simplifyVector = TRUE
    ),
    error = function(error) {
      stop(
        "Statistics Canada's Web Data Service returned invalid JSON. ",
        conditionMessage(error),
        call. = FALSE
      )
    }
  )

  if (!is.list(payload) || !identical(payload$status, "SUCCESS") ||
      !is.character(payload$object) || length(payload$object) != 1L ||
      !grepl("^https://", payload$object)) {
    details <- if (is.list(payload) && !is.null(payload$object)) {
      paste(as.character(payload$object), collapse = " ")
    } else {
      "unexpected response"
    }
    stop(
      "Statistics Canada did not provide a download for table ",
      format_product_id(product_id), ": ", details, ".",
      call. = FALSE
    )
  }

  payload$object
}


stop_for_statcan_status <- function(response, product_id) {
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
    "Statistics Canada returned HTTP ", status, " for table ",
    format_product_id(product_id), ".", suffix,
    call. = FALSE
  )
}


read_statcan_zip <- function(zip_file, product_id, lang, work_dir) {
  archive <- tryCatch(
    utils::unzip(zip_file, list = TRUE),
    error = function(error) {
      stop("The Statistics Canada download is not a valid ZIP archive. ",
           conditionMessage(error), call. = FALSE)
    }
  )
  archive_names <- archive$Name
  data_name <- archive_names[
    basename(archive_names) == paste0(product_id, ".csv")
  ]
  metadata_name <- archive_names[
    basename(archive_names) == paste0(product_id, "_MetaData.csv")
  ]

  if (length(data_name) != 1L || length(metadata_name) != 1L) {
    stop(
      "The Statistics Canada ZIP archive does not contain the expected data ",
      "and metadata files.",
      call. = FALSE
    )
  }

  extracted <- tryCatch(
    utils::unzip(
      zip_file,
      files = c(data_name, metadata_name),
      exdir = work_dir
    ),
    error = function(error) {
      stop("Unable to extract the Statistics Canada ZIP archive. ",
           conditionMessage(error), call. = FALSE)
    }
  )
  data_file <- extracted[basename(extracted) == paste0(product_id, ".csv")]
  metadata_file <- extracted[
    basename(extracted) == paste0(product_id, "_MetaData.csv")
  ]

  can_data <- data.table::fread(
    data_file,
    encoding = "UTF-8",
    showProgress = FALSE
  )
  metadata <- data.table::fread(
    metadata_file,
    nrows = 1L,
    encoding = "UTF-8",
    showProgress = FALSE
  )
  if (!ncol(can_data) || !nrow(metadata) || !ncol(metadata)) {
    stop("Statistics Canada returned an empty data or metadata file.",
         call. = FALSE)
  }

  raw_reference_date <- can_data[[1L]]
  data.table::setnames(can_data, 1L, "REF_DATE")
  can_data[["REF_DATE"]] <- parse_reference_dates(can_data[["REF_DATE"]])
  coordinate_columns <- intersect(
    c("COORDINATE", "COORDONN\u00c9ES", "COORDONNEES"),
    names(can_data)
  )
  for (coordinate_column in coordinate_columns) {
    can_data[[coordinate_column]] <- as.character(can_data[[coordinate_column]])
  }
  can_data[["INDICATOR"]] <- as.character(metadata[[1L]][1L])

  if (is_fiscal_reference(raw_reference_date)) {
    can_data[["REF_PERIOD"]] <- if (lang == "eng") {
      "Fiscal year"
    } else {
      "Exercice financier"
    }
    data.table::setcolorder(
      can_data,
      c("REF_DATE", "REF_PERIOD", setdiff(names(can_data),
                                            c("REF_DATE", "REF_PERIOD")))
    )
  }

  data.table::setDF(can_data)
  can_data
}


parse_reference_dates <- function(reference_date) {
  reference_date <- as.character(reference_date)
  result <- rep(as.Date(NA), length(reference_date))

  fiscal <- grepl("^[0-9]{4}/[0-9]{4}$", reference_date)
  year_month <- grepl("^[0-9]{4}-[0-9]{2}$", reference_date)
  year <- grepl("^[0-9]{4}$", reference_date)
  iso_date <- grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", reference_date)

  if (any(fiscal)) {
    result[fiscal] <- as.Date(paste0(
      sub(".*/", "", reference_date[fiscal]),
      "-03-31"
    ))
  }
  if (any(year_month)) {
    result[year_month] <- as.Date(paste0(
      reference_date[year_month],
      "-01"
    ))
  }
  if (any(year)) {
    result[year] <- as.Date(paste0(reference_date[year], "-01-01"))
  }
  if (any(iso_date)) {
    result[iso_date] <- as.Date(reference_date[iso_date])
  }

  unsupported <- !is.na(reference_date) &
    !(fiscal | year_month | year | iso_date)
  if (any(unsupported)) {
    warning(
      "Some REF_DATE values use an unsupported format and were converted to NA.",
      call. = FALSE
    )
  }

  result
}


is_fiscal_reference <- function(reference_date) {
  reference_date <- as.character(reference_date)
  any(grepl("^[0-9]{4}/[0-9]{4}$", reference_date), na.rm = TRUE)
}

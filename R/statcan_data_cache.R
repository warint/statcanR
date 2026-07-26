# On-disk cache for full Statistics Canada tables downloaded by statcan_data().
#
# The discovery functions (statcan_search(), statcan_find()) already cache the
# small catalogue and metadata files. A full data table is the remaining, and by
# far the largest, download, so caching it saves the most time on repeated
# calls. Individual tables can be hundreds of megabytes, so the cache is
# actively size-managed to respect CRAN's policy that tools::R_user_dir() caches
# be kept "as small as possible" with "outdated material" removed: a total-size
# ceiling with least-recently-used eviction, on top of release-date and
# time-to-live freshness checks.

# Ceiling for the on-disk table cache, in bytes (500 MB by default). Users can
# raise or lower it with options(statcanR.cache_max_bytes = ...); a value of 0
# disables the table cache entirely, both reading and writing.
statcan_data_cache_limit <- function() {
  limit <- getOption("statcanR.cache_max_bytes", 500 * 1024^2)
  if (!is.numeric(limit) || length(limit) != 1L || is.na(limit) || limit < 0) {
    return(500 * 1024^2)
  }
  as.numeric(limit)
}


statcan_data_cache_enabled <- function() {
  statcan_data_cache_limit() > 0
}


# When a table's release date cannot be determined without a network request,
# fall back to treating a cached copy as fresh for this many seconds.
statcan_data_cache_ttl <- function() {
  24 * 60 * 60
}


statcan_data_cache_dir <- function() {
  file.path(tools::R_user_dir("statcanR", which = "cache"), "tables")
}


statcan_data_cache_file <- function(cache_dir, product_id, lang) {
  file.path(cache_dir, paste0("table_", product_id, "_", lang, ".rds"))
}


# Read the catalogue only if it is already cached locally, so the download path
# never triggers a catalogue network request of its own. Returns NULL when no
# valid cached catalogue is available.
cached_catalogue_if_present <- function() {
  cache_file <- file.path(
    tools::R_user_dir("statcanR", which = "cache"),
    "statcan_catalogue.rds"
  )
  if (!file.exists(cache_file)) {
    return(NULL)
  }
  catalogue <- read_cached_catalogue(cache_file)
  if (is_valid_statcan_catalogue(catalogue)) catalogue else NULL
}


# The release date Statistics Canada last published for a table, or NA when it
# cannot be determined without a network request. Keying the cache on this means
# a cached copy is served only until StatCan republishes the table, so callers
# get the same data they would have downloaded, just faster.
statcan_table_release_date <- function(product_id) {
  catalogue <- cached_catalogue_if_present()
  if (is.null(catalogue)) {
    return(as.Date(NA))
  }
  row <- match(format_product_id(product_id), catalogue$id)
  if (is.na(row)) {
    return(as.Date(NA))
  }
  catalogue$release_date[[row]]
}


# Reject corrupt cache entries and entries written by an incompatible schema.
is_valid_cached_table <- function(entry) {
  is.list(entry) &&
    is.data.frame(entry$data) &&
    inherits(entry$release_date, "Date") &&
    length(entry$release_date) == 1L &&
    is.numeric(entry$cached_at) &&
    length(entry$cached_at) == 1L &&
    !is.na(entry$cached_at)
}


# Return a fresh cached table, or NULL to fall through to a download. A copy is
# fresh when its stored release date matches the current one; when either date
# is unknown (the catalogue is not cached locally), a time-to-live backstop is
# used instead.
read_statcan_data_cache <- function(product_id, lang, release_date) {
  if (!statcan_data_cache_enabled()) {
    return(NULL)
  }
  cache_file <- statcan_data_cache_file(
    statcan_data_cache_dir(), product_id, lang
  )
  if (!file.exists(cache_file)) {
    return(NULL)
  }
  entry <- tryCatch(readRDS(cache_file), error = function(error) NULL)
  if (!is_valid_cached_table(entry)) {
    return(NULL)
  }

  fresh <- if (!is.na(release_date) && !is.na(entry$release_date)) {
    entry$release_date == release_date
  } else {
    (as.numeric(Sys.time()) - entry$cached_at) < statcan_data_cache_ttl()
  }
  if (!isTRUE(fresh)) {
    return(NULL)
  }

  # Stamp the access time so least-recently-used eviction can identify cold
  # entries. A failure to touch the file only makes eviction slightly less
  # precise, so it is ignored.
  tryCatch(Sys.setFileTime(cache_file, Sys.time()), error = function(error) NULL)
  entry$data
}


# Store a downloaded table, then evict least-recently-used entries so the cache
# stays under its size ceiling. Every step is best-effort: a caching failure
# must never prevent statcan_data() from returning the data it just downloaded.
write_statcan_data_cache <- function(product_id, lang, release_date, data) {
  max_bytes <- statcan_data_cache_limit()
  if (max_bytes <= 0) {
    return(invisible())
  }
  cache_dir <- statcan_data_cache_dir()
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }
  cache_file <- statcan_data_cache_file(cache_dir, product_id, lang)
  entry <- list(
    data = data,
    release_date = as.Date(release_date),
    cached_at = as.numeric(Sys.time())
  )
  written <- tryCatch({
    saveRDS(entry, cache_file, version = 3L)
    TRUE
  }, error = function(error) FALSE)
  if (!written) {
    return(invisible())
  }

  # A single table larger than the whole budget is not worth keeping: it would
  # evict every other entry and still leave the cache over its ceiling.
  size <- file.info(cache_file)$size
  if (is.na(size) || size > max_bytes) {
    unlink(cache_file, force = TRUE)
    return(invisible())
  }

  prune_statcan_data_cache(cache_dir, max_bytes)
  invisible()
}


# Delete least-recently-used entries until the cache fits under max_bytes.
prune_statcan_data_cache <- function(cache_dir,
                                     max_bytes = statcan_data_cache_limit()) {
  files <- list.files(
    cache_dir,
    pattern = "^table_[0-9]{8}_(eng|fra)\\.rds$",
    full.names = TRUE
  )
  if (!length(files)) {
    return(invisible())
  }
  info <- file.info(files)
  info <- info[!is.na(info$size), , drop = FALSE]
  if (!nrow(info) || sum(info$size) <= max_bytes) {
    return(invisible())
  }

  # Oldest access (or write) time first; stop as soon as the cache fits again.
  order_index <- order(info$mtime)
  ordered_files <- rownames(info)[order_index]
  ordered_sizes <- info$size[order_index]
  total <- sum(ordered_sizes)
  for (index in seq_along(ordered_files)) {
    if (total <= max_bytes) {
      break
    }
    unlink(ordered_files[[index]], force = TRUE)
    total <- total - ordered_sizes[[index]]
  }
  invisible()
}

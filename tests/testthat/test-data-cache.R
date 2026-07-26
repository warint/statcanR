# The cache directory is redirected to a temporary location in setup.R, so these
# tests never touch the real user cache.

sample_table <- function(value = 1) {
  data.frame(
    REF_DATE = as.Date("2026-01-01"),
    GEO = "Canada",
    VALUE = value,
    INDICATOR = "Test table",
    stringsAsFactors = FALSE
  )
}

# Write a valid catalogue into the cache so statcan_table_release_date() can find
# a release date without a network request.
seed_cached_catalogue <- function() {
  cache_dir <- tools::R_user_dir("statcanR", which = "cache")
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  saveRDS(
    sample_catalogue(),
    file.path(cache_dir, "statcan_catalogue.rds"),
    version = 3L
  )
}

clear_table_cache <- function() {
  unlink(statcanR:::statcan_data_cache_dir(), recursive = TRUE, force = TRUE)
}


test_that("release date is read from the cached catalogue only", {
  clear_table_cache()
  unlink(
    file.path(
      tools::R_user_dir("statcanR", which = "cache"),
      "statcan_catalogue.rds"
    ),
    force = TRUE
  )

  # No catalogue cached yet: the download path must not reach out to the network.
  expect_true(is.na(statcanR:::statcan_table_release_date("10100004")))

  seed_cached_catalogue()
  expect_identical(
    statcanR:::statcan_table_release_date("10100004"),
    as.Date("2026-07-16")
  )
  # A table absent from the catalogue has no known release date.
  expect_true(is.na(statcanR:::statcan_table_release_date("99999999")))
})


test_that("a cached table is reused while the release date is unchanged", {
  clear_table_cache()
  release <- as.Date("2026-07-16")

  statcanR:::write_statcan_data_cache("10100004", "eng", release, sample_table(7))

  hit <- statcanR:::read_statcan_data_cache("10100004", "eng", release)
  expect_s3_class(hit, "data.frame")
  expect_identical(hit$VALUE, 7)

  # A newer release date invalidates the cached copy.
  expect_null(
    statcanR:::read_statcan_data_cache("10100004", "eng", as.Date("2026-08-01"))
  )
})


test_that("an unknown release date falls back to the time-to-live", {
  clear_table_cache()
  statcanR:::write_statcan_data_cache(
    "10100004", "eng", as.Date(NA), sample_table(3)
  )

  # Fresh within the TTL when neither release date is known.
  hit <- statcanR:::read_statcan_data_cache("10100004", "eng", as.Date(NA))
  expect_identical(hit$VALUE, 3)

  # Backdate the stored timestamp beyond the TTL: the copy is now stale.
  cache_file <- statcanR:::statcan_data_cache_file(
    statcanR:::statcan_data_cache_dir(), "10100004", "eng"
  )
  entry <- readRDS(cache_file)
  entry$cached_at <- entry$cached_at - statcanR:::statcan_data_cache_ttl() - 10
  saveRDS(entry, cache_file, version = 3L)

  expect_null(
    statcanR:::read_statcan_data_cache("10100004", "eng", as.Date(NA))
  )
})


test_that("entries written by a different package version are ignored", {
  clear_table_cache()
  cache_dir <- statcanR:::statcan_data_cache_dir()
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  cache_file <- statcanR:::statcan_data_cache_file(cache_dir, "10100004", "eng")

  # A structurally valid entry stamped with a stale version must be rejected, so
  # an upgrade that changes table processing never serves old-schema data.
  saveRDS(
    list(
      version = "0.0.0",
      data = sample_table(),
      release_date = as.Date("2026-07-16"),
      cached_at = as.numeric(Sys.time())
    ),
    cache_file,
    version = 3L
  )
  expect_null(
    statcanR:::read_statcan_data_cache("10100004", "eng", as.Date("2026-07-16"))
  )
})


test_that("statcan_data() serves the second call from cache", {
  clear_table_cache()
  seed_cached_catalogue()

  downloads <- 0L
  # Stand in for the whole network + unzip path. read_statcan_zip() is the last
  # step of statcan_data() before the result is cached, so mocking it exercises
  # the real cache read/write wiring while counting downloads.
  local_mocked_bindings(
    statcan_download_url = function(product_id, lang) {
      "https://example.invalid/table.zip"
    },
    read_statcan_zip = function(zip_file, product_id, lang, work_dir) {
      downloads <<- downloads + 1L
      sample_table(99)
    },
    .package = "statcanR"
  )
  # Also short-circuit the actual HTTP GET and status check.
  local_mocked_bindings(
    GET = function(...) structure(list(), class = "response"),
    http_error = function(...) FALSE,
    .package = "httr"
  )

  first <- suppressMessages(statcan_data("10-10-0004-01", "eng"))
  expect_identical(first$VALUE, 99)
  expect_identical(downloads, 1L)

  # Second call: same release date in the seeded catalogue, so it is served from
  # cache and never reaches the download path.
  expect_message(
    second <- statcan_data("10-10-0004-01", "eng"),
    "cached copy"
  )
  expect_identical(second$VALUE, 99)
  expect_identical(downloads, 1L)

  # refresh = TRUE bypasses the cache and downloads again.
  suppressMessages(statcan_data("10-10-0004-01", "eng", refresh = TRUE))
  expect_identical(downloads, 2L)
})


test_that("corrupt or foreign cache entries are ignored", {
  clear_table_cache()
  cache_dir <- statcanR:::statcan_data_cache_dir()
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  cache_file <- statcanR:::statcan_data_cache_file(cache_dir, "10100004", "eng")

  # Not a valid entry list.
  saveRDS(list(data = "not a data frame"), cache_file, version = 3L)
  expect_null(
    statcanR:::read_statcan_data_cache("10100004", "eng", as.Date("2026-07-16"))
  )

  # Unreadable file.
  writeLines("garbage", cache_file)
  expect_null(
    statcanR:::read_statcan_data_cache("10100004", "eng", as.Date("2026-07-16"))
  )
})


test_that("the cache evicts least-recently-used tables under its size cap", {
  clear_table_cache()
  cache_dir <- statcanR:::statcan_data_cache_dir()
  ids <- c("10100004", "18100004", "36100434")
  files <- vapply(
    ids,
    function(id) statcanR:::statcan_data_cache_file(cache_dir, id, "eng"),
    character(1)
  )

  # Write all three with a cap high enough that nothing is evicted yet, so the
  # test can control the access order and the eviction cap explicitly.
  withr::with_options(
    list(statcanR.cache_max_bytes = 1e9),
    for (id in ids) {
      statcanR:::write_statcan_data_cache(
        id, "eng", as.Date("2026-01-01"), sample_table(1)
      )
    }
  )

  # Make 10100004 the least-recently-used and 36100434 the most-recently-used.
  Sys.setFileTime(files[[1L]], as.POSIXct("2020-01-01", tz = "UTC"))
  Sys.setFileTime(files[[2L]], as.POSIXct("2020-01-02", tz = "UTC"))
  Sys.setFileTime(files[[3L]], as.POSIXct("2020-01-03", tz = "UTC"))

  sizes <- file.info(files)$size
  # A cap that fits only the two most recent entries forces one eviction.
  cap <- sizes[[2L]] + sizes[[3L]]
  statcanR:::prune_statcan_data_cache(cache_dir, cap)

  remaining <- list.files(cache_dir, pattern = "^table_.*\\.rds$",
                          full.names = TRUE)
  expect_lte(sum(file.info(remaining)$size), cap)
  # The least-recently-used table was evicted; the most recent survives.
  expect_false(file.exists(files[[1L]]))
  expect_true(file.exists(files[[3L]]))
})


test_that("a table larger than the whole budget is not cached", {
  clear_table_cache()
  # Any real entry is larger than a one-byte ceiling.
  withr::local_options(statcanR.cache_max_bytes = 1)

  statcanR:::write_statcan_data_cache(
    "10100004", "eng", as.Date("2026-01-01"), sample_table()
  )
  expect_false(file.exists(
    statcanR:::statcan_data_cache_file(
      statcanR:::statcan_data_cache_dir(), "10100004", "eng"
    )
  ))
})


test_that("setting the cap to zero disables the cache", {
  clear_table_cache()
  withr::local_options(statcanR.cache_max_bytes = 0)

  expect_false(statcanR:::statcan_data_cache_enabled())
  statcanR:::write_statcan_data_cache(
    "10100004", "eng", as.Date("2026-01-01"), sample_table()
  )
  expect_false(file.exists(
    statcanR:::statcan_data_cache_file(
      statcanR:::statcan_data_cache_dir(), "10100004", "eng"
    )
  ))
  expect_null(
    statcanR:::read_statcan_data_cache("10100004", "eng", as.Date("2026-01-01"))
  )
})

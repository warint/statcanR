test_that("Product IDs retain compatibility with earlier input formats", {
  expect_identical(
    statcanR:::normalize_product_id("27-10-0014-01"),
    "27100014"
  )
  expect_identical(statcanR:::normalize_product_id("27100014"), "27100014")
  expect_identical(
    statcanR:::normalize_product_id("27-10-0014"),
    "27100014"
  )
  expect_identical(
    statcanR:::format_product_id("27100014"),
    "27-10-0014-01"
  )
})

test_that("invalid Product IDs and languages fail clearly", {
  expect_error(statcanR:::normalize_product_id(27100014), "character")
  expect_error(statcanR:::normalize_product_id("27-10"), "eight-digit")
  expect_identical(statcanR:::normalize_language("eng"), "eng")
  expect_identical(statcanR:::normalize_language("fr"), "fra")
  expect_error(statcanR:::normalize_language("deu"), "eng.*fra")
})

test_that("reference periods are converted to stable dates", {
  dates <- statcanR:::parse_reference_dates(
    c("2020/2021", "2024-07", "2025", "2026-07-17")
  )

  expect_s3_class(dates, "Date")
  expect_identical(
    format(dates),
    c("2021-03-31", "2024-07-01", "2025-01-01", "2026-07-17")
  )

  annual <- statcanR:::parse_reference_dates(1999:2001)
  expect_identical(
    format(annual),
    c("1999-01-01", "2000-01-01", "2001-01-01")
  )
})

test_that("download output paths must already exist", {
  expect_identical(statcanR:::normalize_output_path(tempdir()), tempdir())
  expect_error(
    statcanR:::normalize_output_path(file.path(tempdir(), "not-created")),
    "does not exist"
  )
})

test_that("statcan_download_data writes and returns its data", {
  output_dir <- tempfile("statcanR-test-")
  dir.create(output_dir)
  on.exit(unlink(output_dir, recursive = TRUE, force = TRUE), add = TRUE)

  local_mocked_bindings(
    statcan_data = function(tableNumber, lang) {
      data.frame(
        REF_DATE = as.Date("2026-01-01"),
        COORDINATE = "1.1",
        VALUE = 42,
        stringsAsFactors = FALSE
      )
    },
    .package = "statcanR"
  )

  expect_message(
    result <- statcan_download_data("10-10-0001-01", "eng", output_dir),
    "saved"
  )
  expected_file <- file.path(output_dir, "statcan_10100001_eng.csv")

  expect_s3_class(result, "data.frame")
  expect_true(file.exists(expected_file))
  expect_identical(
    attr(result, "statcan_file"),
    normalizePath(expected_file, winslash = "/", mustWork = TRUE)
  )
})

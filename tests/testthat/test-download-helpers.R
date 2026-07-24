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

test_that("multi-section metadata files yield the cube title (issue #8)", {
  metadata_file <- tempfile(fileext = ".csv")
  on.exit(unlink(metadata_file), add = TRUE)

  # Mirror the real "_MetaData.csv" layout: a header and one cube row, then a
  # blank line and further sections with different column counts. The cube row
  # has a comma-bearing quoted title and an unquoted, semicolon-separated field.
  writeLines(
    c(
      paste0(
        '"Cube Title","Product Id","CANSIM Id",URL,"Cube Notes",',
        '"Archive Status",Frequency,"Start Reference Period",',
        '"End Reference Period","Total number of dimensions"'
      ),
      paste0(
        '"Life expectancy, single-year estimates, Canada, all provinces ',
        'except Prince Edward Island","13100837",,',
        '"https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1310083701",',
        '1;2;3;13,"CURRENT - a cube available to the public and that is ',
        'current","Annual","1980-01-01","2024-01-01","4",'
      ),
      "",
      '"Dimension ID","Dimension name","Dimension Notes","Dimension Definitions"',
      '1,"Geography",,',
      '2,"Age group",,'
    ),
    metadata_file,
    useBytes = TRUE
  )

  metadata <- statcanR:::read_statcan_metadata(metadata_file)

  # Exactly the cube row: if later sections bled in, nrow would exceed 1.
  expect_identical(nrow(metadata), 1L)
  expect_identical(
    as.character(metadata[[1L]][1L]),
    paste0(
      "Life expectancy, single-year estimates, Canada, all provinces ",
      "except Prince Edward Island"
    )
  )
})

test_that("empty or truncated metadata files return an empty table", {
  short_file <- tempfile(fileext = ".csv")
  on.exit(unlink(short_file), add = TRUE)
  writeLines('"Cube Title","Product Id"', short_file)

  metadata <- statcanR:::read_statcan_metadata(short_file)
  expect_s3_class(metadata, "data.frame")
  expect_identical(nrow(metadata), 0L)
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

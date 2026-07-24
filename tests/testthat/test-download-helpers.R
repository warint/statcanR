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

test_that("empty Statistics Canada columns get a stable character type", {
  data_csv <- tempfile(fileext = ".csv")
  on.exit(unlink(data_csv), add = TRUE)
  # DGUID, STATUS, SYMBOL and TERMINATED are blank for every row, as in many
  # real tables; the data-bearing columns are populated.
  writeLines(
    c(
      paste(
        "REF_DATE", "GEO", "DGUID", "Sector", "UOM", "UOM_ID",
        "SCALAR_FACTOR", "SCALAR_ID", "VECTOR", "COORDINATE", "VALUE",
        "STATUS", "SYMBOL", "TERMINATED", "DECIMALS",
        sep = ","
      ),
      "2020,Canada,,Public sector,Persons,249,units,0,v1,1.1,100,,,,0",
      "2021,Canada,,Public sector,Persons,249,units,0,v1,1.1,110,,,,0"
    ),
    data_csv
  )
  raw <- data.table::fread(data_csv, encoding = "UTF-8", showProgress = FALSE)

  # Precondition: fread types the all-blank columns as logical.
  expect_true(is.logical(raw$DGUID))
  expect_true(is.logical(raw$STATUS))
  expect_true(is.logical(raw$SYMBOL))
  expect_true(is.logical(raw$TERMINATED))

  stable <- statcanR:::stabilize_statcan_empty_columns(raw)

  # The empty text columns are now character, still holding no values.
  for (nm in c("DGUID", "STATUS", "SYMBOL", "TERMINATED")) {
    expect_type(stable[[nm]], "character")
    expect_true(all(is.na(stable[[nm]])))
  }

  # Populated columns keep their natural type and values.
  expect_type(stable$GEO, "character")
  expect_identical(stable$GEO, c("Canada", "Canada"))
  expect_true(is.numeric(stable$VALUE))
  expect_equal(as.numeric(stable$VALUE), c(100, 110))
  expect_true(is.numeric(stable$UOM_ID))
})

test_that("type stabilization never rewrites populated flag columns", {
  data_csv <- tempfile(fileext = ".csv")
  on.exit(unlink(data_csv), add = TRUE)
  # STATUS carries reliability letters ("E", "F"); TERMINATED carries "t". The
  # "F" and "t" must survive as themselves, not be coerced to "FALSE"/logical.
  writeLines(
    c(
      "REF_DATE,GEO,VALUE,STATUS,TERMINATED",
      "2020,Canada,100,E,",
      "2021,Canada,,F,t"
    ),
    data_csv
  )
  raw <- data.table::fread(data_csv, encoding = "UTF-8", showProgress = FALSE)
  stable <- statcanR:::stabilize_statcan_empty_columns(raw)

  expect_type(stable$STATUS, "character")
  expect_identical(stable$STATUS, c("E", "F"))
  expect_identical(stable$TERMINATED, c("", "t"))
})

test_that("type stabilization is column-name agnostic", {
  data_csv <- tempfile(fileext = ".csv")
  on.exit(unlink(data_csv), add = TRUE)
  # An arbitrary, non-standard empty column stands in for a French header or a
  # column Statistics Canada might add later: the rule is driven by type, not
  # by a hard-coded list of names.
  writeLines(
    c(
      "REF_DATE,GEO,SOME_NEW_COLUMN,VALUE",
      "2020,Canada,,100",
      "2021,Canada,,110"
    ),
    data_csv
  )
  raw <- data.table::fread(data_csv, encoding = "UTF-8", showProgress = FALSE)
  expect_true(is.logical(raw$SOME_NEW_COLUMN))

  stable <- statcanR:::stabilize_statcan_empty_columns(raw)
  expect_type(stable$SOME_NEW_COLUMN, "character")
  expect_true(all(is.na(stable$SOME_NEW_COLUMN)))
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

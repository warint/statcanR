sample_catalogue <- function() {
  data.frame(
    title_eng = c(
      "Bank assets",
      "Consumer prices",
      "International exports"
    ),
    title_fra = c(
      "Actifs bancaires",
      "Prix à la consommation",
      "Exportations internationales"
    ),
    id = c("10-10-0004-01", "18-10-0004-01", "36-10-0434-01"),
    release_date = as.Date(c("2026-07-16", "2026-07-15", "2026-07-14")),
    stringsAsFactors = FALSE
  )
}

test_that("catalogue responses are normalized", {
  payload <- data.frame(
    productId = c(10100004, 18100004),
    cubeTitleEn = c("Bank assets", "Consumer prices"),
    cubeTitleFr = c("Actifs bancaires", "Prix à la consommation"),
    releaseTime = c("2026-07-16T08:30:00Z", "2026-07-15T08:30:00Z")
  )

  result <- statcanR:::normalize_statcan_catalogue(payload)

  expect_identical(result$id, c("10-10-0004-01", "18-10-0004-01"))
  expect_s3_class(result$release_date, "Date")
  expect_true(statcanR:::is_valid_statcan_catalogue(result))
})

test_that("search filtering is case-insensitive", {
  result <- statcanR:::filter_statcan_catalogue(
    sample_catalogue(),
    c("INTERNATIONAL", "exports"),
    "eng"
  )

  expect_equal(nrow(result), 1L)
  expect_identical(result$id, "36-10-0434-01")
})

test_that("French titles can be searched", {
  result <- statcanR:::filter_statcan_catalogue(
    sample_catalogue(),
    "CONSOMMATION",
    "fra"
  )

  expect_equal(nrow(result), 1L)
  expect_identical(result$id, "18-10-0004-01")
  expect_identical(result$lang, "fra")
})

test_that("no matches return an empty data frame", {
  result <- statcanR:::filter_statcan_catalogue(
    sample_catalogue(),
    "not present",
    "eng"
  )

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0L)
  expect_identical(
    names(result),
    c("title", "id", "description", "release_date", "lang")
  )
})

test_that("invalid catalogue schemas are rejected", {
  invalid <- sample_catalogue()
  invalid$id[1] <- "not-a-table-id"

  expect_false(statcanR:::is_valid_statcan_catalogue(invalid))
})

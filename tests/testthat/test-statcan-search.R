test_that("catalogue responses are normalized", {
  payload <- data.frame(
    productId = c(10100004, 18100004),
    cubeTitleEn = c("Bank assets", "Consumer prices"),
    cubeTitleFr = c("Actifs bancaires", "Prix à la consommation"),
    cubeStartDate = c("1978-01-01", "2000-01-01"),
    cubeEndDate = c("2026-01-01", "2026-01-01"),
    releaseTime = c("2026-07-16T08:30:00Z", "2026-07-15T08:30:00Z"),
    archived = c("2", "1"),
    frequencyCode = c(12, 6)
  )

  result <- statcanR:::normalize_statcan_catalogue(payload)

  expect_identical(result$id, c("10-10-0004-01", "18-10-0004-01"))
  expect_s3_class(result$release_date, "Date")
  expect_identical(result$archived, c(FALSE, TRUE))
  expect_identical(result$frequency_code, c(12L, 6L))
  expect_true(statcanR:::is_valid_statcan_catalogue(result))
})

test_that("wrapped catalogue responses are normalized", {
  payload <- list(
    status = "SUCCESS",
    object = data.frame(
      productId = "1010000401",
      cubeTitleEn = "Bank assets",
      cubeTitleFr = "Actifs bancaires",
      releaseTime = "2026-07-16T08:30:00Z"
    )
  )

  result <- statcanR:::normalize_statcan_catalogue(payload)
  expect_identical(result$id, "10-10-0004-01")
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

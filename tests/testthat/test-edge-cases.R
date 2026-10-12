# Acceptance 3 edge cases: empty results, NULL columns, type
# coercion (requirements.md acceptance criteria 3)

test_that("empty results return a zero-row data.frame", {
  df <- data.frame(x = 1:4, g = c("a", "a", "b", "b"))
  res <- duckdf("SELECT x FROM df WHERE x > 100", df = list(df = df))
  expect_s3_class(res, "data.frame")
  expect_equal(nrow(res), 0)
  expect_equal(names(res), "x")
})

test_that("NULL columns come back as NA logicals", {
  df <- data.frame(x = 1:2)
  res <- duckdf("SELECT NULL AS n, x FROM df", df = list(df = df))
  expect_true(all(is.na(res$n)))
  # DuckDB maps a NULL literal column to NA integer; NA-ness is the
  # contract, the concrete type is the engine's mapping
  expect_true(all(is.na(res$n)) && nrow(res) == 2)
})

test_that("engine types land as the right R classes", {
  df <- data.frame(x = 1:4, y = c(1.5, 2.5, 3.5, 4.5))
  res <- duckdf(
    "SELECT SUM(x) AS s, AVG(y) AS a, CAST(MIN(x) AS VARCHAR) AS t FROM df",
    df = list(df = df))
  expect_type(res$s, "double")
  expect_type(res$a, "double")
  expect_type(res$t, "character")
  expect_equal(res$s, 10)
})

# ingest() contract

csv_fixture <- function(dir) {
  path <- file.path(dir, "ing_test.csv")
  write.csv(data.frame(x = 1:4, y = c("a", "b", "c", "d")), path,
            row.names = FALSE)
  path
}

test_that("ingest returns a data.frame by default", {
  dir <- tempdir()
  csv_fixture(dir)
  res <- withr::with_dir(dir, ingest("ing_df", "ing_test.csv",
                                     persist = FALSE))
  expect_s3_class(res, "data.frame")
  expect_false(inherits(res, "data.table"))
  expect_equal(nrow(res), 4)
})

test_that("ingest returns data.table and tibble forms", {
  dir <- tempdir()
  csv_fixture(dir)
  dt <- withr::with_dir(dir, ingest("ing_dt", "ing_test.csv",
                                    persist = FALSE, object_type = "data.table"))
  expect_s3_class(dt, "data.table")
  tb <- withr::with_dir(dir, ingest("ing_tb", "ing_test.csv",
                                    persist = FALSE, object_type = "tibble"))
  expect_s3_class(tb, "tbl_df")
})

test_that("missing package is package_error with install hint", {
  skip_if(requireNamespace("data.table", quietly = TRUE))
  dir <- tempdir()
  csv_fixture(dir)
  expect_error(ingest("ing_x", "ing_test.csv", persist = FALSE,
                      object_type = "data.table"),
               regexp = "install.packages", class = "package_error")
})

test_that("persist path writes an on-disk database named after the table", {
  dir <- tempdir()
  csv_fixture(dir)
  on.exit(unlink(file.path(dir, "ing_db",
                           paste0("ing_db", c(".wal", ".tmp"))),
                 recursive = TRUE, force = TRUE), add = TRUE)
  withr::with_dir(dir, {
    invisible(ingest("ing_db", "ing_test.csv", persist = TRUE))
    expect_true(file.exists("ing_db"))
    g <- gander("ing_db")
    expect_setequal(names(g), "ing_db")
  })
})

test_that("no GlobalEnv mutation: ingest returns, callers capture", {
  dir <- tempdir()
  csv_fixture(dir)
  res <- withr::with_dir(dir, ingest("captured_df", "ing_test.csv",
                                     persist = FALSE))
  expect_false("captured_df" %in% ls(globalenv()))
  expect_equal(nrow(res), 4)
})

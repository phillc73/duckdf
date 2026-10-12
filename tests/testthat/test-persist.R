# persist() contract (spec-api-contract.md)

test_that("persist creates a database, writes tables, then queries", {
  dir <- tempdir()
  on.exit(unlink(file.path(dir, c("mk_test", "mk_test.wal", "mk_test.tmp")),
                 recursive = TRUE, force = TRUE), add = TRUE)
  withr::with_dir(dir, {
    res <- persist("SELECT AVG(mpg) AS avg_mpg FROM mpg_df",
                   db_name = "mk_test",
                   df = list(mpg_df = data.frame(mpg = c(21, 22, 18))))
    expect_s3_class(res, "data.frame")
    expect_equal(round(res$avg_mpg, 3), 20.333)
    expect_true(file.exists("mk_test"))
    expect_false(file.exists("mk_test.wal"))
  })
})

test_that("persist queries an existing database without rewriting", {
  dir <- tempdir()
  on.exit(unlink(file.path(dir, "ex_test.duckdb",
                           paste0("ex_test.duckdb", c(".wal", ".tmp"))),
                 recursive = TRUE, force = TRUE), add = TRUE)
  withr::with_dir(dir, {
    persist("SELECT * FROM one_df", db_name = "ex_test.duckdb",
            df = list(one_df = data.frame(a = 1:3)))
    res <- persist("SELECT SUM(a) AS s FROM one_df", db_name = "ex_test.duckdb")
    expect_equal(res$s, 6)
  })
})

test_that("persist writes multiple tables via the df list", {
  dir <- tempdir()
  on.exit(unlink(file.path(dir, "multi_test",
                           paste0("multi_test", c(".wal", ".tmp"))),
                 recursive = TRUE, force = TRUE), add = TRUE)
  withr::with_dir(dir, {
    res <- persist("SELECT COUNT(*) AS n FROM a_df JOIN b_df USING (k)",
                   db_name = "multi_test",
                   df = list(a_df = data.frame(k = 1:3),
                             b_df = data.frame(k = c(1, 2, 2))))
    expect_equal(res$n, 3)
    g <- gander("multi_test")
    expect_setequal(names(g), c("a_df", "b_df"))
  })
})

test_that("connection is closed on a write error (2021 leak fixed)", {
  dir <- tempdir()
  on.exit(unlink(file.path(dir, "err_test",
                           paste0("err_test", c(".wal", ".tmp"))),
                 recursive = TRUE, force = TRUE), add = TRUE)
  withr::with_dir(dir, {
    bad <- structure(data.frame(x = 1), class = c("weird", "data.frame"))
    expect_error(persist("SELECT * FROM bad_df", df = list(bad_df = bad)),
                 class = "error")
    con <- duckdf:::duckdf_con()
    expect_true(DBI::dbIsValid(con))
  })
})

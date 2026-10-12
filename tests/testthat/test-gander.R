# gander() contract

test_that("gander returns five-row heads per table, named by table", {
  dir <- tempdir()
  on.exit(unlink(file.path(dir, "gn_test",
                           paste0("gn_test", c(".wal", ".tmp"))),
                 recursive = TRUE, force = TRUE), add = TRUE)
  withr::with_dir(dir, {
    persist("SELECT * FROM big_df",
            db_name = "gn_test", df = list(big_df = data.frame(x = 1:9)))
    res <- gander("gn_test")
    expect_type(res, "list")
    expect_setequal(names(res), "big_df")
    expect_equal(nrow(res$big_df), 5)
    expect_null(attr(res$big_df, "types"))
  })
})

test_that("show_types adds column type information", {
  dir <- tempdir()
  on.exit(unlink(file.path(dir, "gt_test",
                           paste0("gt_test", c(".wal", ".tmp"))),
                 recursive = TRUE, force = TRUE), add = TRUE)
  withr::with_dir(dir, {
    persist("SELECT * FROM typed_df", db_name = "gt_test",
            df = list(typed_df = data.frame(x = 1L, y = "a")))
    res <- gander("gt_test", show_types = TRUE)
    types <- attr(res$typed_df, "types")
    expect_setequal(types$column_name, c("x", "y"))
  })
})

test_that("missing database is a db_error naming the path", {
  expect_error(gander("definitely_not_here"), regexp = "definitely_not_here",
               class = "db_error")
})

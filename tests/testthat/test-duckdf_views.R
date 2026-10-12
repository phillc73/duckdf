# duckdf_views() contract

test_that("empty view listing is an empty data.frame, not an error", {
  duckdf:::duckdf_shutdown()
  res <- duckdf_views()
  expect_s3_class(res, "data.frame")
  expect_equal(nrow(res), 0)
  expect_setequal(names(res), c("view_name", "backing_class"))
})

test_that("populated listing names views and backing classes", {
  con <- duckdf:::duckdf_con()
  duckdf:::duckdf_register_view(con, "views_df", data.frame(x = 1))
  on.exit(tryCatch(duckdb::duckdb_unregister(con, "views_df"),
                   error = function(e) NULL), add = TRUE)
  res <- duckdf_views()
  expect_true("views_df" %in% res$view_name)
  expect_equal(res$backing_class[res$view_name == "views_df"], "data.frame")
})

test_that("views vanish from the listing after per-call unregistration", {
  duckdf("SELECT COUNT(*) AS n FROM gone_df",
         df = list(gone_df = data.frame(x = 1)))
  expect_equal(nrow(duckdf_views()), 0)
})

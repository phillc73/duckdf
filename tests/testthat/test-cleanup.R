# cleanup() parity: db + .wal + .tmp removal, observable return

test_that("cleanup removes db, wal and tmp files and returns them", {
  dir <- tempdir()
  path <- file.path(dir, "cln_test.duckdb")
  files <- c(path, paste0(path, ".wal"), paste0(path, ".tmp"))
  on.exit(unlink(files), add = TRUE)
  writeLines("x", files[1])
  writeLines("x", files[2])
  writeLines("x", files[3])
  removed <- withr::with_dir(dir, cleanup("cln_test.duckdb"))
  expect_setequal(removed, basename(files))
  expect_false(any(file.exists(files)))
})

test_that("cleanup with missing files returns empty and does not error", {
  dir <- tempdir()
  removed <- withr::with_dir(dir, cleanup("never_existed_db"))
  expect_equal(removed, character(0))
})

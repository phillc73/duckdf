# Harness smoke test: tiny data, all constructible arms, no long timings
# GPL-3, see README

test_that("bench harness runs all constructible arms on tiny data", {
  skip_if_not_installed("duckdb")
  harness <- file.path("..", "..", "bench", "run_benchmarks.R")
  skip_if_not(file.exists(harness), "bench harness present")
  env <- new.env(parent = globalenv())
  sys.source(harness, env = env)

  out <- env$run_benchmarks(tiny = TRUE, write = FALSE)

  expect_s3_class(out$results, "data.frame")
  expect_setequal(unique(out$results$arm),
                  c("duckdf", "raw_duckdb", "sqldf", "data_table",
                    "dplyr", "duckplyr", "dbplyr"))
  expect_setequal(unique(out$results$task), c("q1", "q2", "q3", "q4"))

  # no arm silently errored: failures must carry an observation
  bad <- out$results[!out$results$equiv_status %in%
                       c("match", "observation", "not-run"), ]
  expect_equal(nrow(bad), 0,
               info = paste(bad$arm, bad$task, bad$observation,
                            collapse = " | "))

  # constructible arms produced timings
  timed <- out$results[!is.na(out$results$warm_s), ]
  expect_gt(nrow(timed), 0)
  expect_true(all(timed$warm_s > 0))

  # verdicts computed per task against the frozen 1.10x band
  expect_setequal(unique(out$verdicts$task), c("q1", "q2", "q3", "q4"))
  expect_true(all(out$verdicts$claim4a %in%
                    c("PASS", "FAIL", "not-run")))
})

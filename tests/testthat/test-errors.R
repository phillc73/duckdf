# Error taxonomy classes (spec-lifecycle-and-errors.md)

test_that("bad arguments raise input_error before any connection work", {
  expect_error(cleanup(""), class = "input_error")
  expect_error(cleanup(NA_character_), class = "input_error")
  expect_error(cleanup(123), class = "input_error")
  expect_error(cleanup(c("a", "b")), class = "input_error")
})

test_that("duckdf_error is the parent class of duckdf errors", {
  expect_error(cleanup(""), class = "duckdf_error")
})

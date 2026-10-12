#!/bin/sh
# duckdf test runner - exits nonzero on failure, prints RESULT: pass on green
cd "$(dirname "$0")" || exit 1
Rscript -e '
  out <- testthat::test_local(".", reporter = testthat::ListReporter$new(),
                              stop_on_failure = FALSE);
  if (length(out) == 0) quit(status = 1);
  bad <- function(r) inherits(r, c("expectation_failure", "expectation_error"));
  nbad <- sum(unlist(lapply(out, function(t) vapply(t$results, bad, logical(1)))));
  quit(status = if (nbad > 0) 1 else 0)
' && echo "RESULT: pass"

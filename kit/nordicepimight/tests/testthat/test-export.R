test_that("summary counts from 1 to 5 are suppressed, 0 and 6 are kept", {
  summary <- data.table(trait = "t", relatives_kind = "FS", birth_year = c("1950", "1960"),
                        probands = c(100L, 100L), cases = c(6L, 3L), competing = c(0L, 40L),
                        censored = c(94L, 57L), with_relatives = c(5L, 60L),
                        with_affected_relatives = c(0L, 12L), relatives = c(120L, 70L),
                        affected_relatives = c(1L, 30L))
  out <- suppress_summary(summary, 5L)$table
  expect_equal(out$cases, c(6L, NA))
  expect_equal(out$with_relatives, c(NA, 60L))
  expect_equal(out$with_affected_relatives, c(0L, 12L))
  expect_equal(out$affected_relatives, c(NA, 30L))
  expect_equal(out$probands, c(100L, 100L))
})

test_that("hiding one outcome count hides the other two, so probands can't reveal it", {
  summary <- data.table(probands = 100L, cases = 3L, competing = 40L, censored = 57L,
                        with_relatives = 60L, with_affected_relatives = 12L, relatives = 70L,
                        affected_relatives = 30L)
  out <- suppress_summary(summary, 5L)
  expect_true(all(is.na(unlist(out$table[, .(cases, competing, censored)]))))
  expect_equal(out$hidden, 3L)
})

test_that("CIF rows with 1 to 5 cumulative cases are dropped, weighted counts included", {
  cif <- data.table(age = 0:4, cif = c(0, 0.01, 0.02, 0.03, 0.05),
                    cases = c(0, 1, 4.5, 5, 6.2))
  out <- suppress_cif(cif, 5L)
  expect_equal(out$table$age, c(0L, 4L))
  expect_equal(out$hidden, 3L)
})

test_that("the exported run record names files without their paths", {
  run <- list(inputs = list(site = list(path = "/secure/registry/dk.yaml", md5 = "abc")))
  out <- export_record(run, 5L, list(summary = 2L, cif = 1L))
  expect_equal(out$inputs$site, list(file = "dk.yaml", md5 = "abc"))
  expect_true(out$export$preliminary)
})

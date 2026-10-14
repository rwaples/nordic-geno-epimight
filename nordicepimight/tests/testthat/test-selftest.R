test_that("a comparison with a column absent fails instead of passing on nothing", {
  actual <- data.table(k = "a", x = 1)
  expected <- data.table(k = "a", x = 1, y = 2)
  expect_equal(compare_tables("t", actual, expected, "k", c("x", "y"))$verdict, "FAIL")
  expect_equal(compare_tables("t", actual, expected, "k", "x")$verdict, "PASS")
})

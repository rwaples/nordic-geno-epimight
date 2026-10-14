test_that("an rg heatmap shows only its own relationship", {
  rg <- data.table(level = "pooled", relationship = c("PO", "FS"), index_trait = "a",
                   relatives_trait = "b", rg = c(0.5, 0.9), l95_sandwich = 0.1, u95_sandwich = 1)
  plot <- plot_rg_heatmap(rg, "FS")
  expect_equal(plot$data$rg, 0.9)
  expect_equal(plot$labels$title, "Pooled rg, FS")
})

test_that("an estimate reads as value and interval, or NA with its note", {
  expect_equal(format_estimate(c(0.5, NA), c(0.1, NA), c(0.9, NA), c(NA, "no FS rows")),
               c("0.500 (0.100, 0.900)", "NA: no FS rows"))
})

test_that("CIF panels run population, family history, cross", {
  cif <- data.table(cohort = c("cross", "population", "family_history"), index_trait = "a",
                    relatives_trait = c("b", NA, "a"), relationship = c("FS", NA, "FS"),
                    birth_year = "1950", age = 1, cif = 0.1)
  expect_equal(levels(plot_cif(cif, "birth_year")$data$panel),
               c("population: a", "family history: a, FS relatives with a",
                 "cross: a, FS relatives with b"))
})

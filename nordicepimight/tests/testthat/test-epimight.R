test_that("each EPIMIGHT call is planned once, with what rg needs", {
  analyses <- data.table(
    analysis_id = c("a", "b", "c"), analysis = c("h2", "rg", "rg"),
    trait = c("t1", "t1", "t2"), relatives_trait = c("t1", "t2", "t1"), relationship = "FS"
  )
  jobs <- plan_jobs(analyses, "birth_year")
  expect_setequal(jobs$job, c(
    "cif|t1", "cif|t2", "cif|t1|t1|FS", "cif|t2|t2|FS", "h2|t1|t1|FS", "h2|t2|t2|FS",
    "h2_pooled|t1|t1|FS", "h2_pooled|t2|t2|FS", "cif|t1|t2|FS", "cif|t2|t1|FS",
    "rg|t1|t2|FS", "rg|t2|t1|FS", "rg_pooled|t1|t2|FS", "rg_pooled|t2|t1|FS"
  ))
  rg <- jobs[job == "rg_pooled|t2|t1|FS", args][[1]]
  expect_equal(rg$meta_analyze, "fixed")
  expect_equal(rg$relatedness, 0.5)
  expect_equal(rg$cif_cross, list(index_trait = "t2", relatives_trait = "t1", relatives_kind = "FS",
                                  stratify_columns = list("birth_year")))
  expect_equal(jobs[job == "h2_pooled|t1|t1|FS", args][[1]]$method, "fixed")
})

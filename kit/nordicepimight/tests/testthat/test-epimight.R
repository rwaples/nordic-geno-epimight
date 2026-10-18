test_that("the sandwich pairs probands through people outside the pool, who add nothing (#1)", {
  ped <- fixture_spec()$pedigree[, .(person_id = id, mother_id = mother, father_id = father)]
  probands <- paste0("c", 1:6)
  x <- c(1, 2, 3, 5, 7, 11)
  variance <- function(pedigree) {
    sandwich <- epimight:::SandwichAnalysis$new(pedigree = pedigree, probands = probands,
                                                max_degree = 3L)
    built <- sandwich$graph()
    # assemble_influence fills only pool rows, so everyone else has zero influence.
    psi <- matrix(0, built$graph$n, 1)
    psi[match(probands, built$person_id), 1] <- x
    list(ids = built$person_id, v = sandwich$calculate_pair_variances(built$graph, psi, 3L))
  }
  # c1-c3 and c4-c6 are two sibships; every pair across them is 1C through gp1 and gp2.
  a <- x[1:3]
  b <- x[4:6]
  fs <- sum(utils::combn(a, 2, prod)) + sum(utils::combn(b, 2, prod))
  full <- variance(ped)
  expect_setequal(full$ids, ped$person_id)
  expect_equal(full$v, sum(x^2) + 2 * (fs + sum(a) * sum(b)))
  # Without the parents' rows the probands' parents are external, and the cousins are lost.
  expect_equal(variance(ped[person_id %in% probands])$v, sum(x^2) + 2 * fs)
})

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

plan_dir <- file.path(test_path(), "..", "..", "..", "..", "plan")

test_that("the initial and complete plans share every setting but the analyses", {
  skip_if_not(dir.exists(plan_dir), "not run from the repository")
  initial <- yaml::read_yaml(file.path(plan_dir, "initial.yaml"))
  complete <- yaml::read_yaml(file.path(plan_dir, "complete.yaml"))
  expect_equal(initial[names(initial) != "analyses"], complete[names(complete) != "analyses"])
})

test_that("both analysis lists pass the checks, and the initial is part of the complete", {
  skip_if_not(dir.exists(plan_dir), "not run from the repository")
  traits <- read_traits(file.path(plan_dir, "traits.tsv"), plan_dir)$table
  lists <- lapply(c(initial = "analyses_initial.tsv", complete = "analyses_complete.tsv"),
                  function(f) read_analyses(file.path(plan_dir, f), traits, 3L))
  for (l in lists) expect_equal(nrow(l$findings), 0)
  expect_true(all(lists$initial$table$analysis_id %in% lists$complete$table$analysis_id))
})

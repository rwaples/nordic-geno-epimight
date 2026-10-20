test_that("a step needs the one before it to have finished", {
  out <- tempfile("out")
  expect_error(begin_step(out, "cohort"), "check has not finished")
  begin_step(out, "check")
  finish_step(out, "check")
  expect_true(dir.exists(begin_step(out, "cohort")))
})

test_that("starting a step deletes its own and every later step's output", {
  out <- tempfile("out")
  for (step in STEPS) {
    dir.create(step_dir(out, step), recursive = TRUE)
    writeLines("x", file.path(step_dir(out, step), "DONE"))
  }
  writeLines("x", file.path(out, "h2.tsv"))
  writeLines("x", file.path(out, "report.html"))
  begin_step(out, "cohort")
  expect_true(file.exists(file.path(step_dir(out, "check"), "DONE")))
  expect_false(file.exists(file.path(step_dir(out, "cohort"), "DONE")))
  expect_false(any(dir.exists(vapply(STEPS[3:6], step_dir, "", out = out))))
  expect_false(file.exists(file.path(out, "h2.tsv")))
  expect_false(file.exists(file.path(out, "report.html")))
})

test_that("later steps stop when an input changed after check", {
  path <- write_fixture(function(s) {
    s$traits[2, file := "./t1.tsv"]
    s
  })
  out <- tempfile("out")
  capture.output(run_step("check", run_check, c(path, out)))
  recorded <- yaml::read_yaml(file.path(out, "1_check", "run.yaml"))$inputs
  expect_equal(sum(grepl("t1.tsv$", vapply(recorded, `[[`, "", "path"))), 1L)
  expect_length(changed_inputs(path, out), 0)
  analyses <- file.path(dirname(path), "plan", "analyses.tsv")
  cat("\n", file = analyses, append = TRUE)
  expect_equal(changed_inputs(path, out), normalizePath(analyses))
  expect_error(run_step("cohort", run_cohort, c(path, out)), "differ from what")
  other <- write_fixture()
  expect_error(run_step("cohort", run_cohort, c(other, out)), "differ from what")
})

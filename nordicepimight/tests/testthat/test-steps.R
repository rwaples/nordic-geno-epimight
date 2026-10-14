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
  expect_false(any(dir.exists(vapply(STEPS[3:5], step_dir, "", out = out))))
  expect_false(file.exists(file.path(out, "h2.tsv")))
  expect_false(file.exists(file.path(out, "report.html")))
})

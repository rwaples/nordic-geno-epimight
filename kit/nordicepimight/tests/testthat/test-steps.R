test_that("a step needs the one before it to have finished", {
  out <- tempfile("out")
  expect_error(begin_step(out, "cohort"), "check has not finished")
  begin_step(out, "check")
  finish_step(out, "check")
  expect_true(dir.exists(begin_step(out, "cohort")))
})

test_that("an output folder that can't be created stops, saying what the image can see", {
  blocker <- tempfile("file")
  writeLines("x", blocker)
  out <- file.path(blocker, "out")
  expect_error(begin_step(out, "check"), "can't create the output folder")
  expect_error(create_out_dir(out, image = TRUE), "sees only")
  expect_error(create_out_dir(out, image = FALSE), "may write there")
  expect_error(run_selftest(out), "can't create the output folder")
  expect_match(bind_hint("apptainer"), "link points to")
  expect_match(bind_hint("docker"), "link points to")
})

test_that("study and a step each name themselves in their usage", {
  expect_error(run_study(character()), "usage: pixi run study SITE.yaml OUT/", fixed = TRUE)
  expect_error(run_step("check", run_check, "site.yaml"),
               "usage: pixi run check SITE.yaml OUT/", fixed = TRUE)
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

test_that("later steps stop when the kit is not the one check ran with", {
  path <- write_fixture()
  out <- tempfile("out")
  capture.output(run_step("check", run_check, c(path, out)))
  expect_silent(stop_if_kit_changed(out))
  other <- utils::modifyList(kit_source(), list(commit = "another"))
  expect_error(stop_if_kit_changed(out, other), "with another kit")
  record <- file.path(out, "1_check", "run.yaml")
  recorded <- yaml::read_yaml(record)
  recorded$kit <- NULL
  yaml::write_yaml(recorded, record)
  expect_error(run_step("cohort", run_cohort, c(path, out)), "not recorded")
})

test_that("a later step names inputs that are gone instead of calling them changed", {
  path <- write_fixture()
  out <- tempfile("out")
  capture.output(run_step("check", run_check, c(path, out)))
  unlink(file.path(dirname(path), "plan", "analyses.tsv"))
  expect_error(run_step("cohort", run_cohort, c(path, out)), "not found now:\\s+\\S*analyses\\.tsv")
})

test_that("the image's template points at the plan in the image", {
  site <- site_template(test_path("../../../../local/example.yaml"))
  expect_equal(yaml::yaml.load(paste(site, collapse = "\n"))$plan,
               "/opt/kit/plan/initial.yaml")
  plan_line <- grep("^plan:", site, value = TRUE)
  original <- grep("^plan:", readLines(test_path("../../../../local/example.yaml")), value = TRUE)
  expect_equal(regexpr("#", plan_line), regexpr("#", original))
  expect_match(paste(site[1:3], collapse = " "), "--bind.*-v at the same path")

  example <- tempfile(fileext = ".yaml")
  writeLines(c("# checkout only", "site: x", "plan: ../plan/complete.yaml # tight"), example)
  site <- site_template(example)
  expect_equal(site[-(1:3)], c("site: x", "plan: /opt/kit/plan/complete.yaml # tight"))
  writeLines("site: x", example)
  expect_error(site_template(example), "no `plan: ../plan/...` line")
})

test_that("the image lists its own commands", {
  expect_false("template" %in% kit_commands(image = FALSE))
  expect_contains(kit_commands(image = TRUE), c("study", "check", "template", "pedsum", "help"))
})

test_that("an image tells Apptainer from Docker and names the command the user typed", {
  expect_equal(container_runtime(c("/x/kit.sif", "")), "apptainer")
  expect_equal(container_runtime(c("", "/x/kit.sif")), "apptainer")
  expect_equal(container_runtime(c("", "")), "docker")
  expect_match(bind_hint("apptainer", "apptainer run IMAGE"),
               "apptainer run --bind /path/to/folder IMAGE \\.\\.\\.", fixed = FALSE)
  expect_match(bind_hint("apptainer", "nordicepimight"),
               "apptainer exec --bind /path/to/folder IMAGE nordicepimight", fixed = TRUE)
  expect_match(bind_hint("docker", "nordicepimight"),
               "docker run -v /path/to/folder:/path/to/folder IMAGE nordicepimight", fixed = TRUE)
  expect_no_match(bind_hint("docker", "nordicepimight"), "--bind")
  expect_equal(kit_command("", image = TRUE), "nordicepimight")
  expect_equal(kit_command("", image = FALSE), "pixi run")
})

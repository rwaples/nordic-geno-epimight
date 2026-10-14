facts_of <- function(rows, affected) {
  list(strata = data.table(trait = "t1", birth_year = c("1900", "1925")),
       relatives = data.table(trait = "t1", relationship = "FS", rows = rows, affected = affected))
}
job_of <- function(kind, status, error = NA_character_) {
  data.table(job = job_id(kind, "t1", "t1", "FS"), kind = kind, index_trait = "t1",
             relatives_trait = "t1", relationship = "FS", status = status, error = error)
}

test_that("an EPIMIGHT stop the cohort table predicts becomes a note", {
  jobs <- job_of("h2", "error", "No probands with at least 1 relative (of kind \"FS\")")
  out <- classify_jobs(jobs, facts_of(10, 0), list(), "birth_year")
  expect_equal(nrow(out$findings), 0)
  expect_equal(out$notes[["h2|t1|t1|FS"]], "no proband with a FS relative affected by t1")
})

test_that("an unpredicted EPIMIGHT error stops the run", {
  jobs <- job_of("h2", "error", "something else")
  out <- classify_jobs(jobs, facts_of(10, 3), list(), "birth_year")
  expect_equal(out$findings$code, "epimight_error_unpredicted")
})

test_that("a predicted stop that did not happen stops the run", {
  out <- classify_jobs(job_of("h2", "ok"), facts_of(0, 0), list(), "birth_year")
  expect_equal(out$findings$code, "epimight_prediction_unmet")
})

test_that("an empty cohort's analysis keeps a row per stratum and a pooled row, with notes", {
  analyses <- data.table(analysis_id = "a", analysis = "h2", trait = "t1", relatives_trait = "t1",
                         relationship = "FS")
  notes <- list(`h2|t1|t1|FS` = "no FS rows for trait t1",
                `h2_pooled|t1|t1|FS` = "no FS rows for trait t1")
  block <- h2_block(analyses, facts_of(0, 0), list(), notes, "birth_year")
  expect_equal(names(block), h2_columns("birth_year"))
  expect_equal(block$level, c("stratum", "stratum", "pooled"))
  expect_equal(block$birth_year, c("1900", "1925", NA))
  expect_true(all(is.na(block$h2)))
  expect_equal(unique(block$note), "no FS rows for trait t1")
  expect_equal(block$relatedness, rep(0.5, 3))
})

test_that("tables are written with 6 significant digits", {
  path <- tempfile(fileext = ".tsv")
  write_rounded(data.table(x = 0.123456789, n = 3L, s = "a"), path)
  expect_equal(readLines(path), c("x\tn\ts", "0.123457\t3\ta"))
})

test_that("notes join without empty parts", {
  expect_equal(join_notes(c("a", NA, NA), c(NA, "b", NA)), c("a", "b", NA))
  expect_equal(join_notes("a", "b"), "a; b")
})

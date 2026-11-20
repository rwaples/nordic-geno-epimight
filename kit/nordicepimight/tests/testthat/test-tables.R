# fh_cases: each stratum's cases among probands with an affected FS relative.
facts_of <- function(rows, affected, fh_cases = c(1L, 1L)) {
  strata <- c("1900", "1925")
  list(strata = data.table(trait = "t1", birth_year = strata),
       relatives = data.table(trait = "t1", relationship = "FS", rows = rows, affected = affected),
       curves = data.table(birth_year = strata, probands = c(5L, 5L, rep(min(affected, 1L), 2)),
                           cases = c(2L, 2L, fh_cases), index_trait = "t1",
                           relatives_trait = rep(c(NA, "t1"), each = 2),
                           relationship = rep(c(NA, "FS"), each = 2)))
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

test_that("a family-history curve with affected relatives but no case is a predicted stop", {
  stop_text <- paste("No proband has a cause-1 event (trait_status 1) for index_trait \"t1\",",
                     "relatives_trait \"t1\" and relatives_kind \"FS\"")
  jobs <- rbind(job_of("cif", "error", stop_text), job_of("h2", "error", stop_text))
  out <- classify_jobs(jobs, facts_of(10, 3, fh_cases = c(0L, 0L)), list(), "birth_year")
  expect_equal(nrow(out$findings), 0)
  expect_equal(out$notes[["h2|t1|t1|FS"]],
               "no case of t1 among probands with a FS relative affected by t1")
  # With no affected relative, EPIMIGHT stops before it looks for a case.
  out <- classify_jobs(jobs, facts_of(10, 0, fh_cases = c(0L, 0L)), list(), "birth_year")
  expect_equal(out$findings$code, rep("epimight_error_unpredicted", 2))
})

test_that("a stratum with affected relatives but no case says so", {
  analyses <- data.table(analysis_id = "a", analysis = "h2", trait = "t1", relatives_trait = "t1",
                         relationship = "FS")
  cif <- data.table(birth_year = "1925", age = c(0, 10, 20))
  results <- list(
    `h2|t1|t1|FS` = data.table(birth_year = "1925", age = 20, h2 = 0.4, se = 0.1,
                               sandwich_se = 0.1, sandwich_l95 = 0.2, sandwich_u95 = 0.6),
    `cif|t1` = cif, `cif|t1|t1|FS` = cif,
    `h2_pooled|t1|t1|FS` = data.table(h2 = 0.4, se = 0.1, sandwich_se = 0.1, sandwich_l95 = 0.2,
                                      sandwich_u95 = 0.6, n_strata = 1L)
  )
  block <- h2_block(analyses, facts_of(10, 3, fh_cases = c(0L, 4L)), results, list(),
                    "birth_year")
  expect_equal(block[birth_year == "1900", note],
               "no case of t1 among this stratum's probands with a FS relative affected by t1")
  expect_true(is.na(block[birth_year == "1925", note]))
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

test_that("a pooled rg with no stratum to pool is NA with a note, whatever EPIMIGHT did", {
  facts <- list(strata = data.table(trait = c("t1", "t2"), birth_year = "1950"),
                relatives = data.table(trait = c("t1", "t2"), relationship = "FS", rows = 5,
                                       affected = 2),
                curves = data.table(index_trait = c("t1", "t2", "t1", "t2", "t1"),
                                    relatives_trait = c(NA, NA, "t1", "t2", "t2"),
                                    relationship = c(NA, NA, "FS", "FS", "FS"),
                                    birth_year = "1950", probands = 2L, cases = 1L))
  jobs <- data.table(job = job_id("rg_pooled", "t1", "t2", "FS"), kind = "rg_pooled",
                     index_trait = "t1", relatives_trait = "t2", relationship = "FS",
                     status = "ok", error = NA_character_)
  results <- list(`rg|t1|t2|FS` = data.table(birth_year = "1950", rg = NaN, se = NaN))
  out <- classify_jobs(jobs, facts, results, "birth_year")
  expect_equal(nrow(out$findings), 0)
  expect_equal(out$notes[["rg_pooled|t1|t2|FS"]], "no stratum with a finite rg and SE to pool")
})

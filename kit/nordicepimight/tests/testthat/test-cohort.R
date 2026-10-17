repo_file <- function(...) file.path(test_path(), "..", "..", "..", ...)

test_that("the cohort table matches make_epimight_tte on every rule case", {
  study <- repo_file("selftest", "cohort_cases", "site.yaml")
  expected_path <- repo_file("selftest", "expected", "cohort_cases.tsv.gz")
  skip_if_not(file.exists(study) && file.exists(expected_path), "not run from the repository")
  checked <- check_inputs(study, tempfile("check"))
  expect_equal(codes(checked, "STOP"), character())
  cohort <- build_cohort(checked$inputs)$cohort
  expected <- as.data.table(utils::read.delim(gzfile(expected_path),
                                              colClasses = c(person_id = "character")))
  key <- c("trait", "relatives_kind", "person_id")
  setkeyv(cohort, key)
  setkeyv(expected, key)
  expect_equal(nrow(cohort), nrow(expected))
  expect_equal(cohort, expected[, names(cohort), with = FALSE], ignore_attr = TRUE)
})

rule_of <- function(...) {
  defaults <- list(min_followup = NA_real_, max_followup = NA_real_, trait2 = NA_character_,
                   exclude_trait2 = "none", trait2_window = NA_real_,
                   trait2_window_type = "within", trait2_action = "exclude",
                   filter_relatives = FALSE)
  as.data.table(utils::modifyList(defaults, list(...)))
}
end <- as.IDate("2020-01-01")
people <- function(age, status = 1L, born = "1950-01-01") {
  data.table(id = paste0("i", seq_along(age)), status = as.integer(status), age = age,
             birth_date = as.IDate(born))
}

test_that("max_followup censors events after the window and keeps those at it", {
  d <- people(c(19.9, 20, 20.1), status = c(1, 2, 1))
  out <- apply_rules(d, rule_of(max_followup = 20), NULL, end)$probands
  expect_equal(out$status, c(1L, 2L, 0L))
  expect_equal(out$age, c(19.9, 20, 20))
})

test_that("a window removes people born too late to be observed for it", {
  born <- as.IDate(c("1999-12-31", "2000-01-02"))
  d <- people(c(5, 5), born = born)
  out <- apply_rules(d, rule_of(max_followup = 20), NULL, end)
  expect_equal(out$probands$id, "i1")
  expect_equal(out$log[rule == "max_followup: born too late, removed", people], 1L)
  expect_equal(apply_rules(d, rule_of(min_followup = 20), NULL, end)$probands$id, "i1")
})

test_that("trait2 at the same age counts as before", {
  d <- people(c(30, 30, 30))
  onsets <- data.table(id = c("i1", "i2"), age = c(30, 30.5))
  before <- apply_rules(d, rule_of(trait2 = "x", exclude_trait2 = "before"), onsets, end)
  expect_equal(before$probands$id, c("i2", "i3"))
  after <- apply_rules(d, rule_of(trait2 = "x", exclude_trait2 = "after"), onsets, end)
  expect_equal(after$probands$id, c("i1", "i3"))
})

test_that("trait2 windows are inclusive: within <= w, at_least >= w", {
  d <- people(c(30, 30, 30))
  onsets <- data.table(id = c("i1", "i2", "i3"), age = c(28, 28.5, 25))
  within <- rule_of(trait2 = "x", exclude_trait2 = "before", trait2_window = 2)
  expect_equal(apply_rules(d, within, onsets, end)$probands$id, "i3")
  at_least <- rule_of(trait2 = "x", exclude_trait2 = "before", trait2_window = 2,
                      trait2_window_type = "at_least")
  expect_equal(apply_rules(d, at_least, onsets, end)$probands$id, "i2")
})

test_that("competing recodes to status 2 at the trait2 onset", {
  d <- people(c(30, 40), status = c(1, 0))
  onsets <- data.table(id = c("i1", "i2"), age = c(25, 35))
  rule <- rule_of(trait2 = "x", exclude_trait2 = "before", trait2_action = "competing")
  out <- apply_rules(d, rule, onsets, end)$probands
  expect_equal(out$status, c(2L, 2L))
  expect_equal(out$age, c(25, 35))
})

test_that("trait2 onsets after max_followup are ignored", {
  d <- people(c(50))
  onsets <- data.table(id = "i1", age = 25)
  rule <- rule_of(max_followup = 20, trait2 = "x", exclude_trait2 = "any")
  expect_equal(nrow(apply_rules(d, rule, onsets, end)$probands), 1L)
})

test_that("relatives come from the file, or from the probands with filter_relatives", {
  rows <- people(c(30, 60), status = c(1, 1))
  probands <- rows[1]
  expect_equal(nrow(relatives_status(rows, probands, rule_of(), NA, end)), 2L)
  expect_equal(nrow(relatives_status(rows, probands, rule_of(filter_relatives = TRUE), NA, end)),
               1L)
  windowed <- relatives_status(rows, probands, rule_of(), 50, end)
  expect_equal(windowed$relative_status, c(1L, 0L))
})

test_that("vertical relationships count only the person's elders", {
  p <- fixture_spec()$pedigree[, multiple_birth_set := NA_character_]
  pairs <- relative_pairs(p, c("PO", "Av", "1G", "FS", "1C"))
  of <- function(person, rel) sort(pairs[person_id == person & relationship == rel, relative_id])
  expect_equal(of("c1", "PO"), c("p1", "p2"))
  expect_equal(of("p1", "PO"), c("gp1", "gp2"))
  expect_equal(of("c1", "Av"), "p3")
  expect_equal(of("c4", "Av"), "p1")
  expect_equal(of("c1", "1G"), c("gp1", "gp2"))
  expect_equal(of("gp1", "1G"), character())
  expect_equal(of("c1", "FS"), c("c2", "c3"))
  expect_equal(of("c1", "1C"), c("c4", "c5", "c6"))
  expect_equal(of("c4", "1C"), c("c1", "c2", "c3"))
})

test_that("members of one multiple-birth set are not each other's FS", {
  p <- fixture_spec()$pedigree[, multiple_birth_set := c(rep(NA, 6), "1", "1", "1", "2", "2", NA)]
  pairs <- relative_pairs(p, c("FS", "1C"))
  of <- function(person, rel) sort(pairs[person_id == person & relationship == rel, relative_id])
  expect_equal(of("c1", "FS"), character())
  expect_equal(of("c4", "FS"), "c6")
  expect_equal(of("c6", "FS"), c("c4", "c5"))
  expect_equal(of("c1", "1C"), c("c4", "c5", "c6"))
})

test_that("pedsum finds a twin pair and a triplet set, and the cohort keeps them as probands", {
  checked <- check_fixture(function(s) {
    triplets <- c("1950-02-01", "1950-02-02", "1950-02-02")
    s$pedigree[id %in% c("c1", "c2", "c3"), birth_date := triplets]
    s$pedigree[id %in% c("c4", "c5"), birth_date := "1951-05-01"]
    s
  }, pedsum = TRUE)
  expect_equal(codes(checked, "STOP"), character())
  sets <- checked$inputs$pedigree[!is.na(multiple_birth_set), .N, by = multiple_birth_set]
  expect_setequal(sets$N, c(3L, 2L))
  cohort <- build_cohort(checked$inputs)$cohort[trait == "t1"]
  expect_setequal(cohort$person_id, paste0("c", 1:6))
  expect_equal(cohort[order(person_id), relatives_n], c(0L, 0L, 0L, 1L, 1L, 2L))
})

test_that("only relatives with a trait-file row count", {
  inputs <- check_fixture()$inputs
  cohort <- build_cohort(inputs)$cohort
  # c1-c3's parents and c4-c6's parents have no rows, so FS counts only siblings.
  expect_equal(cohort[trait == "t1" & person_id == "c1", relatives_n], 2L)
  expect_equal(cohort[trait == "t1" & person_id == "c1", relatives_n_trait], 0L)
  expect_equal(cohort[trait == "t1" & person_id == "c2", relatives_n_trait], 1L)
  expect_equal(nrow(cohort), 12L)
})

test_that("a trait with no probands left stops the cohort step", {
  path <- write_fixture(function(s) {
    s$traits[, min_followup := c("90", NA)]
    s
  })
  out <- tempfile("out")
  dir <- begin_step(out, "check")
  capture.output(checked <- run_check(path, out, dir))
  expect_true(checked)
  finish_step(out, "check")
  dir <- begin_step(out, "cohort")
  expect_output(expect_false(run_cohort(path, out, dir)), "trait_no_probands")
  expect_equal(fread(file.path(dir, "findings.tsv"))$code, "trait_no_probands")
})

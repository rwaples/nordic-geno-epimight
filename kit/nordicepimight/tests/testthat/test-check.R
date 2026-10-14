test_that("the fixture study passes with only the few-cases warning", {
  result <- check_fixture(pedsum = TRUE)
  expect_equal(codes(result, "STOP"), character())
  expect_equal(unique(codes(result, "WARN")), "few_cases")
  expect_setequal(result$inputs$population, paste0("c", 1:6))
  expect_equal(result$inputs$validated_pedigree[id == "c1", c(mother, father)], c("p2", "p1"))
  expect_equal(result$inputs$pedigree[id == "c1", birth_year], 1950L)
})

set_rows <- function(dt, i, ...) {
  dt <- copy(dt)
  values <- list(...)
  for (col in names(values)) {
    if (!(col %in% names(dt))) set(dt, j = col, value = NA_character_)
    set(dt, i = as.integer(i), j = col, value = values[[col]])
  }
  dt
}
with_trait2 <- function(s, ...) {
  s$traits <- set_rows(s$traits, 1, ...)
  s
}
with_windows <- function(s, windows) {
  s$plan$relative_windows <- "relative_windows.tsv"
  s$relative_windows <- windows
  s
}
with_dates <- function(s, file, shift_days = 0, first_date = NULL) {
  rows <- trait_rows(s$trait_files[[file]], "t1", s$pedigree)
  rows[, date := as.character(as.IDate(date) + shift_days)]
  if (!is.null(first_date)) rows[1, date := first_date]
  s$trait_files[[file]] <- rows
  s
}

cases <- list(
  config_unknown_key = function(s) {
    s$site$colour <- "blue"
    s
  },
  config_missing_key = function(s) {
    s$site$study_end <- NULL
    s
  },
  config_value_invalid = function(s) {
    s$site$threads <- 0L
    s
  },
  file_missing = function(s) {
    s$plan$analyses <- "nope.tsv"
    s
  },
  study_end_invalid = function(s) {
    s$site$study_end <- "31/12/2023"
    s
  },
  stratify_invalid = function(s) {
    s$plan$stratify <- list()
    s
  },
  traits_missing_column = function(s) {
    s$traits[, type := NULL]
    s
  },
  traits_unknown_column = function(s) {
    s$traits[, colour := "blue"]
    s
  },
  trait_name_invalid = function(s) {
    s$traits[1, trait := "t 1"]
    s
  },
  trait_duplicate = function(s) {
    s$traits <- rbind(s$traits, s$traits[1])
    s
  },
  trait_type_unknown = function(s) {
    s$traits[1, type := "binary"]
    s
  },
  trait_file_missing = function(s) {
    s$traits[1, file := "nope.tsv"]
    s
  },
  trait_rule_invalid = function(s) with_trait2(s, max_followup = "-3"),
  trait2_missing = function(s) with_trait2(s, exclude_trait2 = "before"),
  trait2_unknown = function(s) with_trait2(s, trait2 = "t9", exclude_trait2 = "any"),
  trait2_self = function(s) with_trait2(s, trait2 = "t1", exclude_trait2 = "before"),
  trait2_competing_needs_before = function(s) {
    with_trait2(s, trait2 = "t2", exclude_trait2 = "after", trait2_action = "competing")
  },
  trait2_unused = function(s) with_trait2(s, trait2 = "t2"),
  analyses_missing_column = function(s) {
    s$analyses[, relationship := NULL]
    s
  },
  analyses_unknown_column = function(s) {
    s$analyses[, colour := "blue"]
    s
  },
  analysis_id_invalid = function(s) {
    s$analyses[1, analysis_id := "h2 t1"]
    s
  },
  analysis_id_duplicate = function(s) {
    s$analyses[2, analysis_id := "h2_t1_FS"]
    s
  },
  analysis_unknown = function(s) {
    s$analyses[1, analysis := "h3"]
    s
  },
  relationship_unknown = function(s) {
    s$analyses[1, relationship := "GP"]
    s
  },
  h2_relatives_trait_differs = function(s) {
    s$analyses[1, relatives_trait := "t2"]
    s
  },
  rg_same_trait = function(s) {
    s$analyses[2, relatives_trait := "t1"]
    s
  },
  analysis_duplicate = function(s) {
    s$analyses <- rbind(s$analyses, s$analyses[1][, analysis_id := "again"])
    s
  },
  max_degree_below_relationship = function(s) {
    s$plan$max_degree <- 2L
    s$analyses[1, relationship := "1C"]
    s
  },
  analysis_trait_unknown = function(s) {
    s$analyses[2, relatives_trait := "t9"]
    s
  },
  relative_windows_trait_unknown = function(s) {
    with_windows(s, data.table(trait = "t9", relationship = "PO", max_followup_relatives = "50"))
  },
  relative_windows_duplicate = function(s) {
    with_windows(s, data.table(trait = "t1", relationship = "PO",
                               max_followup_relatives = c("50", "none")))
  },
  pedigree_missing_column = function(s) {
    s$pedigree[, sex := NULL]
    s
  },
  parent_zero = function(s) {
    s$pedigree[id == "c1", mother := "0"]
    s
  },
  birth_date_missing = function(s) {
    s$pedigree[id == "p4", birth_date := NA]
    s
  },
  birth_date_invalid = function(s) {
    s$pedigree[id == "p4", birth_date := "1927/01/01"]
    s
  },
  stratify_not_in_pedigree = function(s) {
    s$plan$stratify <- c("birth_year", "region")
    s
  },
  pedigree_birth_year_replaced = function(s) {
    s$pedigree[, birth_year := 1]
    s
  },
  pedigree_invalid = function(s) {
    s$pedigree[id == "p1", birth_date := "1960-01-01"]
    s
  },
  external_parent_over_cap = function(s) {
    s$plan$external_parent_cap <- 2L
    s$pedigree[id %in% c("c1", "c2", "c3"), father := "X9"]
    s
  },
  external_parents = function(s) {
    s$pedigree[id == "c4", father := "X9"]
    s
  },
  pedigree_autofixed = function(s) {
    s$pedigree[id == "p1", sex := 2]
    s
  },
  trait_file_missing_column = function(s) {
    s$trait_files$t1.tsv[, status := NULL]
    s
  },
  trait_id_missing = function(s) {
    s$trait_files$t1.tsv <- trait_rows(s$trait_files$t1.tsv, "t1", s$pedigree)[1, id := NA]
    s
  },
  trait_duplicate_id = function(s) {
    s$trait_files$t1.tsv <- rbind(s$trait_files$t1.tsv, s$trait_files$t1.tsv[1])
    s
  },
  trait_file_trait_values = function(s) {
    s$trait_files$t1.tsv[, trait := c("t1", "x", "t1", "t1", "t1", "t1")]
    s
  },
  status_invalid = function(s) {
    s$trait_files$t1.tsv[1, status := 3]
    s
  },
  age_invalid = function(s) {
    s$trait_files$t1.tsv <- trait_rows(s$trait_files$t1.tsv, "t1", s$pedigree)[1, age := -1]
    s
  },
  date_invalid = function(s) with_dates(s, "t1.tsv", first_date = "yesterday"),
  trait_id_not_in_pedigree = function(s) {
    s$trait_files$t1.tsv[1, id := "zz"]
    s
  },
  date_before_birth = function(s) with_dates(s, "t1.tsv", first_date = "1900-01-01"),
  date_after_study_end = function(s) {
    s$trait_files$t1.tsv[6, age := 80]
    s
  },
  age_date_mismatch = function(s) with_dates(s, "t1.tsv", shift_days = 2),
  trait_population_differs = function(s) {
    s$trait_files$t2.tsv <- s$trait_files$t2.tsv[-6]
    s
  },
  stratum_na = function(s) {
    s$plan$stratify <- c("birth_year", "region")
    s$pedigree[, region := ifelse(id == "c1", NA, "north")]
    s
  }
)
trait_rule_cases <- list(
  max_followup_zero = function(s) with_trait2(s, max_followup = "0"),
  min_followup_text = function(s) with_trait2(s, min_followup = "ten"),
  exclude_unknown = function(s) with_trait2(s, trait2 = "t2", exclude_trait2 = "sometimes"),
  window_type_unknown = function(s) {
    with_trait2(s, trait2 = "t2", exclude_trait2 = "before", trait2_window_type = "near")
  },
  filter_relatives_yes = function(s) with_trait2(s, filter_relatives = "yes"),
  window_relatives = function(s) {
    with_windows(s, data.table(trait = "t1", relationship = "PO", max_followup_relatives = "0"))
  }
)

pedsum_cases <- c("pedigree_invalid", "external_parent_over_cap", "external_parents",
                  "pedigree_autofixed")
for (code in names(cases)) {
  local({
    expected <- code
    edit <- cases[[code]]
    test_that(paste("a broken input yields", expected), {
      expect_contains(codes(check_fixture(edit, pedsum = expected %in% pedsum_cases)), expected)
    })
  })
}
for (name in names(trait_rule_cases)) {
  local({
    edit <- trait_rule_cases[[name]]
    test_that(paste("trait_rule_invalid:", name), {
      expect_contains(codes(check_fixture(edit), "STOP"), "trait_rule_invalid")
    })
  })
}

test_that("an unreadable site file stops", {
  path <- tempfile(fileext = ".yaml")
  writeLines("pedigree: [", path)
  expect_equal(read_study(path)$findings$code, "config_unreadable")
})

test_that("a stop leaves no inputs for the next step", {
  expect_null(check_fixture(cases$parent_zero)$inputs)
})

test_that("rule columns parse with the script's defaults", {
  t <- check_fixture(function(s) {
    s$traits <- set_rows(s$traits, 1, max_followup = "20", trait2 = "t2", exclude_trait2 = "before")
    s$traits <- set_rows(s$traits, 2, max_followup = "30", max_followup_relatives = "none")
    s
  })$inputs$traits
  expect_equal(t$max_followup_relatives, c(20, NA))
  expect_equal(t$trait2_window_type, c("within", "within"))
  expect_equal(t$trait2_action, c("exclude", "exclude"))
  expect_equal(t$exclude_trait2, c("before", "none"))
  expect_equal(t$filter_relatives, c(FALSE, FALSE))
})

test_that("ids are text: 001, 1 and 1.0 are three people", {
  result <- check_fixture(function(s) {
    ids <- c("001", "1", "1.0")
    s$pedigree[id %in% c("c1", "c2", "c3"), id := ids]
    for (f in names(s$trait_files)) s$trait_files[[f]][1:3, id := ids]
    s
  }, pedsum = TRUE)
  expect_equal(codes(result, "STOP"), character())
  expect_setequal(result$inputs$population, c("001", "1", "1.0", "c4", "c5", "c6"))
})

test_that("an external parent is a warning within the cap", {
  result <- check_fixture(cases$external_parents, pedsum = TRUE)
  expect_equal(result$findings[code == "external_parents", examples], "X9: 1 children")
  expect_equal(codes(result, "STOP"), character())
})

test_that("a pedigree or trait file that cannot be read stops", {
  path <- write_fixture()
  root <- dirname(path)
  # A gzipped pedigree: fread needs R.utils for it, which the kit does not install.
  con <- gzfile(file.path(root, "data", "pedigree.tsv.gz"), "w")
  writeLines(readLines(file.path(root, "data", "pedigree.tsv")), con)
  close(con)
  site <- yaml::read_yaml(path)
  site$pedigree <- "pedigree.tsv.gz"
  yaml::write_yaml(site, path)
  dir.create(file.path(root, "data", "folder"))
  traits <- fread(file.path(root, "plan", "traits.tsv"))
  traits[1, file := "folder"]
  fwrite(traits, file.path(root, "plan", "traits.tsv"), sep = "\t")
  result <- check_inputs(path, file.path(root, "out"), validate = skip_pedsum)
  expect_contains(codes(result), c("pedigree_unreadable", "trait_file_unreadable"))
})

test_that("a missing data folder, plan or pedigree is file_missing", {
  for (key in c("data", "plan", "pedigree")) {
    result <- check_fixture(function(s) {
      s$site[[key]] <- "nope"
      s
    })
    expect_contains(codes(result, "STOP"), "file_missing")
  }
})

test_that("absolute paths are used as given", {
  expect_equal(resolve_path("/root", c("a.tsv", "/data/b.tsv")), c("/root/a.tsv", "/data/b.tsv"))
  path <- write_fixture()
  site <- yaml::read_yaml(path)
  site$data <- file.path(dirname(path), "data")
  yaml::write_yaml(site, path)
  expect_equal(read_study(path)$study$data, normalizePath(site$data))
})

test_that("an invalid setting stops the run and is replaced by its default", {
  result <- check_fixture(function(s) {
    s$site$threads <- 0L
    s$plan$max_degree <- 9L
    s
  })
  expect_contains(codes(result, "STOP"), "config_value_invalid")
  study <- read_study(write_fixture(function(s) {
    s$plan$max_degree <- 9L
    s
  }))$study
  expect_equal(study$max_degree, 3L)
})

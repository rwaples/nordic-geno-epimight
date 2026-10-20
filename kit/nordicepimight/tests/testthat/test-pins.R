pinned <- list(
  epimight = list(version = "2.2.0", commit = "aaa"),
  pedigreegraph = list(version = "0.12.2", commit = "bbb")
)

test_that("matching installs give no mismatches", {
  installed <- list(
    epimight = list(version = "2.2.0", commit = "aaa"),
    pedigreegraph = list(version = "0.12.2", commit = "bbb")
  )
  expect_null(pin_mismatches(installed, pinned))
})

test_that("a different commit or a missing package is reported", {
  installed <- list(
    epimight = list(version = "2.2.0", commit = "zzz"),
    pedigreegraph = list(version = NA_character_, commit = NA_character_)
  )
  out <- pin_mismatches(installed, pinned)
  expect_length(out, 2)
  expect_match(out[1], "^epimight: installed 2.2.0 \\(zzz\\)")
  expect_match(out[2], "^pedigreegraph: installed NA")
})

test_that("the shipped pins name both GitHub packages by full commit", {
  p <- pins()
  expect_setequal(names(p), c("epimight", "pedigreegraph"))
  for (pkg in names(p)) expect_match(p[[pkg]]$commit, "^[0-9a-f]{40}$")
})

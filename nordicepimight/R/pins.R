# The pinned GitHub sources, from inst/pins.yaml.
pins <- function() {
  yaml::read_yaml(system.file("pins.yaml", package = "nordicepimight", mustWork = TRUE))
}

# What is installed of each pinned package: version and the commit it was built from.
installed_sources <- function() {
  lapply(stats::setNames(nm = names(pins())), function(pkg) {
    desc <- suppressWarnings(utils::packageDescription(pkg))
    if (!is.list(desc)) {
      return(list(version = NA_character_, commit = NA_character_))
    }
    list(version = desc$Version, commit = desc$RemoteSha %||% NA_character_)
  })
}

# One line per pinned package whose installed version or commit differs from its pin.
pin_mismatches <- function(installed = installed_sources(), pinned = pins()) {
  unlist(lapply(names(pinned), function(pkg) {
    have <- installed[[pkg]]
    want <- pinned[[pkg]]
    if (identical(have$commit, want$commit) && identical(have$version, want$version)) {
      return(NULL)
    }
    sprintf("%s: installed %s (%s), pinned %s (%s); run `pixi run setup`",
            pkg, have$version, have$commit, want$version, want$commit)
  }))
}

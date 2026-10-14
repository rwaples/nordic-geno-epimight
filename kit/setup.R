# pixi run setup
#
# Step 0: builds epimight and pedigreegraph from their pinned GitHub commits
# (kit/nordicepimight/inst/pins.yaml) into this pixi environment, then installs the kit's own
# package. A package already built from its pinned commit is kept, so rerunning is cheap.
# Needs internet access the first time; pedigreegraph compiles Rust (a few minutes).

pinned <- yaml::read_yaml("kit/nordicepimight/inst/pins.yaml")

built_from <- function(pkg) {
  desc <- suppressWarnings(utils::packageDescription(pkg))
  if (is.list(desc)) desc$RemoteSha %||% NA_character_ else NA_character_
}

install_pinned <- function(pkg) {
  pin <- pinned[[pkg]]
  if (identical(built_from(pkg), pin$commit)) {
    message(sprintf("%s %s already built from %s", pkg, pin$version, substr(pin$commit, 1, 7)))
    return(invisible())
  }
  message(sprintf("building %s %s from %s@%s", pkg, pin$version, pin$repo,
                  substr(pin$commit, 1, 7)))
  # build = FALSE installs from the unpacked repository: pedigreegraph's Rust crate depends
  # on the repository's core crate by a path outside r/, which a built tarball would drop.
  remotes::install_github(
    pin$repo, ref = pin$commit, subdir = pin$subdir, build = FALSE,
    dependencies = FALSE, upgrade = "never", force = TRUE, quiet = FALSE
  )
  if (!identical(built_from(pkg), pin$commit)) {
    stop(sprintf("%s did not install from %s", pkg, pin$commit), call. = FALSE)
  }
}

install_pinned("pedigreegraph")
install_pinned("epimight")

message("installing nordicepimight")
install.packages("kit/nordicepimight", repos = NULL, type = "source", quiet = TRUE)

library(nordicepimight)
problems <- pin_mismatches()
if (length(problems) > 0) stop(paste(problems, collapse = "\n"), call. = FALSE)
if (!("run_h2_pooled" %in% names(epimight::Pipeline$public_methods))) {
  stop("the installed epimight has no Pipeline$run_h2_pooled", call. = FALSE)
}
versions <- vapply(pinned, `[[`, "", "version")
message("setup done: ", paste(names(pinned), versions, collapse = ", "))

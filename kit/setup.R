# pixi run setup
#
# Setup: builds epimight and pedigreegraph from their pinned GitHub commits
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

# Windows only: conda-forge's Matrix 1.7-6 (r45h5ea86f4_0) calls BLAS and LAPACK through
# 32-bit runtime pseudo-relocations, so a process that loads it dies with "32 bit pseudo
# relocation ... out of range" whenever Windows maps Matrix.dll more than 2 GB from MKL,
# about one start in 20 once survival, pedigreegraph and the tidyverse are loaded. Built
# here from CRAN's source of the same version, its calls go through import thunks. The
# stamp in the package folder holds the build's Built field, which any other build of
# Matrix (a pixi reinstall or upgrade) changes, so only this build passes.
rebuild_matrix_on_windows <- function() {
  if (.Platform$OS.type != "windows") {
    return(invisible())
  }
  stamp <- function() file.path(find.package("Matrix"), "kit-built-from-source")
  built <- function() utils::packageDescription("Matrix")$Built
  version <- utils::packageDescription("Matrix")$Version
  if (file.exists(stamp()) && identical(readLines(stamp()), built())) {
    message(sprintf("Matrix %s already built from source", version))
    return(invisible())
  }
  message(sprintf(paste("building Matrix %s from CRAN's source",
                        "(conda-forge's Windows build can crash on load)"), version))
  was <- built()
  # remotes returns NA, not an error, when the download fails.
  installed <- remotes::install_version("Matrix", version, repos = "https://cloud.r-project.org",
                                        dependencies = FALSE, upgrade = "never", quiet = FALSE)
  if (!identical(unname(installed), "Matrix") || identical(built(), was) ||
        !identical(utils::packageDescription("Matrix")$Version, version)) {
    stop(sprintf("Matrix %s did not build from CRAN's source", version), call. = FALSE)
  }
  writeLines(built(), stamp())
}

rebuild_matrix_on_windows()
install_pinned("pedigreegraph")
install_pinned("epimight")

# The kit's commit and `git describe`, which run.yaml records: from the image build
# (container/build.sh sets both variables), else from git when this folder is the top of
# its own checkout, so an enclosing repository is never read. `-dirty` marks changed or
# untracked files under kit/. NULL when neither knows.
source_stamp <- function() {
  env <- Sys.getenv(c("KIT_COMMIT", "KIT_VERSION"))
  if (all(nzchar(env))) {
    return(unname(env))
  }
  git <- function(...) {
    tryCatch(system2("git", c(...), stdout = TRUE, stderr = FALSE),
             error = function(e) NULL, warning = function(w) NULL)
  }
  if (!identical(git("rev-parse", "--show-prefix"), "")) {
    return(NULL)
  }
  commit <- git("rev-parse", "HEAD")
  version <- git("describe", "--tags", "--always")
  if (length(commit) != 1 || length(version) != 1) {
    return(NULL)
  }
  dirty <- length(git("status", "--porcelain", "--", "kit")) > 0
  c(commit, paste0(version, if (dirty) "-dirty"))
}

message("installing nordicepimight")
stamp <- source_stamp()
stamped <- file.path(tempfile(), "nordicepimight")
dir.create(dirname(stamped))
file.copy("kit/nordicepimight", dirname(stamped), recursive = TRUE)
if (!is.null(stamp)) {
  cat(sprintf("RemoteSha: %s\nRemoteRef: %s\n", stamp[1], stamp[2]),
      file = file.path(stamped, "DESCRIPTION"), append = TRUE)
}
install.packages(stamped, repos = NULL, type = "source", quiet = TRUE)

library(nordicepimight)
problems <- pin_mismatches()
if (length(problems) > 0) stop(paste(problems, collapse = "\n"), call. = FALSE)
if (!("run_h2_pooled" %in% names(epimight::Pipeline$public_methods))) {
  stop("the installed epimight has no Pipeline$run_h2_pooled", call. = FALSE)
}
versions <- vapply(pinned, `[[`, "", "version")
message("setup done: ", paste(names(pinned), versions, collapse = ", "))

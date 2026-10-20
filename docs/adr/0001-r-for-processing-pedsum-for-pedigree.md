# R does the data processing; pedsum checks the pedigree

Status: accepted (2026-10-14)

## Context

The first version of the kit was Python (pixi) around one R script that called EPIMIGHT
inside its image. The collaborators who run it know R, not Python, and need to read and
adapt what processes their register data.

## Decision

Everything except the pedigree runs in R: checking the trait files, building EPIMIGHT's
cohort table, running EPIMIGHT, formatting its output, and summarizing and plotting the results.
The pedigree is built and checked by pedsum, unchanged, in Python.

## Consequences

- Building the cohort table (EPIMIGHT's pool) moves to R. It was the collaborator's job before (runner design I2),
  and the Python recount that checked it goes away.
- The kit still needs Python for pedsum; pixi installs it next to R (ADR 0002).
- The R side uses the packages EPIMIGHT already brings (`data.table`, `yaml`,
  `ggplot2`, `pedigreegraph`, among others in EPIMIGHT's `default.nix`), plus jsonlite,
  rmarkdown and pandoc for the run record and the HTML report, and testthat and lintr for
  the kit's own tests.

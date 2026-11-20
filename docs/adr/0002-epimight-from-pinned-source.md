# EPIMIGHT is built from a pinned commit of its sandwich branch

Status: accepted (2026-10-14). ADR 0006 adds an Apptainer image built from this install.

Amended 2026-11-17: "Step 0" below is `pixi run setup`. The kit now calls it setup and
uses step 0 for the site's data preparation (`docs/step-0.md`). Setup also installs the
kit's own package, `nordicepimight`.

Amended 2026-11-20: the pin moved from BioPsyk/epimight's `sandwich` branch to the fork
branch `rwaples/epimight@epimight-wcinc` (`bb8263d`), which descends from the old pin
`55803e1`. It computes every CIF with one weighted cumulative incidence (cmprsk's
estimator and variance, also for the weighted curves), reads h² and rg at the end of
follow-up, drops h² at or below 1e-10, and stops `run_cif` on a curve with no case. The
kit's self-test reference comes from the Python port that matches this branch. The pin
returns to a BioPsyk commit once BioPsyk merges these changes.

## Context

The first version ran EPIMIGHT in BioPsyk's Docker image, pinned by digest. That image
predates `run_h2_pooled`, so pooled h² came out empty. BioPsyk republishes the
`2.2.0-sandwich` tag whenever the branch is published, so the tag alone does not say what
ran. Register servers often have no Docker.

## Decision

Step 0 of the kit downloads and builds the software it needs. It builds EPIMIGHT from one
pinned commit of the `sandwich` branch of BioPsyk/epimight, and the pedigreegraph R
package from one pinned pedigree-graph tag. The Docker and Apptainer runtimes are
dropped.

## Consequences

- The first install needs internet access and a Rust toolchain, because pedigreegraph
  compiles Rust.
- Moving to a newer EPIMIGHT means changing the pin and rerunning the self-test.
- pixi provides R, Rust and EPIMIGHT's CRAN dependencies from conda-forge, locked in
  `pixi.lock` next to pedsum. Step 0 (`pixi run setup`) adds only the two GitHub packages
  to that environment. Collaborators install pixi and nothing else.
- Each run records the installed EPIMIGHT commit and pedigreegraph version.

# EPIMIGHT is built from a pinned commit of its sandwich branch

Status: accepted (2026-10-14)

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

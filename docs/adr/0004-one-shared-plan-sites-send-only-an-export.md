# One shared plan; each site sends only an export folder

Status: accepted, preliminary (2026-10-14)

## Context

Collaborators in several Nordic countries run the same analyses on their own registers.
The first design had one `study.yaml` per study, mixing the analysis choices with the
paths to one site's data, so nothing kept two countries' analyses the same. Nothing
marked which outputs could leave a register server either, although the cohort table and
the check step's files hold individual-level data, and the result tables hold counts.

## Decision

The repository's `plan/` (settings, `traits.tsv`, `analyses.tsv`, optional
`relative_windows.tsv`) is the same at every site. Each site writes a file in `local/`
(not committed) with its name, the plan, its data folder, `study_end` and threads.
`run.yaml` records the plan's checksum.

A sixth step, `export`, writes `OUT/6_export/`, the only folder a site sends on: the
result tables, `run.yaml` without paths, and a report built from them. Counts from 1 to 5
are suppressed (the threshold of `R/Summarise_incidence.R`); when one of a stratum's
cases, competing events or censorings is suppressed, the other two are too, and CIF rows
whose cumulative cases are 1 to 5 are dropped.

## Consequences

- Sites run the same analyses by construction; a plan change is a commit every site pulls.
- Trait files are named by the plan and found in each site's data folder.
- The suppression is preliminary: it does not cover differences between neighbouring
  cells, such as a single case between two ages of a CIF curve, or differences between
  analyses that share probands.

# nordic-geno-epimight

A kit of R scripts that runs the same [EPIMIGHT](https://github.com/BioPsyk/epimight)
analyses on the registers of Denmark, Norway and Sweden. Each country runs it on its own
server and gets birth-year-stratified estimates of the cumulative incidence (CIF),
heritability (h²) and genetic correlation (rg) of 19 psychiatric and cardiometabolic
traits.

Current status: **preliminary**.

## What you do at your site

1. **Prepare your data** in the kit's formats: one pedigree file and one file per trait
   (19 for the initial plan). [docs/step-0.md](docs/step-0.md) gives the formats and the
   rules from the statistical analysis plan (SAP).
2. **Install the kit and run it**, by one of two routes:
   - a server with internet access: [docs/run-with-pixi.md](docs/run-with-pixi.md); on
     64-bit Windows, [docs/windows.md](docs/windows.md) first;
   - a server without internet access, such as TSD:
     [docs/run-with-image.md](docs/run-with-image.md). The Apptainer image is not released
     yet.
3. **Send the folder `out/6_export/`**, and nothing else. It holds the results with small
   counts suppressed. Everything else the kit writes holds individual-level data or
   unsuppressed counts and stays on your server. [docs/outputs.md](docs/outputs.md) describes every output and what to
   review before sending.

The kit's own work is six steps, which `study` runs in order:

| # | Step | What it does |
|---|---|---|
| 1 | `check` | Checks every input and lists each problem in `findings.tsv` |
| 2 | `cohort` | Applies the trait rules and counts each person's relatives, writing EPIMIGHT's input |
| 3 | `epimight` | Runs EPIMIGHT for the plan's analyses: about three calls per analysis, plus one per trait |
| 4 | `tables` | Collects EPIMIGHT's output into the result tables |
| 5 | `report` | Writes one HTML page with every result and plot |
| 6 | `export` | Writes the folder to share, with small counts suppressed |

Your data preparation is "step 0": the kit has no command for it.

## How the repository is organised

- `plan/`: the shared analysis plan, the same in every country: the traits, the analyses
  and their settings ([plan/README.md](plan/README.md)). Sites don't edit it.
- `local/`: each site's own site file, which says where its data are. Only
  `example.yaml` is committed.
- `docs/`:
  - [step-0.md](docs/step-0.md): preparing your data, and the input formats
  - [run-with-pixi.md](docs/run-with-pixi.md), [run-with-image.md](docs/run-with-image.md): installing and running
  - [outputs.md](docs/outputs.md): the outputs, the folder to share, and what to do when a run stops
  - [glossary.md](docs/glossary.md): the terms used here (proband, stratum, sandwich SE, ...)
  - [open-questions.md](docs/open-questions.md): questions for the collaborators
  - `SAP_Scandinavian_Genealogy.md` (and its source docx): the statistical analysis plan,
    version 8; [SAP_kit_gaps.md](docs/SAP_kit_gaps.md): where the kit falls short of it
  - `adr/`: the kit's design decisions
- `Definitions/`: the trait definitions and ICD codes (`Phenotype_list.tsv`).
- `R/`: the collaborators' scripts.
- `kit/`: the kit's R package (`nordicepimight/`), its setup script, and the self-test's
  toy site, the rule-coverage site (`selftest/cohort_cases/`), expected results and the
  scripts that build them ([kit/selftest/README.md](kit/selftest/README.md)).
  `pixi run test` tests the package; `pixi run lint` lints it, `kit/setup.R` and the build
  scripts.
- `container/`: the kit's command in both images (`nordicepimight`), and the recipe and
  build script of the Apptainer image (ADR 0006). `container/docker/` is the Docker
  image's folder in BioPsyk/imagelib's layout; `.github/workflows/docker.yml` builds it
  from a commit and runs the self-test in it.
  `.github/workflows/container.yml` builds it, runs the self-test and, on a `v*` tag,
  attaches it to the release and pushes it to ghcr.io. To build it yourself, on Linux with
  Apptainer and internet access: `container/build.sh`, or without Apptainer,
  `pixi exec --spec apptainer=1.5.4 container/build.sh`. The build runs the unit tests and
  the self-test inside the image and deletes an image that fails them.

# One Apptainer image carries the kit to servers without internet access

Status: accepted, preliminary (2026-11-09)

## Context

ADR 0002 dropped the Docker and Apptainer runtimes. The kit installs with pixi, and
`pixi install` and `pixi run setup` both download: conda packages, pedsum, and the
sources of EPIMIGHT and pedigreegraph. Register servers such as TSD in Norway and Bianca
in Sweden have no internet access, so the kit can't be installed there. TSD's own guide
says to build an image outside and import the file.

## Decision

Each kit release also ships as one Apptainer image, a `.sif` file with a `.sha256` next
to it. A site imports the file like any other and runs the kit with `apptainer run`.

- `container/nordicepimight.def` is the only recipe. It runs the README's install
  (`pixi install --locked`, `pixi run setup`) inside the image, so the image holds the
  environment of `pixi.lock` and the R packages of `pins.yaml`, as ADR 0002 decided. The
  base image is pinned by digest.
- The image holds the repository at `/opt/kit`, the shared plan included. A site file
  names `/opt/kit/plan/initial.yaml`, so the image fixes which plan ran.
- The build runs the unit tests. `container/build.sh` then runs the self-test in the
  finished image as an ordinary user and deletes an image that fails it.
- `setup` writes the kit's `git describe` and commit into the installed package, and
  `run.yaml` records them under `kit`. A step stops when its kit is not the one `check`
  ran with, so an export names the one image, or checkout, that made it.
- `container/build.sh` builds it, on a laptop or in the `container` GitHub workflow. The
  workflow runs on each `v*` tag, attaches the image to the GitHub release and pushes it
  to `ghcr.io/rwaples/nordic-geno-epimight`.
- There is no Docker image. Docker needs root, which register servers don't give. A
  second recipe would be worth keeping only if a site asks for one.

## Consequences

- The pixi install stays, for servers with internet access and for development. Both
  routes run the same lock file and pins.
- The image keeps the Rust and C toolchains that `setup` needs, so it is about 1 GB, larger than
  it must be. Removing them would make the image differ from the locked environment.
- A server needs Apptainer or Singularity and Linux. A Windows remote desktop, such as
  Statistics Sweden's MONA, can run neither route.
- A plan change means a new image, where the pixi route needs only `git pull`.

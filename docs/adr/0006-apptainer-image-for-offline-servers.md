# One Apptainer image carries the kit to servers without internet access

Status: accepted, preliminary (2026-11-09); amended 2026-11-18 (a Docker image)

## Context

ADR 0002 dropped the Docker and Apptainer runtimes. The kit installs with pixi, and
`pixi install` and `pixi run setup` both download: conda packages, pedsum, and the
sources of EPIMIGHT and pedigreegraph. Register servers such as TSD in Norway and Bianca
in Sweden have no internet access, so the kit can't be installed there. TSD's own guide
says to build an image outside and import the file.

## Decision

Each kit release also ships as one Apptainer image, a `.sif` file with a `.sha256` next
to it. A site imports the file like any other and runs the kit with `apptainer run`.

- `container/nordicepimight.def` is the Apptainer recipe. It runs the README's install
  (`pixi install --locked`, `pixi run setup`) inside the image, so the image holds the
  environment of `pixi.lock` and the R packages of `pins.yaml`, as ADR 0002 decided. The
  base image is pinned by digest.
- The image holds the repository at `/opt/kit`, the shared plan included. The template
  site file names `/opt/kit/plan/initial.yaml`, and `run.yaml`'s plan checksum records
  which plan ran.
- The build runs the unit tests. `container/build.sh` then runs the self-test in the
  finished image as an ordinary user and deletes an image that fails it.
- `setup` writes the kit's `git describe` and commit into the installed package, and
  `run.yaml` records them under `kit`. A step stops when its kit is not the one `check`
  ran with, so an export names the one image, or checkout, that made it.
- `container/build.sh` builds it, on a laptop or in the `container` GitHub workflow. The
  workflow runs on each `v*` tag, attaches the image to the GitHub release and pushes it
  to `ghcr.io/rwaples/nordic-geno-epimight`.
- Amended 2026-11-18: the kit also ships as a Docker image, `biopsyk/nordic-geno-epimight`
  on Docker Hub, so it can join BioPsyk's image library, BioPsyk/imagelib.
  `container/docker/` holds its Dockerfile, README and image `VERSION` in imagelib's
  layout, and imagelib keeps a copy as `images/nordic-geno-epimight/` and publishes it.
  The Dockerfile clones a release tag (`NGE_REF`) and runs the same install and unit
  tests as the Apptainer recipe. The `docker` workflow builds it from each commit it
  runs on and runs the self-test in it; it pushes nothing. Register servers still get
  the `.sif`: Docker needs root, which they don't give, though Singularity can pull the
  Docker image where a server reaches Docker Hub.
- Both images run one command, `container/nordicepimight` (`study`, the steps,
  `selftest`, `template`, `pedsum`, `help`): the Apptainer runscript runs it and the
  Docker image puts it on PATH. The command also sets the kit's environment, R's
  isolation from the host included, so one copy serves both images and the Docker image
  pulled into Singularity. Each image writes `/opt/kit/IMAGE_VERSION`, which tells the
  kit it runs in an image, and sets `KIT_COMMAND` to what its users type before a
  command, which the kit's messages name. The kit tells Apptainer from Docker at run
  time to say whether a folder needs `--bind` or `-v`.

## Consequences

- The pixi install stays, for servers with internet access and for development. Both
  routes run the same lock file and pins.
- The image keeps the Rust and C toolchains that `setup` needs, so it is about 1 GB, larger than
  it must be. Removing them would make the image differ from the locked environment.
- A server needs Apptainer or Singularity and Linux. A Windows remote desktop, such as
  Statistics Sweden's MONA, can run neither route.
- A plan change means a new image, where the pixi route needs only `git pull`.
- Two recipes run the same install and must change together. The copy in imagelib
  follows `container/docker/` by hand, at each release.
- The Docker image is amd64 only, as `pixi.lock` covers linux-64. It uses imagelib's
  `FROM --platform=linux/amd64`, as imagelib's regenie image does.

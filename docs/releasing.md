# Releasing the kit

A release is a `vX.Y.Z` tag. The tag builds the Apptainer image onto a GitHub release and
the Docker image in CI. BioPsyk/imagelib then publishes the Docker image to Docker Hub
from its copy of `container/docker/` (ADR 0006). This page is for the kit's maintainers.

## 1. Prepare the release commit

Change the version in each of these places:

- `kit/nordicepimight/DESCRIPTION`: `Version: X.Y.Z`.
- `container/docker/Dockerfile`: `ARG NGE_REF=vX.Y.Z`. The `docker` workflow fails a tag
  whose default `NGE_REF` is not that tag.
- `container/docker/README.md`: the default `NGE_REF` under Version Information, and the
  `--build-arg NGE_REF=` example under Building the Image.
- `container/docker/VERSION`, the Docker image's own version, in imagelib's scheme: raise
  it for every image that imagelib will publish, the minor for a new kit release. The
  same version appears in `container/docker/README.md` (Internal image version, and the
  `biopsyk/nordic-geno-epimight:` and `nordic-geno-epimight_*.sif` examples).

Run `pixi run test` and `pixi run lint`, and commit.

## 2. Tag and push

```bash
git tag -a vX.Y.Z -m "nordic-geno-epimight X.Y.Z"
git push origin main vX.Y.Z
```

The tag starts two workflows:

- `container` builds the `.sif`, runs the unit tests and the self-test in it, creates the
  GitHub release, attaches `nordic-geno-epimight-vX.Y.Z.sif` and its `.sha256`, and
  pushes the image to `ghcr.io/rwaples/nordic-geno-epimight:vX.Y.Z`.
- `docker` checks the default `NGE_REF`, builds the Docker image from the tag, and runs
  it as a collaborator would. It pushes nothing.

Both pass the run's token to the build, because the GitHub API refuses more than 60
anonymous requests an hour from a runner's shared address.

Check that both runs passed and that the release lists the `.sif` and its `.sha256`:

```bash
gh run list -R rwaples/nordic-geno-epimight -L 4
gh release view vX.Y.Z -R rwaples/nordic-geno-epimight
```

Never move or delete a pushed tag. If a release run fails, fix the cause and release the
next patch version: v0.1.0's runs failed this way, so v0.1.1 is the first release with
images.

## 3. Publish the Docker image through imagelib

We can only read BioPsyk/imagelib, so the copy goes in through a pull request from a fork
(rwaples/imagelib). Its maintainer merges it and runs
`./scripts/build-and-push.sh nordic-geno-epimight`, which pushes
`biopsyk/nordic-geno-epimight:<VERSION>` and `:latest` to Docker Hub.

In a clone of BioPsyk/imagelib with the fork as the remote `fork`:

```bash
git switch main && git pull
git switch -c nordic-geno-epimight-vX.Y.Z
cp /path/to/nordic-geno-epimight/container/docker/{Dockerfile,README.md,VERSION} \
   images/nordic-geno-epimight/
```

- Keep `images/nordic-geno-epimight/PLATFORMS` (`linux/amd64`). It exists only in
  imagelib: `build-and-push.sh` builds for amd64 and arm64 unless an image's
  `PLATFORMS` file names its own, and this image is amd64 only.
- Copy the three files; don't replace the folder, or `PLATFORMS` is lost.
- After the copy, `diff -r images/nordic-geno-epimight /path/to/nordic-geno-epimight/container/docker`
  should report only `PLATFORMS`.
- In imagelib's `README.md`, update the nordic-geno-epimight row of the Available Images
  table (Software Version: the kit version; Image Version: `VERSION`) and the image
  version in its `singularity pull` example.

Build it once from the copy, which takes the default `NGE_REF`, so the copy builds the
release:

```bash
docker build -t biopsyk/nordic-geno-epimight:test images/nordic-geno-epimight
docker run --rm biopsyk/nordic-geno-epimight:test cat /etc/nordic-geno-epimight-version
```

The first line it prints should name `vX.Y.Z`. If the build stops downloading EPIMIGHT
or pedigreegraph from the GitHub API, give it a token:
`GITHUB_PAT=$(gh auth token) docker build --secret id=github_pat,env=GITHUB_PAT ...`.

Commit in imagelib's style (a sentence ending with a period), push the branch to the
fork, and open the pull request against BioPsyk/imagelib's `main`:

```bash
git commit -m "Rebuild nordic-geno-epimight from vX.Y.Z and bump the image to <VERSION>." \
  -- README.md images/nordic-geno-epimight
git push -u fork nordic-geno-epimight-vX.Y.Z
gh pr create -R BioPsyk/imagelib --base main --head rwaples:nordic-geno-epimight-vX.Y.Z
```

In the pull request, name the kit release and link its passing `docker` run.

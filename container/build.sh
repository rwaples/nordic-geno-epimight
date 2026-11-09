#!/usr/bin/env bash
# container/build.sh [OUT.sif]
#
# Builds the kit's Apptainer image and its .sha256 from this checkout: every file git
# tracks or would track, as it is in the working tree. The build runs the unit tests. The
# self-test then runs in the finished image, and an image that fails it is deleted.
#
# Needs apptainer, internet access and about 10 GB of free disk; takes about 3 minutes.
# Without apptainer:
#   pixi exec --spec apptainer=1.5.4 container/build.sh
# If the build stops on newuidmap or on libfakeroot.so, set APPTAINER_IGNORE_SUBUID=1 and
# APPTAINER_IGNORE_FAKEROOT_COMMAND=1.
set -euo pipefail

repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
commit=$(git -C "$repo" rev-parse HEAD)
version=$(git -C "$repo" describe --tags --always)
# Untracked files go into the image too, and `git describe --dirty` doesn't count them.
[ -z "$(git -C "$repo" status --porcelain)" ] || version+=-dirty
out=$(realpath -m -- "${1:-nordic-geno-epimight-$version.sif}")

work=$(mktemp -d "${APPTAINER_TMPDIR:-${TMPDIR:-/tmp}}/kit-image.XXXXXX")
trap 'rm -rf "$work"' EXIT
# The image's files take their modes from here, and other users must be able to read them.
umask 022
mkdir "$work/src"
cd "$repo"
git ls-files -z --cached --others --exclude-standard |
    while IFS= read -r -d '' file; do
        # A tracked file deleted from the working tree is still listed.
        if [ -e "$file" ] || [ -L "$file" ]; then printf '%s\0' "$file"; fi
    done |
    tar --null --files-from=- -cf - | tar -C "$work/src" -xf -

cd "$work"
apptainer build --notest --build-arg "KIT_COMMIT=$commit" \
    --build-arg "KIT_VERSION=$version" "$out" src/container/nordicepimight.def
if ! apptainer test "$out"; then
    rm -f "$out"
    echo "the self-test failed in the built image; $out was deleted" >&2
    exit 1
fi
cd "$(dirname "$out")"
sha256sum "$(basename "$out")" | tee "$out.sha256"

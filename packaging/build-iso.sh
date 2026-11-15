#!/bin/sh
# Builds the Loaf ISO: Ubuntu's own desktop ISO plus /loaf (the loaf package and the packages it needs that
# Ubuntu does not install, so installing works offline) and /autoinstall.yaml (Ubuntu's installer asks all
# its usual questions, then installs Loaf and starts the new account on it). Ubuntu's boot setup is kept as is.
# Runs in Docker, no sudo. Needs the Ubuntu ISO in iso/ (checked against Ubuntu's signed SHA256SUMS).
#   packaging/build-iso.sh            -> iso/loaf-<ubuntu version>-amd64.iso
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
iso=$here/iso
ubuntu=ubuntu-26.04.1-desktop-amd64.iso
version=26.04.1
cd "$iso"
grep " \*$ubuntu\$" SHA256SUMS | sha256sum -c --quiet - || { echo "$ubuntu missing or not Ubuntu's"; exit 1; }

# tools, and Ubuntu's installed system (the base layer the installer copies) to resolve Loaf's packages against
docker image inspect loaf-isotools >/dev/null 2>&1 || docker build -q -t loaf-isotools - <<'EOF'
FROM ubuntu:26.04
RUN apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq xorriso squashfs-tools >/dev/null && rm -rf /var/lib/apt/lists/*
EOF
docker image inspect loaf-isobase:$version >/dev/null 2>&1 || docker run --rm -v "$iso":/iso loaf-isotools sh -c "
    xorriso -osirrox on -indev /iso/$ubuntu -extract /casper/minimal.squashfs /tmp/m.sqfs >/dev/null 2>&1 &&
    unsquashfs -q -d /tmp/root /tmp/m.sqfs >/dev/null && rm /tmp/m.sqfs && tar -C /tmp/root -cf - ." |
    docker import - loaf-isobase:$version >/dev/null

# the loaf package, then everything apt would fetch to install it on a fresh Ubuntu
ls "$here"/packaging/out/loaf_*.deb >/dev/null 2>&1 || "$here/packaging/build-deb.sh"
deb=$(ls -t "$here"/packaging/out/loaf_*.deb | head -1)
rm -rf "$iso/loaf" && mkdir -p "$iso/loaf"
docker run --rm -v "$deb":/loaf.deb:ro -v "$iso/loaf":/pool loaf-isobase:$version sh -c '
    export DEBIAN_FRONTEND=noninteractive
    rm -f /etc/apt/sources.list.d/cdrom.sources  # the install disc, not there when resolving
    apt-get update -qq && apt-get install -y -qq --download-only -o Dir::Cache::archives=/pool /loaf.deb >/dev/null &&
    rm -rf /pool/partial /pool/lock && cp /loaf.deb /pool/ && chown -R '"$(id -u):$(id -g)"' /pool'
echo "bundled: $(ls "$iso/loaf" | wc -l) packages, $(du -sh "$iso/loaf" | cut -f1)"

# Ubuntu's ISO with the two additions; "replay" keeps its boot records (BIOS, UEFI, Secure Boot) byte for byte
out=loaf-$version-amd64.iso
rm -f "$out"
docker run --rm -v "$iso":/iso -v "$here/packaging/iso/autoinstall.yaml":/autoinstall.yaml:ro loaf-isotools \
    xorriso -indev /iso/$ubuntu -outdev /iso/$out -map /iso/loaf /loaf -map /autoinstall.yaml /autoinstall.yaml \
    -boot_image any replay 2>&1 | grep -iE 'error|failure|sorry' || true
docker run --rm -v "$iso":/iso loaf-isotools chown "$(id -u):$(id -g)" /iso/$out
sha256sum "$out" > "$out.sha256"
echo "$iso/$out ($(du -h "$out" | cut -f1))"

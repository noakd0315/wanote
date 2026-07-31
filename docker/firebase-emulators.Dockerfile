# Firebase Local Emulator Suite, containerized so the whole local dev stack
# comes up with `docker compose up` and no real Firebase/GCP account (see
# ../firebase.json / ../.firebaserc, which pin the fake "demo-wanote" project
# id -- Firebase treats any "demo-*" project id as a local-only fake project
# that never talks to real GCP infrastructure).
#
# Built from a plain Node base and firebase-tools installed here (pinned
# version) rather than pulled from an unpinned third-party "firebase
# emulator" image on Docker Hub, so this is fully reproducible from source.
FROM node:20-bullseye-slim

# The Firestore and Storage emulators are Java processes under the hood
# (firebase-tools downloads and runs .jar files for them), so a JRE is
# required in addition to Node. curl is used only for the container
# healthcheck in docker-compose.yml.
RUN apt-get update \
    && apt-get install -y --no-install-recommends default-jre-headless curl \
    && rm -rf /var/lib/apt/lists/*

# Pinned for reproducibility -- bump deliberately, not implicitly via `latest`.
RUN npm install -g firebase-tools@13.29.1

WORKDIR /workspace

# Pre-download the emulator jars/binaries at build time so `docker compose
# up` doesn't need network access on every container start.
RUN firebase setup:emulators:firestore \
    && firebase setup:emulators:ui

# firebase.json / .firebaserc / firestore.rules / storage.rules are bind-mounted
# read-only at runtime by docker-compose.yml, not copied in at build time, so
# editing them on the host doesn't require an image rebuild.

EXPOSE 9099 8080 9199 4000

CMD ["firebase", "emulators:start", "--project=demo-wanote"]

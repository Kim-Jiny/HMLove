#!/bin/sh
set -e

run_app() {
  echo "Syncing database schema..."
  npx prisma db push

  echo "Starting server..."
  exec node src/index.js
}

# When the Firebase service account is mounted as a root-only file (e.g. 600),
# copy it to an appuser-readable temp path before dropping privileges.
if [ "$(id -u)" = "0" ]; then
  if [ -n "$FIREBASE_SERVICE_ACCOUNT" ] && [ -f "$FIREBASE_SERVICE_ACCOUNT" ]; then
    FIREBASE_COPY="/tmp/firebase-service-account.json"
    cp "$FIREBASE_SERVICE_ACCOUNT" "$FIREBASE_COPY"
    chown appuser:appgroup "$FIREBASE_COPY"
    chmod 600 "$FIREBASE_COPY"
    export FIREBASE_SERVICE_ACCOUNT="$FIREBASE_COPY"
  fi

  exec su appuser -s /bin/sh -c '
    set -e
    echo "Syncing database schema..."
    npx prisma db push

    echo "Starting server..."
    exec node src/index.js
  '
fi

run_app

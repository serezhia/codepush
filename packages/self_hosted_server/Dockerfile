# Stage 1 — Build the Dart Frog server
FROM dart:stable AS build

# Install dart_frog_cli
RUN dart pub global activate dart_frog_cli

WORKDIR /app

# Copy only the workspace packages we need
COPY packages/self_hosted_server /app/packages/self_hosted_server
COPY packages/shorebird_code_push_protocol /app/packages/shorebird_code_push_protocol
COPY packages/jwt /app/packages/jwt

# Create a minimal root pubspec with only the packages present in the image.
# The real workspace pubspec references all packages, but we only copy three.
RUN printf 'name: _\npublish_to: none\nenvironment:\n  sdk: ^3.9.0\nworkspace:\n  - packages/jwt\n  - packages/shorebird_code_push_protocol\n  - packages/self_hosted_server\n' > /app/pubspec.yaml

WORKDIR /app/packages/self_hosted_server

RUN dart pub get
RUN dart pub global run dart_frog_cli:dart_frog build

# Compile the generated Dart Frog server to a native executable
WORKDIR /app/packages/self_hosted_server/build
RUN dart compile exe bin/server.dart -o bin/server

# Stage 2 — Minimal runtime
FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /app/packages/self_hosted_server/build/bin/server /app/bin/server
COPY --from=build /app/packages/self_hosted_server/db /app/db

EXPOSE 8080

CMD ["/app/bin/server"]

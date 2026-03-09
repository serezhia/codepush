# Stage 1 — Build Flutter web
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy only the workspace packages we need
COPY packages/shorebird_console /app/packages/shorebird_console
COPY packages/shorebird_code_push_protocol /app/packages/shorebird_code_push_protocol

# Create a minimal root pubspec with only the packages present in the image.
RUN printf 'name: _\npublish_to: none\nenvironment:\n  sdk: ^3.9.0\nworkspace:\n  - packages/shorebird_code_push_protocol\n  - packages/shorebird_console\n' > /app/pubspec.yaml

WORKDIR /app/packages/shorebird_console

RUN flutter pub get
RUN flutter build web --release \
    --dart-define=API_BASE_URL=

# Stage 2 — Serve with nginx + reverse proxy API to server
FROM nginx:alpine

COPY --from=build \
    /app/packages/shorebird_console/build/web \
    /usr/share/nginx/html

COPY packages/shorebird_console/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

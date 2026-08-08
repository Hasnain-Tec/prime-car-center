FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY frontend/pubspec.yaml frontend/analysis_options.yaml ./
RUN flutter pub get
COPY frontend/ .
RUN flutter create . --platforms=web --project-name prime_car_center
ARG API_BASE_URL=/api
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:1.27-alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80

FROM nginx:stable-alpine
ARG APP_VERSION=dev
ARG VCS_REF=local
LABEL org.opencontainers.image.title="DevOps Diploma nginx" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}"
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY html/ /usr/share/nginx/html/
RUN printf '%s\n' "$APP_VERSION" > /usr/share/nginx/html/version.txt
EXPOSE 80
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1/healthz || exit 1

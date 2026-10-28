FROM nickfedor/shoutrrr:0.22.1 AS shoutrrr

FROM alpine:3.24

RUN apk add --no-cache \
    bash \
    git \
    ca-certificates

COPY --from=shoutrrr /shoutrrr /usr/local/bin/shoutrrr

ENV APP_ROOT=/opt/git-sync-mirror
ENV PATH="${APP_ROOT}/bin:${PATH}"
ENV HOME=${APP_ROOT}

COPY bin/ ${APP_ROOT}/bin/

RUN set -eux; \
    chmod -R u+x "${APP_ROOT}/bin"; \
    mkdir -p "${APP_ROOT}"; \
    chgrp -R 0 "${APP_ROOT}"; \
    chmod -R g=u "${APP_ROOT}" /etc/passwd

USER 1000080001:0

WORKDIR ${APP_ROOT}

ENTRYPOINT ["git-sync-mirror.sh"]

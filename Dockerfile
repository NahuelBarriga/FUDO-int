ARG RUBY_VERSION=4.0.7

# ---------- Etapa base: lo común a las otras dos ----------
FROM ruby:${RUBY_VERSION}-slim AS base

WORKDIR /app

ENV RACK_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test

# ---------- Etapa build: compila las gems ----------
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libpq-dev && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache

COPY . .

# ---------- Etapa final: solo lo necesario para correr ----------
FROM base

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libpq5 && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd --system app && \
    useradd --system --gid app --create-home app

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build --chown=app:app /app /app

USER app

EXPOSE 9292

CMD ["bundle", "exec", "puma"]

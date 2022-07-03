# == Engine ==================================================================
FROM node:latest AS build
RUN apt-get update -y && apt-get install -y \
    git tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
ENV TZ=Asia/Tokyo
WORKDIR /

# -- Installations -----------------------------------------------------------
ADD https://api.github.com/repos/sevenc-nanashi/sonolus-pjsekai-engine-extended/git/refs/heads/master dummy.json
RUN git clone https://github.com/sevenc-nanashi/sonolus-pjsekai-engine-extended.git engine

# -- Compile -----------------------------------------------------------------
RUN cd engine && npm install && npm run build

# == Server ==================================================================
FROM ruby:3.1
RUN apt-get update -y && apt-get install -y \
    ffmpeg
WORKDIR /root

# -- Installations -----------------------------------------------------------
COPY Gemfile .
COPY Gemfile.lock .
RUN bundle config with production; \
    bundle install

# -- Startup -----------------------------------------------------------------
COPY --from=build /engine/dist/EngineData engine/dist/EngineData
COPY --from=build /engine/dist/EngineConfiguration engine/dist/EngineConfiguration
COPY . .
ENV PORT=3000
ENV RUBYOPTS=--jit
CMD ["/bin/sh", "-c", "bundle exec puma -p $PORT"]

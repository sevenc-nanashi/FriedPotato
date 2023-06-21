# == Engine ==================================================================
FROM node:latest AS build
RUN apt-get update -y && apt-get install -y \
    git tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
ENV TZ=Asia/Tokyo
WORKDIR /

# -- Installations -----------------------------------------------------------
ADD http://www.random.org/strings/?num=10&len=8&digits=on&upperalpha=on&loweralpha=on&unique=on&format=plain&rnd=new uuid
RUN git clone https://github.com/sevenc-nanashi/sonolus-pjsekai-engine-extended.git engine

# -- Compile -----------------------------------------------------------------
RUN cd engine && git checkout cc5ab1d && npm install && npm run build

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
ENV RUBYOPTS=--jit
ENV RACK_ENV=production
EXPOSE 4567
CMD ["/bin/sh", "-c", "bundle exec falcon host"]

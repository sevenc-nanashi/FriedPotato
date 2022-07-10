#!/usr/bin/env -S falcon host
# frozen_string_literal: true

load :rack

rack "0.0.0.0" do
  scheme "http"
  protocol { Async::HTTP::Protocol::HTTP1 }
  endpoint { Async::HTTP::Endpoint.for(scheme, "0.0.0.0", port: ENV["PORT"] || "4567", protocol: protocol) }
end

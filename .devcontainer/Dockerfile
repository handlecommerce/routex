FROM elixir:1.14

RUN apt-get update
RUN mix local.rebar --force \
  && mix local.hex --force

WORKDIR /workspaces/routex

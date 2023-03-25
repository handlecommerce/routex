defmodule Routex.ParserTest do
  use ExUnit.Case, async: true

  alias Routex.Parser

  test "parse simple route" do
    assert {:ok, [], "", _, _, _} = Parser.route("/")
    assert {:ok, [segment: "hello"], "", _, _, _} = Parser.route("/hello")
    assert {:ok, [segment: "hello", segment: "world"], "", _, _, _} = Parser.route("/hello/world")
  end

  test "parse route with parameter" do
    assert {:ok, [segment: "hello", parameter: [identifier: "name"], segment: "world"], "", _, _,
            _} = Parser.route("/hello/{name}/world")
  end

  test "parse route with parameter and regex" do
    assert {:ok,
            [
              segment: "hello",
              parameter: [identifier: "name", pattern: ~r/^[a-z]+/],
              segment: "world"
            ], "", _, _, _} = Parser.route("/hello/{name:^[a-z]+}/world")
  end

  test "parse route with regex that contains forward slash" do
    assert {:ok,
            [
              segment: "hello",
              parameter: [identifier: "name", pattern: ~r/^[a-z\/]+/],
              segment: "world"
            ], "", _, _, _} = Parser.route("/hello/{name:[a-z\/]+}/world")
  end

  test "parse route with regex that contains forward slash and curly braces" do
    assert {:ok,
            [
              segment: "hello",
              parameter: [identifier: "name", pattern: pattern],
              segment: "world"
            ], "", _, _, _} = Parser.route(~S"/hello/{name:[a-z\/{}]+}/world")

    assert pattern.source == "^[a-z\\/{}]+"
  end
end

defmodule Routex.RouteTest do
  use ExUnit.Case

  alias Routex.Route

  test "match/2 with basic route" do
    route = Route.build("/hello/world", :hello_world)
    assert {:ok, %{}} == Route.match(route, URI.parse("/hello/world"))
    assert :no_match == Route.match(route, URI.parse("/hello"))
    assert :no_match == Route.match(route, URI.parse("/hello/world/again"))
    assert :no_match == Route.match(route, URI.parse("/hello/world/again/and/again"))
  end

  test "match/2 with parameter route" do
    route = Route.build("/hello/{name}/world", :hello_world)
    assert {:ok, %{"name" => "joe"}} == Route.match(route, URI.parse("/hello/joe/world"))
    assert :no_match == Route.match(route, URI.parse("/hello/world"))
    assert :no_match == Route.match(route, URI.parse("/hello/joe/world/again"))
    assert :no_match == Route.match(route, URI.parse("/hello/joe/world/again/and/again"))
  end

  test "match/2 with URI params" do
    route = Route.build("/hello/{name}/world", :hello_world)

    assert {:ok, %{"name" => "joe", "foo" => "bar"}} ==
             Route.match(route, URI.parse("/hello/joe/world?foo=bar"))
  end

  test "match/2 with regex" do
    route = Route.build("/hello/{name:^[a-z]+}/world", :hello_world)
    assert {:ok, %{"name" => "joe"}} == Route.match(route, URI.parse("/hello/joe/world"))
    assert :no_match == Route.match(route, URI.parse("/hello/JOE/world"))
    assert :no_match == Route.match(route, URI.parse("/hello/123/world"))
    assert :no_match == Route.match(route, URI.parse("/hello/joe1/world"))
  end
end

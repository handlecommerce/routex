defmodule Routex.RouteTest do
  use ExUnit.Case

  alias Routex.Route

  test "build/2" do
    assert %Route{
             segments: [{:segment, "hello"}, {:segment, "world"}],
             data: :hello_world
           } == Route.build("/hello/world", :hello_world)

    assert %Route{
             segments: [{:segment, "hello"}, {:parameter, "name", nil}, {:segment, "world"}],
             data: :hello_world
           } == Route.build("/hello/{name}/world", :hello_world)

    assert %Route{
             segments: [
               {:segment, "hello"},
               {:parameter, "name", ~r/^[a-z]+$/},
               {:segment, "world"}
             ],
             data: :hello_world
           } == Route.build("/hello/{name:^[a-z]+}/world", :hello_world)

    assert %Route{
             segments: [{:segment, "hello"}, {:glob, "name"}, {:segment, "world"}],
             data: :hello_world
           } == Route.build("/hello/*name/world", :hello_world)
  end

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

  test "match/2 with glob route" do
    route = Route.build("/hello/{*name}/world", :hello_world)
    assert {:ok, %{"name" => "joe"}} == Route.match(route, URI.parse("/hello/joe/world"))

    assert {:ok, %{"name" => "joe/again"}} ==
             Route.match(route, URI.parse("/hello/joe/again/world"))

    assert {:ok, %{"name" => "joe/again/and/again"}} ==
             Route.match(route, URI.parse("/hello/joe/again/and/again/world"))

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
  end

  test "match/2 with wildcard and regex" do
    route = Route.build(~s(/hello/{*name:[a-z]+}/world), :hello_world)
    assert {:ok, %{"name" => "joe"}} == Route.match(route, URI.parse("/hello/joe/world"))

    assert {:ok, %{"name" => "joe/and/again"}} ==
             Route.match(route, URI.parse("/hello/joe/and/again/world"))

    assert :no_match == Route.match(route, URI.parse("/hello/JOE/world"))
    assert :no_match == Route.match(route, URI.parse("/hello/123/world"))
    assert :no_match == Route.match(route, URI.parse("/hello/joe/123/world"))
  end
end

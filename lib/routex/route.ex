defmodule Routex.Route do
  @moduledoc """
  A route is a path with parameters. For example, `/hello/{name}/world` is a route.
  """
  defstruct [:segments, :data]

  alias Routex.Parser

  @type segment_t ::
          {:segment, String.t()}
          | {:parameter, [identifier: String.t()]}
          | {:parameter, [identifier: String.t(), pattern: Regex.t()]}

  @type t :: %__MODULE__{
          segments: [segment_t],
          data: term
        }

  @spec build(String.t(), term) :: {:ok, t} | {:error, String.t()}
  @doc """
  Build a route from a path. Includes the data you want to associate with the route.
  """
  def build(path, data \\ nil) do
    case Parser.route(path) do
      {:ok, segments, _, _, _, _} -> {:ok, %__MODULE__{segments: segments, data: data}}
      {:error, _, _, _, _, _} -> {:error, "Invalid route"}
    end
  end

  @spec match(t(), URI.t()) :: {:ok, map} | :no_match | {:error, String.t()}
  @doc """
  Match a route to a path. Returns `:no_match` if the path does not match the route.

  If the path matches the route, returns `{:ok, params}` where `params` is a map of
  the parameters extracted from the path.
  """
  def match(%__MODULE__{segments: segments}, %URI{path: path, query: query}) do
    (query || "")
    |> URI.decode_query()
    |> match_segments(segments, path)
  end

  defp match_segments(params, [], "/"), do: {:ok, params}
  defp match_segments(_params, [], _), do: :no_match
  defp match_segments(_params, _, "/"), do: :no_match

  defp match_segments(params, [{:segment, name} | segments], "/" <> path) do
    path
    |> String.split("/", parts: 2)
    |> case do
      [^name, rest] -> match_segments(params, segments, "/" <> rest)
      [^name] -> match_segments(params, segments, "/")
      _ -> :no_match
    end
  end

  defp match_segments(params, [{:parameter, [identifier: identifier]} | segments], "/" <> path) do
    path
    |> String.split("/", parts: 2)
    |> case do
      [value, rest] -> match_segments(Map.put(params, identifier, value), segments, "/" <> rest)
      [value] -> match_segments(Map.put(params, identifier, value), segments, "/")
      _ -> :no_match
    end
  end

  # Match to /*rest
  defp match_segments(params, [{:catch_all, [identifier: identifier]} | []], "/" <> value) do
    params
    |> Map.put(identifier, value)
    |> match_segments([], "/")
  end

  defp match_segments(
         params,
         [{:parameter, [identifier: identifier, pattern: pattern]} | segments],
         "/" <> path
       ) do
    case Regex.run(pattern, path, capture: :first) do
      [value] ->
        params = Map.put(params, identifier, value)
        path = String.replace(path, value, "", global: false)
        match_segments(params, segments, path)

      _ ->
        :no_match
    end
  end

  defp match_segments(_, _, _), do: :no_match
end

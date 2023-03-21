defmodule Routex.Route do
  defstruct [:segments, :data]

  @type segment_t ::
          {:segment, String.t()}
          | {:parameter, String.t(), Regex.t() | nil}
          | {:glob, String.t(), Regex.t() | nil}

  @type t :: %__MODULE__{
          segments: [segment_t],
          data: term
        }

  @spec build(String.t(), term) :: t
  @doc """
  Build a route from a path. Includes the data you want to associate with the route.
  """
  def build(path, data \\ nil) do
    segments =
      path
      |> String.split("/")
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&parse_segment/1)

    %__MODULE__{segments: segments, data: data}
  end

  @spec match(t(), URI.t()) :: {:ok, map} | :no_match | {:error, String.t()}
  @doc """
  Match a route to a path. Returns `:no_match` if the path does not match the route.

  If the path matches the route, returns `{:ok, params}` where `params` is a map of
  the parameters extracted from the path.
  """
  def match(%__MODULE__{segments: segments}, %URI{path: path, query: query}) do
    parts =
      path
      |> String.split("/")
      |> Enum.reject(&(&1 == ""))

    params = if is_nil(query), do: %{}, else: URI.decode_query(query)

    match_segments(params, segments, parts)
  end

  defp match_segments(params, [], []), do: {:ok, params}
  defp match_segments(_params, [], _), do: :no_match
  defp match_segments(_params, _, []), do: :no_match

  defp match_segments(params, [{:segment, name} | segments], [name | parts]),
    do: match_segments(params, segments, parts)

  defp match_segments(params, [{:parameter, name, regex} | segments], [value | parts]) do
    if segment_matches?(value, regex) do
      match_segments(Map.put(params, name, value), segments, parts)
    else
      :no_match
    end
  end

  defp match_segments(params, [{:glob, name, regex} | segments], parts) do
    case List.first(segments) do
      nil ->
        {:ok, Map.put(params, name, Enum.join(parts, "/"))}

      {:segment, next_name} ->
        {globbed_parts, parts} = Enum.split_while(parts, &(&1 != next_name))

        segment = Enum.join(globbed_parts, "/")

        if segment_matches?(segment, regex) do
          match_segments(Map.put(params, name, segment), segments, parts)
        else
          :no_match
        end

      _ ->
        {:error, "Glob followed by a non-segment is not supported"}
    end
  end

  # Compare the match to the regex, allowing nil regex to match anything
  defp segment_matches?("", _regex), do: false
  defp segment_matches?(_segment, nil), do: true
  defp segment_matches?(segment, regex), do: Regex.match?(regex, segment)

  defp parse_segment("*" <> name), do: {:glob, name}

  defp parse_segment("{" <> name_and_close_brace) do
    if String.ends_with?(name_and_close_brace, "}") do
      parse_match_segment(String.slice(name_and_close_brace, 0..-2))
    else
      {:error, "Invalid route: {#{name_and_close_brace}"}
    end
  end

  defp parse_segment(name), do: {:segment, name}

  defp parse_match_segment(name) do
    type = if String.starts_with?(name, "*"), do: :glob, else: :parameter
    name = if type == :glob, do: String.slice(name, 1..-1), else: name

    case String.split(name, ":") do
      [name, regex_string] ->
        case Regex.compile(regex_string) do
          {:ok, regex} ->
            {type, name, regex}

          {:error, error} ->
            {:error, "Invalid route: {#{name}:#{regex_string} (#{error})"}
        end

      [name] ->
        {type, name, nil}

      _ ->
        {:error, "Invalid route: {#{name}"}
    end
  end
end

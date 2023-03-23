defmodule Routex.Parser do
  import NimbleParsec

  identifier =
    utf8_string([?a..?z, ?A..?Z, ?_], 1)
    |> concat(utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-], min: 0))
    |> unwrap_and_tag(:identifier)

  # :regex
  regex_pattern =
    ignore(string(":"))
    |> concat(utf8_string([not: ?}], min: 1))
    |> reduce({Enum, :join, []})
    |> post_traverse(:to_regex)
    |> unwrap_and_tag(:pattern)

  # {identifier} or
  # {identifier:regex}
  parameter_segment =
    ignore(string("{"))
    |> concat(identifier)
    |> optional(regex_pattern)
    |> ignore(string("}"))
    |> tag(:parameter)

  # / only
  empty_segment = ignore(string("/")) |> eos()

  non_parameterized_segment =
    lookahead_not(string("{"))
    |> utf8_string([not: ?/], min: 1)
    |> unwrap_and_tag(:segment)

  segment =
    ignore(string("/"))
    |> choice([parameter_segment, non_parameterized_segment])

  segment_list = times(segment, min: 1)

  defparsec(:route, choice([segment_list, empty_segment]) |> eos())

  # Convert the regex pattern string to a regex
  defp to_regex(rest, pattern, context, _line, _offset) do
    pattern = Enum.join(pattern)

    # Keep the original pattern for error message
    original_pattern = pattern

    pattern = if String.starts_with?(pattern, "^"), do: pattern, else: "^" <> pattern
    pattern = if String.ends_with?(pattern, "$"), do: pattern, else: pattern <> "$"

    case Regex.compile(pattern) do
      {:ok, regex} -> {rest, [regex], context}
      {:error, _} -> {:error, "Invalid route pattern: #{original_pattern}"}
    end
  end
end

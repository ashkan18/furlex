defmodule Furlex.Parser.Twitter do
  @behaviour Furlex.Parser

  alias Furlex.Parser


  @tags ~w(
    twitter:site twitter:description twitter:title twitter:image
  )

  @spec parse(String.t) :: {:ok, Map.t}
  def parse(html) do
    meta = &("meta[name=\"#{&1}\"]")
    map  = Parser.extract tags(), html, meta

    {:ok, map}
  end

  @doc false
  def tags do
    (config(:tags) || [])
    |> Enum.concat(@tags)
    |> Enum.uniq()
  end

  defp config(key), do: Application.get_env(:furlex, __MODULE__)[key]
end

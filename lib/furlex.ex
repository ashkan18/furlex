defmodule Furlex do
  @moduledoc """
  Furlex is a structured data extraction tool written in Elixir.

  It currently supports unfurling oEmbed, Twitter Card, Facebook Open Graph,
  JSON-LD and plain ole' HTML `<meta />` data out of any url you supply.
  """

  use Application

  alias Furlex.{Fetcher, Parser}
  alias Furlex.Parser.{JsonLD, Twitter}

  defstruct [
    :canonical_url, :oembed, :twitter, :json_ld, :status_code
  ]

  @type t :: %__MODULE__{
    canonical_url: String.t,
    oembed: nil | Map.t,
    twitter: Map.t,
    json_ld: List.t,
    status_code: Integer.t,
  }

  @doc false
  def start(_type, _args) do
    import Supervisor.Spec

    opts     = [strategy: :one_for_one, name: Furlex.Supervisor]
    children = [
      worker(Furlex.Oembed, [[name: Furlex.Oembed]]),
    ]

    Supervisor.start_link(children, opts)
  end

  @doc """
  Unfurls a url

  unfurl/1 fetches oembed data if applicable to the given url's host,
  in addition to Twitter Card, Open Graph, JSON-LD and other HTML meta tags.

  unfurl/2 also accepts a keyword list that will be passed to HTTPoison.
  """
  @spec unfurl(String.t, Keyword.t) :: {:ok, __MODULE__.t} | {:error, Atom.t}
  def unfurl(url, opts \\ []) do
    with {:ok, {body, status_code}, oembed} <- fetch(url, opts),
         {:ok, results}                     <- parse(body)
    do
      {:ok, %__MODULE__{
        canonical_url: Parser.extract_canonical(body),
        oembed: oembed,
        twitter: results.twitter,
        json_ld: results.json_ld,
        status_code: status_code,
      }}
    end
  end

  defp fetch(url, opts) do
    fetch        = Task.async Fetcher, :fetch,        [ url, opts ]
    fetch_oembed = Task.async Fetcher, :fetch_oembed, [ url, opts ]
    yield        = Task.yield_many [fetch, fetch_oembed]

    with [ fetch, fetch_oembed ]                          <- yield,
         {_fetch,        {:ok, {:ok, body, status_code}}} <- fetch,
         {_fetch_oembed, {:ok, {:ok, oembed}}}            <- fetch_oembed
    do
      {:ok, {body, status_code}, oembed}
    else
      _ -> {:error, :fetch_error}
    end
  end

  defp parse(body) do
    parse = &Task.async(&1, :parse, [ body ])
    tasks = Enum.map([Twitter, JsonLD], parse)

    with [ twitter, json_ld ] <- Task.yield_many(tasks),
         {_twitter,  {:ok, {:ok, twitter}}}    <- twitter,
         {_json_ld,  {:ok, {:ok, json_ld}}}    <- json_ld
    do
      {:ok, %{
        twitter: twitter,
        json_ld: json_ld,
      }}
    else
      e ->
        IO.inspect(e, label: :error)
        {:error, :parse_error}
    end
  end
end

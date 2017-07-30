defmodule Furlex do
  @moduledoc """
  Furlex is a structured data extraction tool written in Elixir.

  It currently supports unfurling oEmbed, Twitter Card, Facebook Open Graph,
  JSON-LD and plain ole' HTML `<meta />` data out of any url you supply.
  """

  use Application

  alias Furlex.{Fetcher, Parser}
  alias Furlex.Parser.{Facebook, HTML, JsonLD, Twitter}

  defstruct [:canonical_url, :oembed, :facebook, :twitter, :json_ld, :other]

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
  """
  def unfurl(url) do
    with {:ok, body}     <- Fetcher.fetch(url),
         {:ok, oembed}   <- Fetcher.fetch_oembed(url),
         {:ok, facebook} <- Facebook.parse(body),
         {:ok, twitter}  <- Twitter.parse(body),
         {:ok, json_ld}  <- JsonLD.parse(body),
         {:ok, other}    <- HTML.parse(body)
    do
      {:ok, %__MODULE__{
        canonical_url: Parser.extract_canonical(body),
        oembed: oembed,
        facebook: facebook,
        twitter: twitter,
        json_ld: json_ld,
        other: other
      }}
    end
  end
end

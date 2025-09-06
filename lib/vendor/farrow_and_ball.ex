defmodule Paintscraper.Vendor.FarrowAndBall do
  require Logger
  @behaviour Paintscraper.Vendor

  @impl true
  def vendor_name, do: "Farrow & Ball"

  @impl true
  def colors(request \\ Req.new()) do
    Logger.info("Fetching color URLs from paged directory: #{directory_url()}")
    color_urls =
      directory_paged_stream(request, directory_url())
      |> Enum.flat_map(&Floki.attribute(&1.body |> Floki.parse_document!(), ".product-item-name > a", "href"))

    color_urls
    |> Task.async_stream(fn
      url ->
        Logger.info("Fetching document for color: #{url}")
        Req.get!(request, url: url).body
        |> Floki.parse_document!()
        |> html_tree_to_color(url)
    end, timeout: 15000)
    |> Enum.map(fn {_, color} -> color end)
  end

  defp directory_paged_stream(_request, nil), do: []
  defp directory_paged_stream(request, url) do
    Logger.info("Fetching color URLs from directory page: #{url}")
    response = Req.get!(request, url: url)

    next_url =
      response.body
      |> Floki.parse_document!()
      |> Floki.attribute(".next", "href")
      |> List.first()

    [response | directory_paged_stream(request, next_url)]
  end

  defp base_url, do: URI.parse("https://www.farrow-ball.com/eu")
  defp directory_url, do: URI.append_path(base_url(), "/paint/all-paint-colours")

  defp html_tree_to_color(tree, url) do
    %Paintscraper.Color{
      vendor_color_code:
        tree
        |> Floki.find(".product-top-info-code > span")
        |> Floki.text()
        |> String.trim_leading("No. "),
      hex_color_code:
        tree
        |> Floki.attribute(".paint-page", "style")
        |> List.first()
        |> String.trim_leading("background-color: #"),
      vendor: __MODULE__,
      name:
        tree
        |> Floki.find(".page-title > .base")
        |> Floki.text(),
      description:
        tree
        |> Floki.find(".description > .value")
        |> Floki.text(sep: "\n"),
      variant:
        cond do
          tree
          |> Floki.find(".description > .value > p > i")
          |> Floki.text() =~ "Archive"
            -> "Archive"
          true -> nil
        end,
      url: url,
      image_urls:
        tree
        |> Floki.attribute(".product-image-gallery", "src")
    }
  end
end

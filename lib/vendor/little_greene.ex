defmodule Paintscraper.Vendor.LittleGreene do
  require Logger
  require Floki
  @behaviour Paintscraper.Vendor

  @impl true
  def vendor_name, do: "Little Greene"

  @impl true
  def colors(request \\ Req.new()) do
    Logger.info("Fetching color URLs from directory")
    color_urls =
      Req.get!(request, url: directory_url()).body
      |> Floki.parse_document!()
      |> Floki.attribute(".lgpc-product-card__title > a", "href")
      
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

  defp base_url, do: URI.parse("https://www.littlegreene.com")
  defp directory_url, do: URI.append_path(base_url(), "/paint")

  defp html_tree_to_color(tree, url) do
    %Paintscraper.Color{
      vendor_color_code:
        case tree
        |> Floki.find(".paint_number")
        |> Floki.text() do
          # HACK For some reason, Grey Stone (276) is the only color to not officially feature its number on the site.
          "" when url == "https://www.littlegreene.com/grey-stone" -> "276"
          code -> code
        end,
      hex_color_code:
        tree
        |> Floki.find(".hex_code")
        |> Floki.text()
        |> String.trim_leading("#"),
      vendor: __MODULE__,
      name:
        tree
        |> Floki.find(".nosto_product > .name")
        |> Floki.text(),
      description:
        tree
        |> Floki.find(".product > .value")
        |> Floki.text(),
      variant: nil,
      url: url,
      image_urls:
        tree
        |> Floki.find(".alternate_image_url")
        |> Enum.map(&Floki.text(&1))
    }
  end
end

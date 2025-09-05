defmodule Paintscraper.Vendor.Jotun do
  require Logger
  @behaviour Vendor

  @impl true
  def vendor_name, do: "Jotun"

  @impl true
  def colors(request \\ Req.new()) do
    color_collections()
    |> Enum.flat_map(&collection(request, &1))
  end

  defp base_url, do: URI.parse("https://www.jotun.com")
  defp api_base_url, do: URI.append_path(base_url(), "/api/v2")

  defp collection(request, {collection_name, build_relative_url}) do
    request
    |> colors_paged_stream(build_relative_url)
    |> Stream.flat_map(&(&1.body["results"]))
    |> Enum.map(&object_to_color(collection_name, &1))
  end

  defp colors_paged_stream(request, build_relative_url, take \\ 200) do
    Stream.unfold(%{page: -1, total: nil, received: 0}, fn
      %{total: total, received: received} when received >= total -> nil
      pageData ->
        next_page = pageData.page + 1
        relative_url = build_relative_url.(next_page, take)
        Logger.info("Taking <=#{take} colors from page #{next_page} via #{relative_url} (#{pageData.received}/#{pageData.total})",
          page: next_page, relative_url: relative_url)

        response = Req.get!(request, url: URI.append_path(api_base_url(), relative_url))

        body = response.body

        {
          response,
          %{pageData |
            page: body["page"],
            total: body["total"],
            received: body["count"] + pageData.received
          }
        }
    end)
  end

  defp color_collections do
    %{
      "Inomhus" => &"/search/colour?applicationAreas=Interior&page=#{&1}&pageUrl=/se-se/decorative/interior/colours/find-your-colour&skip=0&take=#{&2}",
      "Utomhus" => &"/search/colour?applicationAreas=Exterior&page=#{&1}&pageUrl=/se-se/decorative/exterior/colours/find-your-exterior-colour&skip=0&take=#{&2}"
    }
  end

  defp object_to_color(
      collection_name,
      %{
        "colourCode" => vendorCode,
        "colourHexCode" => hexCode,
        "colourName" => name,
        "description" => description,
        "link" => relative_url,
        "images" => images
      }) do
    %Color{
      vendor_color_code: vendorCode,
      hex_color_code: hexCode,
      vendor: __MODULE__,
      name: format_color_name(name),
      description: description,
      variant: collection_name,
      url:
        URI.merge(base_url(), relative_url) |> URI.to_string,
      image_urls:
        (for %{"url" => url} <- images, do: URI.merge(base_url(), url) |> URI.to_string)
    }
  end

  defp format_color_name(name) do
    String.split(name, " ", trim: false)
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end

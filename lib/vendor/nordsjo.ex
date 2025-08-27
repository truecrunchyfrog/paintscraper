defmodule Vendor.Nordsjo do
  require Logger
  @behaviour Vendor

  @impl true
  def vendor_name, do: "Nordsjö"

  @impl true
  def colors(request \\ Req.new()) do
    Logger.info("Fetching color metadata from directory")
    color_objects =
      Req.get!(request, url: directory_url()).body
      |> Floki.parse_document!()
      |> Floki.find(".js-carousel-data")
      |> Floki.text(js: true)
      |> Jason.decode!()
      |> Enum.flat_map(&(&1["colors"]))
      |> Enum.map(&(&1["color"]))

    color_objects
      |> Task.async_stream(fn
        color_object ->
          url = URI.append_path(base_url(), color_object["href"])
          Logger.info("Fetching document for color: #{url}")
          image_urls =
            Req.get!(request, url: url).body
            |> Floki.parse_document!()
            |> Floki.attribute(".carousel-item .image", "data-src")

          object_to_color(color_object, image_urls)
      end, timeout: 15000)
      |> Enum.map(fn {_, color} -> color end)
  end

  defp base_url, do: URI.parse("https://www.nordsjo.se")
  defp directory_url, do: URI.append_path(base_url(), URI.encode("/sv/hitta-en-kulör"))

  defp object_to_color(
    %{
      "ccid" => vendorCode,
      "hex" => <<"#", hexCode::binary>>,
      "name" => name,
      "href" => href,
      "colorDescription" => description
    },
    image_urls) do
    %Color{
      vendor_color_code: vendorCode,
      hex_color_code: hexCode,
      vendor: __MODULE__,
      name: name,
      description: description,
      variant: nil,
      url: URI.append_path(base_url(), href) |> URI.to_string(),
      image_urls: image_urls
    }
  end
end

defmodule Paintscraper.Color do
  defstruct [
    :vendor_color_code,
    :hex_color_code,
    :vendor,
    :name,
    :description,
    :variant,
    :url,
    :image_urls
  ]

  def unique_id(%{vendor_color_code: vendor_color_code, vendor: vendor})
    when is_binary(vendor_color_code) and is_atom(vendor) do
    "#{vendor.vendor_name()} #{vendor_color_code}"
  end
end

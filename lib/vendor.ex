defmodule Paintscraper.Vendor do
  @callback vendor_name() :: binary()
  @callback colors(request :: Req.Request) :: [Paintscraper.Color.t]
end

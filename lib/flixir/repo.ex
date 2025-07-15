defmodule Flixir.Repo do
  use Ecto.Repo,
    otp_app: :flixir,
    adapter: Ecto.Adapters.Postgres
end

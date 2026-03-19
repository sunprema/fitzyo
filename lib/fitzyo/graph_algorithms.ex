defmodule Fitzyo.GraphAlgorithms do
  use Rustler, otp_app: :fitzyo, crate: "graph_algorithms"

  # Overridden by NIF — returns :ok as a proof of life
  def hello, do: :erlang.nif_error(:nif_not_loaded)
end

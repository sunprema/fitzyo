defmodule Fitzyo.VideoProvider.Info do
  @moduledoc """
  Runtime introspection helpers for VideoProvider modules.
  Discovers all loaded providers and their capabilities.
  """

  @doc """
  Returns all modules in the application that use `Fitzyo.VideoProvider`.
  """
  def all_providers do
    :code.all_loaded()
    |> Enum.map(fn {mod, _} -> mod end)
    |> Enum.filter(fn mod ->
      function_exported?(mod, :provider_name, 0) and
        function_exported?(mod, :capabilities, 0) and
        function_exported?(mod, :models, 0)
    end)
  end

  @doc """
  Returns all providers that support the given capability atom.
  """
  def providers_with_capability(capability) do
    Enum.filter(all_providers(), fn mod ->
      capability in mod.capabilities()
    end)
  end

  @doc """
  Returns the cheapest model across all providers that supports the given
  capability and max_duration requirement.
  """
  def cheapest_model_for(capability, max_duration_needed) do
    for provider <- providers_with_capability(capability),
        model <- provider.models(),
        capability in provider.capabilities(),
        model.max_duration >= max_duration_needed do
      {provider, model}
    end
    |> Enum.min_by(fn {_provider, model} -> model.cost_per_second_usd end, fn -> nil end)
  end
end

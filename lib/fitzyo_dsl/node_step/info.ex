defmodule Fitzyo.NodeStep.Info do
  @moduledoc "Introspection helpers for modules using the Fitzyo.NodeStep DSL."

  use Spark.InfoGenerator, extension: Fitzyo.NodeStep.Dsl, sections: [:node_def]

  def node_definition!(module), do: module.node_definition()

  def node_kind(module), do: module.node_definition().kind
  def node_label(module), do: module.node_definition().label
  def node_category(module), do: module.node_definition().category
  def node_inputs(module), do: module.node_definition().inputs
  def node_outputs(module), do: module.node_definition().outputs
  def node_options(module), do: module.node_definition().options
end

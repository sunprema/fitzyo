defmodule Fitzyo.Workflow.Workflow do
  use Ash.Resource,
    domain: Fitzyo.Workflow,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "workflows"
    repo Fitzyo.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:title]
    end

    update :save_graph do
      accept [:nodes, :edges]
      description "Persist the current canvas node/edge graph to Postgres."
    end

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      get? true
      filter expr(id == ^arg(:id))
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true

    attribute :nodes, {:array, :map},
      default: [],
      public?: true,
      description: "Serialised SvelteFlow node list"

    attribute :edges, {:array, :map},
      default: [],
      public?: true,
      description: "Serialised SvelteFlow edge list"

    timestamps()
  end
end

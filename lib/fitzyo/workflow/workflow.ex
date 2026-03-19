defmodule Fitzyo.Workflow.Workflow do
  use Ash.Resource,
    domain: Fitzyo.Workflow,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "workflows"
    repo Fitzyo.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:title]
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    timestamps()
  end
end

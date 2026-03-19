defmodule Fitzyo.Workflow.WorkflowExecution do
  @moduledoc "Tracks one execution run of a workflow through the Reactor engine."

  use Ash.Resource,
    domain: Fitzyo.Workflow,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "workflow_executions"
    repo Fitzyo.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :start do
      accept [:workflow_id]

      change fn changeset, _ ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :running)
        |> Ash.Changeset.force_change_attribute(:started_at, DateTime.utc_now())
      end
    end

    update :complete do
      accept []

      change fn changeset, _ ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :complete)
        |> Ash.Changeset.force_change_attribute(:completed_at, DateTime.utc_now())
      end
    end

    update :fail do
      accept []

      change fn changeset, _ ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :failed)
        |> Ash.Changeset.force_change_attribute(:completed_at, DateTime.utc_now())
      end
    end

    update :save_context_snapshot do
      accept [:context_snapshot]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :status, :atom do
      allow_nil? false
      default :pending
      public? true
      constraints one_of: [:pending, :running, :complete, :failed]
    end

    attribute :started_at, :utc_datetime_usec, public?: true
    attribute :completed_at, :utc_datetime_usec, public?: true

    attribute :context_snapshot, :map do
      default %{}
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :workflow, Fitzyo.Workflow.Workflow do
      allow_nil? false
      public? true
    end
  end
end

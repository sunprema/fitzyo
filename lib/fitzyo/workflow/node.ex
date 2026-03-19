defmodule Fitzyo.Workflow.Node do
  @moduledoc "Represents a single node in a saved workflow graph."

  use Ash.Resource,
    domain: Fitzyo.Workflow,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "workflow_nodes"
    repo Fitzyo.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:workflow_id, :node_kind, :label, :position_x, :position_y, :data, :status]
    end

    update :update do
      accept [:label, :position_x, :position_y, :data, :status]
    end

    update :set_status do
      accept [:status]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :node_kind, :atom do
      allow_nil? false
      public? true
      constraints one_of: [
        :scene_generator,
        :character_animate,
        :background_gen,
        :vfx_overlay,
        :scene_stitch,
        :audio_mixer,
        :clip_trimmer,
        :final_export,
        :asset_loader,
        :prompt_template,
        :style_reference,
        :webhook_trigger,
        :cron_trigger,
        :wait,
        :conditional,
        :parallel_merge,
        :human_approval
      ]
    end

    attribute :label, :string, allow_nil?: false, public?: true
    attribute :position_x, :float, default: 0.0, public?: true
    attribute :position_y, :float, default: 0.0, public?: true
    attribute :data, :map, default: %{}, public?: true

    attribute :status, :atom do
      default :idle
      public? true
      constraints one_of: [:idle, :pending, :running, :complete, :failed]
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

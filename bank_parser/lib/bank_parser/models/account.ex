defmodule BankParser.Models.Account do
  @moduledoc """
  Account model
  """
  defstruct [:id, :name]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t()
        }

  def new(params) do
    struct!(__MODULE__, params)
  end
end

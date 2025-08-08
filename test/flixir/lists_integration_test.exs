defmodule Flixir.ListsIntegrationTest do
  use ExUnit.Case, async: true

  alias Flixir.Lists

  describe "validate_list_attrs/1" do
    test "validates list attributes correctly" do
      # Test valid attributes
      valid_attrs = %{"name" => "My Watchlist", "description" => "Movies to watch"}
      assert :ok = Lists.validate_list_attrs(valid_attrs)

      # Test missing name
      invalid_attrs = %{"description" => "Movies to watch"}
      assert {:error, :name_required} = Lists.validate_list_attrs(invalid_attrs)

      # Test empty name
      empty_name_attrs = %{"name" => "", "description" => "Movies to watch"}
      assert {:error, :name_required} = Lists.validate_list_attrs(empty_name_attrs)

      # Test name too short
      short_name_attrs = %{"name" => "Hi", "description" => "Movies to watch"}
      assert {:error, :name_too_short} = Lists.validate_list_attrs(short_name_attrs)

      # Test name too long
      long_name = String.duplicate("a", 101)
      long_name_attrs = %{"name" => long_name, "description" => "Movies to watch"}
      assert {:error, :name_too_long} = Lists.validate_list_attrs(long_name_attrs)

      # Test description too long
      long_description = String.duplicate("a", 501)
      long_desc_attrs = %{"name" => "Valid Name", "description" => long_description}
      assert {:error, :description_too_long} = Lists.validate_list_attrs(long_desc_attrs)
    end
  end
end

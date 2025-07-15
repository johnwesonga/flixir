defmodule Flixir.Media.SearchParams do
  @moduledoc """
  Represents search parameters for movie and TV show searches.
  Includes validation for search inputs and parameters.
  """

  @type t :: %__MODULE__{
    query: String.t(),
    media_type: :all | :movie | :tv,
    sort_by: :relevance | :release_date | :title | :popularity,
    page: integer()
  }

  defstruct [
    query: "",
    media_type: :all,
    sort_by: :relevance,
    page: 1
  ]

  @valid_media_types [:all, :movie, :tv]
  @valid_sort_options [:relevance, :release_date, :title, :popularity]
  @max_page 1000
  @min_query_length 1
  @max_query_length 200

  @doc """
  Creates and validates search parameters.
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(params) when is_map(params) do
    with {:ok, query} <- validate_query(params["query"] || params[:query] || ""),
         {:ok, media_type} <- validate_media_type(params["media_type"] || params[:media_type] || :all),
         {:ok, sort_by} <- validate_sort_by(params["sort_by"] || params[:sort_by] || :relevance),
         {:ok, page} <- validate_page(params["page"] || params[:page] || 1) do

      search_params = %__MODULE__{
        query: query,
        media_type: media_type,
        sort_by: sort_by,
        page: page
      }

      {:ok, search_params}
    end
  end

  def new(_), do: {:error, "Invalid parameters format"}

  @doc """
  Validates a search query string.
  """
  @spec validate_query(any()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_query(query) when is_binary(query) do
    trimmed = String.trim(query)

    cond do
      String.length(trimmed) < @min_query_length ->
        {:error, "Search query cannot be empty"}

      String.length(trimmed) > @max_query_length ->
        {:error, "Search query is too long (maximum #{@max_query_length} characters)"}

      String.match?(trimmed, ~r/^\s*$/) ->
        {:error, "Search query cannot contain only whitespace"}

      true ->
        {:ok, trimmed}
    end
  end

  def validate_query(_), do: {:error, "Search query must be a string"}

  @doc """
  Validates media type parameter.
  """
  @spec validate_media_type(any()) :: {:ok, atom()} | {:error, String.t()}
  def validate_media_type(media_type) when is_atom(media_type) do
    if media_type in @valid_media_types do
      {:ok, media_type}
    else
      {:error, "Invalid media type. Must be one of: #{inspect(@valid_media_types)}"}
    end
  end

  def validate_media_type(media_type) when is_binary(media_type) do
    case media_type do
      "all" -> {:ok, :all}
      "movie" -> {:ok, :movie}
      "tv" -> {:ok, :tv}
      _ -> {:error, "Invalid media type. Must be one of: all, movie, tv"}
    end
  end

  def validate_media_type(_), do: {:error, "Media type must be an atom or string"}

  @doc """
  Validates sort_by parameter.
  """
  @spec validate_sort_by(any()) :: {:ok, atom()} | {:error, String.t()}
  def validate_sort_by(sort_by) when is_atom(sort_by) do
    if sort_by in @valid_sort_options do
      {:ok, sort_by}
    else
      {:error, "Invalid sort option. Must be one of: #{inspect(@valid_sort_options)}"}
    end
  end

  def validate_sort_by(sort_by) when is_binary(sort_by) do
    case sort_by do
      "relevance" -> {:ok, :relevance}
      "release_date" -> {:ok, :release_date}
      "title" -> {:ok, :title}
      "popularity" -> {:ok, :popularity}
      _ -> {:error, "Invalid sort option. Must be one of: relevance, release_date, title, popularity"}
    end
  end

  def validate_sort_by(_), do: {:error, "Sort option must be an atom or string"}

  @doc """
  Validates page parameter.
  """
  @spec validate_page(any()) :: {:ok, integer()} | {:error, String.t()}
  def validate_page(page) when is_integer(page) do
    cond do
      page < 1 ->
        {:error, "Page number must be greater than 0"}

      page > @max_page ->
        {:error, "Page number cannot exceed #{@max_page}"}

      true ->
        {:ok, page}
    end
  end

  def validate_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {parsed_page, ""} -> validate_page(parsed_page)
      _ -> {:error, "Page must be a valid integer"}
    end
  end

  def validate_page(_), do: {:error, "Page must be an integer"}

  @doc """
  Converts SearchParams to a map suitable for API calls.
  """
  @spec to_api_params(t()) :: map()
  def to_api_params(%__MODULE__{} = params) do
    %{
      "query" => params.query,
      "page" => params.page
    }
    |> maybe_add_media_type_filter(params.media_type)
  end

  defp maybe_add_media_type_filter(api_params, :all), do: api_params
  defp maybe_add_media_type_filter(api_params, media_type) do
    Map.put(api_params, "media_type", Atom.to_string(media_type))
  end
end

defmodule FlixirWeb.AuthHooks do
  @moduledoc """
  LiveView hooks for authentication state management.

  This module provides on_mount callbacks to ensure authentication state
  is properly set on LiveView socket assigns. Since connection assigns are not
  automatically transferred to socket assigns in Phoenix LiveView, this module
  gets authentication state directly from the session data.
  """

  import Phoenix.Component, only: [assign: 3]

  def on_mount(:default, _params, session, socket) do
    # Since connection assigns are not transferred to socket assigns,
    # we need to get authentication state directly from the session
    # Try encrypted session first, then fallback to plain session
    session_id = get_session_id_from_session(session)

    {authenticated?, current_user, current_session} =
      if session_id do
        # We have a session ID, validate it and get user data
        case Flixir.Auth.validate_session(session_id) do
          {:ok, session_data} ->
            case Flixir.Auth.get_current_user(session_id) do
              {:ok, user_data} ->
                {true, user_data, session_data}

              {:error, reason} ->
                # Log the error for debugging
                require Logger
                Logger.debug("Failed to get current user in auth hook", %{
                  session_id: session_id,
                  error: inspect(reason)
                })
                {false, nil, nil}
            end

          {:error, reason} ->
            # Log the error for debugging
            require Logger
            Logger.debug("Failed to validate session in auth hook", %{
              session_id: session_id,
              error: inspect(reason)
            })
            {false, nil, nil}
        end
      else
        # No session ID
        {false, nil, nil}
      end

    # Log the final authentication state for debugging
    require Logger
    Logger.debug("Auth hook completed", %{
      session_id: session_id,
      authenticated?: authenticated?,
      has_user: not is_nil(current_user),
      has_session: not is_nil(current_session)
    })

    # Set authentication state on the socket
    socket =
      socket
      |> assign(:authenticated?, authenticated?)
      |> assign(:current_user, current_user)
      |> assign(:current_session, current_session)

    {:cont, socket}
  end

  # Private helper to extract session ID from session data
  # This matches the logic in FlixirWeb.Plugs.AuthSession
  defp get_session_id_from_session(session) do
    # Try encrypted session first
    case Map.get(session, "encrypted_session_data") do
      %{session_id: session_id} = session_data when is_binary(session_id) ->
        if valid_session_data?(session_data) do
          session_id
        else
          # Try fallback to plain session
          Map.get(session, "tmdb_session_id")
        end

      _ ->
        # Fallback to plain session
        Map.get(session, "tmdb_session_id")
    end
  end

  # Validate session data structure and age (matches AuthSession plug logic)
  defp valid_session_data?(%{session_id: session_id, created_at: created_at, csrf_token: csrf_token})
       when is_binary(session_id) and is_integer(created_at) and is_binary(csrf_token) do
    # Check if session data is not too old (prevent replay attacks)
    max_age = get_session_max_age()
    current_time = DateTime.utc_now() |> DateTime.to_unix()

    current_time - created_at <= max_age
  end

  defp valid_session_data?(_), do: false

  # Get session max age (matches AuthSession plug)
  defp get_session_max_age do
    # Default to 24 hours if not configured
    Application.get_env(:flixir, :session_max_age, 86400)
  end
end

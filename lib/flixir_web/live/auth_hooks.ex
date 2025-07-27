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
    session_id = Map.get(session, "tmdb_session_id", nil)

    {authenticated?, current_user, current_session} =
      if session_id do
        # We have a session ID, validate it and get user data
        case Flixir.Auth.validate_session(session_id) do
          {:ok, session_data} ->
            case Flixir.Auth.get_current_user(session_id) do
              {:ok, user_data} ->
                {true, user_data, session_data}

              {:error, _reason} ->
                {false, nil, nil}
            end

          {:error, _reason} ->
            {false, nil, nil}
        end
      else
        # No session ID
        {false, nil, nil}
      end

    # Set authentication state on the socket
    socket =
      socket
      |> assign(:authenticated?, authenticated?)
      |> assign(:current_user, current_user)
      |> assign(:current_session, current_session)

    {:cont, socket}
  end
end

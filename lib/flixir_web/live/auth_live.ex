defmodule FlixirWeb.AuthLive do
  @moduledoc """
  LiveView for handling TMDB authentication flow.

  This module provides the UI and logic for:
  - Login initiation with TMDB redirect
  - Authentication callback with token processing
  - Logout functionality with session cleanup
  - Error handling and user feedback for authentication failures
  - Authentication state management
  """

  use FlixirWeb, :live_view

  alias Flixir.Auth

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    # Get authentication state from assigns (set by AuthSession plug)
    authenticated? = Map.get(socket.assigns, :authenticated?, false)
    current_user = Map.get(socket.assigns, :current_user, nil)
    current_session = Map.get(socket.assigns, :current_session, nil)

    socket =
      socket
      |> assign(:page_title, "Authentication")
      |> assign(:loading, false)
      |> assign(:error_message, nil)
      |> assign(:success_message, nil)
      |> assign(:authenticated?, authenticated?)
      |> assign(:current_user, current_user)
      |> assign(:current_session, current_session)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, handle_route(socket, socket.assigns.live_action, params)}
  end

  # Route handlers

  defp handle_route(socket, :login, _params) do
    if socket.assigns.authenticated? do
      # User is already authenticated, redirect to home
      socket
      |> put_flash(:info, "You are already logged in.")
      |> push_navigate(to: ~p"/")
    else
      socket
      |> assign(:page_title, "Login")
      |> assign(:error_message, nil)
      |> assign(:success_message, nil)
    end
  end

  defp handle_route(socket, :callback, %{"request_token" => token}) do
    # Handle authentication callback with token processing
    socket
    |> assign(:loading, true)
    |> assign(:page_title, "Completing Login...")
    |> start_auth_async(:complete_authentication, token)
  end

  defp handle_route(socket, :callback, %{"denied" => "true"}) do
    # User denied authentication on TMDB
    socket
    |> assign(:page_title, "Login")
    |> assign(:error_message, "Authentication was cancelled. Please try again.")
    |> assign(:loading, false)
  end

  defp handle_route(socket, :callback, _params) do
    # Invalid callback parameters
    socket
    |> assign(:page_title, "Login")
    |> assign(:error_message, "Invalid authentication callback. Please try logging in again.")
    |> assign(:loading, false)
  end

  defp handle_route(socket, :logout, _params) do
    # Handle logout confirmation page
    socket
    |> assign(:page_title, "Logout")
    |> assign(:error_message, nil)
    |> assign(:success_message, nil)
  end

  # Event handlers

  @impl true
  def handle_event("login", _params, socket) do
    if socket.assigns.authenticated? do
      # User is already authenticated
      {:noreply,
       socket
       |> put_flash(:info, "You are already logged in.")
       |> push_navigate(to: ~p"/")}
    else
      # Start authentication flow
      socket =
        socket
        |> assign(:loading, true)
        |> assign(:error_message, nil)
        |> start_auth_async(:start_authentication, nil)

      {:noreply, socket}
    end
  end

  def handle_event("logout", _params, socket) do
    if socket.assigns.authenticated? do
      # Start logout process
      session_id = socket.assigns.current_session.tmdb_session_id

      socket =
        socket
        |> assign(:loading, true)
        |> assign(:error_message, nil)
        |> start_auth_async(:logout, session_id)

      {:noreply, socket}
    else
      # User is not authenticated
      {:noreply,
       socket
       |> put_flash(:info, "You are not logged in.")
       |> push_navigate(to: ~p"/")}
    end
  end

  def handle_event("confirm_logout", _params, socket) do
    # Handle logout confirmation
    handle_event("logout", %{}, socket)
  end

  def handle_event("cancel_logout", _params, socket) do
    # Cancel logout and redirect to home
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  def handle_event("retry_login", _params, socket) do
    # Retry login after error
    socket =
      socket
      |> assign(:error_message, nil)
      |> assign(:success_message, nil)
      |> assign(:loading, false)

    {:noreply, socket}
  end

  # Info message handlers

  @impl true
  def handle_info({:store_session_and_redirect, session}, socket) do
    # Default redirect path to home
    redirect_path = "/"

    # Redirect to controller action that will handle session storage
    socket =
      socket
      |> put_flash(:info, "Welcome back, #{session.username}!")
      |> redirect(
        to:
          "/auth/store_session?session_id=#{session.tmdb_session_id}&redirect_to=#{URI.encode(redirect_path)}"
      )

    {:noreply, socket}
  end

  def handle_info(:clear_session_and_redirect, socket) do
    socket =
      socket
      |> put_flash(:info, "You have been logged out successfully.")
      |> redirect(to: "/auth/clear_session")

    {:noreply, socket}
  end

  # Async result handlers

  @impl true
  def handle_async(:auth_result, {:ok, auth_url}, socket) when is_binary(auth_url) do
    Logger.info("Successfully started authentication, redirecting to TMDB")

    # Redirect to TMDB authentication URL
    {:noreply, redirect(socket, external: auth_url)}
  end

  def handle_async(:auth_result, {:ok, session}, socket) when is_struct(session) do
    Logger.info("Successfully completed authentication for user: #{session.username}")

    # Send message to self to handle session storage after async completes
    send(self(), {:store_session_and_redirect, session})

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:success_message, "Authentication successful! Redirecting...")

    {:noreply, socket}
  end

  def handle_async(:auth_result, {:ok, {:ok, auth_url}}, socket) when is_binary(auth_url) do
    Logger.info("Successfully started authentication, redirecting to TMDB")

    # Redirect to TMDB authentication URL
    {:noreply, redirect(socket, external: auth_url)}
  end

  def handle_async(:auth_result, {:ok, {:ok, session}}, socket) when is_struct(session) do
    Logger.info("Successfully completed authentication for user: #{session.username}")

    # Send message to self to handle session storage after async completes
    send(self(), {:store_session_and_redirect, session})

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:success_message, "Authentication successful! Redirecting...")

    {:noreply, socket}
  end

  def handle_async(:auth_result, {:ok, {:error, reason}}, socket) do
    Logger.error("Failed authentication operation: #{inspect(reason)}")

    error_message = format_authentication_error(reason)

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:error_message, error_message)

    {:noreply, socket}
  end

  def handle_async(:auth_result, {:error, reason}, socket) do
    Logger.error("Failed authentication operation: #{inspect(reason)}")

    error_message = format_authentication_error(reason)

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:error_message, error_message)

    {:noreply, socket}
  end

  def handle_async(:auth_result, {:exit, reason}, socket) do
    Logger.error("Authentication process crashed: #{inspect(reason)}")

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:error_message, "An unexpected error occurred. Please try again.")

    {:noreply, socket}
  end

  def handle_async(:logout_result, {:ok, :ok}, socket) do
    Logger.info("Successfully logged out user")

    # Send message to self to handle session clearing after async completes
    send(self(), :clear_session_and_redirect)

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:success_message, "Logged out successfully! Redirecting...")

    {:noreply, socket}
  end

  def handle_async(:logout_result, {:ok, {:error, reason}}, socket) do
    Logger.error("Failed to logout: #{inspect(reason)}")

    # Even if logout fails on TMDB side, clear local session
    send(self(), :clear_session_and_redirect)

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:success_message, "Logged out! Redirecting...")

    {:noreply, socket}
  end

  def handle_async(:logout_result, {:exit, reason}, socket) do
    Logger.error("Logout process crashed: #{inspect(reason)}")

    # Clear local session even if process crashed
    send(self(), :clear_session_and_redirect)

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:success_message, "Logged out! Redirecting...")

    {:noreply, socket}
  end

  # Async task functions

  defp start_auth_async(socket, :start_authentication, _) do
    start_async(socket, :auth_result, fn ->
      Auth.start_authentication()
    end)
  end

  defp start_auth_async(socket, :complete_authentication, token) do
    start_async(socket, :auth_result, fn ->
      Auth.complete_authentication(token)
    end)
  end

  defp start_auth_async(socket, :logout, session_id) do
    start_async(socket, :logout_result, fn ->
      Auth.logout(session_id)
    end)
  end

  # Helper functions

  defp format_authentication_error(:token_creation_failed) do
    "Unable to connect to TMDB for authentication. Please try again later."
  end

  defp format_authentication_error(:session_creation_failed) do
    "Failed to create authentication session. Please try logging in again."
  end

  defp format_authentication_error(:invalid_token) do
    "Invalid authentication token. Please try logging in again."
  end

  defp format_authentication_error(:unauthorized) do
    "Authentication failed. Please check your TMDB credentials and try again."
  end

  defp format_authentication_error(:timeout) do
    "Authentication request timed out. Please check your connection and try again."
  end

  defp format_authentication_error(:rate_limited) do
    "Too many authentication attempts. Please wait a moment and try again."
  end

  defp format_authentication_error(:not_found) do
    "Authentication service not found. Please try again later."
  end

  defp format_authentication_error({:transport_error, _reason}) do
    "Network error during authentication. Please check your connection and try again."
  end

  defp format_authentication_error({:unexpected_status, status}) do
    "Authentication service returned an unexpected response (#{status}). Please try again later."
  end

  defp format_authentication_error(_reason) do
    "An unexpected error occurred during authentication. Please try again."
  end
end

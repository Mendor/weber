defmodule Weber.Session.SessionManager do
  
  @moduledoc """
  Session manager process. Create new session's process,
  manages all sessions.
  """

  use GenServer.Behaviour

  defrecord SessionManager,
    config:  nil

  @doc """
  Start session manager.
  """
  def start_link(config) do
    :gen_server.start_link({:local, :session_manager}, __MODULE__, [config], [])
  end

  @doc """
  gen_server init/1 callback.
  """
  def init([config]) do
    :ets.new(:cookie_storage, [:named_table, :public, :bag])
    { :ok, SessionManager.new config: config }
  end

  @doc """
  Create new session.
  """
  def handle_call({:create_new_session, session_id, pid}, _from, state) do
    {_, session_config} = :lists.keyfind(:session, 1, state.config)
    {_, max_age} = :lists.keyfind(:max_age, 1, session_config)

    Weber.Session.start_link(max_age, session_id)

    case :ets.match_object(:cookie_storage, {:_, pid, :_}) do
      [] ->
        locale = case :lists.keyfind(:localization, 1, state.config) do
          false -> 
            []
          {:localization, localization_config} ->
            {_, default_locale}  = :lists.keyfind(:default_locale, 1, localization_config)
            default_locale
        end
        id = session_id |> :erlang.binary_to_list |> :lists.concat |> :lists.concat |> :erlang.list_to_binary
        :ets.insert(:cookie_storage, {id, pid, [locale: locale]})
        {:reply, id, state}
      [{old_session_id, _pid, _opts}] -> 
        {:reply, old_session_id, state}
    end

  end

  @doc """
  Check cookie in ets.
  """
  def handle_cast({:check_cookie, cookie, pid}, state) do
    case :ets.match_object(:cookie_storage, {cookie, :_, :_}) do
      [] ->
        locale = case :lists.keyfind(:localization, 1, state.config) do
          false -> 
            "en_US"
          {:localization, localization_config} ->
            {_, default_locale}  = :lists.keyfind(:default_locale, 1, localization_config)
            default_locale
        end
        :ets.insert(:cookie_storage, {cookie, pid, [locale: locale]})
      _ ->
        :ok
    end
    {:noreply, state}
  end

end
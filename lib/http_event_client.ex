defmodule HTTPEventClient do
  @moduledoc """
  Emits events to an HTTP event server.  Events can get sent either async or inline.
  Events are sent over the default http method `POST`.  This can be configured with
  the `default_http_method` config option.  Events are sent to the url provided with
  the `event_server_url` option.  You may also set the `force_ssl` option to force
  events to be sent over SSL.  Only events with numbers or letters are allowed.

  ### Simple event
  HTTPEventClient.emit("something happend")

  ### Event with data
  HTTPEventClient.emit("something happend", %{username: "john doe"})

  ### Async event
  HTTPEventClient.emit_async("something happend")

  # Multiple Clients
  To allow for multiple clients, you can instead pass a client object as the first
  parameter to the emit methods.  The client can be defined using the struct for
  this module.  It accepts all of the same options as the config does. Here is and example

  ```
  client = %HTTPEventClient{
              event_server_url: "https://event.example.com/events",
              api_token: "d0fe388f-d491-4ef2-ae48-749c760c42af"
            }

  HTTPEventClient.emit(client, "ping")
  ```
  """

  defstruct [
    event_server_url: Application.get_env(:http_event_client, :event_server_url),
    api_token: Application.get_env(:http_event_client, :api_token),
    force_ssl: Application.get_env(:http_event_client, :force_ssl),
    default_http_method: Application.get_env(:http_event_client, :default_http_method)
  ]

  @doc """
  Sends events async.
  """
  def emit_async(%__MODULE__{} = client, event), do: emit_async(client, event, nil, nil)
  def emit_async(%__MODULE__{} = client, event, data), do: emit_async(client, event, data, nil)
  def emit_async(%__MODULE__{} = client, event, data, method) do
    if event_name_valid?(event) do
      Process.spawn(__MODULE__, :emit, [client, event, data, method], [])
      :ok
    else
      {:error, "Event \"#{event}\" is not a valid event name"}
    end
  end
  def emit_async(event), do: emit_async(event, nil, nil)
  def emit_async(event, data), do: emit_async(event, data, nil)
  def emit_async(event, data, method) do
    client = %__MODULE__{}
    if event_name_valid?(event) do
      Process.spawn(__MODULE__, :emit, [client, event, data, method], [])
      :ok
    else
      {:error, "Event \"#{event}\" is not a valid event name"}
    end
  end

  @doc """
  Sends events and awaits a response.
  """
  def emit(%__MODULE__{} = client, event), do: emit(client, event, nil, nil)
  def emit(%__MODULE__{} = client, event, data), do: emit(client, event, data, nil)
  def emit(%__MODULE__{} = client, event, data, method) do
    if event_name_valid?(event) do
      method = resolve_method_type(client, method)
      IO.puts "[HTTP EVENT CLIENT] Send #{method}:#{event} >>> #{inspect data}"
      case send_event(client, event, event_server_url(client), method, data) do
        {:ok, %HTTPoison.Response{body: result}} ->
          IO.puts "[HTTP EVENT CLIENT] Recv #{method}:#{event} <<< #{inspect result}"
          decode_response(result)
        error -> {:error, error}
      end
    else
      {:error, "Event \"#{event}\" is not a valid event name"}
    end
  end
  def emit(event), do: emit(event, nil, nil)
  def emit(event, data), do: emit(event, data, nil)
  def emit(event, data, method) do
    client = %__MODULE__{}
    if event_name_valid?(event) do
      method = resolve_method_type(client, method)
      IO.puts "[HTTP EVENT CLIENT] Send #{method}:#{event} >>> #{inspect data}"
      case send_event(client, event, event_server_url(client), method, data) do
        {:ok, %HTTPoison.Response{body: result}} ->
          IO.puts "[HTTP EVENT CLIENT] Recv #{method}:#{event} <<< #{inspect result}"
          decode_response(result)
        error -> {:error, error}
      end
    else
      {:error, "Event \"#{event}\" is not a valid event name"}
    end
  end

  defp send_event(_, false, _, _), do: {:error, "Event server URL not defined"}

  defp send_event(client, event, server_url, "POST", data) do
    HTTPoison.post "#{Path.join(server_url, event)}", Poison.encode!(data), headers(client)
  end

  defp send_event(client, event, server_url, "PUT", data) do
    HTTPoison.put "#{Path.join(server_url, event)}", Poison.encode!(data), headers(client)
  end

  defp send_event(client, event, server_url, "PATCH", data) do
    HTTPoison.patch "#{Path.join(server_url, event)}", Poison.encode!(data), headers(client)
  end

  defp send_event(client, event, server_url, "GET", data) do
    HTTPoison.get! "#{Path.join(server_url, event)}", Poison.encode!(data), headers(client)
  end

  defp send_event(client, event, server_url, "DELETE", data) do
    HTTPoison.delete "#{Path.join(server_url, event)}", Poison.encode!(data), headers(client)
  end

  defp event_server_url(%__MODULE__{event_server_url: url} = client) do
    resolve_server_url(url, client)
  end

  defp resolve_server_url(false, _) do
    false
  end

  defp resolve_server_url(url, %__MODULE__{force_ssl: force_ssl}) when is_binary(url) do
    if force_ssl do
      "https://#{String.replace(url, ~r/(http|https):\/\//, "")}"
    else
      if String.match?(url, ~r/(http|https):\/\//) do
        url
      else
        "http://#{url}"
      end
    end
  end

  defp default_event_http_method(%__MODULE__{default_http_method: default_http_method}) do
    default_http_method || :post
  end

  defp event_name_valid?(event) do
    if String.match?(event, ~r/[^a-zA-Z0-9-_]/) do
      false
    else
      true
    end
  end

  defp resolve_method_type(client, method) do
    method = method || default_event_http_method(client)
    method = if String.valid?(method) do
               method
             else
               Atom.to_string(method)
             end

    method = String.upcase(method)
  end

  defp headers(%__MODULE__{api_token: api_token}) do
    [{"Authorization", "Bearer #{api_token}"}, {"Content-Type", "application/json"}]
  end

  defp decode_response(result) do
    case Poison.decode(result) do
      {:ok, data} -> data
      _error -> result
    end

  end
end

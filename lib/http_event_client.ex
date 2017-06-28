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
  """

  @doc """
  Sends events async.
  """
  def emit_async(event), do: emit_async(event, nil, nil)
  def emit_async(event, data, method \\ nil) do
    if event_name_valid?(event) do
      method = resolve_method_type(method)

      Process.send(__MODULE__, :send_event, [event, event_server_url(), method, data])
      :ok
    else
      {:error, "Event \"#{event}\" is not a valid event name"}
    end
  end

  @doc """
  Sends events and awaits a response.
  """
  def emit(event), do: emit(event, nil, nil)
  def emit(event, data, method \\ nil) do
    if event_name_valid?(event) do
      method = resolve_method_type(method)

      send_event(event, event_server_url(), method, data)
    else
      {:error, "Event \"#{event}\" is not a valid event name"}
    end
  end

  defp send_event(_, false, _, _), do: {:error, "Event server URL not defined"}

  defp send_event(event, server_url, "POST", data) do
    IO.puts "SENDING TO: #{Path.join(server_url, event)}"
    HTTPoison.post! "#{Path.join(server_url, event)}", Poison.encode!(data), headers()
  end

  defp send_event(event, server_url, "PUT", data) do
    HTTPoison.put! "#{Path.join(server_url, event)}", Poison.encode!(data), headers()
  end

  defp send_event(event, server_url, "PATCH", data) do
    HTTPoison.patch! "#{Path.join(server_url, event)}", Poison.encode!(data), headers()
  end

  defp send_event(event, server_url, "GET", data) do
    HTTPoison.get! "#{Path.join(server_url, event)}", Poison.encode!(data), headers()
  end

  defp send_event(event, server_url, "DELETE", data) do
    HTTPoison.delete! "#{Path.join(server_url, event)}", Poison.encode!(data), headers()
  end

  defp event_server_url do
    resolve_server_url(Application.get_env(:http_event_client, :event_server_url))
  end

  defp resolve_server_url(false) do
    false
  end

  defp resolve_server_url(url) when is_binary(url) do
    if Application.get_env(:http_event_client, :force_ssl) do
      "https://#{String.replace(url, ~r/(http|https):\/\//, "")}"
    else
      if String.match?(url, ~r/(http|https):\/\//) do
        url
      else
        "http://#{url}"
      end
    end
  end

  defp default_event_http_method do
    Application.get_env(:http_event_client, :default_http_method) || :post
  end

  defp event_name_valid?(event) do
    if String.match?(event, ~r/[^a-zA-Z0-9-_]/) do
      false
    else
      true
    end
  end

  defp resolve_method_type(method) do
    method = method || default_event_http_method()
    unless String.valid?(method) do
      method = Atom.to_string(method)
    end

    method = String.upcase(method)
  end

  defp headers do
    [{"Authorization", "Bearer #{Application.get_env(:http_event_client, :api_token)}"}, {"Content-Type", "application/json"}]
  end
end

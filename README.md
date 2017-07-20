# EventClient

[![Hex.pm version](https://img.shields.io/hexpm/v/http_event_client.svg)](https://hex.pm/packages/http_event_client)
[![Hex.pm](https://img.shields.io/hexpm/l/http_event_client.svg)]()

[Documentation](https://hexdocs.pm/http_event_server/api-reference.html)

## Installation

The package can be installed by adding `http_event_client` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:http_event_client, "~> 0.2.2"}]
end
```

## Usage

### Config Based
Pros: You can use the package anywhere in your code without needing to set up a connection client.
Cons: You can only connect to a single server for the project.

Here is how you would set up the client


```elixir
# Config

config :http_event_client,
  event_server_url: "https://example.com/events",
  api_token: "1944ea5a-c924-4a24-9afa-60030e5bc486"
```

Now you can use this anywhere by calling either the emit or emit_async methods as shown below.

```elixir
HTTPEventClient.emit("my-event", data)

HTTPEventClient.emit_async("my-event", data)
```

### Client Based
Pros: Supports multiple servers/endpoints.
Cons: You have to create a client for every connection.

Here is an example module that properly uses the client method to connect.

```elixir
defmodule Messenger do
  def send_event(data) do
    HTTPEventClient.emit(client(), "my-event", data)
  end

  def send_async_event(data) do
    HTTPEventClient.emit_async(client(), "my-event", data)
  end

  defp client do
    %HTTPEventClient{
      api_token: Application.get_env(:messenger, :event_server_api_token),
      event_server_url: Application.get_env(:messenger, :event_server_url)
    }
  end
end
```


### Additional Info

### Event Types
There are two event types, normal and async.  The async method will just put the normal method in another process.  Because of that, it will never return anything.  The normal method will wait for a response and return the response.  

### Sending Data
Data is, by default, sent with a POST request with a JSON encoded body and authenticated using an Authorization Bearer token.    

### Event Data
Data being sent is encoded into JSON using Poison.  If you use the [http_event_server](https://hex.pm/packages/http_event_server) package, it will decode the data using Poison.  So any data you send should be able to work with Poison's encode/decode methods (pretty much everything).

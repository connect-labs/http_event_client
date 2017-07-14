use Mix.Config

config :logger, :console,
  format: "[$level  -  HTTP EVENT CLIENT] $levelpad$message\n\t\tData: $levelpad$metadata\n",
  metadata: [:event, :method]

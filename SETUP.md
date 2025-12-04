# Headscale UI Setup

Follow these steps to let the Headscale UI talk to your Headscale instance without 401 errors.

1) Make sure the stack is running: `docker compose up -d`
2) Create an API key from the Headscale container (the debug line about `HEADSCALE_CLI_ADDRESS` is normal):
   `docker exec headscale headscale apikeys create --expiration 720h`
   Copy the returned token (example: `InSTKih.gJpg4Ob6dMOuI6NloJN-K3ILC8o6wgke`).
3) Open the UI at `http://localhost:8081`
4) In the UI settings, set:
   - Headscale URL: `http://localhost:8080` (from your host). If configuring from another container on the same Docker network, use `http://headscale:8080`.
   - API key: paste the token from step 2.
5) Reload the page and retry; the UI stores `headscaleURL` and `headscaleAPIKey` in your browser’s localStorage. If you still see 401s, verify the URL is reachable and the key is valid/unexpired.

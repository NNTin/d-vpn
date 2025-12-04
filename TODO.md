# D-VPN Local Development Plan

This document outlines the steps to set up a local development environment for D-VPN using Docker Compose. The initial focus is on getting the core components (Headscale, Keycloak, WireGuard) working together before building the Discord dashboard.

## Milestone 1: Local Environment Setup with Docker Compose

- [ ] **Create `docker-compose.yml`:**
    - [ ] Define a service for **Headscale**.
    - [ ] Define a service for **Keycloak**.
    - [ ] Define a service for a **WireGuard Server** (acting as the home node for local dev).
    - [ ] Add a service for a web UI for Headscale (e.g., `headscale-ui`) for easier development.
    - [ ] Configure a shared Docker network for inter-service communication.
    - [ ] **Note:** Ensure the WireGuard server is configured to allow connections from the Headscale network, and can route traffic to other services if needed.
- [ ] **Initial Configuration Files:**
    - [ ] Create a basic `headscale/config.yaml` to be mounted into the container.
    - [ ] Create directories for persistent data for Keycloak and Headscale.
    - [ ] Create necessary configuration for the WireGuard server (e.g., `wg0.conf`).
- [ ] **Launch Environment:**
    - [ ] Run `docker-compose up -d` and ensure all containers start correctly.
    - [ ] Document the default URLs and admin credentials for Keycloak and Headscale.

## Milestone 2: Core Services Configuration & Integration

- [ ] **Configure Headscale Admin:**
    - [ ] Access the Headscale container or UI.
    - [ ] Create an initial admin user/namespace.
- [ ] **Configure WireGuard "Home Node":**
    - [ ] Generate a pre-auth key in Headscale for the new user.
    - [ ] On your local machine (or a dedicated container), install WireGuard.
    - [ ] Use the pre-auth key to connect the WireGuard client to the Headscale container.
    - [ ] Verify the node appears in Headscale's admin UI.
- [ ] **Configure Keycloak Admin:**
    - [ ] Log in to the Keycloak admin console.
    - [ ] Create a new realm (e.g., `d-vpn`).
    - [ ] Create a new OIDC client within the realm specifically for Headscale.
- [ ] **Integrate Headscale with Keycloak:**
    - [ ] Update `headscale/config.yaml` with the OIDC provider details from Keycloak (issuer URL, client ID, client secret).
    - [ ] Restart the Headscale container to apply the new configuration.
    - [ ] Test the integration by attempting to register a new device with Headscale, which should now require authentication via the Keycloak login page.

## Milestone 3: Discord Dashboard Development (Future Phase)

*Once the local backend is fully integrated and tested, work can begin on the frontend.*

- [ ] **Develop Discord Bot Dashboard:** Create a simple web application for the user-facing dashboard.
- [ ] **Implement Discord OAuth2:** Add a "Login with Discord" feature.
- [ ] **Implement Guild/Role Verification:** After login, the dashboard must verify the user's Discord server membership and roles.
- [ ] **Integrate Dashboard with Keycloak:** After successful verification, redirect the user to Keycloak to complete the authentication and device registration flow with Headscale.

# D-VPN

**D-VPN** is a cloud-first, zero-trust VPN solution that allows secure access to a home network. It leverages:

- **Discord OAuth2** for user authentication
- **Keycloak** as an OIDC broker
- **Headscale** as a self-hosted Tailscale coordination server
- **WireGuard** for encrypted VPN tunnels
- **Raspberry Pi** as a home VPN node

This repository contains setup instructions and configurations for the Discord bot, Keycloak server, and Headscale coordination server.

---

## Table of Contents

- [Architecture](#architecture)  
- [Features](#features)  
- [Prerequisites](#prerequisites)  
- [Setup Instructions](#setup-instructions)  
  - [Discord Bot](#discord-bot)  
  - [Keycloak Server](#keycloak-server)  
  - [Headscale Coordination Server](#headscale-coordination-server)  
- [Sequence Diagram](#sequence-diagram)  
- [License](#license)  

---

## Architecture

```
User Device -> Keycloak (VPS) -> Discord OAuth2 -> Headscale (VPS) -> Raspberry Pi Home Node -> Home Network
```

1. Users authenticate via **Discord OAuth2** through **Keycloak**.  
2. Keycloak issues ephemeral tokens after successful authentication.  
3. Tokens are used to register devices with **Headscale**, which provides **WireGuard keys and gateway info**.  
4. Users establish **WireGuard VPN tunnels** to the Raspberry Pi home node.  
5. Secure access to LAN services (NAS, Home Assistant, Media Servers) is provided.  

---

## Features

- **Cloud-first authentication**: Login via Discord before discovering the home VPN node  
- **Zero-trust security**: Ephemeral credentials ensure only authorized devices can connect  
- **Hidden home network**: Raspberry Pi node is never exposed publicly  
- **Dynamic gateway discovery**: Headscale coordinates connections and distributes ephemeral WireGuard keys  
- **Multi-device support**: Secure access from laptops, desktops, or mobile devices  

---

## Prerequisites

- VPS for hosting **Keycloak** and **Headscale**  
- **Raspberry Pi** with WireGuard / Tailscale node installed at home  
- Discord account with a bot for OAuth2 authentication  
- Basic knowledge of Docker / systemd for service deployment  

---

## Setup Instructions

### Discord Bot

1. Create a new Discord bot via the [Discord Developer Portal](https://discord.com/developers/applications).  
2. Configure OAuth2 scopes: `identify` and `guilds`.  
3. Add the bot to your Discord server.  
4. Copy the **Client ID** and **Client Secret** for Keycloak integration.  

### Keycloak Server

1. Deploy Keycloak on your VPS (Docker or systemd).  
2. Configure Discord as an **Identity Provider** (OIDC/OAuth2) in Keycloak:  
   - Set client ID and secret from your Discord bot  
   - Set redirect URI to your Keycloak instance  
3. Configure realms, users, and roles as needed.  

### Headscale Coordination Server

1. Deploy Headscale on a cloud VPS.  
2. Configure OIDC authentication to accept tokens from Keycloak.  
3. Setup DERP servers or use public relays for NAT traversal.  
4. Register the Raspberry Pi node with Headscale.  
5. Configure WireGuard keys for clients and the home node.  

---

## Sequence Diagram

```mermaid
sequenceDiagram
    participant UserDevice as User Device
    participant Keycloak as Keycloak (VPS)
    participant Discord as Discord OAuth2
    participant Headscale as Headscale (VPS)
    participant HomePi as Raspberry Pi Home Node
    participant LAN as Home Network / LAN Services

    UserDevice->>Keycloak: Initiate login (OIDC)
    Keycloak->>Discord: OAuth2 login request
    Discord-->>UserDevice: Prompt for authentication
    UserDevice->>Discord: Submit credentials / approve
    Discord-->>Keycloak: OAuth2 token / identity info
    Keycloak-->>UserDevice: Issue ephemeral token / certificate

    UserDevice->>Headscale: Register device / request home node info (token)
    Headscale-->>UserDevice: Provide WireGuard keys and home node endpoint

    UserDevice->>HomePi: Establish WireGuard tunnel
    HomePi->>Headscale: Validate token (optional)
    Headscale-->>HomePi: Token valid

    UserDevice->>LAN: Access internal services
    LAN-->>UserDevice: Response over encrypted tunnel

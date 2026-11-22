# Deploying the API on Coolify with a Dockerfile

This repository contains the FastAPI backend only. Its Dockerfile builds the API image and includes FFmpeg for the transcode/remux endpoints. The container listens on **port 300**.

## Coolify setup

1. Create a new Coolify resource from the Git repository and select the root `Dockerfile` build method (do not select Docker Compose).
2. Set **Ports Exposes** to `300`. This is the container's internal listening port; Coolify routes your domain to it.
3. Attach your domain and enable HTTPS, then deploy. Open `https://your-domain/docs` for Swagger UI or `https://your-domain/openapi.json` for the OpenAPI schema.
4. You do not need to append `:300` to the public URL when Coolify's domain proxy is configured.

## Persistent history

The Dockerfile sets `HISTORY_FILE=/data/local_history.json`. In the Coolify resource's persistent storage settings, mount a persistent volume at `/data` if you want local history to survive redeploys or container replacement. Without that mount, history stored in the container filesystem may be lost. MovieBox login sessions are held in backend memory, so a backend restart may require users to sign in again.

## Operations and security

The image includes FFmpeg. External-player launch endpoints (VLC/MPV) execute in the server/container environment and cannot launch an application on a visitor's personal computer.

The API accepts MovieBox account credentials through its login route. Protect the public API with Coolify access protection or an external authentication layer, use HTTPS, and avoid exposing it without access controls. Use a dedicated MovieBox account if you choose to log in. Review the upstream project's terms and permissions before deployment; this setup does not grant additional MovieBox access or VIP features.

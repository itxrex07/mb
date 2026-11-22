# Deploying the API on Coolify

This repository runs the FastAPI backend only. There is no bundled web dashboard. The Docker image includes FFmpeg for the API's transcode/remux endpoints.

## Coolify setup

1. Create a **Docker Compose** resource from the repository and select the branch containing `docker-compose.yml`.
2. Set the exposed service to `api` on container port `8000`, attach your domain, and enable HTTPS.
3. Deploy. Once healthy, open `https://your-domain/docs` for Swagger UI or `https://your-domain/openapi.json` for the OpenAPI schema.
4. The Compose file uses an internal `expose` declaration; route public traffic to the `api` service through Coolify's proxy rather than adding a separate host port mapping.

## Persistence and operations

The named volume `moviebox_data` stores `/data/local_history.json`. MovieBox login sessions are held in backend memory, so a backend restart may require users to sign in again. Back up the named volume if you want to preserve local history.

The image includes FFmpeg. External-player launch endpoints (VLC/MPV) execute in the server/container environment and cannot launch an application on a visitor's personal computer.

## Security before public exposure

The API accepts MovieBox account credentials through its login route. Protect the public API with Coolify access protection or an external authentication layer, use HTTPS, and avoid exposing it without access controls. Use a dedicated MovieBox account if you choose to log in. Review the upstream project's terms and permissions before deployment; this setup does not grant additional MovieBox access or VIP features.

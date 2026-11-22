# Deploying on Coolify

This stack builds two containers from the repository: a FastAPI backend (with FFmpeg) and a Next.js dashboard. The dashboard is the only public service. It proxies `/api/*` requests to the internal `api:8000` service, so browser requests and MovieBox session cookies stay same-origin.

## Coolify setup

1. Push this modified repository to a Git provider you control, or upload/import the project into Coolify.
2. In Coolify, create a new **Docker Compose** resource and select the repository/branch containing `docker-compose.yml`.
3. Configure the resource's exposed service as `web` on container port `3000`, then attach your public domain and enable HTTPS.
4. Keep `api` internal; do not assign it a public domain or publish port `8000`.
5. Deploy. The backend health check must pass before the frontend starts.

No `NEXT_PUBLIC_API_BASE_URL` or `API_INTERNAL_URL` overrides are required for the default Compose network. The defaults are `/api` in the browser and `http://api:8000` inside the Compose network. If you change either value, rebuild the frontend image because Next.js embeds these settings at build time.

## Persistence and operations

The named volume `moviebox_data` stores the backend's `local_history.json`. MovieBox login sessions are held in backend memory, so a backend restart may require users to sign in again. Back up the named volume if you want to preserve local history.

The backend includes FFmpeg for the project's transcode/remux features. External-player launch buttons (VLC/MPV) target the server/container environment, not a visitor's personal computer, so those features are not expected to work as desktop launches when hosted remotely.

## Security before public exposure

This project accepts MovieBox account credentials through its login route. Restrict public access using Coolify's access protection or an external authentication layer, use HTTPS, and do not expose port `8000` directly. Use a dedicated MovieBox account if you choose to log in. Review the upstream project's code and terms before deployment; this Docker setup does not make upstream streams, account features, or VIP access available beyond what MovieBox authorizes.

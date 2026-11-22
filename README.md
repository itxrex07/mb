# MovieBox Internal API — Self-Hosted API Server

A FastAPI service for MovieBox/AOneRoom authentication, content discovery, playback, subtitles, history, and community endpoints. This repository contains the API backend only; it does not include a web dashboard.

## Quick start

### Run locally

Requirements: Python 3.10+ and FFmpeg (for H.265 transcode/remux features).

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python moviebox_api_server.py
```

When run directly with Python, the API listens on `http://localhost:8000`. Interactive Swagger docs are at `http://localhost:8000/docs` and the OpenAPI schema is at `http://localhost:8000/openapi.json`.

### Deploy on Coolify with the Dockerfile

Create a Coolify resource using the repository's root `Dockerfile` (not Docker Compose) and set **Ports Exposes** to `300`. The container listens on port 300; Coolify proxies your domain to it. Once deployed, Swagger UI is at `https://your-domain/docs`. For persistent local history, configure a Coolify persistent volume mounted at `/data`. See [`COOLIFY.md`](COOLIFY.md) for details.

### Optional: Run with Docker Compose

```bash
docker compose up --build -d
```

The Compose service listens on internal container port `300` and exposes it to Docker networks only; it does not publish a host port. For Coolify deployment, use the Dockerfile instructions above; Compose is optional.

Before exposing this API publicly, put it behind access controls and HTTPS. Its login route accepts MovieBox credentials.

---

## Architecture Overview

```
API client / Swagger UI
        │  HTTP REST calls
        ▼
FastAPI API Server (local Python: 8000; Docker container: 300)  ◄──► MovieBox/AOneRoom API servers
        │
        ├── /proxy-media  ───► CDN streams and subtitles
        ├── /play-compat  ───► FFmpeg H.265-to-H.264 transcode
        └── /download     ───► FFmpeg/HTTPX download or remux
```

### Key Components

| Component | File | Purpose |
|---|---|---|
| **Backend API Server** | `moviebox_api_server.py` | FastAPI application and endpoints |
| **MovieBox API Client** | `moviebox_api/client.py` | Signs and sends requests to AOneRoom |
| **Auth Module** | `moviebox_api/auth.py` | Login, session, and OTP operations |
| **Content Module** | `moviebox_api/content.py` | Home, search, detail, and episodes |
| **Stream Module** | `moviebox_api/stream.py` | Playback URL resolution and stream handling |
| **User Module** | `moviebox_api/user.py` | Profile, history, and watchlist |

---

## 📡 API Endpoints Reference

When running the server directly with Python, endpoints are served from `http://localhost:8000`; in the Docker image, the container listens on port `300`.

---

### 🔐 Authentication

#### `POST /login`
Authenticate with email/phone + password.

**Request Body (JSON):**
```json
{
  "account": "user@example.com",
  "password": "yourpassword",
  "authType": 1
}
```
**Response:**
```json
{
  "status": "success",
  "user": { "nickname": "...", "avatar": "..." }
}
```
> Sets a `session_id` cookie on success. All subsequent requests must include this cookie.

---

#### `POST /register`
Create a new MovieBox account.

**Request Body (JSON):**
```json
{
  "account": "user@example.com",
  "password": "yourpassword",
  "otp": "123456",
  "authType": 1
}
```

---

#### `POST /request-otp`
Send a verification code to email/phone.

**Request Body (JSON):**
```json
{
  "account": "user@example.com",
  "authType": 1,
  "type": 1
}
```
> `type`: `1` = Register, `2` = Login

---

#### `POST /logout`
Invalidate the current session.

---

#### `GET /user-info`
Get the currently logged-in user's profile.

**Response:**
```json
{
  "logged_in": true,
  "user": { "nickname": "...", "avatar": "...", "email": "..." }
}
```

---

### 🏠 Content Discovery

#### `GET /home`
Fetch the main home feed with curated content sections.

**Response:**
```json
{
  "data": {
    "list": [
      {
        "title": "Trending Now",
        "type": "movies",
        "items": [ { "subjectId": "...", "title": "...", "cover": "..." } ]
      }
    ]
  }
}
```

---

#### `GET /anime`
Fetch anime content section.

---

#### `GET /rankings`
Fetch movie/series rankings.

---

#### `GET /discovery`
Fetch the "Discovery" / "For You" feed.

---

#### `GET /trending`
Fetch trending content.

---

#### `GET /movies`
Fetch the movies section.

---

#### `GET /search-suggestions?q={query}`
Get search autocomplete suggestions.

**Query Params:**
| Param | Default | Description |
|---|---|---|
| `q` | `""` | Partial search query |

---

#### `GET /search?q={query}`
Full-text search for movies and series.

**Query Params:**
| Param | Type | Description |
|---|---|---|
| `q` | string | Search query |

---

### 🎬 Content Detail

#### `GET /detail/{subject_id}`
Get full metadata for a movie or series.

**Response:**
```json
{
  "code": 0,
  "data": {
    "title": "Classroom of the Elite",
    "subjectId": "123456",
    "subjectType": 2,
    "cover": "https://...",
    "poster": "https://...",
    "score": "9.1",
    "runtime": "24",
    "releaseTime": "2022",
    "description": "...",
    "cast": [ { "name": "...", "role": "...", "avatar": "..." } ],
    "related": [ { "subjectId": "...", "title": "..." } ],
    "likeStatus": 1
  }
}
```

> `subjectType`: `1` = Movie, `2` = Series/Anime

---

#### `GET /episodes/{series_id}`
Get full season and episode list for a series.

**Response:**
```json
{
  "data": {
    "seasons": [
      {
        "seasonNumber": 1,
        "episodes": [
          { "episodeNumber": 1, "title": "Episode 1" }
        ]
      }
    ]
  }
}
```

---

### ▶️ Playback

#### `GET /stream/{subject_id}?season=1&episode=1&quality=720P`
Resolve the playback URL for a movie or episode.

**Query Params:**
| Param | Default | Description |
|---|---|---|
| `season` | `1` | Season number |
| `episode` | `1` | Episode number |
| `quality` | `720p` | Stream quality (360p, 480p, 720p, 1080p) |

**Response (Standard H.264 stream):**
```json
{
  "url": "https://cdn.example.com/video.mp4",
  "quality": "720P",
  "cookie": "signCookie=...",
  "subtitles": [ { "lanName": "English", "url": "..." } ],
  "streamId": "..."
}
```

**Response (Auto-transcoded H.265 stream):**
```json
{
  "url": "http://localhost:8000/play-compat/{subject_id}?season=1&episode=1&quality=720P",
  "cookie": "",
  "isTranscoded": true,
  "runtime": "24"
}
```

> When `isTranscoded: true`, API clients can use the returned `play-compat` URL to stream through the FFmpeg transcode pipe.

---

#### `GET /play-compat/{subject_id}?season=1&episode=1&quality=720P&start_time=0`
**FFMPEG Live Transcode Pipe** — converts HEVC/H.265 to browser-native H.264 fMP4.

Streams video directly to the browser. Supports `HEAD` requests for range negotiation.

**Query Params:**
| Param | Default | Description |
|---|---|---|
| `season` | `1` | Season number |
| `episode` | `1` | Episode number |
| `quality` | `720P` | Quality level |
| `start_time` | `0` | Seek to this second before transcoding |

> **This endpoint requires FFMPEG to be installed** and in the system PATH.

---

#### `GET /proxy-media?url={url}&cookie={cookie}`
Universal media proxy. Forwards any CDN URL through the local server to bypass CORS restrictions.

- Auto-rewrites `.m3u8` HLS manifests to route segments through the proxy
- Converts `.srt` subtitles to WebVTT on the fly
- Adds `Access-Control-Allow-Origin: *` to all responses

**Query Params:**
| Param | Description |
|---|---|
| `url` | The CDN media URL to proxy (URL-encoded) |
| `cookie` | The `signCookie` from the stream response |
| `start_time` | (optional) Resume timestamp in seconds |

---

#### `GET /download/{subject_id}?season=1&episode=1&quality=720P&title=Movie`
Download a movie or episode file to disk.

- For MP4 streams: proxies raw bytes with correct headers (browser native download)
- For DASH/HLS streams: uses FFMPEG to remux to `.ts` and pipes to the browser

**Query Params:**
| Param | Default | Description |
|---|---|---|
| `season` | `1` | Season number |
| `episode` | `1` | Episode number |
| `quality` | `720p` | Quality level |
| `title` | `Movie` | Filename prefix for the download |

---

### 📝 Subtitles

#### `GET /subtitles/{subject_id}?se=1&ep=1`
Get subtitle tracks for a movie or episode.

**Response:**
```json
{
  "data": {
    "list": [
      { "id": "...", "lanName": "English", "url": "https://cdn.../sub.srt" }
    ]
  }
}
```

---

#### `GET /subtitles/stream/{stream_id}`
Get subtitles linked to a specific stream ID.

---

#### `GET /subtitles/external/{subject_id}?episode=1`
Fetch extended community captions from the official extended subtitles API.

---

#### `GET /subtitles/search?q={title}&season=1&episode=1`
Search OpenSubtitles for matching subtitle tracks.

---

### 📚 History & Watchlist

#### `GET /history`
Get the user's complete watch history.

**Response:**
```json
{
  "data": { "list": [ { "subjectId": "...", "title": "...", "seeTime": 1234 } ] }
}
```

---

#### `GET /watchlist`
Get the user's watchlist ("Want to Watch" list).

---

#### `POST /watchlist/toggle`
Add or remove a title from the watchlist.

**Query Params:**
| Param | Type | Description |
|---|---|---|
| `subject_id` | string | The movie/series ID |
| `add` | bool | `true` to add, `false` to remove |
| `subject_type` | int | `1` = Movie, `2` = Series |

---

#### `GET /history/position?subject_id={id}&stream_id={id}`
Get the saved playback position for a specific stream.

---

#### `POST /history/position`
Save a playback position.

**Query Params:**
| Param | Type | Description |
|---|---|---|
| `subject_id` | string | Movie/series ID |
| `stream_id` | string | Stream ID from `/stream` response |
| `position_ms` | int | Position in milliseconds |

---

#### `POST /history/seen`
Mark a subject as "have seen".

---

#### `POST /history/delete/{subject_id}`
Delete a specific item from watch history.

---

#### `POST /history/progress`
Report full playback progress (used for "Continue Watching" sync).

**Request Body (JSON):**
```json
{
  "subject_id": "...",
  "progress_ms": 150000,
  "total_ms": 1440000,
  "status": 1
}
```

---

### 📺 External Players

#### `POST /launch-player?player=mpv&url=...&cookie=...`
Launch MPV or VLC with the stream URL and subtitle file.

**Query Params:**
| Param | Default | Description |
|---|---|---|
| `player` | `mpv` | `mpv` or `vlc` |
| `url` | required | Stream URL |
| `cookie` | `""` | Authentication cookie |
| `start_time` | `0` | Resume timestamp in seconds |
| `subtitle_url` | `""` | Path or URL to subtitle file |
| `duration` | `0` | Total duration in seconds (for MPV timeline) |
| `title` | `""` | Media title shown in player |
| `subject_id` | `""` | Used to sync history |

---

### 💬 Community / Posts

#### `GET /post/list/{subject_id}`
Get community discussion posts for a movie/series.

#### `POST /post/create`
Post a review/comment.

**Query Params:**
| Param | Description |
|---|---|
| `subject_id` | The movie ID |
| `content` | Text content of the post |

#### `POST /post/like`
Like a post.

#### `GET /post/count/{subject_id}`
Get the total post count for a title.

#### `GET /groups/trending`
Get trending community groups.

#### `GET /groups/interactive`
Get interactive groups.

---

## 🛠️ Troubleshooting

### Stream or download fails

- Check the API container logs for errors on `/stream`, `/download`, or `/play-compat`.
- Confirm FFmpeg is installed in the image with `ffmpeg -version`.
- Some remote streams may be unavailable or may change independently of this API.

### History is not retained after restart

For Coolify Dockerfile deployment, mount persistent storage at `/data`. Compose instead mounts the `moviebox_data` volume there. Keep `HISTORY_FILE` set to `/data/local_history.json`.

### VLC/MPV does not open

The launch endpoint runs in the server/container environment. It cannot open a media player on the visitor's computer.

---

## 📦 Tech Stack

| Layer | Technology |
|---|---|
| API Framework | FastAPI |
| HTTP Client | HTTPX (async) |
| Runtime | Python 3.12 in Docker |
| Transcoding/remuxing | FFmpeg |
| Authentication | Cookie-based API sessions |

---

## Star History

<a href="https://www.star-history.com/?repos=solo12345689%2Fmoviebox-internal-api&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=solo12345689/moviebox-internal-api&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=solo12345689/moviebox-internal-api&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=solo12345689/moviebox-internal-api&type=date&legend=top-left" />
 </picture>
</a>

## 📁 Project Structure

```
.
├── moviebox_api/
│   ├── auth.py
│   ├── client.py
│   ├── content.py
│   ├── models.py
│   ├── stream.py
│   ├── user.py
│   └── utils.py
├── moviebox_api_server.py
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
├── COOLIFY.md
└── README.md
```

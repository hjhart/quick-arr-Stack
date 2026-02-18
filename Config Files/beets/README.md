# Soulseek to Plex Music Pipeline

This setup allows you to download music from Soulseek (via slskd) and automatically import it into your Plex library using beets.

## How It Works

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   slskd     │────▶│   beets     │────▶│    Plex     │
│  (download) │     │  (organize) │     │  (playback) │
└─────────────┘     └─────────────┘     └─────────────┘
     │                    │                    │
     ▼                    │                    ▼
 /Downloads         (hard links)      /Completed/Music
```

**Key features:**
- **Hard linking**: Files stay in the Downloads folder for continued seeding while appearing in your Plex library
- **Automated tagging**: Beets matches music against MusicBrainz for proper metadata
- **Album art**: Automatically fetches and embeds album artwork
- **Daily imports**: Cron job runs at 3:00 AM to import new downloads

## Setup

### 1. Copy Config Files

Copy the beets configuration to your MediaCenter config directory:

```bash
cp -r "Config Files/beets" "${ROOT}/MediaCenter/config/"
```

### 2. Start the Container

```bash
docker-compose up -d beets
```

### 3. Initial Setup (Optional)

The container will automatically set up cron. You can verify it's working:

```bash
docker exec beets crontab -l
```

## Usage

### Manual Import

To immediately import music without waiting for the cron job:

```bash
# Import all new music from the last 24 hours
docker exec beets /scripts/import-music.sh

# Or import a specific directory
docker exec -it beets beet import /downloads/Artist\ -\ Album

# Interactive import (for better matching)
docker exec -it beets beet import /downloads/Artist\ -\ Album
```

### Check Import Logs

```bash
docker exec beets cat /config/cron-import.log
```

### Query Your Library

```bash
# List all albums
docker exec beets beet ls -a

# Search for an artist
docker exec beets beet ls artist:Beatles

# Show library stats
docker exec beets beet stats
```

### Re-import with Different Settings

If an import didn't match well:

```bash
# Remove from beets library (keeps files)
docker exec beets beet remove "album_name"

# Re-import interactively
docker exec -it beets beet import /downloads/path/to/album
```

## Configuration

### Beets Config: `config/beets/config.yaml`

Key settings you might want to adjust:

```yaml
# Change to copy instead of hardlink (uses more disk space)
import:
  hardlink: no
  copy: yes

# Adjust matching threshold (lower = more lenient)
match:
  strong_rec_thresh: 0.04

# Disable auto-import features
plugins: []  # Remove plugins you don't want
```

### Cron Schedule: `config/beets/crontab`

Default: Daily at 3:00 AM

```cron
# Every 6 hours instead
0 */6 * * * /scripts/import-music.sh

# Every hour
0 * * * * /scripts/import-music.sh
```

After changing, restart the container:
```bash
docker-compose restart beets
```

## Troubleshooting

### Files Not Being Hard Linked

Hard links only work when source and destination are on the same filesystem. Verify:

```bash
# Check if on same mount
docker exec beets df /downloads /music
```

If different filesystems, change config to use `copy: yes` instead.

### Import Not Finding Files

Check that slskd downloads are going to the right place:

```bash
# List downloads directory
docker exec beets ls -la /downloads
```

### Beets Not Matching Music

For difficult matches, use interactive mode:

```bash
docker exec -it beets beet import /downloads/album
```

Then choose from the presented options.

### Check Container Logs

```bash
docker logs beets
```

## Volume Paths

| Container | Mount Point | Host Path |
|-----------|-------------|-----------|
| slskd | /app/downloads | ${HDDSTORAGE}/Downloads |
| beets | /downloads | ${HDDSTORAGE}/Downloads |
| beets | /music | ${HDDSTORAGE}/Completed/Music |
| plex | /MediaCenterBox | ${HDDSTORAGE}/Completed |

Both slskd downloads and beets use the same `${HDDSTORAGE}` volume, enabling hard links.

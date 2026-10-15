#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/agility-shell/weather"
CACHE_FILE="$CACHE_DIR/weather_data.json"
mkdir -p "$CACHE_DIR"

FORCE_REFRESH="${1:-}"

# Return cache if fresher than 15 minutes (900 seconds)
if [[ "$FORCE_REFRESH" != "--force" && -f "$CACHE_FILE" ]]; then
    now=$(date +%s)
    mod=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
    if (( now - mod < 900 )); then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# Geolocation lookup with timeout
GEO_JSON=$(curl -s --max-time 3 "https://ipwho.is/" 2>/dev/null || true)
CITY=""
LAT=""
LON=""

if [[ -n "$GEO_JSON" ]]; then
    CITY=$(echo "$GEO_JSON" | jq -r '.city // empty' 2>/dev/null || true)
    LAT=$(echo "$GEO_JSON" | jq -r '.latitude // empty' 2>/dev/null || true)
    LON=$(echo "$GEO_JSON" | jq -r '.longitude // empty' 2>/dev/null || true)
fi

if [[ -z "$LAT" || -z "$LON" ]]; then
    GEO_FALLBACK=$(curl -s --max-time 3 "https://ipapi.co/json/" 2>/dev/null || true)
    if [[ -n "$GEO_FALLBACK" ]]; then
        CITY=$(echo "$GEO_FALLBACK" | jq -r '.city // empty' 2>/dev/null || true)
        LAT=$(echo "$GEO_FALLBACK" | jq -r '.latitude // empty' 2>/dev/null || true)
        LON=$(echo "$GEO_FALLBACK" | jq -r '.longitude // empty' 2>/dev/null || true)
    fi
fi

if [[ -z "$LAT" || -z "$LON" ]]; then
    if [[ -f "$CACHE_FILE" ]]; then
        cat "$CACHE_FILE"
        exit 0
    fi
    echo '{"error": "geolocation_failed", "city": "Unknown", "temperature": 22, "apparent_temperature": 22, "humidity": 50, "wind_speed": 5, "weather_code": 0, "daily": []}'
    exit 0
fi

[[ -z "$CITY" ]] && CITY="Local"

FORECAST_JSON=$(curl -s --max-time 4 "https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto" 2>/dev/null || true)

if [[ -z "$FORECAST_JSON" || "$(echo "$FORECAST_JSON" | jq -r '.error // empty' 2>/dev/null)" == "true" ]]; then
    if [[ -f "$CACHE_FILE" ]]; then
        cat "$CACHE_FILE"
        exit 0
    fi
    echo '{"error": "forecast_failed", "city": "'"$CITY"'", "temperature": 22, "apparent_temperature": 22, "humidity": 50, "wind_speed": 5, "weather_code": 0, "daily": []}'
    exit 0
fi

OUTPUT=$(echo "$FORECAST_JSON" | jq --arg city "$CITY" '. as $root | {
    city: $city,
    temperature: ($root.current.temperature_2m | round),
    apparent_temperature: ($root.current.apparent_temperature | round),
    humidity: $root.current.relative_humidity_2m,
    wind_speed: ($root.current.wind_speed_10m | round),
    weather_code: $root.current.weather_code,
    daily: [
        range(0; 3) | {
            date: $root.daily.time[.],
            code: $root.daily.weather_code[.],
            max: ($root.daily.temperature_2m_max[.] | round),
            min: ($root.daily.temperature_2m_min[.] | round)
        }
    ]
}' 2>/dev/null || true)

if [[ -n "$OUTPUT" ]]; then
    echo "$OUTPUT" > "$CACHE_FILE"
    cat "$CACHE_FILE"
elif [[ -f "$CACHE_FILE" ]]; then
    cat "$CACHE_FILE"
else
    echo '{"error": "parse_failed", "city": "'"$CITY"'", "temperature": 22, "apparent_temperature": 22, "humidity": 50, "wind_speed": 5, "weather_code": 0, "daily": []}'
fi

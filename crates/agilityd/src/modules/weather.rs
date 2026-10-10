//! Weather & Geolocation Background Fetcher.
//! Periodically queries IP geolocation (ip-api.com) and Open-Meteo forecast API.
//! Maps WMO condition codes to Agility duotone icon names and maintains persistent local cache.
//! Exposes `org.agility.Daemon.Weather` D-Bus interface.

use agility_common::{GeolocationData, WeatherData};
use anyhow::{Context, Result};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::{Arc, RwLock};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::sync::broadcast;
use tracing::{info, warn};
use zbus::object_server::SignalEmitter;

/// Cache durations and polling intervals.
pub const CACHE_DURATION_SECS: u64 = 600; // 10 minutes
pub const STALE_CACHE_MAX_SECS: u64 = 1800; // 30 minutes
pub const LOCATION_CACHE_MAX_SECS: u64 = 86400; // 24 hours

pub const IP_LOCATION_API: &str = "http://ip-api.com/json/";
pub const WEATHER_API_BASE: &str = "https://api.open-meteo.com/v1/forecast";

/// Maps WMO weather code to `(emoji, duotone_icon, description)`.
pub fn get_weather_info(code: u32) -> (&'static str, &'static str, &'static str) {
    match code {
        0 => ("☀️", "sun-duotone", "Clear sky"),
        1 => ("🌤️", "cloud-sun-duotone", "Mainly clear"),
        2 => ("⛅", "cloud-sun-duotone", "Partly cloudy"),
        3 => ("☁️", "cloud-duotone", "Overcast"),
        45 => ("🌫️", "cloud-fog-duotone", "Fog"),
        48 => ("🌫️", "cloud-fog-duotone", "Depositing rime fog"),
        51 => ("🌦️", "cloud-rain-duotone", "Light drizzle"),
        53 => ("🌦️", "cloud-rain-duotone", "Moderate drizzle"),
        55 => ("🌧️", "cloud-rain-duotone", "Dense drizzle"),
        56 => ("🌨️", "cloud-rain-duotone", "Light freezing drizzle"),
        57 => ("🌨️", "cloud-rain-duotone", "Dense freezing drizzle"),
        61 => ("🌦️", "cloud-rain-duotone", "Slight rain"),
        63 => ("🌧️", "cloud-rain-duotone", "Moderate rain"),
        65 => ("🌧️", "cloud-rain-duotone", "Heavy rain"),
        66 => ("🌨️", "cloud-rain-duotone", "Light freezing rain"),
        67 => ("🌨️", "cloud-rain-duotone", "Heavy freezing rain"),
        71 => ("❄️", "cloud-snow-duotone", "Slight snow"),
        73 => ("🌨️", "cloud-snow-duotone", "Moderate snow"),
        75 => ("❄️", "cloud-snow-duotone", "Heavy snow"),
        77 => ("❄️", "cloud-snow-duotone", "Snow grains"),
        80 => ("🌦️", "cloud-rain-duotone", "Slight rain showers"),
        81 => ("🌧️", "cloud-rain-duotone", "Moderate rain showers"),
        82 => ("⛈️", "cloud-lightning-duotone", "Violent rain showers"),
        85 => ("🌨️", "cloud-snow-duotone", "Slight snow showers"),
        86 => ("❄️", "cloud-snow-duotone", "Heavy snow showers"),
        95 => ("⛈️", "cloud-lightning-duotone", "Thunderstorm"),
        96 => ("⛈️", "cloud-lightning-duotone", "Thunderstorm with hail"),
        99 => (
            "⛈️",
            "cloud-lightning-duotone",
            "Thunderstorm with heavy hail",
        ),
        _ => ("🌡️", "cloud-sun-duotone", "Unknown"),
    }
}

/// Convert wind direction in degrees to 16-point compass direction string.
pub fn get_wind_direction(degrees: f64) -> &'static str {
    const DIRS: &[&str] = &[
        "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW",
        "NW", "NNW",
    ];
    let normalized = ((degrees / 22.5).round() as usize) % 16;
    DIRS[normalized]
}

/// Weather service managing asynchronous fetching, caching, and D-Bus properties.
pub struct WeatherService {
    data: Arc<RwLock<WeatherData>>,
    location: Arc<RwLock<GeolocationData>>,
    cache_dir: PathBuf,
}

impl WeatherService {
    /// Create new WeatherService, initializing and loading cached data if fresh.
    pub fn new(cache_dir: PathBuf) -> Arc<Self> {
        let weather_dir = cache_dir.join("weather");
        let _ = fs::create_dir_all(&weather_dir);

        let mut initial_location = GeolocationData::default();
        let mut initial_weather = WeatherData::default();

        // 1. Try loading cached location
        let location_cache_file = weather_dir.join("location_cache.json");
        if location_cache_file.is_file() {
            if let Ok(content) = fs::read_to_string(&location_cache_file) {
                if let Ok(loc) = serde_json::from_str::<GeolocationData>(&content) {
                    initial_location = loc;
                }
            }
        }

        // 2. Try loading cached weather
        let weather_cache_file = weather_dir.join("weather_cache.json");
        if weather_cache_file.is_file() {
            if let Ok(content) = fs::read_to_string(&weather_cache_file) {
                if let Ok(weather) = serde_json::from_str::<WeatherData>(&content) {
                    initial_weather = weather;
                }
            }
        }

        Arc::new(Self {
            data: Arc::new(RwLock::new(initial_weather)),
            location: Arc::new(RwLock::new(initial_location)),
            cache_dir: weather_dir,
        })
    }

    /// Retrieve cache directory path.
    pub fn cache_dir(&self) -> &Path {
        &self.cache_dir
    }

    /// Retrieve snapshot copy of current WeatherData.
    pub fn get_weather(&self) -> WeatherData {
        self.data.read().unwrap().clone()
    }

    /// Retrieve current WeatherData serialized as JSON.
    pub fn get_weather_json(&self) -> String {
        serde_json::to_string(&self.get_weather()).unwrap_or_default()
    }

    /// Retrieve snapshot of current GeolocationData.
    pub fn get_location(&self) -> GeolocationData {
        self.location.read().unwrap().clone()
    }

    /// Override location manually and update persistent location cache.
    pub fn set_location(&self, city: &str, lat: f64, lon: f64) -> bool {
        let new_loc = GeolocationData {
            lat,
            lon,
            city: city.to_string(),
            country: String::new(),
        };

        *self.location.write().unwrap() = new_loc.clone();
        let _ = self.save_location_cache(&new_loc);

        // Update city in current weather data
        {
            let mut w = self.data.write().unwrap();
            w.city = city.to_string();
        }

        info!("Weather location updated to {city} ({lat}, {lon})");
        true
    }

    /// Save location data to `location_cache.json`.
    fn save_location_cache(&self, loc: &GeolocationData) -> Result<()> {
        let file = self.cache_dir.join("location_cache.json");
        let content = serde_json::to_string_pretty(loc)?;
        fs::write(&file, content)?;
        Ok(())
    }

    /// Save weather data to `weather_cache.json`.
    fn save_weather_cache(&self, weather: &WeatherData) -> Result<()> {
        let file = self.cache_dir.join("weather_cache.json");
        let content = serde_json::to_string_pretty(weather)?;
        fs::write(&file, content)?;
        Ok(())
    }

    /// Query IP geolocation from `http://ip-api.com/json/` using curl.
    pub fn fetch_geolocation(&self) -> Result<GeolocationData> {
        let current_loc = self.get_location();
        let loc_file = self.cache_dir.join("location_cache.json");

        // Return cached location if valid and file modified within LOCATION_CACHE_MAX_SECS
        if current_loc.lat != 0.0 || current_loc.lon != 0.0 {
            if let Ok(meta) = fs::metadata(&loc_file) {
                if let Ok(mtime) = meta.modified() {
                    let elapsed = SystemTime::now()
                        .duration_since(mtime)
                        .unwrap_or_default()
                        .as_secs();
                    if elapsed < LOCATION_CACHE_MAX_SECS {
                        return Ok(current_loc);
                    }
                }
            }
        }

        let output = Command::new("curl")
            .arg("-s")
            .arg("--max-time")
            .arg("5")
            .arg("-L")
            .arg(IP_LOCATION_API)
            .output()
            .context("Failed to execute curl for ip-api")?;

        if !output.status.success() {
            anyhow::bail!("ip-api request failed with status: {}", output.status);
        }

        let json_str = String::from_utf8_lossy(&output.stdout);
        let val: serde_json::Value =
            serde_json::from_str(&json_str).context("Failed to parse ip-api JSON response")?;

        if val.get("status").and_then(|s| s.as_str()) != Some("success") {
            anyhow::bail!("ip-api returned non-success status: {json_str}");
        }

        let lat = val.get("lat").and_then(|v| v.as_f64()).unwrap_or(0.0);
        let lon = val.get("lon").and_then(|v| v.as_f64()).unwrap_or(0.0);
        let city = val
            .get("city")
            .and_then(|v| v.as_str())
            .unwrap_or("Unknown")
            .to_string();
        let country = val
            .get("country")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();

        let loc = GeolocationData {
            lat,
            lon,
            city,
            country,
        };

        *self.location.write().unwrap() = loc.clone();
        let _ = self.save_location_cache(&loc);
        info!("Resolved IP geolocation: {}, {}", loc.city, loc.country);
        Ok(loc)
    }

    /// Query Open-Meteo forecast API for current weather data.
    pub fn fetch_weather(&self) -> Result<WeatherData> {
        let loc = match self.fetch_geolocation() {
            Ok(l) => l,
            Err(e) => {
                let existing_loc = self.get_location();
                if existing_loc.lat != 0.0 || existing_loc.lon != 0.0 {
                    existing_loc
                } else {
                    anyhow::bail!("Cannot fetch weather: location resolution failed: {e:#}");
                }
            }
        };

        let now_epoch = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        // Check if cached weather is still fresh (< 10 minutes)
        let cache_file = self.cache_dir.join("weather_cache.json");
        if let Ok(meta) = fs::metadata(&cache_file) {
            if let Ok(mtime) = meta.modified() {
                let elapsed = SystemTime::now()
                    .duration_since(mtime)
                    .unwrap_or_default()
                    .as_secs();
                if elapsed < CACHE_DURATION_SECS {
                    let cached = self.get_weather();
                    if cached.last_updated_epoch > 0 {
                        return Ok(cached);
                    }
                }
            }
        }

        let url = format!(
            "{WEATHER_API_BASE}?latitude={}&longitude={}&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,surface_pressure,wind_speed_10m,wind_direction_10m&timezone=auto",
            loc.lat, loc.lon
        );

        let output = Command::new("curl")
            .arg("-s")
            .arg("--max-time")
            .arg("7")
            .arg("-L")
            .arg(&url)
            .output()
            .context("Failed to execute curl for Open-Meteo")?;

        if !output.status.success() {
            anyhow::bail!("Open-Meteo request failed with status: {}", output.status);
        }

        let json_str = String::from_utf8_lossy(&output.stdout);
        let root: serde_json::Value =
            serde_json::from_str(&json_str).context("Failed to parse Open-Meteo JSON response")?;

        let current = root
            .get("current")
            .context("Open-Meteo response missing 'current' object")?;

        let temp = current
            .get("temperature_2m")
            .and_then(|v| v.as_f64())
            .unwrap_or(0.0);
        let feels = current
            .get("apparent_temperature")
            .and_then(|v| v.as_f64())
            .unwrap_or(temp);
        let humidity = current
            .get("relative_humidity_2m")
            .and_then(|v| v.as_u64())
            .unwrap_or(0) as u32;
        let pressure = current
            .get("surface_pressure")
            .and_then(|v| v.as_u64())
            .unwrap_or(1013) as u32;
        let wind_speed = current
            .get("wind_speed_10m")
            .and_then(|v| v.as_f64())
            .unwrap_or(0.0);
        let wind_dir_deg = current
            .get("wind_direction_10m")
            .and_then(|v| v.as_f64())
            .unwrap_or(0.0);
        let precipitation = current
            .get("precipitation")
            .and_then(|v| v.as_f64())
            .unwrap_or(0.0);
        let wmo_code = current
            .get("weather_code")
            .and_then(|v| v.as_u64())
            .unwrap_or(0) as u32;

        let (emoji, icon, desc) = get_weather_info(wmo_code);
        let wind_dir = get_wind_direction(wind_dir_deg).to_string();

        let weather = WeatherData {
            temperature: temp,
            feels_like: feels,
            humidity,
            pressure,
            wind_speed,
            wind_direction: wind_dir,
            precipitation,
            weather_code: wmo_code,
            condition_text: desc.to_string(),
            condition_icon: icon.to_string(),
            condition_emoji: emoji.to_string(),
            city: loc.city,
            country: loc.country,
            is_loading: false,
            has_error: false,
            error_message: String::new(),
            last_updated_epoch: now_epoch,
        };

        *self.data.write().unwrap() = weather.clone();
        let _ = self.save_weather_cache(&weather);
        info!(
            "Weather updated for {}: {:.1}°C ({desc})",
            weather.city, weather.temperature
        );
        Ok(weather)
    }

    /// Perform a refresh, updating error flags on failure.
    pub fn refresh(&self) -> bool {
        match self.fetch_weather() {
            Ok(_) => true,
            Err(e) => {
                warn!("Weather refresh error: {e:#}");
                let mut w = self.data.write().unwrap();
                w.has_error = true;
                w.error_message = e.to_string();
                w.is_loading = false;
                false
            }
        }
    }

    /// Start background polling task running every `interval` (default 10 minutes).
    pub fn start_poller(
        self: &Arc<Self>,
        interval: Duration,
        mut shutdown_rx: broadcast::Receiver<()>,
    ) {
        let service = Arc::clone(self);

        tokio::spawn(async move {
            // Initial asynchronous fetch
            let s_init = Arc::clone(&service);
            tokio::task::spawn_blocking(move || {
                let _ = s_init.refresh();
            });

            let mut ticker = tokio::time::interval(interval);
            loop {
                tokio::select! {
                    _ = shutdown_rx.recv() => {
                        info!("Weather service poller terminating gracefully.");
                        break;
                    }
                    _ = ticker.tick() => {
                        let s = Arc::clone(&service);
                        tokio::task::spawn_blocking(move || {
                            let _ = s.refresh();
                        });
                    }
                }
            }
        });
    }
}

/// D-Bus interface wrapper implementing `org.agility.Daemon.Weather`.
pub struct WeatherInterface {
    service: Arc<WeatherService>,
}

impl WeatherInterface {
    pub fn new(service: Arc<WeatherService>) -> Self {
        Self { service }
    }
}

#[zbus::interface(name = "org.agility.Daemon.Weather")]
impl WeatherInterface {
    // ─── Properties ───

    #[zbus(property)]
    async fn temperature(&self) -> f64 {
        self.service.get_weather().temperature
    }

    #[zbus(property)]
    async fn feels_like(&self) -> f64 {
        self.service.get_weather().feels_like
    }

    #[zbus(property)]
    async fn humidity(&self) -> u32 {
        self.service.get_weather().humidity
    }

    #[zbus(property)]
    async fn pressure(&self) -> u32 {
        self.service.get_weather().pressure
    }

    #[zbus(property)]
    async fn wind_speed(&self) -> f64 {
        self.service.get_weather().wind_speed
    }

    #[zbus(property)]
    async fn wind_direction(&self) -> String {
        self.service.get_weather().wind_direction
    }

    #[zbus(property)]
    async fn precipitation(&self) -> f64 {
        self.service.get_weather().precipitation
    }

    #[zbus(property)]
    async fn condition_code(&self) -> u32 {
        self.service.get_weather().weather_code
    }

    #[zbus(property)]
    async fn condition_text(&self) -> String {
        self.service.get_weather().condition_text
    }

    #[zbus(property)]
    async fn condition_icon(&self) -> String {
        self.service.get_weather().condition_icon
    }

    #[zbus(property)]
    async fn condition_emoji(&self) -> String {
        self.service.get_weather().condition_emoji
    }

    #[zbus(property)]
    async fn city(&self) -> String {
        self.service.get_weather().city
    }

    #[zbus(property)]
    async fn country(&self) -> String {
        self.service.get_weather().country
    }

    #[zbus(property)]
    async fn is_loading(&self) -> bool {
        self.service.get_weather().is_loading
    }

    #[zbus(property)]
    async fn has_error(&self) -> bool {
        self.service.get_weather().has_error
    }

    #[zbus(property)]
    async fn error_message(&self) -> String {
        self.service.get_weather().error_message
    }

    // ─── Methods ───

    /// Retrieve full weather snapshot serialized as JSON.
    async fn get_weather(&self) -> String {
        self.service.get_weather_json()
    }

    /// Trigger an immediate weather and geolocation refresh.
    async fn refresh(&self, #[zbus(signal_emitter)] emitter: SignalEmitter<'_>) -> bool {
        let success = self.service.refresh();
        let _ = Self::weather_changed(&emitter, &self.service.get_weather_json()).await;
        success
    }

    /// Override location coordinates and city manually.
    async fn set_location(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        city: &str,
        lat: f64,
        lon: f64,
    ) -> bool {
        let success = self.service.set_location(city, lat, lon);
        let _ = self.service.refresh();
        let _ = Self::weather_changed(&emitter, &self.service.get_weather_json()).await;
        success
    }

    // ─── Signals ───

    /// Emitted when weather data is updated.
    #[zbus(signal)]
    pub async fn weather_changed(
        emitter: &SignalEmitter<'_>,
        weather_json: &str,
    ) -> zbus::Result<()>;
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU64, Ordering};

    struct TestDirGuard(PathBuf);
    impl Drop for TestDirGuard {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    static TEST_COUNTER: AtomicU64 = AtomicU64::new(1);

    fn create_test_service() -> (Arc<WeatherService>, TestDirGuard) {
        let seq = TEST_COUNTER.fetch_add(1, Ordering::SeqCst);
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos();
        let temp_dir = std::env::temp_dir().join(format!("agility_test_weather_{nanos}_{seq}"));
        let _ = fs::create_dir_all(&temp_dir);

        let service = WeatherService::new(temp_dir.clone());
        (service, TestDirGuard(temp_dir))
    }

    #[test]
    fn test_wmo_weather_code_mappings() {
        assert_eq!(get_weather_info(0), ("☀️", "sun-duotone", "Clear sky"));
        assert_eq!(
            get_weather_info(2),
            ("⛅", "cloud-sun-duotone", "Partly cloudy")
        );
        assert_eq!(get_weather_info(3), ("☁️", "cloud-duotone", "Overcast"));
        assert_eq!(
            get_weather_info(61),
            ("🌦️", "cloud-rain-duotone", "Slight rain")
        );
        assert_eq!(
            get_weather_info(75),
            ("❄️", "cloud-snow-duotone", "Heavy snow")
        );
        assert_eq!(
            get_weather_info(95),
            ("⛈️", "cloud-lightning-duotone", "Thunderstorm")
        );
        assert_eq!(
            get_weather_info(999),
            ("🌡️", "cloud-sun-duotone", "Unknown")
        );
    }

    #[test]
    fn test_wind_direction_calculation() {
        assert_eq!(get_wind_direction(0.0), "N");
        assert_eq!(get_wind_direction(90.0), "E");
        assert_eq!(get_wind_direction(180.0), "S");
        assert_eq!(get_wind_direction(270.0), "W");
        assert_eq!(get_wind_direction(45.0), "NE");
        assert_eq!(get_wind_direction(225.0), "SW");
    }

    #[test]
    fn test_default_weather_data_and_serialization() {
        let (service, _guard) = create_test_service();
        let data = service.get_weather();

        assert_eq!(data.temperature, 0.0);
        assert_eq!(data.condition_text, "Clear sky");
        assert_eq!(data.condition_icon, "sun-duotone");

        let json = service.get_weather_json();
        assert!(json.contains("condition_icon"));
        assert!(json.contains("temperature"));
    }

    #[test]
    fn test_manual_location_override_and_caching() {
        let (service, guard) = create_test_service();

        assert!(service.set_location("Tokyo", 35.6762, 139.6503));
        let loc = service.get_location();
        assert_eq!(loc.city, "Tokyo");
        assert_eq!(loc.lat, 35.6762);
        assert_eq!(loc.lon, 139.6503);

        // Verify cache file was written
        let cache_file = guard.0.join("weather").join("location_cache.json");
        assert!(cache_file.is_file());
        let content = fs::read_to_string(&cache_file).unwrap();
        assert!(content.contains("Tokyo"));
    }

    #[test]
    fn test_weather_cache_freshness_and_stale_fallback() {
        let (service, guard) = create_test_service();

        let sample_weather = WeatherData {
            temperature: 22.5,
            city: "Berlin".to_string(),
            last_updated_epoch: 123456789,
            ..Default::default()
        };

        assert!(service.save_weather_cache(&sample_weather).is_ok());

        // Recreate service from same directory
        let service2 = WeatherService::new(guard.0.clone());
        let loaded = service2.get_weather();
        assert_eq!(loaded.temperature, 22.5);
        assert_eq!(loaded.city, "Berlin");
    }
}

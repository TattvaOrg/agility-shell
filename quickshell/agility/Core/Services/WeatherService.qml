import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Services
pragma Singleton

Item {
    id: weatherService

    property string city: "Loading..."
    property int temperatureC: 22
    property int apparentTemperatureC: 22
    property int humidity: 50
    property int windSpeed: 5
    property int weatherCode: 0
    property var dailyForecast: []
    property bool isFetching: false

    readonly property string displayTemp: {
        let isF = SettingsService.appletWeatherUnit === "F";
        let val = isF ? Math.round(temperatureC * 9 / 5 + 32) : temperatureC;
        return val + (isF ? "°F" : "°C");
    }

    readonly property string displayFeelsLike: {
        let isF = SettingsService.appletWeatherUnit === "F";
        let val = isF ? Math.round(apparentTemperatureC * 9 / 5 + 32) : apparentTemperatureC;
        return val + (isF ? "°F" : "°C");
    }

    function wmoToIcon(code) {
        if (code === 0)
            return "sun-duotone";
        if (code === 1 || code === 2)
            return "cloud-sun-duotone";
        if (code === 3)
            return "cloud-duotone";
        if (code === 45 || code === 48)
            return "cloud-fog-duotone";
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82))
            return "cloud-rain-duotone";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return "cloud-snow-duotone";
        if (code >= 95)
            return "cloud-lightning-duotone";
        return "sun-duotone";
    }

    function wmoToText(code) {
        if (code === 0)
            return "Clear sky";
        if (code === 1)
            return "Mainly clear";
        if (code === 2)
            return "Partly cloudy";
        if (code === 3)
            return "Overcast";
        if (code === 45 || code === 48)
            return "Foggy";
        if (code >= 51 && code <= 55)
            return "Drizzle";
        if (code >= 61 && code <= 65)
            return "Rain";
        if (code >= 71 && code <= 77)
            return "Snow";
        if (code >= 80 && code <= 82)
            return "Rain showers";
        if (code >= 95)
            return "Thunderstorm";
        return "Fair";
    }

    readonly property string conditionText: wmoToText(weatherCode)
    readonly property string conditionIcon: wmoToIcon(weatherCode)

    function formatDaily(dailyList) {
        if (!dailyList || !Array.isArray(dailyList))
            return [];

        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        let isF = SettingsService.appletWeatherUnit === "F";
        let res = [];

        for (let i = 0; i < dailyList.length; i++) {
            let item = dailyList[i];
            let d = new Date(item.date);
            let dayName = (i === 0) ? "Today" : ((i === 1) ? "Tomorrow" : days[d.getDay()]);
            let maxVal = isF ? Math.round(item.max * 9 / 5 + 32) : item.max;
            let minVal = isF ? Math.round(item.min * 9 / 5 + 32) : item.min;

            res.push({
                "day": dayName,
                "icon": wmoToIcon(item.code),
                "condition": wmoToText(item.code),
                "max": maxVal + "°",
                "min": minVal + "°"
            });
        }
        return res;
    }

    function refreshWeather(force) {
        if (isFetching)
            return;
        isFetching = true;
        let scriptPath = Quickshell.shellDir + "/Scripts/system/fetch_weather.sh";
        weatherProc.command = ["bash", scriptPath, force ? "--force" : ""];
        weatherProc.running = true;
    }

    Process {
        id: weatherProc

        stdout: StdioCollector {
            id: weatherOutput
        }

        onExited: function(exitCode) {
            weatherService.isFetching = false;
            if (exitCode === 0 && weatherOutput.text) {
                try {
                    let data = JSON.parse(weatherOutput.text.trim());
                    if (data && !data.error) {
                        weatherService.city = data.city || "Local";
                        weatherService.temperatureC = data.temperature !== undefined ? data.temperature : 22;
                        weatherService.apparentTemperatureC = data.apparent_temperature !== undefined ? data.apparent_temperature : 22;
                        weatherService.humidity = data.humidity !== undefined ? data.humidity : 50;
                        weatherService.windSpeed = data.wind_speed !== undefined ? data.wind_speed : 5;
                        weatherService.weatherCode = data.weather_code !== undefined ? data.weather_code : 0;
                        weatherService.dailyForecast = weatherService.formatDaily(data.daily);
                    }
                } catch (e) {
                    console.error("Error parsing weather JSON: " + e);
                }
            }
        }
    }

    Timer {
        id: weatherPollTimer

        interval: 900000 // 15 mins
        repeat: true
        running: SettingsService.appletWeather
        triggeredOnStart: true
        onTriggered: {
            weatherService.refreshWeather(false);
        }
    }

    Component.onCompleted: {
        weatherService.refreshWeather(false);
    }
}

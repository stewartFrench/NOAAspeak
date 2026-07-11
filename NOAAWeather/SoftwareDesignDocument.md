# NOAAspeak - Software Design Document v1.0

## 1. Introduction

### 1.1 Purpose
This document provides a comprehensive technical overview of NOAAspeak (formerly NOAAWeather), an iOS application that provides real-time NOAA weather forecasts and alerts with continuous text-to-speech capabilities, similar to traditional NOAA Weather Radio.

### 1.2 Scope
NOAAspeak is a native iOS application built with SwiftUI that:
- Automatically detects user location via GPS with optional automatic location updates
- Fetches real-time weather data from official NOAA APIs
- Displays detailed 6-period forecasts and complete active weather alerts
- Provides continuous text-to-speech weather broadcasting with full alert details
- Enables location-based weather searches with autocomplete and auto-focus keyboard
- Supports voice selection and preference persistence
- Provides seamless location switching with immediate speech updates
- Supports portrait orientation only
- Configurable automatic location updates (1, 2, 5, 10, or 15 minute intervals)
- Intelligent location management preventing GPS from overwriting manual location entries
- Ensures proper speech restart from beginning (no resume from middle)
- Waits for reverse geocoding before announcing location name
- Stable UI with no button movement during location updates

### 1.3 Definitions and Acronyms
- **NOAA**: National Oceanic and Atmospheric Administration
- **NWS**: National Weather Service
- **API**: Application Programming Interface
- **TTS**: Text-to-Speech
- **CoreLocation**: Apple's framework for location services
- **MapKit**: Apple's framework for maps and location search
- **AVSpeechSynthesizer**: Apple's text-to-speech framework

## 2. System Overview

### 2.1 System Context
NOAAWeather is a standalone iOS application that:
- Uses device GPS for location detection
- Fetches weather data from official NOAA API (api.weather.gov)
- Synthesizes speech from text forecasts
- Operates in foreground mode
- No data persistence required (real-time data only)

### 2.2 System Architecture

The application follows the Model-View-ViewModel (MVVM) pattern using SwiftUI's modern declarative approach with the `@Observable` macro for state management.

```
┌──────────────────────────────────────────────────────┐
│               User Interface                         │
│  (ContentView, LocationSearchView, SettingsView)     │
└────────────┬─────────────────────────────────────────┘
             │
             ├──────────────┬──────────────┬────────────┐
             │              │              │            │
    ┌────────▼───────┐ ┌───▼──────┐ ┌─────▼──────┐ ┌──▼────────┐
    │NOAAWeather     │ │Speech    │ │Location    │ │User       │
    │Service         │ │Manager   │ │Manager     │ │Defaults   │
    └────────┬───────┘ └───┬──────┘ └─────┬──────┘ └───────────┘
             │             │              │
    ┌────────▼───────┐ ┌───▼──────┐ ┌─────▼────────────────┐
    │NOAA API        │ │AVSpeech  │ │CoreLocation/MapKit   │
    │api.weather.gov │ │Synthesizer│ │CLLocation/MKGeocoder │
    └────────────────┘ └──────────┘ └──────────────────────┘
```

## 3. Architectural Design

### 3.1 Design Patterns

#### 3.1.1 Observable Pattern
Uses Swift's `@Observable` macro for reactive state management:
- `NOAAWeatherService`: Manages weather data fetching and state
- `SpeechManager`: Manages text-to-speech playback with continuous mode support
- `LocationManager`: Manages location services and reverse geocoding

#### 3.1.2 Delegation Pattern
Implements:
- `CLLocationManagerDelegate` for location updates
- `AVSpeechSynthesizerDelegate` for speech events

#### 3.1.3 Async/Await Pattern
Modern Swift concurrency for API calls and background operations

### 3.2 Component Architecture

#### 3.2.1 Presentation Layer
**Views (SwiftUI)**:
- `ContentView`: Main application interface with forecasts, continuous mode controls, and alerts
- `LocationSearchView`: Location search with autocomplete using MKLocalSearchCompleter
- `SettingsView`: Voice selection and app configuration

#### 3.2.2 Business Logic Layer
**Services**:
- `NOAAWeatherService`: Weather data fetching from NOAA API
- `SpeechManager`: Text-to-speech synthesis
- `LocationManager`: Location detection and management

#### 3.2.3 Data Layer
**Models**:
- `NOAAPointResponse`: API response for location points
- `NOAAForecastResponse`: API response for forecasts
- `NOAAAlertResponse`: API response for weather alerts
- `ForecastPeriod`: Individual forecast period
- `AlertFeature`: Individual weather alert

## 4. Detailed Design

### 4.1 Data Models

#### 4.1.1 NOAAPointResponse
```swift
struct NOAAPointResponse: Codable
{
  let properties: PointProperties
  
  struct PointProperties: Codable
  {
    let forecast: String
    let forecastHourly: String
    let forecastGridData: String
    let observationStations: String
  }
}
```

**Purpose**: Response from api.weather.gov/points endpoint containing URLs for detailed forecasts

#### 4.1.2 NOAAForecastResponse
```swift
struct NOAAForecastResponse: Codable
{
  let properties: ForecastProperties
  
  struct ForecastProperties: Codable
  {
    let periods: [ForecastPeriod]
  }
  
  struct ForecastPeriod: Codable, Identifiable
  {
    let number: Int
    let name: String              // "Tonight", "Wednesday", etc.
    let startTime: String
    let endTime: String
    let isDaytime: Bool
    let temperature: Int
    let temperatureUnit: String   // "F" or "C"
    let windSpeed: String
    let windDirection: String
    let shortForecast: String     // Brief description
    let detailedForecast: String  // Full description
    
    var id: Int { number }
  }
}
```

**Purpose**: Contains forecast periods with detailed weather information

#### 4.1.3 NOAAAlertResponse
```swift
struct NOAAAlertResponse: Codable
{
  let features: [AlertFeature]
  
  struct AlertFeature: Codable, Identifiable
  {
    let id: String
    let properties: AlertProperties
  }
  
  struct AlertProperties: Codable
  {
    let event: String           // "Tornado Warning", etc.
    let headline: String?
    let description: String
    let instruction: String?
    let severity: String        // "Extreme", "Severe", etc.
    let urgency: String
    let certainty: String
  }
}
```

**Purpose**: Contains active weather alerts and warnings

### 4.2 Service Components

#### 4.2.1 NOAAWeatherService

**Responsibilities**:
- Fetch weather data from NOAA API
- Parse JSON responses
- Manage forecast and alert state
- Provide formatted text for display and speech

**Key Methods**:
```swift
func fetchWeather(for location: CLLocation) async
```

**State Properties**:
- `forecastPeriods: [ForecastPeriod]` - Array of forecast periods (displays 6)
- `activeAlerts: [AlertFeature]` - Array of active alerts
- `currentLocation: CLLocation?` - Current location
- `statusMessage: String` - User-facing status
- `isLoading: Bool` - Loading state (prevents concurrent fetches)
- `errorMessage: String?` - Error message if fetch fails
- `weatherDataReady: Bool` - Flag indicating forecast and alerts are loaded

**Computed Properties**:
- `weatherSummary: String` - Formatted text for display
- `func speechText(locationName: String?) -> String` - Formatted text optimized for TTS with location announcement, COMPLETE alert details (event, headline, full description, and instructions), and natural pauses (UPDATED)

**API Workflow**:
```
1. Get forecast URL:
   GET https://api.weather.gov/points/{lat},{lon}
   Response: forecast URL

2. Fetch forecast:
   GET {forecast URL from step 1}
   Response: forecast periods

3. Fetch alerts:
   GET https://api.weather.gov/alerts/active?point={lat},{lon}
   Response: active alerts
```

#### 4.2.2 SpeechManager

**Responsibilities**:
- Configure audio session for speech
- Manage AVSpeechSynthesizer
- Handle speech playback (play/pause/stop)
- Track speech state

**Key Methods**:
```swift
func speak(_ text: String)
func stop()
func pause()
func resume()
func togglePause()
```

**State Properties**:
- `isSpeaking: Bool` - Whether speech is active
- `statusText: String` - Current speech status
- `selectedVoiceIdentifier: String` - Selected voice ID (persisted to UserDefaults)
- `wasManuallyStopped: Bool` - Prevents continuous loop on manual stop
- `onSpeechFinished: (() -> Void)?` - Callback for continuous mode

**Audio Session Configuration**:
```swift
Category: .playback
Mode: .spokenAudio
Options: []
usesApplicationAudioSession: false  // For CarPlay compatibility
```

**Speech Configuration**:
- Voice: User-selectable from available English voices (default: Samantha)
- Rate: 0.5 (slightly slower for clarity)
- Pitch: 1.0
- Volume: 1.0

**Continuous Mode**:
- `onSpeechFinished` callback triggers weather refresh after 2-second pause
- `wasManuallyStopped` flag prevents loop when user stops speech
- Automatic restart when speech finishes naturally

**Speech Restart Logic** (UPDATED):
- Synthesizer is completely recreated on each `speak()` call
- Prevents speech from resuming from middle due to cached state
- Uses `DispatchQueue.main.asyncAfter` with 50ms delay for clean stop/start separation
- Old synthesizer delegate is cleared before creating new instance
- Ensures speech always starts from beginning, never resumes

#### 4.2.3 LocationManager

**Responsibilities**:
- Request location permissions
- Get current device location
- Reverse geocode for location names using iOS 26 MapKit APIs
- Track location state
- Handle both GPS and manually entered locations
- Manage automatic location updates with configurable intervals
- Prevent GPS from overwriting manual location entries

**Key Methods**:
```swift
func requestLocation()
func locationManager(_:didUpdateLocations:)
func locationManager(_:didFailWithError:)
```

**State Properties**:
- `currentLocation: CLLocation?` - Current device location (GPS or manual entry)
- `locationName: String?` - Human-readable location name (City, State format)
- `locationStatus: String` - Location status message
- `isManualLocation: Bool` - Flag to track if location was manually entered (NEW)
- `autoUpdateLocation: Bool` - Enable/disable automatic location updates (NEW, default: false)
- `locationUpdateInterval: TimeInterval` - Update interval in seconds (NEW, default: 300 = 5 minutes)

**Accuracy Configuration**:
```swift
desiredAccuracy = kCLLocationAccuracyKilometer
```

**Manual Location Protection** (NEW):
When `isManualLocation` is true:
- GPS location updates are ignored
- Prevents automatic location timer from overwriting user's manual location selection
- Flag is cleared when user taps "This Location" button

**Automatic Location Updates** (NEW):
- Timer-based location refresh during continuous mode
- Configurable intervals: 60, 120, 300, 600, or 900 seconds
- Only active when both continuous mode AND autoUpdateLocation are enabled
- Settings persisted to UserDefaults
- Timer automatically stops/starts based on continuous mode state

**iOS 26 Geocoding**:
Uses modern MapKit APIs:
- `MKReverseGeocodingRequest` instead of deprecated CLGeocoder
- `addressRepresentations.cityWithContext` and `addressRepresentations.regionName` for location names

### 4.3 User Interface Design

#### 4.3.1 ContentView

**Layout Structure**:
```
VStack
├── Header
│   ├── Settings button (gear icon, top-right)
│   ├── Cloud/Sun icon
│   ├── "NOAA Weather" title
│   ├── Location name (if available)
│   └── Status message
├── Action Buttons (HStack - equal width)
│   ├── Enter Location (Blue)
│   │   ├── Magnifying glass icon
│   │   └── "Enter\nLocation" text
│   ├── Listen/Stop (Green/Gray)
│   │   ├── Play/Stop icon
│   │   └── "Listen"/"Stop" text (based on continuousMode)
│   └── This Location (Blue)
│       ├── Location pin icon
│       └── "This\nLocation" text
├── Speech Status (fixed height to prevent layout shift)
│   └── "Speaking forecast..." (when active, blank otherwise)
└── Forecast ScrollView
    ├── Active Alerts (if any) - at top of scroll area
    │   ├── Alert header with warning icon
    │   └── Alert cards (red background) - COMPLETE ALERTS (NEW)
    │       ├── Event name (bold)
    │       ├── Headline (semibold, if available)
    │       ├── Full description text
    │       ├── Divider
    │       └── Instructions (if available)
    └── Forecast Period Cards (6 periods)
        ├── Period name + Temperature
        ├── Day/Night icon + Short forecast
        ├── Detailed forecast
        └── Wind information
```

**Button Styling**:
- All buttons: Equal width, 50pt min height
- Layout: VStack with icon above text
- Enter Location: Blue, always enabled
- Listen/Stop: Green when forecast available, gray when disabled, label changes based on continuousMode
- This Location: Blue, disabled during loading, requests fresh GPS location

**UI Stability** (NEW):
- Header maintains fixed height using placeholder text when location is nil
- Status message has `minHeight: 20` to prevent layout shifts
- Speech status has fixed `height: 20` 
- Buttons remain stationary during location updates and weather fetches
- No Spacer below ScrollView to prevent flexible layout changes

**State Transitions**:
1. **Initial Launch**: Automatically requests location and starts speaking in continuous mode
2. **Loading**: Progress indicator in forecast area, buttons remain stable
3. **Ready**: Forecast cards displayed, continuous speech active
4. **Error**: Error icon + error message in forecast area
5. **Stopped**: User tapped Stop, continuousMode = false, shows Listen button
6. **Location Change**: Stops speech, fetches new weather, resumes continuous mode, UI stays stable

**Continuous Mode Behavior**:
- Enabled by default on launch and when entering new location
- Speaks complete 6-period forecast with alerts
- Waits 2 seconds after speech completes
- Automatically refreshes weather and speaks again
- Disabled when user taps Stop button
- Button shows "Stop" when continuous, "Listen" when stopped

#### 4.3.2 LocationSearchView

**Purpose**: Enable users to search for weather at any US location with autocomplete and auto-focus

**Layout**:
```
NavigationView
├── Instructions text
├── Search TextField (auto-focused)
├── Autocomplete Results List (MKLocalSearchCompleter)
│   └── Completion items with title and subtitle
├── Progress indicator (when searching)
└── Toolbar
    └── Cancel button
```

**Auto-Focus Keyboard** (NEW):
- Uses `@FocusState` to manage text field focus
- Automatically focuses search field on view appearance
- Keyboard appears immediately when user taps "Enter Location"
- Improves user experience by eliminating extra tap

**Search Implementation**:
Uses `MKLocalSearchCompleter` for autocomplete:
```swift
let completer = MKLocalSearchCompleter()
completer.queryFragment = searchText
// Delegate receives completion results
```

Uses `MKLocalSearch` for final selection:
```swift
let request = MKLocalSearch.Request(completion: selectedCompletion)
let search = MKLocalSearch(request: request)
search.start { response, error in ... }
```

**Workflow**:
1. User types location text
2. MKLocalSearchCompleter provides real-time suggestions
3. User taps a suggestion
4. MKLocalSearch finds exact coordinates
5. Stops any ongoing speech
6. Enables continuous mode
7. Updates location and triggers weather fetch via onChange
8. Dismiss sheet
9. Speech starts automatically when weather loads

#### 4.3.3 SettingsView

**Purpose**: Configure app preferences, automatic location updates, and voice selection

**Layout**:
```
NavigationView
├── Form
│   ├── About Section
│   │   ├── App version (1.0)
│   │   └── Weather data source attribution
│   ├── Location Updates Section
│   │   ├── Auto-Update Location toggle
│   │   └── Update Interval picker (1, 2, 5, 10, 15 minutes)
│   ├── Voice Selection Section
│   │   ├── Picker with all available English voices
│   │   └── Voice quality indicator (Enhanced)
│   └── Preview Section
│       └── Test Voice button (previews selected voice)
└── Toolbar
    └── Done button
```

**Location Updates** (NEW):
- Toggle to enable/disable automatic location updates during continuous mode
- Configurable update interval: 1, 2, 5, 10, or 15 minutes (default: 5 minutes)
- Settings persisted to UserDefaults
- Only active when continuous mode is enabled
- Respects manual location entries (won't override with GPS)

**Voice Selection**:
- Displays all available English voices from `AVSpeechSynthesisVoice.speechVoices()`
- Shows voice name, language code, and quality (Enhanced)
- Test button speaks sample text with selected voice
- Selection persisted to UserDefaults via SpeechManager

**Implementation**:
```swift
Toggle("Auto-Update Location", isOn: $locationManager.autoUpdateLocation)

Picker("Update Interval", selection: $locationManager.locationUpdateInterval)
{
  Text("1 minute").tag(60.0)
  Text("2 minutes").tag(120.0)
  Text("5 minutes").tag(300.0)
  Text("10 minutes").tag(600.0)
  Text("15 minutes").tag(900.0)
}

Picker("Voice", selection: $speechManager.selectedVoiceIdentifier)
{
  ForEach(speechManager.availableVoices, id: \.identifier)
  { voice in
    Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
  }
}

Button("Test Voice")
{
  speechManager.speak("This is a test of the selected voice.")
}
```

### 4.4 Data Flow

**Location → Weather Flow** (UPDATED):
```
1. LocationManager.requestLocation() or user enters location
2. CLLocationManager returns location OR MKLocalSearch provides coordinates
3. LocationManager checks isManualLocation flag:
   - If true and update is from GPS: IGNORE update (don't overwrite manual location)
   - If false or update is from manual entry: proceed
4. LocationManager updates currentLocation
5. ContentView.onChange(of: currentLocation) triggers with distance check:
   - Calculate distance from current weatherService.currentLocation
   - Only fetch if distance > 1km OR no existing forecast data
   - Prevents redundant API calls for minor GPS coordinate changes
6. Task { await weatherService.fetchWeather(for: location) }
7. NOAAWeatherService fetches forecast and alerts from API
8. weatherService.weatherDataReady = true (only if forecast data is not empty)
9. ContentView.onChange(of: weatherDataReady) triggers
10. If continuousMode is true, calls speechManager.speak()
11. SwiftUI re-renders with new data
```

**Continuous Speech Flow**:
```
1. App launches or user enters location
2. continuousMode = true
3. Weather data loads, weatherDataReady triggers speech
4. SpeechManager speaks: location, alerts, 6 forecast periods
5. When speech finishes naturally (not manually stopped):
   - onSpeechFinished callback triggers
   - Wait 2 seconds
   - Fetch fresh weather data
   - weatherDataReady triggers speech again
   - Loop continues until user taps Stop
```

**Manual Stop Flow**:
```
1. User taps Stop button
2. continuousMode = false
3. speechManager.stop() called
4. wasManuallyStopped = true (prevents onSpeechFinished callback)
5. Button changes to "Listen"
6. No automatic refresh until user interaction
```

**This Location Flow** (UPDATED):
```
1. User taps This Location button (guarded by !isLoading check)
2. speechManager.stop() (stops any ongoing speech)
3. continuousMode = true (re-enable continuous mode)
4. isManualLocation = false (clear manual location flag to allow GPS updates)
5. locationName = nil (clear old location name)
6. waitingForGPSLocation = true (set flag to wait for reverse geocoding)
7. weatherService.currentLocation = nil (force fresh fetch)
8. locationManager.currentLocation = nil (force fresh GPS lookup)
9. requestLocation() (get actual GPS coordinates)
10. Weather fetch completes → weatherDataReady = true
11. If waitingForGPSLocation && locationName == nil: skip speech, wait for geocoding
12. Reverse geocoding completes → locationName updated
13. onChange(locationName) detects update and triggers speech with correct location
14. Speech starts with proper "Here is the weather for [City, State]" announcement
```

**Automatic Location Update Flow** (NEW):
```
1. User enables Auto-Update Location in Settings
2. User sets update interval (e.g., 5 minutes)
3. When continuousMode is enabled:
   - Timer starts with specified interval
   - Timer fires every N minutes
   - Calls locationManager.requestLocation()
   - If isManualLocation = false, GPS location updates
   - If location moved > 1km, weather fetch triggers
   - New weather data speaks automatically
4. When continuousMode is disabled:
   - Timer stops automatically
5. When manual location is entered:
   - isManualLocation = true prevents timer's GPS updates from overwriting
   - Timer continues running but GPS updates are ignored
   - Ensures manual location persists during continuous mode
```

## 5. External Dependencies

### 5.1 iOS Frameworks

#### 5.1.1 SwiftUI
- **Purpose**: User interface framework
- **Usage**: All views, navigation, state management
- **Minimum Version**: iOS 17.0+

#### 5.1.2 AVFoundation
- **Purpose**: Text-to-speech synthesis
- **Components Used**:
  - `AVSpeechSynthesizer`: Speech generation
  - `AVSpeechUtterance`: Speech content
  - `AVAudioSession`: Audio session configuration

#### 5.1.3 CoreLocation
- **Purpose**: Location services
- **Components Used**:
  - `CLLocationManager`: Location updates
  - `CLLocation`: Geographic coordinates
  - `CLLocationManagerDelegate`: Location callbacks
- **Permissions**: "When In Use" location access

#### 5.1.4 MapKit
- **Purpose**: Location search and reverse geocoding
- **Components Used**:
  - `MKLocalSearch`: Natural language location search
  - `MKLocalSearchCompleter`: Autocomplete suggestions
  - `MKLocalSearch.Request`: Search configuration
  - `MKReverseGeocodingRequest`: iOS 26 reverse geocoding (replaces deprecated CLGeocoder)
  - `MKMapItem`: Location results with address information
- **Usage**: Converting place names to coordinates, autocomplete, and reverse geocoding
- **iOS 26 Updates**: Uses modern `addressRepresentations` API for city/state extraction

#### 5.1.5 Foundation
- **Purpose**: Core utilities and data persistence
- **Components Used**:
  - `URLSession`: Network requests
  - `JSONDecoder`: JSON parsing
  - `URL`: Network resource handling
  - `UserDefaults`: Voice preference persistence

### 5.2 External Services

#### 5.2.1 NOAA Weather API (api.weather.gov)

**Endpoints Used**:
1. Points: `GET /points/{latitude},{longitude}`
2. Forecast: `GET /gridpoints/{office}/{grid}/forecast`
3. Alerts: `GET /alerts/active?point={latitude},{longitude}`

**Data Format**: JSON
**Authentication**: None required (public API)
**Rate Limits**: Not officially documented, reasonable use expected
**Availability**: 24/7 official government service

**Response Times**: Typically < 1 second

## 6. Security and Privacy

### 6.1 Location Privacy

**Permission Model**:
- "When In Use" authorization only
- Location only accessed when app is active
- Clear purpose string in Info.plist

**Info.plist Entries** (UPDATED):
```xml
<key>CFBundleDisplayName</key>
<string>NOAAspeak</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Location is used to fetch weather forecasts for your area.</string>

<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>

<key>UISupportedInterfaceOrientations</key>
<array>
  <string>UIInterfaceOrientationPortrait</string>
</array>
```

**Data Handling**:
- Location never transmitted except to NOAA API
- No location storage or tracking
- Reverse geocoding for display only

### 6.2 Network Security

**API Communication**:
- HTTPS only (api.weather.gov uses TLS)
- No authentication tokens or credentials
- Public government data only

### 6.3 Data Privacy

**User Data**:
- No data persistence beyond current session
- No analytics or tracking
- No personal information collected
- No third-party data sharing
- No advertisements

## 7. Performance Considerations

### 7.1 API Calls

**Optimization** (UPDATED):
- Weather data refreshes in continuous mode (2-second delay between cycles)
- Prevents concurrent fetches with `isLoading` flag
- No automatic background updates (foreground only)
- Responses used immediately, no long-term caching
- Distance-based fetch optimization: Only fetches when location changes > 1km
- Prevents redundant API calls from minor GPS coordinate variations
- Optional automatic location updates with configurable intervals (1-15 minutes)

**Network Performance**:
- Typical API response: < 1 second
- All calls use async/await (non-blocking)
- Error handling with user feedback
- Preserves last good forecast data on error (doesn't clear existing data)

### 7.2 Speech Synthesis

**Performance**:
- Speech generation is instant (local processing)
- No network dependency for TTS
- Background audio capable

### 7.3 Memory Management

**Resource Usage**:
- Minimal data storage (current session only)
- No large data structures
- Forecast data: ~10-50KB per fetch
- SwiftUI automatic memory management

### 7.4 Device Orientation (NEW)

**Supported Orientations**:
- Portrait only for iPhone
- Landscape disabled to maintain optimal layout
- Configured in both Info.plist and project settings:
  - `UISupportedInterfaceOrientations`: UIInterfaceOrientationPortrait
  - `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone`: UIInterfaceOrientationPortrait

## 8. Error Handling

### 8.1 API Errors

**Scenarios**:
1. **Network Unavailable**
   - Display: "Failed to fetch weather data: [error]"
   - User Action: Tap refresh to retry

2. **Invalid Location**
   - Display: "No forecast data available"
   - User Action: Search different location

3. **API Rate Limiting** (rare)
   - Display error message
   - User Action: Wait and retry

### 8.2 Location Errors

**Scenarios**:
1. **User Denies Permission**
   - Display: "Failed to get location"
   - Fallback: User must search manually

2. **Location Unavailable**
   - Display error with description
   - Fallback: User must search manually

### 8.3 Speech Errors

**Scenarios**:
1. **No Forecast Data**
   - Button disabled (gray)
   - No action available

2. **Audio Session Error**
   - Logged to console
   - Speech may fail silently

## 9. Configuration and Settings

### 9.1 App Configuration (Info.plist)

**Required Keys**:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location is used to fetch weather forecasts for your area.</string>
```

**Note**: Background audio not required (TTS is foreground only)

### 9.2 UserDefaults Storage

**Persisted Settings**:
- `selectedVoiceIdentifier` (String): User's selected TTS voice
  - Saved automatically when changed via didSet property observer
  - Loaded on SpeechManager initialization
  - Default: "com.apple.voice.compact.en-US.Samantha"

### 9.3 Build Settings

**Target**: iOS 26.0+ (uses iOS 26 MapKit APIs)
**Language**: Swift 6.0+
**Architecture**: Universal (iPhone only, portrait orientation)
**Key iOS 26 Features Used**:
- MKReverseGeocodingRequest (replaces deprecated CLGeocoder)
- MKLocalSearchCompleter for autocomplete
- Modern addressRepresentations API

## 10. Testing Considerations

### 10.1 Unit Testing Opportunities

**NOAAWeatherService**:
- JSON decoding accuracy
- Error handling for network failures
- Data formatting for display and speech

**SpeechManager**:
- State transitions (speaking/stopped)
- Delegate method handling
- Continuous mode callback logic
- Manual stop vs natural finish behavior
- Voice preference persistence

**LocationManager**:
- Permission handling
- Location update processing

### 10.2 Integration Testing

**API Integration**:
- Real API calls with various locations
- Alert handling when alerts are active
- Error scenarios (invalid coordinates, etc.)

**User Flow**:
1. Launch app → location requested → weather spoken automatically in continuous mode
2. Tap Stop → continuous mode disabled, speech stops
3. Tap Listen → continuous mode enabled, speech resumes
4. Search location → speech stops, new weather fetched and spoken in continuous mode
5. Tap This Location → returns to GPS location, speaks weather in continuous mode
6. Access Settings → change voice, test voice preview
7. Continuous mode → speaks weather, waits 2 seconds, refreshes, repeats until stopped

### 10.3 UI Testing

**Scenarios**:
- Launch app → verify initial state and automatic speech start
- Grant location → verify weather loads and speaks automatically
- Tap Stop → verify speech stops and button shows Listen
- Tap Listen → verify speech resumes in continuous mode
- Search location with autocomplete → verify suggestions appear
- Select location → verify speech stops, new weather loads and speaks
- Tap This Location → verify returns to GPS location and speaks
- Change voice in Settings → verify voice persists across launches
- Continuous mode → verify 2-second pause and automatic refresh
- Multiple rapid taps → verify no race conditions or infinite loops
- Handle errors gracefully

## 11. Deployment

### 11.1 App Store Submission

**Requirements**:
- App icon (all sizes)
- Privacy policy (optional for this simple app)
- Screenshots for multiple device sizes
- Description and keywords

**Privacy Declarations**:
- Location usage: For fetching local weather forecasts
- Network usage: For accessing NOAA weather API
- Data source: Official NOAA government data

**Key Advantage**: No third-party services or unauthorized APIs

### 11.2 Versioning

**Current Version**: 2.0
**Versioning Scheme**: Semantic (major.minor.patch)

**Version History**:
- 1.0: Initial release with streaming (rejected by App Store)
- 2.0: Complete redesign using NOAA API with TTS
  - Official NOAA weather API integration
  - Text-to-speech forecast reading
  - Active weather alerts display
  - Location-based weather search
  - No streaming or third-party services

## 12. Implementation Challenges and Solutions

### 12.1 Continuous Mode Speech Loop

**Challenge**: Creating a reliable continuous weather broadcast loop without infinite loops or race conditions.

**Solution**:
- `wasManuallyStopped` flag distinguishes manual stops from natural speech completion
- `onSpeechFinished` callback only triggers when speech finishes naturally
- `weatherDataReady` flag coordinates forecast and alert loading before speaking
- `isLoading` flag prevents concurrent weather fetches

### 12.2 iOS 26 API Deprecations

**Challenge**: CLGeocoder and related placemark APIs deprecated in iOS 26.

**Solution**:
- Migrated to `MKReverseGeocodingRequest` for reverse geocoding
- Use `addressRepresentations.cityWithContext` and `addressRepresentations.regionName` for location names
- Updated to modern MapKit patterns throughout

### 12.3 Location State Management

**Challenge**: Distinguishing between GPS location and manually entered locations, especially for "This Location" button.

**Solution**:
- Set `currentLocation = nil` before requesting GPS to force fresh lookup
- Separate onChange handlers for location updates and weather data ready
- Clear separation between location source (GPS vs manual entry)

### 12.4 Speech Interruption Handling

**Challenge**: Stopping speech when user changes location should not trigger continuous loop restart.

**Solution**:
- Call `speechManager.stop()` before location changes sets `wasManuallyStopped = true`
- New location enables `continuousMode = true` before fetching weather
- `weatherDataReady` triggers speech with fresh data in continuous mode
- Loop continues naturally from new starting point

### 12.5 Race Conditions in Weather Fetching

**Challenge**: Multiple rapid button taps or location changes could trigger concurrent API calls.

**Solution**:
- Guard clause in `fetchWeather` returns early if `isLoading = true`
- Prevents duplicate fetches during active requests
- Ensures data consistency

### 12.6 UI Layout Stability

**Challenge**: Speech status text appearing/disappearing caused buttons to shift vertically.

**Solution**:
- Fixed-height frame for speech status area
- Shows blank space when not speaking instead of hiding element
- Prevents layout reflow

### 12.7 Voice Preference Persistence

**Challenge**: Remember user's voice selection across app launches.

**Solution**:
- `didSet` property observer on `selectedVoiceIdentifier` auto-saves to UserDefaults
- Init method loads saved preference on app launch
- Seamless persistence without explicit save/load calls

## 13. Future Enhancements

### 12.1 Potential Features

1. **Extended Forecasts**
   - Hourly forecasts (using forecastHourly endpoint)
   - 7-day detailed forecasts

2. **Weather Maps**
   - Radar imagery
   - Satellite views
   - Temperature maps

3. **Notifications**
   - Push notifications for severe weather alerts
   - Background monitoring (requires additional permissions)

4. **Siri Integration**
   - "Hey Siri, what's the weather forecast?"
   - Shortcuts support

5. **Widget Support**
   - Home screen widget showing current conditions
   - Lock screen widget

6. **Multiple Locations**
   - Save favorite locations
   - Quick switch between locations

7. **Customization** (Voice selection ✅ implemented)
   - Speech rate adjustment
   - Refresh interval customization
   - Dark mode optimization

8. **Offline Mode**
   - Cache recent forecasts
   - Last known conditions

### 12.2 Technical Improvements

1. **Caching**
   - Cache API responses with expiration
   - Reduce redundant API calls

2. **Accessibility**
   - VoiceOver optimization
   - Dynamic Type support
   - High contrast mode

3. **Localization**
   - Multi-language support
   - International weather services

4. **Performance**
   - Image caching for weather icons
   - Pagination for long forecasts

## 13. Code Formatting Standards

The project follows strict formatting rules defined in `format_rules.md`:

### 13.1 Key Standards

**Braces**: Always on separate lines
```swift
// Correct
func example()
{
  if condition
  {
    // code
  } // if
} // example
```

**Indentation**: 2 spaces (not tabs)

**Comments**: After closing braces
```swift
} // if
} // for
} // func functionName
} // struct StructName
```

**Line Length**: Maximum 80-100 characters (flexible)

## 14. Appendices

### 14.1 File Structure
```
NOAAWeather/
├── NOAAWeather/
│   ├── NOAAWeatherApp.swift       # App entry point
│   ├── ContentView.swift             # Main UI
│   ├── LocationSearchView.swift      # Location search UI
│   ├── NOAAWeatherService.swift      # Weather API service
│   ├── SpeechManager.swift           # Text-to-speech manager
│   ├── Info.plist                    # App configuration
│   ├── format_rules.md               # Code formatting standards
│   ├── SoftwareDesignDocument.md     # This document
│   └── Assets.xcassets/
│       └── AppIcon.appiconset/       # App icons
└── NOAAWeather.xcodeproj/         # Xcode project
```

### 14.2 API Examples

**Get Forecast for Location**:
```
1. GET https://api.weather.gov/points/32.7767,-96.7970
   Response: { "properties": { "forecast": "..." } }

2. GET [forecast URL from step 1]
   Response: { "properties": { "periods": [...] } }
```

**Get Active Alerts**:
```
GET https://api.weather.gov/alerts/active?point=32.7767,-96.7970
Response: { "features": [...] }
```

### 14.3 State Diagram

```
[App Launch] → [Request Location]
                     ↓
              [Location Received]
                     ↓
              [Fetch Weather API]
                     ↓
         [Display Forecast + Alerts]
                     ↓
         [User Taps Listen Button]
                     ↓
         [Text-to-Speech Plays]
                     ↓
         [User Can Stop/Refresh/Search]
```

### 14.4 Network Flow

```
┌──────────────┐
│   iPhone     │
│ LocalNOAAApp │
└──────┬───────┘
       │
       │ HTTPS REST API
       ↓
┌──────────────────────┐
│  api.weather.gov     │
│  (NOAA Weather API)  │
└──────┬───────────────┘
       │
       │ Official Data
       ↓
┌──────────────────────┐
│  National Weather    │
│  Service (NWS)       │
└──────────────────────┘
```

---

## Document Revision History

| Version | Date       | Author          | Changes                           |
|---------|------------|-----------------|-----------------------------------|
| 1.0     | 2026-06-16 | Claude Sonnet   | Initial comprehensive SDD for streaming version |
| 2.0     | 2026-06-20 | Claude Sonnet   | Complete redesign for NOAA API with TTS, removed all streaming functionality |
| 1.0     | 2026-07-10 | Claude Sonnet 4.5 | App Store release version: Renamed to NOAAspeak, added automatic location updates with configurable intervals, complete alert display and speech, portrait-only orientation, intelligent location management with manual/GPS distinction, distance-based fetch optimization (1km threshold), bug fixes for location race conditions and infinite loop prevention |
| 1.0.1   | 2026-07-11 | Claude Sonnet 4.5 | Bug fixes: Fixed speech resume-from-middle issue by recreating synthesizer on each speak() call, added waitingForGPSLocation flag to ensure correct location name announcement, improved UI stability with fixed-height header and status areas, added auto-focus keyboard for location search, prevented button movement during updates, added guard against multiple rapid "This Location" presses |

---

**End of Document**

//
//  ContentView.swift
//  NOAAWeather
//
//  Created by Stewart French on 6/15/26.
//

import SwiftUI
import CoreLocation
import MapKit


//------------
struct ContentView: View
{
  @State private var weatherService = NOAAWeatherService()
  @State private var speechManager = SpeechManager()
  @State private var locationManager = LocationManager()
  @State private var showLocationSearch = false
  @State private var showSettings = false
  @State private var continuousMode = true
  

  var body: some View
  {
    VStack(spacing: 20)
    {
              // Header
      VStack(spacing: 8)
      {
        HStack
        {
          Spacer()
          
          Button(action:
          {
            showSettings = true
          }) // action
          {
            Image(systemName: "gearshape.fill")
              .font(.title2)
              .foregroundStyle(.blue)
          } // Button
          .padding(.trailing)
        } // HStack
        
        Image(systemName: "cloud.sun.fill")
          .font(.system(size: 60))
          .foregroundStyle(.blue)
        
        Text("NOAA Weather")
          .font(.largeTitle)
          .fontWeight(.bold)
        
        if let location = weatherService.currentLocation
        {
          Text(locationManager.locationName ?? "Your Location")
            .font(.headline)
            .foregroundStyle(.secondary)
          
          Text(String(format: "%.4f°, %.4f°",
                     location.coordinate.latitude,
                     location.coordinate.longitude))
            .font(.caption)
            .foregroundStyle(.secondary)
        } // if
      } // VStack
      .padding(.top)
      
              // Status message
      Text(weatherService.statusMessage)
        .font(.subheadline)
        .foregroundStyle(weatherService.errorMessage != nil ? .red : .secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
      
              // Action Buttons
      HStack(spacing: 12)
      {
                // Enter Location button
        Button(action:
        {
          showLocationSearch = true
        }) // action
        {
          VStack(spacing: 4)
          {
            Image(systemName: "magnifyingglass")
              .font(.title2)
            Text("Enter\nLocation")
              .font(.caption)
              .multilineTextAlignment(.center)
          } // VStack
          .frame(maxWidth: .infinity, minHeight: 50)
          .padding()
          .background(Color.blue)
          .foregroundColor(.white)
          .cornerRadius(12)
        } // Button
        
                // Listen/Stop button
        Button(action:
        {
          if continuousMode
          {
            // Stop continuous mode
            speechManager.stop()
            continuousMode = false
          } // if
          else
          {
            // Start continuous mode
            continuousMode = true
            let speech = weatherService.speechText(locationName: locationManager.locationName)
            speechManager.speak(speech)
          } // else
        }) // action
        {
          VStack(spacing: 4)
          {
            Image(systemName: continuousMode ? "stop.fill" : "play.fill")
              .font(.title2)
            Text(continuousMode ? "Stop" : "Listen")
              .font(.caption)
          } // VStack
          .frame(maxWidth: .infinity, minHeight: 50)
          .padding()
          .background(!weatherService.forecastPeriods.isEmpty ? Color.green : Color.gray)
          .foregroundColor(.white)
          .cornerRadius(12)
        } // Button
        .disabled(weatherService.forecastPeriods.isEmpty)
        
                // This Location button
        Button(action:
        {
          // Stop any ongoing speech
          speechManager.stop()
          
          // Enable continuous mode
          continuousMode = true
          
          // Clear current location to force a fresh GPS lookup
          locationManager.currentLocation = nil
          
          // Request current GPS location (this will trigger weather fetch and speech via onChange handlers)
          locationManager.requestLocation()
        }) // action
        {
          VStack(spacing: 4)
          {
            Image(systemName: "location.fill")
              .font(.title2)
            Text("This\nLocation")
              .font(.caption)
              .multilineTextAlignment(.center)
          } // VStack
          .frame(maxWidth: .infinity, minHeight: 50)
          .padding()
          .background(Color.blue)
          .foregroundColor(.white)
          .cornerRadius(12)
        } // Button
        .disabled(weatherService.isLoading)
      } // HStack
      .padding(.horizontal)
      
              // Speech status (fixed height to prevent layout shift)
      Text(speechManager.isSpeaking ? speechManager.statusText : " ")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(height: 20)
      
              // Scrollable weather forecast
      ScrollView
      {
        VStack(alignment: .leading, spacing: 16)
        {
                  // Active alerts section
          if !weatherService.activeAlerts.isEmpty
          {
            VStack(alignment: .leading, spacing: 8)
            {
              HStack
              {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundStyle(.red)
                Text("ACTIVE ALERTS")
                  .font(.headline)
                  .foregroundStyle(.red)
              } // HStack
              
              ForEach(weatherService.activeAlerts.prefix(3))
              { alert in
                VStack(alignment: .leading, spacing: 4)
                {
                  Text(alert.properties.event)
                    .font(.subheadline)
                    .fontWeight(.bold)
                  
                  if let headline = alert.properties.headline
                  {
                    Text(headline)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  } // if
                } // VStack
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
              } // ForEach
            } // VStack
          } // if
          
          if weatherService.isLoading
          {
            ProgressView("Loading weather data...")
              .frame(maxWidth: .infinity)
              .padding()
          } // if
          else if let error = weatherService.errorMessage
          {
            VStack(spacing: 8)
            {
              Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
              Text(error)
                .multilineTextAlignment(.center)
            } // VStack
            .frame(maxWidth: .infinity)
            .padding()
          } // else if
          else if !weatherService.forecastPeriods.isEmpty
          {
            ForEach(weatherService.forecastPeriods.prefix(6))
            { period in
              VStack(alignment: .leading, spacing: 8)
              {
                HStack
                {
                  Text(period.name)
                    .font(.headline)
                  Spacer()
                  Text("\(period.temperature)°\(period.temperatureUnit)")
                    .font(.title2)
                    .fontWeight(.bold)
                } // HStack
                
                HStack
                {
                  Image(systemName: period.isDaytime ? "sun.max.fill" : "moon.stars.fill")
                    .foregroundStyle(period.isDaytime ? .orange : .blue)
                  Text(period.shortForecast)
                    .font(.subheadline)
                } // HStack
                
                Text(period.detailedForecast)
                  .font(.body)
                  .foregroundStyle(.secondary)
                
                HStack
                {
                  Image(systemName: "wind")
                  Text("\(period.windSpeed) \(period.windDirection)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } // HStack
              } // VStack
              .padding()
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color(.systemGray6))
              .cornerRadius(12)
            } // ForEach
          } // else if
          else
          {
            VStack(spacing: 16)
            {
              Image(systemName: "cloud.sun.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
              
              Text("Welcome to NOAA Weather")
                .font(.title2)
                .fontWeight(.bold)
              
              Text("Get real-time weather forecasts and alerts from the National Weather Service")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
              
              Text("Tap the location button to get started")
                .font(.caption)
                .foregroundStyle(.secondary)
            } // VStack
            .padding()
          } // else
        } // VStack
        .padding()
      } // ScrollView
      .frame(minHeight: 300)
      
      Spacer()
    } // VStack
    .sheet(isPresented: $showLocationSearch)
    {
      LocationSearchView(weatherService: weatherService,
                        speechManager: speechManager,
                        locationManager: locationManager,
                        continuousMode: $continuousMode)
    } // sheet
    .sheet(isPresented: $showSettings)
    {
      SettingsView(speechManager: speechManager)
    } // sheet
    .onAppear
    {
      locationManager.requestLocation()
      
      // Set up continuous weather loop
      speechManager.onSpeechFinished =
      {
        if continuousMode
        {
          // Wait 2 seconds, then refresh (weatherDataReady will trigger speech)
          Task
          {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            if let location = weatherService.currentLocation
            {
              await weatherService.fetchWeather(for: location)
              // Speech will be triggered by weatherDataReady onChange
            } // if
          } // Task
        } // if
      } // onSpeechFinished
    } // onAppear
    .onChange(of: locationManager.currentLocation)
    {
      if let location = locationManager.currentLocation
      {
        Task
        {
          await weatherService.fetchWeather(for: location)
        } // Task
      } // if
    } // onChange
    .onChange(of: weatherService.weatherDataReady)
    {
      // Auto-speak when weather data is fully loaded and continuous mode is enabled
      if weatherService.weatherDataReady && 
         !weatherService.forecastPeriods.isEmpty &&
         continuousMode
      {
        let speech = weatherService.speechText(locationName: locationManager.locationName)
        speechManager.speak(speech)
        weatherService.weatherDataReady = false  // Reset for next fetch
      } // if
      else if weatherService.weatherDataReady
      {
        // Still reset the flag even if we don't speak
        weatherService.weatherDataReady = false
      } // else if
    } // onChange
  } // body

} // struct ContentView


//------------
// Simple location manager for getting user location
@Observable
class LocationManager: NSObject, CLLocationManagerDelegate
{
  private var manager = CLLocationManager()
  var currentLocation: CLLocation?
  var locationName: String?
  var locationStatus: String = "Getting location..."
  
  
  override init()
  {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyKilometer
  } // init
  
  
  func requestLocation()
  {
    manager.requestWhenInUseAuthorization()
    manager.requestLocation()
  } // requestLocation
  
  
  func locationManager(_ manager: CLLocationManager,
                      didUpdateLocations locations: [CLLocation])
  {
    guard let location = locations.first else { return }
    currentLocation = location
    locationStatus = "Location found"
    
    // Reverse geocode to get city name
    Task
    {
      do
      {
        guard let request = MKReverseGeocodingRequest(location: location) else
        {
          self.locationName = "Current Location"
          return
        }
        let mapItems = try await request.mapItems
        
        if let mapItem = mapItems.first
        {
          let addressReps = mapItem.addressRepresentations
          
          // Try to get city and state from the new iOS 26 API
          if let city = addressReps?.cityWithContext,
             let region = addressReps?.regionName
          {
            self.locationName = "\(city), \(region)"
          } // if
          else if let city = addressReps?.cityWithContext
          {
            self.locationName = city
          } // else if
          else if let region = addressReps?.regionName
          {
            self.locationName = region
          } // else if
          else
          {
            self.locationName = "Current Location"
          } // else
        } // if
        else
        {
          self.locationName = "Current Location"
        } // else
      } // do
      catch
      {
        self.locationName = "Current Location"
        print("❌ Reverse geocoding error: \(error)")
      } // catch
    } // Task
  } // didUpdateLocations
  
  
  func locationManager(_ manager: CLLocationManager,
                      didFailWithError error: Error)
  {
    locationStatus = "Failed to get location"
    print("❌ Location error: \(error)")
  } // didFailWithError

} // class LocationManager


//------------
#Preview
{
  ContentView()
} // Preview

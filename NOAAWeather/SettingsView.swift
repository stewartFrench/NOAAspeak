//
//  SettingsView.swift
//  NOAAWeather
//
//  Created by Stewart French on 6/20/26.
//

import SwiftUI
import AVFoundation


//------------
struct SettingsView: View
{
  @Environment(\.dismiss) var dismiss
  @Bindable var speechManager: SpeechManager
  @Bindable var locationManager: LocationManager
  
  
  var body: some View
  {
    NavigationView
    {
      Form
      {
        Section(header: Text("About"))
        {
          HStack
          {
            Text("Version")
            Spacer()
            Text(appVersionWithBuild)
              .foregroundStyle(.secondary)
          } // HStack
          
          HStack
          {
            Text("Data Source")
            Spacer()
            Text("NOAA API")
              .foregroundStyle(.secondary)
          } // HStack
        } // Section
        
        Section(header: Text("Location Updates"))
        {
          Text("Automatically update location while in continuous mode")
            .font(.caption)
            .foregroundStyle(.secondary)
          
          Toggle("Auto-Update Location", isOn: $locationManager.autoUpdateLocation)
          
          if locationManager.autoUpdateLocation
          {
            VStack(alignment: .leading, spacing: 8)
            {
              Text("Update Interval")
                .font(.subheadline)
              
              Picker("Update Interval", selection: $locationManager.locationUpdateInterval)
              {
                Text("1 minute").tag(60.0)
                Text("2 minutes").tag(120.0)
                Text("5 minutes").tag(300.0)
                Text("10 minutes").tag(600.0)
                Text("15 minutes").tag(900.0)
              } // Picker
              .pickerStyle(.segmented)
              
              Text("Location will update every \(locationManager.locationUpdateInterval < 60 ? "\(Int(locationManager.locationUpdateInterval)) seconds" : "\(Int(locationManager.locationUpdateInterval / 60)) minute\(locationManager.locationUpdateInterval == 60 ? "" : "s")")")
                .font(.caption)
                .foregroundStyle(.secondary)
            } // VStack
          } // if
        } // Section
        
        Section(header: Text("Voice Selection"))
        {
          Text("Choose the voice for weather announcements")
            .font(.caption)
            .foregroundStyle(.secondary)
          
          Picker("Voice", selection: $speechManager.selectedVoiceIdentifier)
          {
            ForEach(speechManager.availableVoices, id: \.identifier)
            { voice in
              Text(voiceName(for: voice))
                .tag(voice.identifier)
            } // ForEach
          } // Picker
          .pickerStyle(.inline)
        } // Section
        
        Section(header: Text("Preview"))
        {
          Button(action:
          {
            let testText = "Here is the weather for your location. Today, partly cloudy, Temperature 75 degrees."
            speechManager.speak(testText)
          }) // action
          {
            HStack
            {
              Image(systemName: "play.circle.fill")
              Text("Test Voice")
            } // HStack
          } // Button
        } // Section
      } // Form
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar
      {
        ToolbarItem(placement: .confirmationAction)
        {
          Button("Done")
          {
            dismiss()
          } // Button
        } // ToolbarItem
      } // toolbar
    } // NavigationView
  } // body
  
  
  //----
          // Get app version with build number
  var appVersionWithBuild: String
  {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    return "\(version) (\(build))"
  } // appVersionWithBuild
  
  
  //----
          // Get friendly name for voice
  func voiceName(for voice: AVSpeechSynthesisVoice) -> String
  {
    let name = voice.name
    let language = voice.language
    let quality = voice.quality == .enhanced ? " (Enhanced)" : ""
    return "\(name) (\(language))\(quality)"
  } // voiceName

} // struct SettingsView

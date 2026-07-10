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
  
  
  var body: some View
  {
    NavigationView
    {
      Form
      {
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
        
        Section(header: Text("About"))
        {
          HStack
          {
            Text("Version")
            Spacer()
            Text("2.0")
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
          // Get friendly name for voice
  func voiceName(for voice: AVSpeechSynthesisVoice) -> String
  {
    let name = voice.name
    let language = voice.language
    let quality = voice.quality == .enhanced ? " (Enhanced)" : ""
    return "\(name) (\(language))\(quality)"
  } // voiceName

} // struct SettingsView

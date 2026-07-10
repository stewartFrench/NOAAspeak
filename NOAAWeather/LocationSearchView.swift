//
//  LocationSearchView.swift
//  NOAAWeather
//
//  Created by Stewart French on 6/15/26.
//

import SwiftUI
import MapKit


//------------
struct LocationSearchView: View
{
  @Environment(\.dismiss) var dismiss
  @Bindable var weatherService: NOAAWeatherService
  @Bindable var speechManager: SpeechManager
  @Bindable var locationManager: LocationManager
  @Binding var continuousMode: Bool
  
  @State private var searchText = ""
  @State private var searchResults: [MKLocalSearchCompletion] = []
  @State private var isSearching = false
  @State private var completerDelegate = LocationCompleterDelegate()
  
  
  var body: some View
  {
    NavigationView
    {
      VStack(spacing: 20)
      {
        Text("Search for any US location to get weather forecasts and alerts")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding()
        
        VStack(spacing: 0)
        {
          HStack
          {
            TextField("Enter city or address",
                     text: $searchText)
              .textFieldStyle(.roundedBorder)
              .autocapitalization(.words)
              .onChange(of: searchText)
              {
                completerDelegate.searchCompleter.queryFragment = searchText
              } // onChange
            
            if !searchText.isEmpty
            {
              Button(action:
              {
                searchText = ""
                searchResults = []
              }) // action
              {
                Image(systemName: "xmark.circle.fill")
                  .foregroundColor(.gray)
              } // Button
            } // if
          } // HStack
          .padding(.horizontal)
          
          // Autocomplete results
          if !searchResults.isEmpty
          {
            List(searchResults, id: \.self)
            { completion in
              Button(action:
              {
                selectCompletion(completion)
              }) // action
              {
                VStack(alignment: .leading, spacing: 4)
                {
                  Text(completion.title)
                    .font(.body)
                  Text(completion.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } // VStack
                .padding(.vertical, 4)
              } // Button
            } // List
            .listStyle(.plain)
            .frame(maxHeight: 300)
          } // if
        } // VStack
        
        if isSearching
        {
          ProgressView("Searching...")
            .padding()
        } // if
        
        Spacer()
      } // VStack
      .navigationTitle("Search Location")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar
      {
        ToolbarItem(placement: .cancellationAction)
        {
          Button("Cancel")
          {
            dismiss()
          } // Button
        } // ToolbarItem
      } // toolbar
      .onAppear
      {
        completerDelegate.onResultsUpdate =
        { results in
          searchResults = results
        } // onResultsUpdate
      } // onAppear
    } // NavigationView
  } // body
  
  
  //----
          // Select an autocomplete result
  func selectCompletion(_ completion: MKLocalSearchCompletion)
  {
    isSearching = true
    searchResults = []
    
    let request = MKLocalSearch.Request(completion: completion)
    let search = MKLocalSearch(request: request)
    
    search.start
    { response, error in
      isSearching = false
      
      if let error = error
      {
        print("❌ Search error: \(error)")
        return
      } // if
      
      guard let mapItem = response?.mapItems.first else
      {
        print("❌ No results found")
        return
      } // guard
      
      let coordinate = mapItem.location.coordinate
      let location = CLLocation(latitude: coordinate.latitude,
                               longitude: coordinate.longitude)
      
      // Stop any ongoing speech
      speechManager.stop()
      
      // Disable continuous mode temporarily to stop the location timer
      continuousMode = false
      
      // Mark this as a manual location entry
      locationManager.isManualLocation = true
      
      // Update location name
      locationManager.locationName = mapItem.name ?? "Selected Location"
      
      // Update location (this will trigger onChange in ContentView to fetch weather)
      locationManager.currentLocation = location
      
      // Re-enable continuous mode after location is set
      // This ensures the timer restarts fresh with the new location
      continuousMode = true
      
      dismiss()
    } // start
  } // selectCompletion

} // struct LocationSearchView


//------------
// Delegate for handling location search completions
class LocationCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate
{
  let searchCompleter = MKLocalSearchCompleter()
  var onResultsUpdate: (([MKLocalSearchCompletion]) -> Void)?
  
  
  override init()
  {
    super.init()
    searchCompleter.delegate = self
    searchCompleter.resultTypes = [.address, .pointOfInterest]
  } // init
  
  
  func completerDidUpdateResults(_ completer: MKLocalSearchCompleter)
  {
    onResultsUpdate?(completer.results)
  } // completerDidUpdateResults
  
  
  func completer(_ completer: MKLocalSearchCompleter,
                didFailWithError error: Error)
  {
    print("❌ Autocomplete error: \(error)")
  } // completer

} // class LocationCompleterDelegate

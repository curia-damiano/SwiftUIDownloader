//
//  ContentView.swift
//  SwiftUIDownloader
//
//  Created by Damiano Curia on 03.01.22.
//

import SwiftUI

struct ContentView: View {
	var body: some View {
		NavigationView {
			VStack {
				Spacer()
				
				NavigationLink(destination: DownloadForegroundView(vm: DownloadForegroundViewModel())) {
					Text("Download Foreground")
				}
				Spacer()
				
				NavigationLink(destination: DownloadBackgroundView(vm: DownloadBackgroundViewModel())) {
					Text("Download Background")
				}
				Spacer()
				
				NavigationLink(destination: MultipleDownloadsView(vm: MultipleDownloadsViewModel())) {
					Text("Multiple Downloads")
				}
				Spacer()
			}
			.navigationTitle("Swift Downloader")
			.navigationBarTitleDisplayMode(.automatic)
		}
		.navigationViewStyle(.stack)
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}

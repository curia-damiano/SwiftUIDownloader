//
//  ContentView.swift
//  SwiftUIDownloader
//
//  Created by Damiano Curia on 06.10.2024.
//

import SwiftUI

struct ContentView: View {
	var body: some View {
		NavigationStack {
			Spacer()

			NavigationLink("Download Foreground", destination: DownloadForegroundView(vm: DownloadForegroundViewModel()))
			Spacer()

			NavigationLink("Download Background", destination: DownloadBackgroundView(vm: DownloadBackgroundViewModel()))
			Spacer()

			NavigationLink("Multiple Downloads", destination: MultipleDownloadsView(vm: MultipleDownloadsViewModel()))
			Spacer()
		}
	}
}

#Preview {
	ContentView()
}

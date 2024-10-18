//
//  DownloadBackgroundView.swift
//  SwiftUIDownloader
//
//  Created by Damiano Curia on 06.10.2024.
//

import SwiftUI

struct DownloadBackgroundView: View {
	@ObservedObject var vm: DownloadBackgroundViewModel

	var body: some View {
		VStack {
			Spacer()

			HStack {
				Text("Download size: ")
				Picker("Download size: ", selection: $vm.selectedDownloadSize) {
					ForEach(vm.availableDownloadSizes, id: \.self) {
						Text($0)
					}
				}
				.pickerStyle(.segmented)
				.disabled(vm.isBusy)
			}
			Spacer()

			if vm.error != nil {
				Text("Error: \(vm.error!)")
			}
			if vm.percentage != nil {
				Text("Downloaded percentage: \(vm.percentage!) %")
			}
			if vm.fileName != nil {
				Text("File name: \(vm.fileName!)")
			}
			if vm.downloadedSize != nil {
				Text("Downloaded size: \(vm.downloadedSize!)")
			}
			Spacer()

			Group {
				Button("Download in Background") {
					vm.downloadInBackground()
				}
				.disabled(vm.isBusy)
				HStack {
					Button("Pause") {
						vm.pauseDownload()
					}
					.disabled(!vm.canPauseDownload)

					Button("Resume") {
						vm.resumeDownload()
					}
					.disabled(!vm.canResumeDownload)
				}
			}
			Spacer()
		}
		.padding()
	}
}

#Preview {
	DownloadBackgroundView(vm: DownloadBackgroundViewModel())
}

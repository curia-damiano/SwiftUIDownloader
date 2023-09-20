//
//  MultipleDownloadsView.swift
//  SwiftUIDownloader
//
//  Created by Damiano Curia on 03.01.22.
//

import SwiftUI

struct MultipleDownloadsView: View {
	@ObservedObject var vm: MultipleDownloadsViewModel
	
	var body: some View {
		VStack {
			List {
				ForEach(vm.downloads.indices, id: \.self) { index in // See https://twitter.com/lostmoa_nz/status/1256152748447330304
					MultipleDownloadsListRowView(vm: vm, download: vm.downloads[index])
				}
			}
		}
		.padding()
	}
}

struct MultipleDownloadsView_Previews: PreviewProvider {
	static var previews: some View {
		MultipleDownloadsView(vm: MultipleDownloadsViewModel())
	}
}

struct MultipleDownloadsListRowView: View {
	let vm: MultipleDownloadsViewModel
	@ObservedObject var download: DownloadModel
	
	var body: some View {
		VStack {
			Group {
				Text(download.fileToDownload)
				Text("Status: " + (download.isBusy ? "downloading..." : "idle"))
				if download.error != nil {
					Text("Error: \(download.error!)")
				}
				if download.percentage != nil {
					Text("Downloaded percentage: \(download.percentage!) %")
				}
				if download.fileName != nil {
					Text("File name: \(download.fileName!)")
				}
				if download.downloadedSize != nil {
					Text("Downloaded size: \(download.downloadedSize!)")
				}
			}
			Button("Download") {
				vm.downloadInBackground(download: download)
			}
			.disabled(download.isBusy)
			
			HStack {
				Button("Pause") {
					vm.pauseDownload(download: download)
				}
				.disabled(!vm.canPauseDownload(download: download))
				
				Button("Resume") {
					vm.resumeDownload(download: download)
				}
				.disabled(!vm.canResumeDownload(download: download))
			}
		}
	}
}

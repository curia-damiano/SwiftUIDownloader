//
//  MultipleDownloadsViewModel.swift
//  SwiftUIDownloader
//
//  Created by Damiano Curia on 03.01.22.
//

import Foundation

@MainActor
class DownloadModel: Identifiable, ObservableObject {
	let id = UUID().uuidString
	let fileToDownload: String
	@Published var isBusy: Bool = false
	@Published var error: String? = nil
	@Published var percentage: Int? = nil
	@Published var fileName: String? = nil
	@Published var downloadedSize: UInt64? = nil
	@Published var downloadTask: URLSessionDownloadTask? = nil
	@Published var resumeData: Data? = nil
	
	init(fileToDownload: String) {
		self.fileToDownload = fileToDownload
	}
}

@MainActor
class MultipleDownloadsViewModel: NSObject, ObservableObject {
	@Published var downloads: [DownloadModel]

	// Init of properties in actor: see https://stackoverflow.com/questions/71396296/how-do-i-fix-expression-requiring-global-actor-mainactor-cannot-appear-in-def/71412877#71412877
	@MainActor override init() {
		downloads = [
			DownloadModel(fileToDownload: "https://speed.hetzner.de/100MB.bin"),
			DownloadModel(fileToDownload: "https://speed.hetzner.de/1GB.bin"),
			DownloadModel(fileToDownload: "https://speed.hetzner.de/10GB.bin")
		]
	}

	// https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_in_the_background
	private lazy var urlSession: URLSession = {
		let config = URLSessionConfiguration.background(withIdentifier: "me.curia.MySessionMultiple")
		config.isDiscretionary = true
		config.sessionSendsLaunchEvents = true
		return URLSession(configuration: config, delegate: self, delegateQueue: nil)
	}()
	func downloadInBackground(download: DownloadModel) {
		download.isBusy = true
		download.error = nil
		download.percentage = 0
		download.fileName = nil
		download.downloadedSize = nil
		
		let downloadTask = urlSession.downloadTask(with: URL(string: download.fileToDownload)!)
		//downloadTask.earliestBeginDate = Date().addingTimeInterval(60 * 60)
		//downloadTask.countOfBytesClientExpectsToSend = 200
		//downloadTask.countOfBytesClientExpectsToReceive = 500 * 1024
		downloadTask.resume()
		download.downloadTask = downloadTask
	}
	
	// https://developer.apple.com/documentation/foundation/url_loading_system/pausing_and_resuming_downloads
	func canPauseDownload(download: DownloadModel) -> Bool {
		return download.downloadTask != nil && download.resumeData == nil
	}
	func pauseDownload(download: DownloadModel) {
		guard let downloadTask = download.downloadTask else {
			return
		}
		downloadTask.cancel { resumeDataOrNil in
			guard let resumeData = resumeDataOrNil else {
				// download can't be resumed; remove from UI if necessary
				return
			}
			Task { @MainActor in download.resumeData = resumeData }
		}
	}
	
	// https://developer.apple.com/documentation/foundation/url_loading_system/pausing_and_resuming_downloads
	func canResumeDownload(download: DownloadModel) -> Bool {
		return download.resumeData != nil
	}
	func resumeDownload(download: DownloadModel) {
		guard let resumeData = download.resumeData else {
			return
		}
		let downloadTask = urlSession.downloadTask(withResumeData: resumeData)
		downloadTask.resume()
		download.error = nil
		download.downloadTask = downloadTask
		download.resumeData = nil
	}
}

extension MultipleDownloadsViewModel: URLSessionDownloadDelegate
{
	// https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_from_websites
	func urlSession(_ session: URLSession,
					downloadTask: URLSessionDownloadTask,
					didWriteData bytesWritten: Int64,
					totalBytesWritten: Int64,
					totalBytesExpectedToWrite: Int64) {
		guard let download = self.downloads.first(where: { $0.downloadTask == downloadTask }) else {
			return
		}
		let percentage = Int(totalBytesWritten * 100 / totalBytesExpectedToWrite)

		Task { @MainActor in download.percentage = percentage }
	}
	
	// https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_from_websites
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		/*guard let absoluteUrl = downloadTask.originalRequest?.url?.absoluteString else {
			return
		}
		guard let download = self.downloads.first(where: { $0.fileToDownload == absoluteUrl }) else {
			return
		}*/
		guard let download = self.downloads.first(where: { $0.downloadTask == downloadTask }) else {
			return
		}
		
		defer {
			Task { @MainActor in download.isBusy = false }
		}
		
		guard let httpResponse = downloadTask.response as? HTTPURLResponse else {
			Task { @MainActor in download.error = "No HTTP Result" }
			return
		}
		guard (200...299).contains(httpResponse.statusCode) else {
			Task { @MainActor in download.error = "Http Result: \(httpResponse.statusCode)" }
			return
		}
		
		let fileName = location.path
		let attributes = try? FileManager.default.attributesOfItem(atPath: fileName)
		let fileSize = attributes?[.size] as? UInt64
		
		Task { @MainActor in
			download.error = nil
			download.percentage = 100
			download.fileName = fileName
			download.downloadedSize = fileSize
			download.downloadTask = nil
		}
	}
	
	// https://developer.apple.com/documentation/foundation/url_loading_system/pausing_and_resuming_downloads
	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		guard let absoluteUrl = task.originalRequest?.url?.absoluteString else {
			return
		}
		guard let download = self.downloads.first(where: { $0.fileToDownload == absoluteUrl }) else {
			return
		}
		
		guard let error = error else {
			return
		}
		Task { @MainActor in download.error = error.localizedDescription }
		
		let userInfo = (error as NSError).userInfo
		if let resumeData = userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
			Task { @MainActor in download.resumeData = resumeData }
		} else {
			Task { @MainActor in
				download.isBusy = false
				download.downloadTask = nil
			}
		}
	}
}

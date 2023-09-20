//
//  DownloadBackgroundViewModel.swift
//  SwiftUIDownloader
//
//  Created by Damiano Curia on 03.01.22.
//

import Foundation

@MainActor
class DownloadBackgroundViewModel: NSObject, ObservableObject {
	let urlToDownloadFormat = "https://speed.hetzner.de/%1$@.bin"
	let availableDownloadSizes = ["100MB", "1GB", "10GB", "ERR"]
	var selectedDownloadSize: String = "100MB"
	var fileToDownload: String {
		get {
			String(format: urlToDownloadFormat, selectedDownloadSize)
		}
	}
	
	@Published private(set) var isBusy = false
	@Published private(set) var error: String? = nil
	@Published private(set) var percentage: Int? = nil
	@Published private(set) var fileName: String? = nil
	@Published private(set) var downloadedSize: UInt64? = nil

	// https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_in_the_background
	private lazy var urlSession: URLSession = {
		let config = URLSessionConfiguration.background(withIdentifier: "me.curia.MySessionBackground")
		config.isDiscretionary = true
		config.sessionSendsLaunchEvents = true
		return URLSession(configuration: config, delegate: self, delegateQueue: nil)
	}()
	@Published private var downloadTask: URLSessionDownloadTask? = nil
	func downloadInBackground() {
		self.isBusy = true
		self.error = nil
		self.percentage = 0
		self.fileName = nil
		self.downloadedSize = nil
		
		let downloadTask = urlSession.downloadTask(with: URL(string: fileToDownload)!)
		//downloadTask.earliestBeginDate = Date().addingTimeInterval(60 * 60)
		//downloadTask.countOfBytesClientExpectsToSend = 200
		//downloadTask.countOfBytesClientExpectsToReceive = 500 * 1024
		downloadTask.resume()
		self.downloadTask = downloadTask
	}
	
	// https://developer.apple.com/documentation/foundation/url_loading_system/pausing_and_resuming_downloads
	@Published private var resumeData: Data? = nil
	var canPauseDownload: Bool {
		get { return self.downloadTask != nil && self.resumeData == nil }
	}
	func pauseDownload() {
		guard let downloadTask = self.downloadTask else {
			return
		}
		downloadTask.cancel { resumeDataOrNil in
			guard let resumeData = resumeDataOrNil else {
				// download can't be resumed; remove from UI if necessary
				return
			}
			Task { @MainActor in self.resumeData = resumeData }
		}
	}
	
	// https://developer.apple.com/documentation/foundation/url_loading_system/pausing_and_resuming_downloads
	var canResumeDownload: Bool {
		get { return self.resumeData != nil }
	}
	func resumeDownload() {
		guard let resumeData = self.resumeData else {
			return
		}
		let downloadTask = urlSession.downloadTask(withResumeData: resumeData)
		downloadTask.resume()
		self.error = nil
		self.downloadTask = downloadTask
		self.resumeData = nil
	}
}

extension DownloadBackgroundViewModel: URLSessionDownloadDelegate
{
	// https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_from_websites
	func urlSession(_ session: URLSession,
					downloadTask: URLSessionDownloadTask,
					didWriteData bytesWritten: Int64,
					totalBytesWritten: Int64,
					totalBytesExpectedToWrite: Int64) {
		if downloadTask != self.downloadTask {
			return
		}
		
		let percentage = Int(totalBytesWritten * 100 / totalBytesExpectedToWrite)

		Task { @MainActor in self.percentage = percentage }
	}
	
	// https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_from_websites
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		if downloadTask != self.downloadTask {
			return
		}
		
		defer {
			Task { @MainActor in self.isBusy = false }
		}
		
		guard let httpResponse = downloadTask.response as? HTTPURLResponse else {
			Task { @MainActor in self.error = "No HTTP Result" }
			return
		}
		guard (200...299).contains(httpResponse.statusCode) else {
			Task { @MainActor in self.error = "Http Result: \(httpResponse.statusCode)" }
			return
		}
		
		let fileName = location.path
		let attributes = try? FileManager.default.attributesOfItem(atPath: fileName)
		let fileSize = attributes?[.size] as? UInt64
		
		Task { @MainActor in
			self.error = nil
			self.percentage = 100
			self.fileName = fileName
			self.downloadedSize = fileSize
			self.downloadTask = nil
		}
	}
	
	// https://developer.apple.com/documentation/foundation/url_loading_system/pausing_and_resuming_downloads
	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		guard let error = error else {
			return
		}
		Task { @MainActor in self.error = error.localizedDescription }
		
		let userInfo = (error as NSError).userInfo
		if let resumeData = userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
			Task { @MainActor in self.resumeData = resumeData }
		} else {
			Task { @MainActor in
				self.isBusy = false
				self.downloadTask = nil
			}
		}
	}
}

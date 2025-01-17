//
//  DownloadForegroundViewModel.swift
//  SwiftUIDownloader
//
//  Created by Damiano Curia on 06.10.2024.
//

import Foundation

@MainActor
class DownloadForegroundViewModel: NSObject, ObservableObject {
	let urlToDownloadFormat = "https://ash-speed.hetzner.com/%1$@.bin"
	let availableDownloadSizes = ["100MB", "1GB", "10GB", "ERR"]
	var selectedDownloadSize: String = "100MB"
	var fileToDownload: String {
		String(format: urlToDownloadFormat, selectedDownloadSize)
	}

	@Published private(set) var isBusy = false
	@Published private(set) var error: String? = nil
	@Published private(set) var percentage: Int? = nil
	@Published private(set) var fileName: String? = nil
	@Published private(set) var downloadedSize: UInt64? = nil

	// https://developer.apple.com/documentation/foundation/url_loading_system/fetching_website_data_into_memory
	func downloadInMemory() async {
		self.isBusy = true
		self.error = nil
		self.percentage = 0
		self.fileName = nil
		self.downloadedSize = nil

		defer {
			self.isBusy = false
		}

		do {
			let config = URLSessionConfiguration.default
			config.httpAdditionalHeaders = ["User-Agent": ""]
			// config.waitsForConnectivity = false
			// config.allowsCellularAccess = true
			// config.allowsConstrainedNetworkAccess = true
			let urlSession = URLSession(configuration: config)
			let (data, response) = try await urlSession.data(from: URL(string: fileToDownload)!)
			guard let httpResponse = response as? HTTPURLResponse else {
				self.error = "No HTTP Result"
				return
			}
			guard (200...299).contains(httpResponse.statusCode) else {
				self.error =  "Http Result: \(httpResponse.statusCode)"
				return
			}

			self.error = nil
			self.percentage = 100
			self.fileName = nil
			self.downloadedSize = UInt64(data.count)
		} catch {
			self.error = error.localizedDescription
		}
	}

	// https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_from_websites
	func downloadToFile() async {
		self.isBusy = true
		self.error = nil
		self.percentage = 0
		self.fileName = nil
		self.downloadedSize = nil

		defer {
			self.isBusy = false
		}

		do {
			let config = URLSessionConfiguration.default
			config.httpAdditionalHeaders = ["User-Agent": ""]
			// config.waitsForConnectivity = false
			// config.allowsCellularAccess = true
			// config.allowsConstrainedNetworkAccess = true
			let urlSession = URLSession(configuration: config)
			let (localURL, response) = try await urlSession.download(from: URL(string: fileToDownload)!)
			guard let httpResponse = response as? HTTPURLResponse else {
				self.error = "No HTTP Result"
				return
			}
			guard (200...299).contains(httpResponse.statusCode) else {
				self.error = "Http Result: \(httpResponse.statusCode)"
				return
			}

			let attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
			let fileSize = attributes[.size] as? UInt64

			self.error = nil
			self.percentage = 100
			self.fileName = localURL.path
			self.downloadedSize = fileSize
		} catch {
			self.error = error.localizedDescription
		}
	}

	// https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_from_websites
	private lazy var urlSession: URLSession = {
		let config = URLSessionConfiguration.default
		config.httpAdditionalHeaders = ["User-Agent": ""]
		// config.waitsForConnectivity = false
		// config.allowsCellularAccess = true
		// config.allowsConstrainedNetworkAccess = true
		return URLSession(configuration: config, delegate: self, delegateQueue: nil)
	}()
	@Published private var downloadTask: URLSessionDownloadTask? = nil
	func downloadToFileWithProgress() async {
		self.isBusy = true
		self.error = nil
		self.percentage = 0
		self.fileName = nil
		self.downloadedSize = nil

		let downloadTask = urlSession.downloadTask(with: URL(string: fileToDownload)!)
		downloadTask.resume()
		self.downloadTask = downloadTask
	}

	// https://developer.apple.com/documentation/foundation/url_loading_system/pausing_and_resuming_downloads
	@Published private var resumeData: Data? = nil
	var canPauseDownload: Bool {
		self.downloadTask != nil && self.resumeData == nil
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
		self.resumeData != nil
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

extension DownloadForegroundViewModel: URLSessionDownloadDelegate {
	// https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_from_websites
	nonisolated func urlSession(_ session: URLSession,
					 downloadTask: URLSessionDownloadTask,
					 didWriteData bytesWritten: Int64,
					 totalBytesWritten: Int64,
					 totalBytesExpectedToWrite: Int64) {
		Task { @MainActor in
			if downloadTask != self.downloadTask {
				return
			}

			let percentage = Int(totalBytesWritten * 100 / totalBytesExpectedToWrite)

			self.percentage = percentage
		}
	}

	// https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_from_websites
	nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		Task { @MainActor in
			if downloadTask != self.downloadTask {
				return
			}

			self.isBusy = false

			guard let httpResponse = downloadTask.response as? HTTPURLResponse else {
				self.error = "No HTTP Result"
				return
			}
			guard (200...299).contains(httpResponse.statusCode) else {
				self.error = "Http Result: \(httpResponse.statusCode)"
				return
			}

			let fileName = location.path
			let attributes = try? FileManager.default.attributesOfItem(atPath: fileName)
			let fileSize = attributes?[.size] as? UInt64

			self.error = nil
			self.percentage = 100
			self.fileName = fileName
			self.downloadedSize = fileSize
			self.downloadTask = nil
		}
	}

	// https://developer.apple.com/documentation/foundation/url_loading_system/pausing_and_resuming_downloads
	nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		guard let error = error else {
			return
		}

		Task { @MainActor in
			self.error = error.localizedDescription

			let userInfo = (error as NSError).userInfo
			if let resumeData = userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
				self.resumeData = resumeData
			} else {
				self.isBusy = false
				self.downloadTask = nil
			}
		}
	}
}

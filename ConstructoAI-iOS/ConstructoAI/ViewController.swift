//
//  ViewController.swift
//  ConstructoAI
//
//  WebView wrapper pour constructoai.ca avec support complet
//  pour iOS et macOS (Mac Catalyst)
//

import UIKit
import WebKit

class ViewController: UIViewController {

    // MARK: - Properties

    private var webView: WKWebView!
    private var refreshControl: UIRefreshControl!
    private var loadingView: UIView!
    private var activityIndicator: UIActivityIndicatorView!
    private var loadingLabel: UILabel!

    private let appURL = "https://app.constructoai.ca/"

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLoadingView()
        setupWebView()
        loadWebsite()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - Setup

    private func setupLoadingView() {
        // Vue de chargement
        loadingView = UIView()
        loadingView.backgroundColor = UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0) // #007AFF
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingView)

        // Indicateur d'activité
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        loadingView.addSubview(activityIndicator)

        // Label de chargement
        loadingLabel = UILabel()
        loadingLabel.text = "Chargement..."
        loadingLabel.textColor = .white
        loadingLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingView.addSubview(loadingLabel)

        NSLayoutConstraint.activate([
            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor, constant: -20),

            loadingLabel.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16)
        ])
    }

    private func setupWebView() {
        // Configuration WebView
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // Préférences
        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences = preferences

        // Configuration de la page web
        let pagePreferences = WKWebpagePreferences()
        pagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = pagePreferences

        // Processus de contenu
        configuration.processPool = WKProcessPool()

        // Créer le WebView
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = true

        #if !targetEnvironment(macCatalyst)
        // Pull-to-refresh uniquement sur iOS
        refreshControl = UIRefreshControl()
        refreshControl.tintColor = UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)
        refreshControl.addTarget(self, action: #selector(refreshWebView), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl
        #endif

        // Safe area pour éviter l'encoche
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic

        view.insertSubview(webView, at: 0)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadWebsite() {
        guard let url = URL(string: appURL) else { return }
        let request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 30)
        webView.load(request)
    }

    // MARK: - Actions

    @objc private func refreshWebView() {
        // Pour les SPA, utiliser JavaScript pour rafraîchir sans recharger complètement
        let currentURL = webView.url?.absoluteString ?? ""
        if currentURL.contains("constructoai.ca") || currentURL.contains("app.constructoai.ca") {
            // Rafraîchissement doux pour SPA
            webView.evaluateJavaScript("window.location.reload();") { [weak self] _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.refreshControl?.endRefreshing()
                }
            }
        } else {
            webView.reload()
        }
    }

    private func hideLoadingView() {
        UIView.animate(withDuration: 0.3, animations: {
            self.loadingView.alpha = 0
        }) { _ in
            self.loadingView.isHidden = true
        }
    }

    private func showLoadingView() {
        loadingView.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.loadingView.alpha = 1
        }
    }
}

// MARK: - WKNavigationDelegate

extension ViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refreshControl?.endRefreshing()
        hideLoadingView()

        // Injecter du CSS pour améliorer l'affichage
        let css = """
        body {
            -webkit-touch-callout: none;
            -webkit-user-select: none;
        }
        """
        let js = "var style = document.createElement('style'); style.innerHTML = '\(css)'; document.head.appendChild(style);"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        refreshControl?.endRefreshing()
        hideLoadingView()
        showErrorAlert(error: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        refreshControl?.endRefreshing()
        hideLoadingView()
        showErrorAlert(error: error)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        // Ouvrir les liens externes dans Safari
        if let host = url.host,
           !host.contains("constructoai.ca") &&
           navigationAction.navigationType == .linkActivated {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        // Gérer les schémas spéciaux (tel:, mailto:, etc.)
        if let scheme = url.scheme,
           ["tel", "mailto", "sms", "facetime"].contains(scheme) {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    private func showErrorAlert(error: Error) {
        let alert = UIAlertController(
            title: "Erreur de connexion",
            message: "Impossible de charger l'application. Vérifiez votre connexion internet et réessayez.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Réessayer", style: .default) { [weak self] _ in
            self?.showLoadingView()
            self?.loadWebsite()
        })
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - WKUIDelegate

extension ViewController: WKUIDelegate {

    // Gestion des alertes JavaScript
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler()
        })
        present(alert, animated: true)
    }

    // Gestion des confirmations JavaScript
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { _ in
            completionHandler(false)
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(true)
        })
        present(alert, animated: true)
    }

    // Gestion des prompts JavaScript
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = defaultText
        }
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { _ in
            completionHandler(nil)
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
        })
        present(alert, animated: true)
    }

    // Gestion de l'upload de fichiers
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        #if targetEnvironment(macCatalyst)
        // Sur Mac, utiliser le panneau de fichiers natif
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        documentPicker.allowsMultipleSelection = parameters.allowsMultipleSelection
        documentPicker.delegate = FilePickerDelegate(completionHandler: completionHandler)
        present(documentPicker, animated: true)
        #else
        // Sur iOS, utiliser UIImagePickerController ou UIDocumentPickerViewController
        let actionSheet = UIAlertController(title: "Choisir un fichier", message: nil, preferredStyle: .actionSheet)

        // Option: Photothèque
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            actionSheet.addAction(UIAlertAction(title: "Photothèque", style: .default) { [weak self] _ in
                self?.presentImagePicker(sourceType: .photoLibrary, completionHandler: completionHandler)
            })
        }

        // Option: Caméra
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            actionSheet.addAction(UIAlertAction(title: "Prendre une photo", style: .default) { [weak self] _ in
                self?.presentImagePicker(sourceType: .camera, completionHandler: completionHandler)
            })
        }

        // Option: Documents
        actionSheet.addAction(UIAlertAction(title: "Documents", style: .default) { [weak self] _ in
            self?.presentDocumentPicker(allowsMultipleSelection: parameters.allowsMultipleSelection, completionHandler: completionHandler)
        })

        actionSheet.addAction(UIAlertAction(title: "Annuler", style: .cancel) { _ in
            completionHandler(nil)
        })

        // Support iPad
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = view
            popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }

        present(actionSheet, animated: true)
        #endif
    }

    #if !targetEnvironment(macCatalyst)
    private func presentImagePicker(sourceType: UIImagePickerController.SourceType, completionHandler: @escaping ([URL]?) -> Void) {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = ImagePickerDelegate(completionHandler: completionHandler)
        picker.modalPresentationStyle = .fullScreen
        present(picker, animated: true)
    }

    private func presentDocumentPicker(allowsMultipleSelection: Bool, completionHandler: @escaping ([URL]?) -> Void) {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        documentPicker.allowsMultipleSelection = allowsMultipleSelection
        documentPicker.delegate = FilePickerDelegate(completionHandler: completionHandler)
        present(documentPicker, animated: true)
    }
    #endif

    // Gestion des nouvelles fenêtres
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Ouvrir les liens target="_blank" dans le même webview
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

// MARK: - File Picker Delegate

class FilePickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let completionHandler: ([URL]?) -> Void

    init(completionHandler: @escaping ([URL]?) -> Void) {
        self.completionHandler = completionHandler
        super.init()
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        completionHandler(urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completionHandler(nil)
    }
}

// MARK: - Image Picker Delegate

#if !targetEnvironment(macCatalyst)
class ImagePickerDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let completionHandler: ([URL]?) -> Void

    init(completionHandler: @escaping ([URL]?) -> Void) {
        self.completionHandler = completionHandler
        super.init()
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)

        if let imageURL = info[.imageURL] as? URL {
            completionHandler([imageURL])
        } else if let image = info[.originalImage] as? UIImage {
            // Sauvegarder l'image temporairement
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
            if let data = image.jpegData(compressionQuality: 0.8) {
                try? data.write(to: tempURL)
                completionHandler([tempURL])
            } else {
                completionHandler(nil)
            }
        } else {
            completionHandler(nil)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        completionHandler(nil)
    }
}
#endif

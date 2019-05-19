//
//  ScarRecognisitionViewController.swift
//  dmMD
//
//  Created by Siddharth on 18/05/19.
//  Copyright © 2019 Siddharth. All rights reserved.
//

import UIKit
import ARKit
import CoreML
import Vision
import ImageIO
import Foundation

class ScarRecognisitionViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var camScanner: ARSCNView!
    
    private var rashInfo = RashIdentifierViewController()
    
    lazy var config = ARWorldTrackingConfiguration()
    //private var companyInfo = CompanyInformationViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        _ = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true, block: { timer in
            let image = self.camScanner.snapshot()
            self.updateClassifications(for: image)
        })
        
        camScanner.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        //config.planeDetection = .vertical
        camScanner.session.run(config)
        camScanner.delegate = self
        //        let popUp = SCNPlane(width: 0.1, height: 0.1)
        //        popUp.firstMaterial?.diffuse.contents = companyInfo.view
        //        let popUpNode = SCNNode(geometry: popUp)
        //        popUpNode.position = SCNVector3(0.1, 0.1, -0.1)
        //        camScanner.scene.rootNode.addChildNode(popUpNode)
        
    }
    
    
    /// - Tag: MLModelSetup
    lazy var classificationRequest: VNCoreMLRequest = {
        do {
            /*
             Use the Swift class `MobileNet` Core ML generates from the model.
             To use a different Core ML classifier model, add it to the project
             and replace `MobileNet` with that model's generated Swift class.
             */
            let model = try VNCoreMLModel(for: ImageClassifier().model)
            
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    /// - Tag: PerformRequests
    func updateClassifications(for image: UIImage) {
        print("Classifying...")
        
        guard let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue)) else { return }
        guard let ciImage = CIImage(image: image) else { fatalError("Unable to create \(CIImage.self) from \(image).") }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
            do {
                try handler.perform([self.classificationRequest])
            } catch {
                /*
                 This handler catches general image processing errors. The `classificationRequest`'s
                 completion handler `processClassifications(_:error:)` catches errors specific
                 to processing that request.
                 */
                print("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }
    
    /// Updates the UI with the results of the classification.
    /// - Tag: ProcessClassifications
    func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                print("Unable to classify image.\n\(error!.localizedDescription)")
                return
            }
            // The `results` will always be `VNClassificationObservation`s, as specified by the Core ML model in this project.
            let classifications = results as! [VNClassificationObservation]
            print("F")
            if classifications.isEmpty {
                print("Nothing recognized.")
            } else {
                // Display top classifications ranked by confidence in the UI.
                let topClassifications = classifications.prefix(1)
                let descriptions = topClassifications.map { classification in
                    // Formats the classification for display; e.g. "(0.37) cliff, drop, drop-off".
                    return String(format: "%.2f)%@", classification.confidence, classification.identifier)
                }
                print("Classification:\n" + descriptions.joined(separator: "\n"))
                
                let confidence = descriptions[0].prefix(3)
                let title = descriptions[0].dropFirst(5)
                
                let data = (String(confidence), String(title))
                self.determineLogo(typeRash: data)
            }
        }
    }
    
    func determineLogo (typeRash: (String, String)) {
        print("data: ", typeRash)
        if(Double(typeRash.0)! > 0.85 && typeRash.1 != "logo_none") {

            let popUp = SCNPlane(width: 0.1, height: 0.1)
            popUp.firstMaterial?.diffuse.contents = rashInfo.view
            let popUpNode = SCNNode(geometry: popUp)
            popUpNode.position = SCNVector3(0.1, 0.1, -0.1)
            camScanner.scene.rootNode.addChildNode(popUpNode)


            rashInfo._rashLabel = typeRash.1
            rashInfo.updateContent()
        }
    }
}

//
//  ViewController.swift
//  CoreML_Demo
//
//  Created by Hung Chang Lo on 2018/9/5.
//  Copyright © 2018年 Hung Chang Lo. All rights reserved.
//

import UIKit
import CoreML

// https://developer.apple.com/documentation/coreml
// https://www.appcoda.com.tw/coreml-introduction/
// note: model https://developer.apple.com/machine-learning/build-run-models/

class ViewController: UIViewController, UINavigationControllerDelegate {
    
    var model: Inceptionv3!
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 初始化，當你的 App 試著識別你的圖像裡有哪些物件時，會快上許多。
        model = Inceptionv3()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    // MARK: - IBAction
    
    @IBAction func cameraButtonDidPushed(_ sender: UIBarButtonItem) {
        
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            return
        }
        
        let cameraPicker = UIImagePickerController()
        cameraPicker.delegate = self
        cameraPicker.sourceType = .camera
        cameraPicker.allowsEditing = false
        
        present(cameraPicker, animated: true)
    }
    
    @IBAction func openLibraryButtonDidPushed(_ sender: UIButton) {
        
        let picker = UIImagePickerController()
        picker.allowsEditing = false
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true)
    }
}



// MARK: - UIImagePickerControllerDelegate

extension ViewController: UIImagePickerControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    // 處理選取完照片的後續動作。
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        // 我們從 info 這個 Dictionary (使用 UIImagePickerControllerOriginalImage 這個 key)裡取回了選取的的圖像。同時我們讓 UIImagePickerController 在我們選取圖像後消失
        picker.dismiss(animated: true)
        descriptionLabel.text = "Analyzing Image..."
        guard let image = info["UIImagePickerControllerOriginalImage"] as? UIImage else {
            return
        }
        
        // 重劃一個大小為 299 * 299的點陣圖
        // 因為我們使用的模型只接受 299x299 的尺寸，所以將圖像轉換為正方形，並將這個新的正方形圖像指定給另個常數 newImage
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 299, height: 299), true, 2.0)
        image.draw(in: CGRect(x: 0, y: 0, width: 299, height: 299))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        // 我們把 newImage 轉換為 CVPixelBuffer。 給對於 CVPixelBuffer 不熟悉的人， CVPixelBuffers 是一個將像數（Pixcel）存在主記憶體裡的圖像緩衝器．
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(newImage.size.width), Int(newImage.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
            return
        }
        
        // 確保圖像的記憶體空間是可以存取的
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(newImage.size.width), height: Int(newImage.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) //3
        
        // 我們取得了這個圖像裡的像數並轉換為裝置的 RGB 色彩。接著把這些資料作成 CGContext。這樣一來每當我們需要渲染（或是改變）一些底層屬性時可以很輕易的呼叫使用。最後的兩行程式碼即是以此進行翻轉以及縮放。
        context?.translateBy(x: 0, y: newImage.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        // 我們完成新圖像的繪製並把舊的資料移除，然後將 newImage 指定給 imageView.image
        UIGraphicsPushContext(context!)
        newImage.draw(in: CGRect(x: 0, y: 0, width: newImage.size.width, height: newImage.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        imageView.image = newImage
        
        // 我們使用 Inceptionv3 模型來作物件識別
        guard let prediction = try? model.prediction(image: pixelBuffer!) else {
            return
        }
        
        descriptionLabel.text = "I think this is a \(prediction.classLabel)."
        NSLog("prediction.classLabelProbs = \(prediction.classLabelProbs)")
    }
}


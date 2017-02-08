//
//  ViewController.swift
//  LYImagePicker
//
//  Created by tony on 2017/2/8.
//  Copyright © 2017年 chengkaizone. All rights reserved.
//

import UIKit
import Photos

class ViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func pickerAction(_ sender: Any) {
        
        let control = LYImagePickerViewController()
        control.choiceMode = 1
        control.delegate = self
        
        self.present(control, animated: true, completion: nil)
    }
}

extension ViewController: LYImagePickerViewControllerDelegate {
    
    func imagePicker(assets: [PHAsset]!, completion: Bool) {
        
        
        if completion {
            print("results: \(assets.count)")
        } else {
            print("false")
        }
    }
    
}

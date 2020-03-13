//
//  GestureViewController.swift
//  GestureAI
//
//  Created by akimach on 2017/09/25.
//  Copyright © 2017年 akimach. All rights reserved.
//

import UIKit
import CoreML
import CoreMotion

class GestureViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource{
    
    // MARK:- Properties
    
    private var gestureAI = GestureAlphabetProcessor()
    private let queue = OperationQueue.init()
    private let motionManager = CMMotionManager()
    private lazy var timer: Timer = {
        Timer.scheduledTimer(timeInterval: 1.0, target: self,
                             selector: #selector(self.updateTimer(tm:)), userInfo: nil, repeats: true)
    }()
    let userDefaults = UserDefaults.standard
    
    private let timeMax: Int = 4
    private var cntTimer: Int = 0
    private let inputDim: Int = 3
    private let lengthMax: Int = 40
    private var sequenceTargetX: [Double] = []
    private var sequenceTargetY: [Double] = []
    private var sequenceTargetZ: [Double] = []
    
    // MARK:- Outlets
    
    @IBOutlet weak var gaBtn: UIButton!
    @IBOutlet weak var recBtn: UIButton!
    @IBOutlet weak var recPicker: UIPickerView!
    @IBOutlet weak var gaArea: UILabel!
    
    var pickerData: [String] = ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"];
    
    // MARK:- UIViewControllers
    
    override func viewDidLoad() {
        super.viewDidLoad();
        self.recPicker.delegate = self;
        self.recPicker.dataSource = self;
        motionManager.accelerometerUpdateInterval = 0.1
        let statusBar = UIView(frame:CGRect(x: 0.0, y: 0.0, width: UIScreen.main.bounds.size.width, height: 20.0))
        statusBar.backgroundColor = GAColor.btnSensing
        self.view.addSubview(statusBar)
        
        // Setup outlets
        gaBtn.layer.masksToBounds = true
        gaBtn.layer.cornerRadius = gaBtn.frame.width / 2.0
        gaBtn.backgroundColor = GAColor.btnNormal
        gaBtn.setImage(UIImage(contentsOfFile: "gesture"), for: UIControlState.highlighted)
        gaBtn.adjustsImageWhenHighlighted = false
        gaArea.backgroundColor = GAColor.btnSensing
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerData.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerData[row]
    }
    
    // MARK:- Events
    
    @IBAction func gaBtnTouchDown(_ sender: Any) {
        gaBtn.backgroundColor = GAColor.btnSensing
        self.sequenceTargetX = []
        self.sequenceTargetY = []
        self.sequenceTargetZ = []
        
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.updateTimer(tm:)), userInfo: nil, repeats: true)
        timer.fire()
        
        motionManager.startAccelerometerUpdates(to: queue, withHandler: {
            (accelerometerData, error) in
            if let e = error {
                fatalError(e.localizedDescription)
            }
            guard let data = accelerometerData else { return }
            self.sequenceTargetX.append(data.acceleration.x)
            self.sequenceTargetY.append(data.acceleration.y)
            self.sequenceTargetZ.append(data.acceleration.z)
        })
    }
    
    
    @IBAction func gaBtnTouchUpInside(_ sender: Any) {
        gaBtn.backgroundColor = GAColor.btnNormal
        motionManager.stopAccelerometerUpdates()

        timer.invalidate()
        cntTimer = 0
        
        let cnt = self.sequenceTargetX.count
        if cnt >= lengthMax*inputDim {
            cntTimer = 0
            return
        }
        
        // Pay attention to input dimension for RNN
        for _ in cnt..<lengthMax*inputDim {
            self.sequenceTargetX.append(0.0)
            self.sequenceTargetY.append(0.0)
            self.sequenceTargetZ.append(0.0)
        }

        let output = predict(self.sequenceTargetX,self.sequenceTargetY,self.sequenceTargetZ)
        // Find a maximum likelihood
        /*
        var max = Double(truncating: output.output1[0])
        var index_max: Int = 0
        let end = output.output1.count
        for i in 1..<end {
            let t = Double(truncating: output.output1[i])
            if t >= max {
                max = t
                index_max = i
            }
        }
        */
        /*
        gestureAI = GestureAlphabetProcessor()
        guard let symbol = GASymbol.alphaMap[index_max] else {
            return
        }
        */
        //gaArea.text = symbol
        gaArea.text = output.label
    }
    /*
    @IBAction func recBtnTouchDown(_ sender: Any) {
        recBtn.backgroundColor = GAColor.btnSensing
        self.sequenceTarget = []
        
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.updateRecTimer(tm:)), userInfo: nil, repeats: true)
        timer.fire()
        
        motionManager.startAccelerometerUpdates(to: queue, withHandler: {
            (accelerometerData, error) in
            if let e = error {
                fatalError(e.localizedDescription)
            }
            guard let data = accelerometerData else { return }
            self.sequenceTarget.append(data.acceleration.x)
            self.sequenceTarget.append(data.acceleration.y)
            self.sequenceTarget.append(data.acceleration.z)
        })
    }
    
    
    @IBAction func recBtnTouchUpInside(_ sender: Any) {
        recBtn.backgroundColor = GAColor.btnNormal
        motionManager.stopAccelerometerUpdates()

        timer.invalidate()
        cntTimer = 0
        
        let cnt = self.sequenceTarget.count
        if cnt >= lengthMax*inputDim {
            cntTimer = 0
            return
        }
        
        // Pay attention to input dimension for RNN
        for _ in cnt..<lengthMax*inputDim {
            self.sequenceTarget.append(0.0);
        }
        let i = 0;
        print(self.sequenceTarget);
        for i in i..<self.sequenceTarget.count/3 {
            print(i)
            let str = String(format:"%d, %d, %d\n",self.sequenceTarget[i*3],self.sequenceTarget[i*3+1],self.sequenceTarget[i*3+2])
            print(str)
        }
        let output = predict(self.sequenceTarget)
        // Find a maximum likelihood
        var max = Double(truncating: output.output1[0])
        var index_max: Int = 0
        let end = output.output1.count
        for i in 1..<end {
            let t = Double(truncating: output.output1[i])
            if t >= max {
                max = t
                index_max = i
            }
        }
        
        gestureAI = GestureAlphabetProcessor()
        guard let symbol = GASymbol.alphaMap[index_max] else {
            return
        }
        gaArea.text = symbol
    }
    */
    
    
    
    // MARK:- Utils
    
    @objc private func updateTimer(tm: Timer) {
        if cntTimer >= timeMax {
            gaBtn.backgroundColor = GAColor.btnWarning
            timer.invalidate()
            cntTimer = 0
            return
        }
        cntTimer += 1
    }
    /*
    @objc private func updateRecTimer(tm: Timer) {
        if cntTimer >= timeMax {
            recBtn.backgroundColor = GAColor.btnWarning
            timer.invalidate()
            cntTimer = 0
            return
        }
        cntTimer += 1
    }
    */
    /// Convert double array type into MLMultiArray
    ///
    /// - Parameters:
    /// - arr: double array
    /// - Returns: MLMultiArray
    private func toMLMultiArray(_ arr: [Double]) -> MLMultiArray {
        guard let sequence = try? MLMultiArray(shape:[30], dataType:MLMultiArrayDataType.double) else {
            fatalError("Unexpected runtime error. MLMultiArray")
        }
        let size = Int(truncating: sequence.shape[0])
        for i in 0..<size {
            sequence[i] = NSNumber(floatLiteral: arr[i])
        }
        return sequence
    }
    
    /// Predict class label
    ///
    /// - Parameters:
    /// - arr: Sequence
    /// - Returns: Likelihood
    private func predict(_ arrX: [Double], _ arrY: [Double], _ arrZ: [Double]) -> GestureAlphabetProcessorOutput {
        guard let output = try? gestureAI.prediction(input:
            GestureAlphabetProcessorInput(accelerometerAccelerationX_G_: toMLMultiArray(arrX),
                                          accelerometerAccelerationY_G_: toMLMultiArray(arrY),
                                          accelerometerAccelerationZ_G_: toMLMultiArray(arrZ))) else {
                fatalError("Unexpected runtime error.")
        }
        return output
    }
}


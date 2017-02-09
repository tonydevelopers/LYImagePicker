//
//  LYImagePickerViewController.swift
//  Ying
//
//  Created by tony on 2017/2/3.
//  Copyright © 2017年 chengkaizone. All rights reserved.
//

import UIKit
import Photos

// 扩展属性
private var assetSelectedPointer: String?
fileprivate extension PHAsset {
    
    // 是否被选择
    var assetSelected: Bool? {
        
        get {
            // 转化回来
            if let value = objc_getAssociatedObject(self, &assetSelectedPointer) as? Bool {
                return value
            }
            
            return false
        }
        
        set {
            if let value = newValue {
                objc_setAssociatedObject(self, &assetSelectedPointer, value, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
}

protocol LYImagePickerViewControllerDelegate: NSObjectProtocol {
    
    // MARK: 返回选择结果 completion = false代表取消 true有可能返回0个或多个
    func imagePicker(assets: [PHAsset]!, completion: Bool)
    
}

/// MARK: 图片拾取器
class LYImagePickerViewController: UIViewController {
    
    weak var delegate: LYImagePickerViewControllerDelegate?
    
    /// 图片默认多选/视频默认单选/不宜同时出现视频和图片
    open var mediaType: PHAssetMediaType = .image
    
    // 0: single 1: multiple 视频状态下只允许选一个
    open var choiceMode: Int = 0
    
    // 标记选择的icon
    open var markerIcon: String?
    
    open var cancelTitle: String! = "Cancel" {
        didSet {
            self.cancelButton?.setTitle(cancelTitle, for: .normal)
        }
    }
    
    open var doneTitle: String! = "Done" {
        didSet {
            self.doneButton?.setTitle(doneTitle, for: .normal)
        }
    }
    
    fileprivate var sideSize: CGFloat!
    
    fileprivate let cellIdentifier: String = "LYImagePickerViewCell"
    fileprivate let cellCount: Int = 4
    fileprivate let navigationHeight: CGFloat = 44
    
    fileprivate var collectionView: UICollectionView!
    fileprivate var collectionViewLayout: UICollectionViewFlowLayout!
    
    fileprivate var titleLabel: UILabel!
    fileprivate var cancelButton: UIButton!
    fileprivate var doneButton: UIButton!
    
    // 查询出的结果
    fileprivate var assets: PHFetchResult<PHAsset>! {
        didSet {
            
            if assets == nil {
                selectAssets = nil
            } else {
                selectAssets = [PHAsset]()
            }
        }
    }
    
    fileprivate var selectAssets: [PHAsset]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        
        let navigationView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: navigationHeight))
        self.view.addSubview(navigationView)
        navigationView.backgroundColor = UIColor.black
        
        titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textAlignment = .center
        titleLabel.sizeToFit()
        navigationView.addSubview(titleLabel)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let constraintTitleHorizontalCenter = NSLayoutConstraint.init(item: titleLabel, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: navigationView, attribute: NSLayoutAttribute.centerX, multiplier: 1.0, constant: 0)
        let constraintTitleVerticalCenter = NSLayoutConstraint.init(item: titleLabel, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: navigationView, attribute: NSLayoutAttribute.centerY, multiplier: 1.0, constant: 0)
        self.view.addConstraint(constraintTitleHorizontalCenter)
        self.view.addConstraint(constraintTitleVerticalCenter)
        
        cancelButton = UIButton(type: .custom)
        cancelButton.setTitle(cancelTitle, for: .normal)
        cancelButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        cancelButton.addTarget(self, action: #selector(cancelAction(_:)), for: .touchUpInside)
        navigationView.addSubview(cancelButton)
        
        doneButton = UIButton(type: .custom)
        doneButton.setTitle(doneTitle, for: .normal)
        doneButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        doneButton.addTarget(self, action: #selector(doneAction(_:)), for: .touchUpInside)
        navigationView.addSubview(doneButton)
        
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        let constraintCancelVerticalCenter = NSLayoutConstraint.init(item: cancelButton, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: navigationView, attribute: NSLayoutAttribute.centerY, multiplier: 1.0, constant: 0)
        
        let constraintCancelLeft = NSLayoutConstraint.init(item: cancelButton, attribute: NSLayoutAttribute.left, relatedBy: NSLayoutRelation.equal, toItem: navigationView, attribute: NSLayoutAttribute.left, multiplier: 1.0, constant: 10)
        self.view.addConstraint(constraintCancelLeft)
        self.view.addConstraint(constraintCancelVerticalCenter)
        
        let constraintDoneVerticalCenter = NSLayoutConstraint.init(item: doneButton, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: navigationView, attribute: NSLayoutAttribute.centerY, multiplier: 1.0, constant: 0)
        
        let constraintDoneRight = NSLayoutConstraint.init(item: doneButton, attribute: NSLayoutAttribute.right, relatedBy: NSLayoutRelation.equal, toItem: navigationView, attribute: NSLayoutAttribute.right, multiplier: 1.0, constant: -10)
        self.view.addConstraint(constraintDoneRight)
        self.view.addConstraint(constraintDoneVerticalCenter)
        
        
        self.setup()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        
        return .lightContent
    }
    
    override var prefersStatusBarHidden: Bool {
        
        return true
    }
    
    private func setup() {
        
        sideSize = self.view.bounds.width / CGFloat(cellCount)
        collectionViewLayout = UICollectionViewFlowLayout()
        collectionViewLayout.itemSize = CGSize(width: sideSize, height: sideSize)
        collectionViewLayout.minimumLineSpacing = 0
        collectionViewLayout.minimumInteritemSpacing = 0
        
        let collectionFrame = CGRect(x: 0, y: navigationHeight, width: self.view.bounds.width, height: self.view.bounds.height - navigationHeight)
        collectionView = UICollectionView(frame: collectionFrame, collectionViewLayout: collectionViewLayout)
        collectionView.backgroundColor = UIColor.white
        collectionView.register(LYImagePickerViewCell.classForCoder(), forCellWithReuseIdentifier: cellIdentifier)
        collectionView.alwaysBounceVertical = true
        collectionView.dataSource = self
        collectionView.delegate = self
        
        self.view.addSubview(collectionView)
        
        self.checkPermission()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    fileprivate func checkPermission() {
        
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            reloadAssets()
        } else {
            PHPhotoLibrary.requestAuthorization({ (status: PHAuthorizationStatus) -> Void in
                if status == .authorized {
                    self.reloadAssets()
                } else {
                    self.showNeedAccessMessage()
                }
            })
        }
    }
    
    // 显示需要授权的提示
    fileprivate func showNeedAccessMessage() {
        let alert = UIAlertController(title: "Media picker", message: "App need get access to photos", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction) -> Void in
            self.dismiss(animated: true, completion: nil)
        }))
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action: UIAlertAction) -> Void in
            UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
        }))
        
        show(alert, sender: nil)
    }
    
    // 根据创建时间排序
    fileprivate func fetchAssetsWithDate(assetCollection: PHAssetCollection, mediaType: PHAssetMediaType) -> PHFetchResult<PHAsset> {
        
        let fetchOptions = PHFetchOptions()
        
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        if mediaType != .unknown {
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", mediaType.rawValue)
        }
        
        let assets = PHAsset.fetchAssets(in: assetCollection, options: fetchOptions)
        
        return assets
    }
    
    // 加载图片
    fileprivate func reloadAssets() {
        // 请求授权
        PHPhotoLibrary.requestAuthorization({ (status: PHAuthorizationStatus) in
            
            DispatchQueue.main.async {[weak self] in
                switch status {
                case .authorized:
                    
                    self?.assets = nil
                    self?.collectionView.reloadData()
                    // 相机胶卷
                    if let cameraColl = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).lastObject {
                        
                        self?.titleLabel.text = cameraColl.localizedTitle
                        self?.assets = self?.fetchAssetsWithDate(assetCollection: cameraColl, mediaType: self!.mediaType)
                        
                    }
                    self?.collectionView.reloadData()
                    break
                case .notDetermined:// 请求时不存在这种情况
                    
                    break
                case .denied, .restricted/* 因系统原因无法访问该权限 */:
                    // 提示打开相册权限
                    let alert = UIAlertController(title: NSLocalizedString("authorize tips", comment: ""), message: NSLocalizedString("album authorize guide", comment: ""), preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("open setting", comment: ""), style: UIAlertActionStyle.default, handler: { (action: UIAlertAction) in
                        
                        if #available(iOS 8.0, *) {
                            let audioSetting = URL(string: UIApplicationOpenSettingsURLString)
                            if UIApplication.shared.canOpenURL(audioSetting!) {
                                UIApplication.shared.openURL(audioSetting!)
                            }
                        } else {
                            // 手动到设置界面中打开
                        }
                    }))
                    alert.addAction(UIAlertAction(title: NSLocalizedString("no", comment: ""), style: UIAlertActionStyle.cancel, handler: {[weak self] (action: UIAlertAction) in
                        
                        let _ = self?.navigationController?.popViewController(animated: true)
                    }))
                    
                    self?.present(alert, animated: true, completion: nil)
                    break
                }
            }
            
        })
    }
    
    @objc func cancelAction(_ sender: UIButton) {
        self.dismiss(animated: true) { [weak self] in
            self?.delegate?.imagePicker(assets: nil, completion: false)
        }
    }
    
    @objc func doneAction(_ sender: UIButton) {
        
        var results: [PHAsset] = [PHAsset]()
        
        for i in 0..<self.assets.count {
            
            if let asset = self.assets?[i] {
                if let selected = asset.assetSelected {
                    if selected {
                        results.append(asset)
                    }
                }
            }
        }
        self.dismiss(animated: true) { [weak self] in
            self?.delegate?.imagePicker(assets: results, completion: true)
        }
    }
    
}

class LYImagePickerViewCell: UICollectionViewCell {
    
    var margin: CGFloat = 0.5
    var markerSize: CGFloat = 24
    var markerMargin: CGFloat = 4
    
    var assetImageView:UIImageView!
    
    var assetDurationLabel: UILabel!
    // 遮罩视图
    var markView: UIView!
    
    var imageMarker: UIImageView!
    
    var markerIcon: String! {
        didSet {
            if markerIcon != nil {
                imageMarker?.image = UIImage(named: markerIcon)
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        setup()
    }
    
    fileprivate func setup() {
        self.clipsToBounds = true
        
        let contentFrame = CGRect(x: margin, y: margin, width: self.bounds.width - margin * 2, height: self.bounds.height - margin * 2)
        assetImageView = UIImageView(frame: contentFrame)
        assetImageView.contentMode = UIViewContentMode.scaleAspectFill
        assetImageView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        assetImageView.clipsToBounds = true
        addSubview(assetImageView)
        
        assetDurationLabel = UILabel(frame: CGRect(x: 8, y: self.bounds.height - 20, width: self.bounds.width - 8 * 2, height: 20))
        assetDurationLabel.font = UIFont.systemFont(ofSize: 12)
        assetDurationLabel.textColor = .white
        assetDurationLabel.textAlignment = .right
        addSubview(assetDurationLabel)
        
        markView = UIView(frame: contentFrame)
        markView.backgroundColor = UIColor(white: 1, alpha: 0.3)
        addSubview(markView)
        
        markView.isHidden = true
        
        imageMarker = UIImageView(frame: CGRect(x: self.frame.width - markerSize - markerMargin, y: self.frame.height - markerSize - markerMargin, width: markerSize, height: markerSize))
        imageMarker.image = UIImage(named: "ic_asset_select_p")
        
        self.addSubview(imageMarker)
        imageMarker.isHidden = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let contentFrame = CGRect(x: margin, y: margin, width: self.bounds.width - margin * 2, height: self.bounds.height - margin * 2)
        assetImageView.frame = contentFrame
        markView.frame = contentFrame
        
        imageMarker.frame = CGRect(x: self.frame.width - markerSize - markerMargin, y: self.frame.height - markerSize - markerMargin, width: markerSize, height: markerSize)
        
        assetDurationLabel.frame = CGRect(x: 8, y: self.bounds.height - 20, width: self.bounds.width - 8 * 2, height: 20)
    }
    
}

extension LYImagePickerViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        if assets == nil {
            return 0
        }
        
        return assets!.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! LYImagePickerViewCell
        
        let asset = self.assets![indexPath.row]
        
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: sideSize, height: sideSize), contentMode: .aspectFill, options: nil) { (image: UIImage?, info: [AnyHashable: Any]?) -> Void in
            
            cell.assetImageView.image = image
        }
        
        if let selected = asset.assetSelected {
            
            cell.markView.isHidden = !selected
            cell.imageMarker.isHidden = !selected
        } else {
            cell.markView.isHidden = true
            cell.imageMarker.isHidden = true
        }
        
        if asset.mediaType == .video {
            cell.assetDurationLabel.isHidden = false
            cell.assetDurationLabel.text = stringWithSeconds(asset.duration)
        } else {
            cell.assetDurationLabel.isHidden = true
        }
        
        return cell
    }
    
    /** 将时长处理成时间字符串显示 */
    fileprivate func stringWithSeconds(_ duration:Double) -> String {
        let hour:Int = Int(duration/3600);
        let hour_:Int = Int(duration.truncatingRemainder(dividingBy: 3600));
        let minute:Int = Int(hour_/60);
        let sec:Int = Int(hour_%60);
        
        if(hour==0){
            return String(format: "%02d:%02d", minute,sec);
        }
        
        return String(format: "%02d:%02d:%02d", hour,minute,sec);
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
        
    }
    
}

extension LYImagePickerViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let asset = self.assets?[indexPath.row] else {
            return
        }
        
        if self.mediaType == .video {
            
            self.dismiss(animated: true, completion: {
                self.delegate?.imagePicker(assets: [asset], completion: true)
            })
            
            return
        }
        
        if self.choiceMode == 0 {// 单选
            
            self.dismiss(animated: true, completion: {
                self.delegate?.imagePicker(assets: [asset], completion: true)
            })
            return
        }
        
        if let selected = asset.assetSelected {
            
            asset.assetSelected = !selected
            asset.assetSelected = !selected
        } else {
            asset.assetSelected = true
        }
        
        collectionView.reloadItems(at: [indexPath])
    }
    
}

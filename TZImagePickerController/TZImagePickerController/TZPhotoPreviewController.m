//
//  TZPhotoPreviewController.m
//  TZImagePickerController
//
//  Created by 谭真 on 15/12/24.
//  Copyright © 2015年 谭真. All rights reserved.
//

#import "TZPhotoPreviewController.h"
#import "TZPhotoPreviewCell.h"
#import "TZAssetModel.h"
#import "UIView+Layout.h"
#import "TZImagePickerController.h"
#import "TZImageManager.h"
#import "TZImageCropManager.h"

@interface TZPhotoPreviewController ()<UICollectionViewDataSource,UICollectionViewDelegate,UIScrollViewDelegate> {
    UICollectionView *_collectionView;
    UICollectionViewFlowLayout *_layout;
    NSArray *_photosTemp;
    NSArray *_assetsTemp;
    
    UIView *_naviBar;
    UILabel *_navTitleLabel;
    UIButton *_backButton;
    UIButton *_selectPhotoButton;
    UIView *_selectView;
    UILabel *_indexLabel;
    
    UIView *_toolBar;
    UIButton *_doneButton;
    UIImageView *_numberImageView;
    UILabel *_numberLabel;
    UIButton *_originalPhotoButton;
    UILabel *_originalPhotoLabel;
    
    CGFloat _offsetItemCount;
}
@property (nonatomic, assign) BOOL isHideNaviBar;
@property (nonatomic, strong) UIView *cropBgView;
@property (nonatomic, strong) UIView *cropView;

@property (nonatomic, assign) double progress;
@property (strong, nonatomic) id alertView;
@end

@implementation TZPhotoPreviewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [TZImageManager manager].shouldFixOrientation = YES;
    __weak typeof(self) weakSelf = self;
    TZImagePickerController *_tzImagePickerVc = (TZImagePickerController *)weakSelf.navigationController;
    if (!self.models.count) {
        self.models = [NSMutableArray arrayWithArray:_tzImagePickerVc.selectedModels];
        _assetsTemp = [NSMutableArray arrayWithArray:_tzImagePickerVc.selectedAssets];
    }
    
    [self configCollectionView];
    [self configSelectButton];
    [self configCustomNaviBar];
    //    [self configBottomToolBar];
    
    self.view.clipsToBounds = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeStatusBarOrientationNotification:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

- (void)setPhotos:(NSMutableArray *)photos {
    _photos = photos;
    _photosTemp = [NSArray arrayWithArray:photos];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    if (iOS7Later) [UIApplication sharedApplication].statusBarHidden = YES;
    if (_currentIndex) [_collectionView setContentOffset:CGPointMake((self.view.tz_width + 20) * _currentIndex, 0) animated:NO];
    [self refreshNaviBarAndBottomBarState];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    if (tzImagePickerVc.needShowStatusBar && iOS7Later) {
        [UIApplication sharedApplication].statusBarHidden = NO;
    }
    [TZImageManager manager].shouldFixOrientation = NO;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)configCustomNaviBar {
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    
    _naviBar = [[UIView alloc] initWithFrame:CGRectZero];
    if (tzImagePickerVc.naviBgColor != nil) {
        _naviBar.backgroundColor = tzImagePickerVc.naviBgColor;
    } else {
        _naviBar.backgroundColor = tzImagePickerVc.navigationBar.barTintColor;
    }
    
    _navTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _navTitleLabel.font = [UIFont fontWithName:@"PingFangTC-Regular" size:17];
    _navTitleLabel.text = [NSString stringWithFormat:@"%lu/%lu", (unsigned long)self.currentIndex, (unsigned long)self.models.count - 1];
    _navTitleLabel.textColor = self.navigationController.navigationBar.tintColor;
    
    _backButton = [[UIButton alloc] initWithFrame:CGRectZero];
    [_backButton setImage:[UIImage imageNamedFromMyBundle:@"navi_back"] forState:UIControlStateNormal];
    [_backButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_backButton addTarget:self action:@selector(backButtonClick) forControlEvents:UIControlEventTouchUpInside];
    
    _doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _doneButton.titleLabel.font = [UIFont fontWithName:@"PingFangTC-Regular" size:17];
    [_doneButton addTarget:self action:@selector(doneButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [_doneButton setTitle:@"選擇" forState:UIControlStateNormal];
    [_doneButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    [_naviBar addSubview:_navTitleLabel];
    [_naviBar addSubview:_backButton];
    [_naviBar addSubview:_doneButton];
    [self.view addSubview:_naviBar];
}

- (void)configSelectButton {
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    
    _selectPhotoButton = [[UIButton alloc] initWithFrame:CGRectZero];
    [_selectPhotoButton addTarget:self action:@selector(select:) forControlEvents:UIControlEventTouchUpInside];
    _selectPhotoButton.hidden = !tzImagePickerVc.showSelectBtn;
    
    _selectView = [[UIView alloc] initWithFrame:CGRectZero];
    _selectView.hidden = !tzImagePickerVc.showSelectBtn;
    
    _indexLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _indexLabel.font = [UIFont systemFontOfSize:16];
    _indexLabel.textColor = [UIColor whiteColor];
    _indexLabel.textAlignment = NSTextAlignmentCenter;
    
    [_selectView addSubview:_indexLabel];
    [self.view addSubview:_selectView];
    [self.view addSubview:_selectPhotoButton];
}

- (void)configBottomToolBar {
    _toolBar = [[UIView alloc] initWithFrame:CGRectZero];
    static CGFloat rgb = 34 / 255.0;
    _toolBar.backgroundColor = [UIColor colorWithRed:rgb green:rgb blue:rgb alpha:0.7];
    
    TZImagePickerController *_tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    if (_tzImagePickerVc.allowPickingOriginalPhoto) {
        _originalPhotoButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _originalPhotoButton.imageEdgeInsets = UIEdgeInsetsMake(0, -10, 0, 0);
        _originalPhotoButton.backgroundColor = [UIColor clearColor];
        [_originalPhotoButton addTarget:self action:@selector(originalPhotoButtonClick) forControlEvents:UIControlEventTouchUpInside];
        _originalPhotoButton.titleLabel.font = [UIFont systemFontOfSize:13];
        [_originalPhotoButton setTitle:_tzImagePickerVc.fullImageBtnTitleStr forState:UIControlStateNormal];
        [_originalPhotoButton setTitle:_tzImagePickerVc.fullImageBtnTitleStr forState:UIControlStateSelected];
        [_originalPhotoButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        [_originalPhotoButton setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
        [_originalPhotoButton setImage:_tzImagePickerVc.photoPreviewOriginDefImage forState:UIControlStateNormal];
        [_originalPhotoButton setImage:_tzImagePickerVc.photoOriginSelImage forState:UIControlStateSelected];
        
        _originalPhotoLabel = [[UILabel alloc] init];
        _originalPhotoLabel.textAlignment = NSTextAlignmentLeft;
        _originalPhotoLabel.font = [UIFont systemFontOfSize:13];
        _originalPhotoLabel.textColor = [UIColor whiteColor];
        _originalPhotoLabel.backgroundColor = [UIColor clearColor];
        if (_isSelectOriginalPhoto) [self showPhotoBytes];
    }
    
    _doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _doneButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [_doneButton addTarget:self action:@selector(doneButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [_doneButton setTitle:_tzImagePickerVc.doneBtnTitleStr forState:UIControlStateNormal];
    [_doneButton setTitleColor:_tzImagePickerVc.oKButtonTitleColorNormal forState:UIControlStateNormal];
    
    [_originalPhotoButton addSubview:_originalPhotoLabel];
    [_toolBar addSubview:_doneButton];
    [_toolBar addSubview:_originalPhotoButton];
    [_toolBar addSubview:_numberImageView];
    [_toolBar addSubview:_numberLabel];
    [self.view addSubview:_toolBar];
    
    if (_tzImagePickerVc.photoPreviewPageUIConfigBlock) {
        _tzImagePickerVc.photoPreviewPageUIConfigBlock(_collectionView, _naviBar, _backButton, _selectPhotoButton, _indexLabel, _toolBar, _originalPhotoButton, _originalPhotoLabel, _doneButton, _numberImageView, _numberLabel);
    }
}

- (void)configCollectionView {
    _layout = [[UICollectionViewFlowLayout alloc] init];
    _layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:_layout];
    _collectionView.backgroundColor = [UIColor blackColor];
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.pagingEnabled = YES;
    _collectionView.scrollsToTop = NO;
    _collectionView.showsHorizontalScrollIndicator = NO;
    _collectionView.contentOffset = CGPointMake(0, 0);
    _collectionView.contentSize = CGSizeMake(self.models.count * (self.view.tz_width + 20), 0);
    [self.view addSubview:_collectionView];
    [_collectionView registerClass:[TZPhotoPreviewCell class] forCellWithReuseIdentifier:@"TZPhotoPreviewCell"];
    [_collectionView registerClass:[TZVideoPreviewCell class] forCellWithReuseIdentifier:@"TZVideoPreviewCell"];
    [_collectionView registerClass:[TZGifPreviewCell class] forCellWithReuseIdentifier:@"TZGifPreviewCell"];
}

- (void)configCropView {
    TZImagePickerController *_tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    if (_tzImagePickerVc.maxImagesCount <= 1 && _tzImagePickerVc.allowCrop) {
        [_cropView removeFromSuperview];
        [_cropBgView removeFromSuperview];
        
        _cropBgView = [UIView new];
        _cropBgView.userInteractionEnabled = NO;
        _cropBgView.frame = self.view.bounds;
        _cropBgView.backgroundColor = [UIColor clearColor];
        [self.view addSubview:_cropBgView];
        [TZImageCropManager overlayClippingWithView:_cropBgView cropRect:_tzImagePickerVc.cropRect containerView:self.view needCircleCrop:_tzImagePickerVc.needCircleCrop];
        
        _cropView = [UIView new];
        _cropView.userInteractionEnabled = NO;
        _cropView.frame = _tzImagePickerVc.cropRect;
        _cropView.backgroundColor = [UIColor clearColor];
        _cropView.layer.borderColor = [UIColor whiteColor].CGColor;
        _cropView.layer.borderWidth = 1.0;
        if (_tzImagePickerVc.needCircleCrop) {
            _cropView.layer.cornerRadius = _tzImagePickerVc.cropRect.size.width / 2;
            _cropView.clipsToBounds = YES;
        }
        [self.view addSubview:_cropView];
        if (_tzImagePickerVc.cropViewSettingBlock) {
            _tzImagePickerVc.cropViewSettingBlock(_cropView);
        }
        
        [self.view bringSubviewToFront:_naviBar];
        [self.view bringSubviewToFront:_toolBar];
    }
}

#pragma mark - Layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    TZImagePickerController *_tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    
    CGFloat statusBarHeight = [TZCommonTools tz_statusBarHeight];
    CGFloat naviBarHeight = _tzImagePickerVc.navigationBar.tz_height;
    CGFloat appBarHeight = statusBarHeight + naviBarHeight;
    _naviBar.frame = CGRectMake(0, 0, self.view.tz_width, appBarHeight);
    [_navTitleLabel sizeToFit];
    CGPoint titleLabelOrigin = CGPointMake((self.view.tz_width - _navTitleLabel.frame.size.width)/2, statusBarHeight + (naviBarHeight - _navTitleLabel.frame.size.height)/2);
    _navTitleLabel.tz_origin = titleLabelOrigin;
    
    _backButton.frame = CGRectMake(-5, statusBarHeight + (naviBarHeight - 44)/2, 44, 44);
    _selectPhotoButton.frame = CGRectMake(self.view.tz_width - 42 - 10, appBarHeight + 10, 42, 42);
    _selectView.frame = CGRectMake(self.view.tz_width - 30 - 15, appBarHeight + 15, 30, 30);
    _selectView.layer.cornerRadius = 15;
    _indexLabel.frame = CGRectMake(0, 0, 30, 30);
    
    _layout.itemSize = CGSizeMake(self.view.tz_width + 20, self.view.tz_height);
    _layout.minimumInteritemSpacing = 0;
    _layout.minimumLineSpacing = 0;
    _collectionView.frame = CGRectMake(-10, 0, self.view.tz_width + 20, self.view.tz_height);
    [_collectionView setCollectionViewLayout:_layout];
    if (_offsetItemCount > 0) {
        CGFloat offsetX = _offsetItemCount * _layout.itemSize.width;
        [_collectionView setContentOffset:CGPointMake(offsetX, 0)];
    }
    if (_tzImagePickerVc.allowCrop) {
        [_collectionView reloadData];
    }
    
    CGFloat toolBarHeight = [TZCommonTools tz_isIPhoneX] ? 44 + (83 - 49) : 44;
    CGFloat toolBarTop = self.view.tz_height - toolBarHeight;
    _toolBar.frame = CGRectMake(0, toolBarTop, self.view.tz_width, toolBarHeight);
    if (_tzImagePickerVc.allowPickingOriginalPhoto) {
        CGFloat fullImageWidth = [_tzImagePickerVc.fullImageBtnTitleStr tz_calculateSizeWithAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:13]} maxSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)].width;
        _originalPhotoButton.frame = CGRectMake(0, 0, fullImageWidth + 56, 44);
        _originalPhotoLabel.frame = CGRectMake(fullImageWidth + 42, 0, 80, 44);
    }
    [_doneButton sizeToFit];
    _doneButton.frame = CGRectMake(self.view.tz_width - _doneButton.tz_width - 17, statusBarHeight + (naviBarHeight - 44)/2, _doneButton.tz_width, 44);
    _numberImageView.frame = CGRectMake(_doneButton.tz_left - 30, statusBarHeight + (naviBarHeight - 25)/2, 25, 25);
    _numberLabel.frame = _numberImageView.frame;
    
    [self configCropView];
}

#pragma mark - Notification

- (void)didChangeStatusBarOrientationNotification:(NSNotification *)noti {
    _offsetItemCount = _collectionView.contentOffset.x / _layout.itemSize.width;
}

#pragma mark - Click Event

- (void)select:(UIButton *)selectButton {
    TZImagePickerController *_tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    TZAssetModel *model = _models[_currentIndex];
    if (!selectButton.isSelected) {
        // 1. select:check if over the maxImagesCount / 选择照片,检查是否超过了最大个数的限制
        if (_tzImagePickerVc.selectedModels.count >= _tzImagePickerVc.maxImagesCount) {
            NSString *title = [NSString stringWithFormat:[NSBundle tz_localizedStringForKey:@"Select a maximum of %zd photos"], _tzImagePickerVc.maxImagesCount];
            [_tzImagePickerVc showAlertWithTitle:title];
            return;
            // 2. if not over the maxImagesCount / 如果没有超过最大个数限制
        } else {
            [_tzImagePickerVc addSelectedModel:model];
            if (self.photos) {
                [_tzImagePickerVc.selectedAssets addObject:_assetsTemp[_currentIndex]];
                [self.photos addObject:_photosTemp[_currentIndex]];
            }
            if (model.type == TZAssetModelMediaTypeVideo && !_tzImagePickerVc.allowPickingMultipleVideo) {
                [_tzImagePickerVc showAlertWithTitle:[NSBundle tz_localizedStringForKey:@"Select the video when in multi state, we will handle the video as a photo"]];
            }
        }
    } else {
        NSArray *selectedModels = [NSArray arrayWithArray:_tzImagePickerVc.selectedModels];
        for (TZAssetModel *model_item in selectedModels) {
            if ([[[TZImageManager manager] getAssetIdentifier:model.asset] isEqualToString:[[TZImageManager manager] getAssetIdentifier:model_item.asset]]) {
                // 1.6.7版本更新:防止有多个一样的model,一次性被移除了
                NSArray *selectedModelsTmp = [NSArray arrayWithArray:_tzImagePickerVc.selectedModels];
                for (NSInteger i = 0; i < selectedModelsTmp.count; i++) {
                    TZAssetModel *model = selectedModelsTmp[i];
                    if ([model isEqual:model_item]) {
                        [_tzImagePickerVc removeSelectedModel:model];
                        // [_tzImagePickerVc.selectedModels removeObjectAtIndex:i];
                        break;
                    }
                }
                if (self.photos) {
                    // 1.6.7版本更新:防止有多个一样的asset,一次性被移除了
                    NSArray *selectedAssetsTmp = [NSArray arrayWithArray:_tzImagePickerVc.selectedAssets];
                    for (NSInteger i = 0; i < selectedAssetsTmp.count; i++) {
                        id asset = selectedAssetsTmp[i];
                        if ([asset isEqual:_assetsTemp[_currentIndex]]) {
                            [_tzImagePickerVc.selectedAssets removeObjectAtIndex:i];
                            break;
                        }
                    }
                    // [_tzImagePickerVc.selectedAssets removeObject:_assetsTemp[_currentIndex]];
                    [self.photos removeObject:_photosTemp[_currentIndex]];
                }
                break;
            }
        }
    }
    model.isSelected = !selectButton.isSelected;
    [self refreshNaviBarAndBottomBarState];
    if (model.isSelected) {
        [UIView showOscillatoryAnimationWithLayer:selectButton.imageView.layer type:TZOscillatoryAnimationToBigger];
    }
    [UIView showOscillatoryAnimationWithLayer:_numberImageView.layer type:TZOscillatoryAnimationToSmaller];
    [UIView showOscillatoryAnimationWithLayer:_numberLabel.layer type:TZOscillatoryAnimationToSmaller];
}

- (void)backButtonClick {
    if (self.navigationController.childViewControllers.count < 2) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        if ([self.navigationController isKindOfClass: [TZImagePickerController class]]) {
            TZImagePickerController *nav = (TZImagePickerController *)self.navigationController;
            if (nav.imagePickerControllerDidCancelHandle) {
                nav.imagePickerControllerDidCancelHandle();
            }
        }
        return;
    }
    [self.navigationController popViewControllerAnimated:YES];
    if (self.backButtonClickBlock) {
        self.backButtonClickBlock(_isSelectOriginalPhoto);
    }
}

- (void)doneButtonClick {
    TZImagePickerController *_tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    // 如果图片正在从iCloud同步中,提醒用户
    if (_progress > 0 && _progress < 1 && (_selectPhotoButton.isSelected || !_tzImagePickerVc.selectedModels.count )) {
        _alertView = [_tzImagePickerVc showAlertWithTitle:[NSBundle tz_localizedStringForKey:@"Synchronizing photos from iCloud"]];
        return;
    }
    
    // 如果没有选中过照片 点击确定时选中当前预览的照片
    if (_tzImagePickerVc.selectedModels.count == 0 && _tzImagePickerVc.minImagesCount <= 0) {
        TZAssetModel *model = _models[_currentIndex];
        [_tzImagePickerVc addSelectedModel:model];
    }
    if (_tzImagePickerVc.allowCrop) { // 裁剪状态
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:_currentIndex inSection:0];
        TZPhotoPreviewCell *cell = (TZPhotoPreviewCell *)[_collectionView cellForItemAtIndexPath:indexPath];
        UIImage *cropedImage = [TZImageCropManager cropImageView:cell.previewView.imageView toRect:_tzImagePickerVc.cropRect zoomScale:cell.previewView.scrollView.zoomScale containerView:self.view];
        if (_tzImagePickerVc.needCircleCrop) {
            cropedImage = [TZImageCropManager circularClipImage:cropedImage];
        }
        if (self.doneButtonClickBlockCropMode) {
            TZAssetModel *model = _models[_currentIndex];
            self.doneButtonClickBlockCropMode(cropedImage,model.asset);
        }
    } else if (self.doneButtonClickBlock) { // 非裁剪状态
        self.doneButtonClickBlock(_isSelectOriginalPhoto);
    }
    if (self.doneButtonClickBlockWithPreviewType) {
        self.doneButtonClickBlockWithPreviewType(self.photos,_tzImagePickerVc.selectedAssets,self.isSelectOriginalPhoto);
    }
}

- (void)originalPhotoButtonClick {
    _originalPhotoButton.selected = !_originalPhotoButton.isSelected;
    _isSelectOriginalPhoto = _originalPhotoButton.isSelected;
    _originalPhotoLabel.hidden = !_originalPhotoButton.isSelected;
    if (_isSelectOriginalPhoto) {
        [self showPhotoBytes];
        if (!_selectPhotoButton.isSelected) {
            // 如果当前已选择照片张数 < 最大可选张数 && 最大可选张数大于1，就选中该张图
            TZImagePickerController *_tzImagePickerVc = (TZImagePickerController *)self.navigationController;
            if (_tzImagePickerVc.selectedModels.count < _tzImagePickerVc.maxImagesCount && _tzImagePickerVc.showSelectBtn) {
                [self select:_selectPhotoButton];
            }
        }
    }
}

- (void)didTapPreviewCell {
    self.isHideNaviBar = !self.isHideNaviBar;
    _toolBar.hidden = self.isHideNaviBar;
    
    if (self.isHideNaviBar) {
        [UIView animateWithDuration:0.2
                         animations:^{
                             self->_selectPhotoButton.alpha = 0.0;
                             self->_selectView.alpha = 0.0;
                             self->_naviBar.alpha = 0.0;
                         }
                         completion:^(BOOL finished){
                             self->_selectPhotoButton.hidden = true;
                             self->_selectView.hidden = true;
                             self->_naviBar.hidden = true;
                         }];
    } else {
        _selectPhotoButton.hidden = false;
        _selectView.hidden = false;
        _naviBar.hidden = false;
        [UIView animateWithDuration:0.3
                         animations:^{
                             self->_selectPhotoButton.alpha = 1.0;
                             self->_selectView.alpha = 1.0;
                             self->_naviBar.alpha = 1.0;
                         }];
    }
    
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat offSetWidth = scrollView.contentOffset.x;
    offSetWidth = offSetWidth +  ((self.view.tz_width + 20) * 0.5);
    
    NSInteger currentIndex = offSetWidth / (self.view.tz_width + 20);
    
    if (currentIndex < _models.count && _currentIndex != currentIndex) {
        _currentIndex = currentIndex;
        [self refreshNaviBarAndBottomBarState];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"photoPreviewCollectionViewDidScroll" object:nil];
}

#pragma mark - UICollectionViewDataSource && Delegate

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _models.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    TZImagePickerController *_tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    TZAssetModel *model = _models[indexPath.item];
    
    TZAssetPreviewCell *cell;
    __weak typeof(self) weakSelf = self;
    if (_tzImagePickerVc.allowPickingMultipleVideo && model.type == TZAssetModelMediaTypeVideo) {
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"TZVideoPreviewCell" forIndexPath:indexPath];
    } else if (_tzImagePickerVc.allowPickingMultipleVideo && model.type == TZAssetModelMediaTypePhotoGif && _tzImagePickerVc.allowPickingGif) {
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"TZGifPreviewCell" forIndexPath:indexPath];
    } else {
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"TZPhotoPreviewCell" forIndexPath:indexPath];
        TZPhotoPreviewCell *photoPreviewCell = (TZPhotoPreviewCell *)cell;
        photoPreviewCell.cropRect = _tzImagePickerVc.cropRect;
        photoPreviewCell.allowCrop = _tzImagePickerVc.allowCrop;
        __weak typeof(_tzImagePickerVc) weakTzImagePickerVc = _tzImagePickerVc;
        __weak typeof(_collectionView) weakCollectionView = _collectionView;
        __weak typeof(photoPreviewCell) weakCell = photoPreviewCell;
        [photoPreviewCell setImageProgressUpdateBlock:^(double progress) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            __strong typeof(weakTzImagePickerVc) strongTzImagePickerVc = weakTzImagePickerVc;
            __strong typeof(weakCollectionView) strongCollectionView = weakCollectionView;
            __strong typeof(weakCell) strongCell = weakCell;
            strongSelf.progress = progress;
            if (progress >= 1) {
                if (strongSelf.isSelectOriginalPhoto) [strongSelf showPhotoBytes];
                if (strongSelf.alertView && [strongCollectionView.visibleCells containsObject:strongCell]) {
                    [strongTzImagePickerVc hideAlertView:strongSelf.alertView];
                    strongSelf.alertView = nil;
                    [strongSelf doneButtonClick];
                }
            }
        }];
    }
    
    cell.model = model;
    [cell setSingleTapGestureBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf didTapPreviewCell];
    }];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell isKindOfClass:[TZPhotoPreviewCell class]]) {
        [(TZPhotoPreviewCell *)cell recoverSubviews];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell isKindOfClass:[TZPhotoPreviewCell class]]) {
        [(TZPhotoPreviewCell *)cell recoverSubviews];
    } else if ([cell isKindOfClass:[TZVideoPreviewCell class]]) {
        [(TZVideoPreviewCell *)cell pausePlayerAndShowNaviBar];
    }
}

#pragma mark - Private Method

- (void)dealloc {
    // NSLog(@"%@ dealloc",NSStringFromClass(self.class));
}

- (void)refreshNaviBarAndBottomBarState {
    TZImagePickerController *_tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    TZAssetModel *model = _models[_currentIndex];
    _selectPhotoButton.selected = model.isSelected;
    
    [self refreshSelectButtonImageViewContentMode];
    
    _navTitleLabel.text = [NSString stringWithFormat:@"%lu/%lu", (unsigned long)self.currentIndex, (unsigned long)self.models.count - 1];
    [_navTitleLabel sizeToFit];
    
    if (_selectPhotoButton.selected) {
        _selectView.backgroundColor = [UIColor colorWithRed:81/255.0 green:204/255.0 blue:146/255.0 alpha:1];
        _selectView.layer.borderWidth = 0;
    } else {
        _selectView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
        _selectView.layer.borderWidth = 1;
        _selectView.layer.borderColor = [UIColor whiteColor].CGColor;
    }
    
    if (_selectPhotoButton.isSelected && _tzImagePickerVc.showSelectedIndex) {
        NSString *assetId = [[TZImageManager manager] getAssetIdentifier:model.asset];
        NSString *index = [NSString stringWithFormat:@"%zd", [_tzImagePickerVc.selectedAssetIds indexOfObject:assetId] + 1];
        _indexLabel.text = index;
        _indexLabel.hidden = NO;
    } else {
        _indexLabel.hidden = YES;
    }
    _numberLabel.text = [NSString stringWithFormat:@"%zd",_tzImagePickerVc.selectedModels.count];
    _numberImageView.hidden = (_tzImagePickerVc.selectedModels.count <= 0 || _isHideNaviBar || _isCropImage);
    _numberLabel.hidden = (_tzImagePickerVc.selectedModels.count <= 0 || _isHideNaviBar || _isCropImage);
    
    _originalPhotoButton.selected = _isSelectOriginalPhoto;
    _originalPhotoLabel.hidden = !_originalPhotoButton.isSelected;
    if (_isSelectOriginalPhoto) [self showPhotoBytes];
    
    // If is previewing video, hide original photo button
    // 如果正在预览的是视频，隐藏原图按钮
    if (!_isHideNaviBar) {
        if (model.type == TZAssetModelMediaTypeVideo) {
            _originalPhotoButton.hidden = YES;
            _originalPhotoLabel.hidden = YES;
        } else {
            _originalPhotoButton.hidden = NO;
            if (_isSelectOriginalPhoto)  _originalPhotoLabel.hidden = NO;
        }
    }
    
    _doneButton.hidden = NO;
    _selectPhotoButton.hidden = !_tzImagePickerVc.showSelectBtn;
    // 让宽度/高度小于 最小可选照片尺寸 的图片不能选中
    if (![[TZImageManager manager] isPhotoSelectableWithAsset:model.asset]) {
        _numberLabel.hidden = YES;
        _numberImageView.hidden = YES;
        _selectPhotoButton.hidden = YES;
        _originalPhotoButton.hidden = YES;
        _originalPhotoLabel.hidden = YES;
        _doneButton.hidden = YES;
    }
}

- (void)refreshSelectButtonImageViewContentMode {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self->_selectPhotoButton.imageView.image.size.width <= 27) {
            self->_selectPhotoButton.imageView.contentMode = UIViewContentModeCenter;
        } else {
            self->_selectPhotoButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
        }
    });
}

- (void)showPhotoBytes {
    [[TZImageManager manager] getPhotosBytesWithArray:@[_models[_currentIndex]] completion:^(NSString *totalBytes) {
        self->_originalPhotoLabel.text = [NSString stringWithFormat:@"(%@)",totalBytes];
    }];
}

@end

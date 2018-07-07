//
//  TZAssetCell.m
//  TZImagePickerController
//
//  Created by 谭真 on 15/12/24.
//  Copyright © 2015年 谭真. All rights reserved.
//

#import "TZAssetCell.h"
#import "TZAssetModel.h"
#import "UIView+Layout.h"
#import "TZImageManager.h"
#import "TZImagePickerController.h"
#import "TZProgressView.h"

@interface TZAssetCell ()
@property (weak, nonatomic) UIImageView *imageView;       // The photo / 照片
@property (weak, nonatomic) UILabel *indexLabel;
@property (weak, nonatomic) UIView *selectView;
@property (weak, nonatomic) UIView *bottomView;
@property (weak, nonatomic) UILabel *timeLength;

@property (nonatomic, weak) UIImageView *videoImgView;
@property (nonatomic, strong) TZProgressView *progressView;
@property (nonatomic, assign) int32_t bigImageRequestID;
@end

@implementation TZAssetCell

- (void)setModel:(TZAssetModel *)model {
    _model = model;
    if (iOS8Later) {
        self.representedAssetIdentifier = [[TZImageManager manager] getAssetIdentifier:model.asset];
    }
    if (self.useCachedImage && model.cachedImage) {
        self.imageView.image = model.cachedImage;
    } else {
        self.model.cachedImage = nil;
        int32_t imageRequestID = [[TZImageManager manager] getPhotoWithAsset:model.asset photoWidth:self.tz_width completion:^(UIImage *photo, NSDictionary *info, BOOL isDegraded) {
            // Set the cell's thumbnail image if it's still showing the same asset.
            if (!iOS8Later) {
                self.imageView.image = photo;
                self.model.cachedImage = photo;
                [self hideProgressView];
                return;
            }
            if ([self.representedAssetIdentifier isEqualToString:[[TZImageManager manager] getAssetIdentifier:model.asset]]) {
                self.imageView.image = photo;
                self.model.cachedImage = photo;
            } else {
                // NSLog(@"this cell is showing other asset");
                [[PHImageManager defaultManager] cancelImageRequest:self.imageRequestID];
            }
            if (!isDegraded) {
                [self hideProgressView];
                self.imageRequestID = 0;
            }
        } progressHandler:nil networkAccessAllowed:NO];
        if (imageRequestID && self.imageRequestID && imageRequestID != self.imageRequestID) {
            [[PHImageManager defaultManager] cancelImageRequest:self.imageRequestID];
            // NSLog(@"cancelImageRequest %d",self.imageRequestID);
        }
        self.imageRequestID = imageRequestID;
    }
    self.selectPhotoButton.selected = model.isSelected;
    self.indexLabel.hidden = !self.selectPhotoButton.isSelected;
    
    if (self.selectPhotoButton.isSelected) {
        self.selectView.backgroundColor = [UIColor colorWithRed:81/255.0 green:204/255.0 blue:146/255.0 alpha:1];
        self.selectView.layer.cornerRadius = 13;
        self.selectView.layer.borderWidth = 0;
    } else {
        self.selectView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
        self.selectView.layer.cornerRadius = 13;
        self.selectView.layer.borderWidth = 1;
        self.selectView.layer.borderColor = [UIColor whiteColor].CGColor;
    }
    
    self.type = (NSInteger)model.type;
    // 让宽度/高度小于 最小可选照片尺寸 的图片不能选中
    if (![[TZImageManager manager] isPhotoSelectableWithAsset:model.asset]) {
        if (_selectView.hidden == NO) {
            self.selectPhotoButton.hidden = YES;
            _selectView.hidden = YES;
        }
    }
    // 如果用户选中了该图片，提前获取一下大图
    if (model.isSelected) {
        [self requestBigImage];
    } else {
        [self cancelBigImageRequest];
    }
    if (model.needOscillatoryAnimation) {
        [UIView showOscillatoryAnimationWithLayer:self.selectView.layer type:TZOscillatoryAnimationToBigger];
    }
    model.needOscillatoryAnimation = NO;
    [self setNeedsLayout];
    
    if (self.assetCellDidSetModelBlock) {
        self.assetCellDidSetModelBlock(self, _imageView, _selectView, _indexLabel, _bottomView, _timeLength, _videoImgView);
    }
}

- (void)setIndex:(NSInteger)index {
    _index = index;
    self.indexLabel.text = [NSString stringWithFormat:@"%zd", index];
    [self.contentView bringSubviewToFront:self.indexLabel];
}

- (void)setShowSelectBtn:(BOOL)showSelectBtn {
    _showSelectBtn = showSelectBtn;
    if (!self.selectPhotoButton.hidden) {
        self.selectPhotoButton.hidden = !showSelectBtn;
    }
    if (!self.selectView.hidden) {
        self.selectView.hidden = !showSelectBtn;
    }
}

- (void)setType:(TZAssetCellType)type {
    _type = type;
    if (type == TZAssetCellTypePhoto || type == TZAssetCellTypeLivePhoto || (type == TZAssetCellTypePhotoGif && !self.allowPickingGif) || self.allowPickingMultipleVideo) {
        _selectView.hidden = NO;
        _selectPhotoButton.hidden = NO;
        _bottomView.hidden = YES;
    } else { // Video of Gif
        _selectView.hidden = YES;
        _selectPhotoButton.hidden = YES;
    }
    
    if (type == TZAssetCellTypeVideo) {
        self.bottomView.hidden = NO;
        self.timeLength.text = _model.timeLength;
        self.videoImgView.hidden = NO;
        _timeLength.tz_left = self.videoImgView.tz_right;
        _timeLength.textAlignment = NSTextAlignmentRight;
    } else if (type == TZAssetCellTypePhotoGif && self.allowPickingGif) {
        self.bottomView.hidden = NO;
        self.timeLength.text = @"GIF";
        self.videoImgView.hidden = YES;
        _timeLength.tz_left = 5;
        _timeLength.textAlignment = NSTextAlignmentLeft;
    }
}

- (void)selectPhotoButtonClick:(UIButton *)sender {
    if (self.didSelectPhotoBlock) {
        self.didSelectPhotoBlock(sender.isSelected);
    }
    if (self.selectPhotoButton.isSelected) {
        self.selectView.backgroundColor = [UIColor colorWithRed:81/255.0 green:204/255.0 blue:146/255.0 alpha:1];
        self.selectView.layer.cornerRadius = self.selectView.tz_height / 2;
        self.selectView.layer.borderWidth = 0;
    } else {
        self.selectView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
        self.selectView.layer.cornerRadius = self.selectView.tz_height / 2;
        self.selectView.layer.borderWidth = 1;
        self.selectView.layer.borderColor = [UIColor whiteColor].CGColor;
    }
    if (sender.isSelected) {
        if (![TZImagePickerConfig sharedInstance].showSelectedIndex && ![TZImagePickerConfig sharedInstance].showPhotoCannotSelectLayer) {
            [UIView showOscillatoryAnimationWithLayer:_selectView.layer type:TZOscillatoryAnimationToBigger];
        }
        // 用户选中了该图片，提前获取一下大图
        [self requestBigImage];
    } else { // 取消选中，取消大图的获取
        [self cancelBigImageRequest];
    }
}

- (void)hideProgressView {
    if (_progressView) {
        self.progressView.hidden = YES;
        self.imageView.alpha = 1.0;
    }
}

- (void)requestBigImage {
    if (_bigImageRequestID) {
        [[PHImageManager defaultManager] cancelImageRequest:_bigImageRequestID];
    }
    
    _bigImageRequestID = [[TZImageManager manager] requestImageDataForAsset:_model.asset completion:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
        [self hideProgressView];
    } progressHandler:^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
        if (self.model.isSelected) {
            progress = progress > 0.02 ? progress : 0.02;;
            self.progressView.progress = progress;
            self.progressView.hidden = NO;
            self.imageView.alpha = 0.4;
            if (progress >= 1) {
                [self hideProgressView];
            }
        } else {
            *stop = YES;
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
            [self cancelBigImageRequest];
        }
    }];
}

- (void)cancelBigImageRequest {
    if (_bigImageRequestID) {
        [[PHImageManager defaultManager] cancelImageRequest:_bigImageRequestID];
    }
    [self hideProgressView];
}

#pragma mark - Lazy load

- (UIButton *)selectPhotoButton {
    if (_selectPhotoButton == nil) {
        UIButton *selectPhotoButton = [[UIButton alloc] init];
        [selectPhotoButton addTarget:self action:@selector(selectPhotoButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:selectPhotoButton];
        _selectPhotoButton = selectPhotoButton;
    }
    return _selectPhotoButton;
}

- (UIImageView *)imageView {
    if (_imageView == nil) {
        UIImageView *imageView = [[UIImageView alloc] init];
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        [self.contentView addSubview:imageView];
        _imageView = imageView;
        
        [self.contentView bringSubviewToFront:_selectView];
        [self.contentView bringSubviewToFront:_bottomView];
    }
    return _imageView;
}


- (UIView *)selectView {
    if (_selectView == nil) {
        UIView *selectView = [[UIView alloc] init];
        selectView.layer.cornerRadius = selectView.tz_height / 2;
        [self.contentView addSubview:selectView];
        _selectView = selectView;
    }
    return _selectView;
}

- (UIView *)bottomView {
    if (_bottomView == nil) {
        UIView *bottomView = [[UIView alloc] init];
        static NSInteger rgb = 0;
        bottomView.backgroundColor = [UIColor colorWithRed:rgb green:rgb blue:rgb alpha:0.8];
        [self.contentView addSubview:bottomView];
        _bottomView = bottomView;
    }
    return _bottomView;
}

- (UIButton *)cannotSelectLayerButton {
    if (_cannotSelectLayerButton == nil) {
        UIButton *cannotSelectLayerButton = [[UIButton alloc] init];
        [self.contentView addSubview:cannotSelectLayerButton];
        _cannotSelectLayerButton = cannotSelectLayerButton;
    }
    return _cannotSelectLayerButton;
}

- (UIImageView *)videoImgView {
    if (_videoImgView == nil) {
        UIImageView *videoImgView = [[UIImageView alloc] init];
        [videoImgView setImage:[UIImage imageNamedFromMyBundle:@"VideoSendIcon"]];
        [self.bottomView addSubview:videoImgView];
        _videoImgView = videoImgView;
    }
    return _videoImgView;
}

- (UILabel *)timeLength {
    if (_timeLength == nil) {
        UILabel *timeLength = [[UILabel alloc] init];
        timeLength.font = [UIFont boldSystemFontOfSize:11];
        timeLength.textColor = [UIColor whiteColor];
        timeLength.textAlignment = NSTextAlignmentRight;
        [self.bottomView addSubview:timeLength];
        _timeLength = timeLength;
    }
    return _timeLength;
}

- (UILabel *)indexLabel {
    if (_indexLabel == nil) {
        UILabel *indexLabel = [[UILabel alloc] init];
        indexLabel.font = [UIFont systemFontOfSize:14];
        indexLabel.textColor = [UIColor whiteColor];
        indexLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:indexLabel];
        _indexLabel = indexLabel;
    }
    return _indexLabel;
}

- (TZProgressView *)progressView {
    if (_progressView == nil) {
        _progressView = [[TZProgressView alloc] init];
        _progressView.hidden = YES;
        [self addSubview:_progressView];
    }
    return _progressView;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _cannotSelectLayerButton.frame = self.bounds;
    if (self.allowPreview) {
        _selectPhotoButton.frame = CGRectMake(self.tz_width - 44, 0, 44, 44);
    } else {
        _selectPhotoButton.frame = self.bounds;
    }
    
    _selectView.frame = CGRectMake(self.tz_width - 31, 5, 26, 26);
    _indexLabel.frame = _selectView.frame;
    _imageView.frame = CGRectMake(0, 0, self.tz_width, self.tz_height);
    
    static CGFloat progressWH = 20;
    CGFloat progressXY = (self.tz_width - progressWH) / 2;
    _progressView.frame = CGRectMake(progressXY, progressXY, progressWH, progressWH);
    
    _bottomView.frame = CGRectMake(0, self.tz_height - 17, self.tz_width, 17);
    _videoImgView.frame = CGRectMake(8, 0, 17, 17);
    _timeLength.frame = CGRectMake(self.videoImgView.tz_right, 0, self.tz_width - self.videoImgView.tz_right - 5, 17);
    
    self.type = (NSInteger)self.model.type;
    self.showSelectBtn = self.showSelectBtn;
    
    [self.contentView bringSubviewToFront:_bottomView];
    [self.contentView bringSubviewToFront:_cannotSelectLayerButton];
    [self.contentView bringSubviewToFront:_selectView];
    [self.contentView bringSubviewToFront:_indexLabel];
    [self.contentView bringSubviewToFront:_selectPhotoButton];
    
    if (self.assetCellDidLayoutSubviewsBlock) {
        self.assetCellDidLayoutSubviewsBlock(self, _imageView, _selectView, _indexLabel, _bottomView, _timeLength, _videoImgView);
    }
}

@end

@interface TZAlbumCell ()
@property (weak, nonatomic) UIImageView *posterImageView;
@property (weak, nonatomic) UILabel *titleLabel;
@end

@implementation TZAlbumCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return self;
}

- (void)setModel:(TZAlbumModel *)model {
    _model = model;
    
    NSMutableAttributedString *nameString = [[NSMutableAttributedString alloc] initWithString:model.name attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:16],NSForegroundColorAttributeName:[UIColor blackColor]}];
    NSAttributedString *countString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"  (%zd)",model.count] attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:16],NSForegroundColorAttributeName:[UIColor lightGrayColor]}];
    [nameString appendAttributedString:countString];
    self.titleLabel.attributedText = nameString;
    [[TZImageManager manager] getPostImageWithAlbumModel:model completion:^(UIImage *postImage) {
        self.posterImageView.image = postImage;
    }];
    if (model.selectedCount) {
        self.selectedCountButton.hidden = NO;
        [self.selectedCountButton setTitle:[NSString stringWithFormat:@"%zd",model.selectedCount] forState:UIControlStateNormal];
    } else {
        self.selectedCountButton.hidden = YES;
    }
    
    if (self.albumCellDidSetModelBlock) {
        self.albumCellDidSetModelBlock(self, _posterImageView, _titleLabel);
    }
}

/// For fitting iOS6
- (void)layoutSubviews {
    if (iOS7Later) [super layoutSubviews];
    _selectedCountButton.frame = CGRectMake(self.tz_width - 24 - 30, 23, 24, 24);
    NSInteger titleHeight = ceil(self.titleLabel.font.lineHeight);
    self.titleLabel.frame = CGRectMake(80, (self.tz_height - titleHeight) / 2, self.tz_width - 80 - 50, titleHeight);
    self.posterImageView.frame = CGRectMake(0, 0, 70, 70);
    
    if (self.albumCellDidLayoutSubviewsBlock) {
        self.albumCellDidLayoutSubviewsBlock(self, _posterImageView, _titleLabel);
    }
}

- (void)layoutSublayersOfLayer:(CALayer *)layer {
    if (iOS7Later) [super layoutSublayersOfLayer:layer];
}

#pragma mark - Lazy load

- (UIImageView *)posterImageView {
    if (_posterImageView == nil) {
        UIImageView *posterImageView = [[UIImageView alloc] init];
        posterImageView.contentMode = UIViewContentModeScaleAspectFill;
        posterImageView.clipsToBounds = YES;
        [self.contentView addSubview:posterImageView];
        _posterImageView = posterImageView;
    }
    return _posterImageView;
}

- (UILabel *)titleLabel {
    if (_titleLabel == nil) {
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.font = [UIFont boldSystemFontOfSize:17];
        titleLabel.textColor = [UIColor blackColor];
        titleLabel.textAlignment = NSTextAlignmentLeft;
        [self.contentView addSubview:titleLabel];
        _titleLabel = titleLabel;
    }
    return _titleLabel;
}

- (UIButton *)selectedCountButton {
    if (_selectedCountButton == nil) {
        UIButton *selectedCountButton = [[UIButton alloc] init];
        selectedCountButton.layer.cornerRadius = 12;
        selectedCountButton.clipsToBounds = YES;
        selectedCountButton.backgroundColor = [UIColor redColor];
        [selectedCountButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        selectedCountButton.titleLabel.font = [UIFont systemFontOfSize:15];
        [self.contentView addSubview:selectedCountButton];
        _selectedCountButton = selectedCountButton;
    }
    return _selectedCountButton;
}

@end



@implementation TZAssetCameraCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        _imageView = [[UIImageView alloc] init];
        _imageView.backgroundColor = [UIColor colorWithWhite:1.000 alpha:0.500];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        [self.contentView addSubview:_imageView];
        self.clipsToBounds = YES;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _imageView.frame = self.bounds;
}

@end

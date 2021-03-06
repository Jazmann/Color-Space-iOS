//
//  ImageFilter.h
//  ColorSpaceConversion
//
//  Created by NBTB on 8/30/13.
//  Copyright (c) 2013 University of Houston - Main Campus. All rights reserved.
//



#ifdef __cplusplus

#include <opencv2/core.hpp>
#include <opencv2/core/core_c.h>
#include <opencv2/core/mat.hpp>
#include <opencv2/calib3d.hpp>
//#include <opencv2/contrib.hpp>
#include <opencv2/objdetect.hpp>
#include <opencv2/opencv.hpp>
#include <opencv2/opencv_modules.hpp>
#include <opencv2/features2d.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/photo.hpp>
#include <opencv2/photo/photo_c.h>



#endif
#import <UIKit/UIKit.h>

@interface imageFilter : NSObject

-(UIImage *)processImage:(UIImage *)inputImage oldImage:(UIImage *)maskImage number:(int)randomNumber sliderValueOne:(float)valueOne sliderValueTwo:(float)valueTwo;




#ifdef __cplusplus

-(cv::Mat)pixelizeMatConversion:(cv::Mat)inputMat pixelValue:(int)pixelSize;

-(cv::Mat)binaryMatConversion:(cv::Mat)inputMat thresholdValue:(float)value;

-(cv::Mat)sketchConversion:(cv::Mat)inputMat;

-(cv::Mat)inverseMatConversion:(cv::Mat)inputMat;

-(cv::Mat)sepiaConversion:(cv::Mat)inputMat;

-(cv::Mat)pencilSketchConversion:(cv::Mat)inputMat;

-(cv::Mat)grayMatConversion:(cv::Mat)inputMat;

-(cv::Mat)filmGrainConversion:(cv::Mat)inputMat;

-(cv::Mat)retroEffectConversion:(cv::Mat)inputMat;

-(cv::Mat)pinholeCameraConversion:(cv::Mat)inputMat;

-(cv::Mat)softFocusConversion:(cv::Mat)inputMat;

-(cv::Mat)cartoonMatConversion:(cv::Mat)inputMat;

-(cv::Mat)inpaintConversion:(cv::Mat)inputMat mask:(cv::Mat)maskMat;

-(cv::Mat)brightnessContrastEnhanceConversion:(cv::Mat)inputMat betaValue:(float)beta alphaValue:(float)alpha;

#endif



@end

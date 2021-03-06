//
//  ViewController.m
//  ColorSpaceConersion
//

#import "ViewController.h"
#import "ImageFilter.h"
#import <opencv2/highgui/cap_ios.h>
#import <AudioToolbox/AudioServices.h>
#import <AudioToolbox/AudioToolbox.h>
#include <list>
#import "UIImageCVMatConverter.h"
#import "CvFilterController.h"

#ifdef __cplusplus
#include <opencv2/imgproc.hpp>
#include <opencv2/core.hpp>
using namespace cv;

#endif

typedef unsigned char uchar;

//olive dispenser fork

NSString* actionSheetImageOpTitles[] = {@"Skin Detection", @"Probability Map", @"Blob Detection", @"Edge Detection", @"Feature Extraction"};

#define SKIN_DETECTION @"Skin Detection"
#define PROBABILITY_MAP @"Probability Map"
#define BLOB_DETECTION @"Blob Detection"
#define EDGE_DETECTION @"Edge Detection"
#define FEATURE_EXTRACTION @"Feature Extraction"

@interface ViewController()
@end

@implementation ViewController

#pragma mark - 
#pragma mark Properties
@synthesize imagePicker;
@synthesize videoCamera;
@synthesize camSwitch;
@synthesize thresholdSlider;
@synthesize imageView;
@synthesize hsvButton;
@synthesize grayButton;
@synthesize binaryButton;
@synthesize inputMat;
@synthesize forwardButton;
@synthesize hsvImage;
@synthesize saveButton;
@synthesize actionSheetImageOperations;
@synthesize mediaTypes;

// @synthesize imageHistory;

int currentImageIndex = 1;
int nextImageIndex = (currentImageIndex + 1) % 10;
int previousImageIndex = (10 + currentImageIndex - 1) % 10;

cv::Mat imageHistory[10];

-(void) forward
{
    currentImageIndex = nextImageIndex;
    nextImageIndex = (currentImageIndex + 1) % 10;
    previousImageIndex = (10 + currentImageIndex - 1) % 10;
    imageView.image = [self UIImageFromCVMat:(imageHistory[currentImageIndex])];
}

-(void) backward
{
    nextImageIndex = currentImageIndex;
    currentImageIndex = previousImageIndex;
    previousImageIndex = (10 + currentImageIndex - 1) % 10;
    imageView.image = [self UIImageFromCVMat:imageHistory[currentImageIndex]];
}

#pragma mark - 
#pragma mark Managing Views

- (void)viewDidAppear:(BOOL)animated;
{
	[super viewDidAppear:animated];
	if (enableProcessing) {
		[self.videoCamera start];
	} else {
		[self.videoCamera stop];
	}
}

- (void)viewWillDisappear:(BOOL)animated;
{
	[super viewWillDisappear:animated];
	
	[self.videoCamera stop];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.videoCamera = [[CvVideoCamera alloc] initWithParentView:self.imageView];
	self.videoCamera.delegate = self;
	self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionFront;
	self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset352x288;
	self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
	self.videoCamera.defaultFPS = 30;
    
    [camSwitch setOn:NO];
    
    enableProcessing = NO;
    enableCanny = NO;
    enableColorSpace = NO;
    
    NSString *imageName = [[NSBundle mainBundle] pathForResource:@"hand_skin_test_3_back_1" ofType:@"jpg"];
    imageView.image = [UIImage imageWithContentsOfFile:imageName];
    inputMat =[self cvMatFromUIImage:imageView.image];
    imageHistory[currentImageIndex] = inputMat;
    cv::Mat hsvImage;
    self.actionSheetImageOperations = [[UIActionSheet alloc] initWithTitle:@"Select an Operation" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:nil];
	for (int i=0; i<5; i++) {
		[self.actionSheetImageOperations addButtonWithTitle:actionSheetImageOpTitles[i]];
	}

    thresholdSlider.hidden = YES;

}

- (void)viewDidUnload
{
    [self setImageView:nil];
    [self setHsvButton:nil];
    [self setGrayButton:nil];
    [self setBinaryButton:nil];
    [self setThresholdSlider:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - 
#pragma mark button action

//-(void)sVecPrint:(cv::sVec<uint8_t, 3>)vec{
//    printf("Test sVec \n");
//    printf("    / %u \\  / %f \\ \n", vec[0],    vec(0));
//    printf("%4.1f| %u |= | %f | \n",  vec.scale, vec[1], vec(1));
//    printf("    \\ %u /  \\ %f / \n", vec[2],    vec(2));
// }

-(void)printDataInfo:(int)type{
    printf("CV_DEPTH_BITS_MAGIC = %llu \n",CV_DEPTH_BITS_MAGIC);
    printf("To get back the information put into CV_MAKETYPE( depth_Type, cn) use.\n");
    printf("int depth_Type = CV_MAT_DEPTH(type) = %u\n", CV_MAT_DEPTH(type));
    printf("int CV_ELEM_SIZE(type) = %u\n", CV_ELEM_SIZE(type));
    printf("int cn = CV_MAT_CN(type) = %u\n", CV_MAT_CN(type));
    printf("To get info on the type itself use:\n");
    printf("int bit_Depth  = CV_MAT_DEPTH_BITS(type) = %u \n",   CV_MAT_DEPTH_BITS(type));
    printf("int byte_Depth = CV_MAT_DEPTH_BYTES(type) = %u \n", CV_MAT_DEPTH_BYTES(type));
    printf("int channels = CV_MAT_CN(type) = %u \n",  CV_MAT_CN(type));
    printf("The internals:\n");
    printf("In case the channels are packed into fewer than one byte each we calculate : bits_used = channels * bits_per_channel\n");
    printf("CV_ELEM_SIZE_BITS(type) [= %u]  ( CV_MAT_CN(type) [= %u] * CV_DEPTH_BITS(type) [= %u] )\n", CV_ELEM_SIZE_BITS(type), CV_MAT_CN(type), CV_DEPTH_BITS(type));
    printf("then bytes = Ceiling( bits_used / 8)\n");
    printf("CV_ELEM_SIZE_BYTES(type) [= %u] ((CV_ELEM_SIZE_BITS(type) >> 3) [= %u] + ( (CV_ELEM_SIZE_BITS(type) & 7) ? 1 : 0 ) [= %u])\n", CV_ELEM_SIZE_BYTES(type), (CV_ELEM_SIZE_BITS(type) >> 3), ((CV_ELEM_SIZE_BITS(type) & 7) ? 1 : 0 ));
    printf("CV_ELEM_SIZE CV_ELEM_SIZE_BYTES\n");
}


//
//
//cv::Matx<int64_t, 3, 2> rational_decomposition(cv::Matx<float, 3, 1> vec, int64_t max_denom){
//    cv::Matx<int64_t, 3, 2> output;
//    int64_t out_num, out_denom;
//    double float_in;
//    for (int i=0; i<3; i++) {
//        float_in = (double) vec(i);
//        cv::rat_approx(float_in, max_denom, &out_num, &out_denom );
//        output(i,0) = out_num;
//        output(i,1) = out_denom;
//    }
//    return output;
//}


template<typename _Tp, int m, int n> std::string toString(_Tp mat[m][n]){
    std::string output="";
    std::string temp="";
    for (int i=0; i<m; i++) {
    output += "| ";
    for (int j=0; j<n-1; j++) {
        temp = std::to_string(mat[i][j]);
        temp.resize(8,' ');
        output += temp + ", ";
    }
        temp = std::to_string(mat[i][n-1]);
        temp.resize(8,' ');
        output += temp + " |\n";
    }
    return output;
}

template<typename _Tp, int m> std::string toString(_Tp mat[m]){
    std::string output="";
    for (int i=0; i<m; i++) {
            output += "| " + std::to_string(mat[i]) + " |\n";
        }
    return output;
}

//template<typename _Tp, int cn> std::string toString(cv::sVec<_Tp, cn> vec){
//     std::string output = std::to_string(vec.scale) + "  / " + std::to_string(vec[0]) + " \\  / " + std::to_string(vec(0)) + " \\ \n";
//     for (int i=1; i<cn-1; i++) {
//         output += "          | " + std::to_string(vec[i]) + " |= | " + std::to_string(vec(i)) + " | \n";
//     }
//     output += "          \\ " + std::to_string(vec[cn-1]) + " /  \\ " + std::to_string(vec(cn-1)) + " / \n";
//     return output;
//}


//template<typename _Tp, int cn> inline cv::sVec<_Tp, cn> sVecRat(const cv::Matx<float, cn, 1>& vec, int64_t max_denom)
//{
//    cv::sVec<_Tp, cn> output;
//    cv::sVec<int64_t, cn> output_num; output_num.scale = 1.0;
//    cv::sVec<int64_t, cn> output_den; output_den.scale = 1.0;
//    int64_t out_num, out_den;
//    double float_in;
//    for (int i=0; i<cn; i++) {
//        float_in = (double) vec(i);
//        cv::rat_approx(float_in, max_denom, &out_num, &out_den );
//        output_num[i] = out_num;
//        output_den[i] = out_den;
//    }
//    printf("output_num\n");
//    std::cout << toString<int64_t, cn>(output_num);
//    printf("output_den\n");
//    std::cout << toString<int64_t, cn>(output_den);
//
//    output_num.factor();
//    output_den.factor();
//    printf("output_num\n");
//    std::cout << toString<int64_t, cn>(output_num);
//    printf("output_den\n");
//    std::cout << toString<int64_t, cn>(output_den);
//    int64_t den_prod = output_den[0];
//    for(int i=1;i<cn;i++){
//        den_prod *= output_den[i];
//    }
//    
//    printf("den_prod = %lli\n",den_prod);
//
//    for(int i=0;i<cn;i++){
//        output_num[i] *= den_prod/output_den[i];
//    }
//    output_num.scale *= 1.0/(output_den.scale * den_prod);
//    output_num.factor();
//    
//    const uint64_t saturateType = (((1 << ((sizeof(_Tp) << 3)-1)) -1 ) << 1) + 1;
//    int exposure = (int) (output_num.max() / saturateType);
//    output.scale = output_num.scale * (exposure + 1);
//    for(int i=0;i<cn;i++){
//        output.val[i] = (_Tp) (output_num[i]/(exposure + 1)) ;
//    }
//    return output;
//}
//

template<typename _Tp, int m, int n> inline cv::Matx<_Tp, m, 1> MaxInRow(cv::Matx<_Tp, m, n> src){
    cv::Matx<_Tp, m, 1> dst;
    for( int i = 0; i < m; i++ ){
        dst(i,0) = src(i,0);
        for( int j = 1; j < n; j++ )
        {
            if (dst(i,0) < src(i,j)) {
                dst(i,0) = src(i,j);
            }
        }
    }
    return dst;
}


template<typename _Tp, int m, int n> inline cv::Matx<_Tp, m, 1> MinInRow(cv::Matx<_Tp, m, n> src){
    cv::Matx<_Tp, m, 1> dst;
    for( int i = 0; i < m; i++ ){
        dst(i,0) = src(i,0);
        for( int j = 1; j < n; j++ )
        {
            if (dst(i,0) > src(i,j)) {
                dst(i,0) = src(i,j);
            }
        }
    }
    return dst;
}

//-(void)sVecTest{
//    cv::sVec<uint8_t, 3> a{1.5,3,6,9};
//    cv::sVec<uint8_t, 3> b{1.5,15,20,10};
//    [self sVecPrint:a];
//    [self sVecPrint:b];
//    a.factor();b.factor();
//    [self sVecPrint:a];
//    [self sVecPrint:b];
//    cv::sVec<uint8_t, 1> ab = a * b ;
//    cv::sVec<uint8_t, 1> ba = b * a;
//    printf("a . b = %f %u = %f \n", ab.scale, ab[0], ab(0));
//    printf("a . b = %f %u = %f \n", ba.scale, ba[0], ab(0));
//    cv::Matx<float, 3, 1> mx{1.2, 2.2, 3.2};
//    printf("Matx{ %f %f %f }\n", mx(0), mx(1), mx(2));
//    cv::sVec<uint8_t, 3> aM(mx);
//    [self sVecPrint:aM];
//    
//    cv::sVec<uint8_t, 3> aV = sVecRat<uint8_t, 3>(mx, 255);
//    [self sVecPrint:aV];
//
//    
//    const unsigned long long int saturateType = (1 << (sizeof(uint8_t) << 3))-1;
//    float maxVal = mx(0,0);
//    for (int i=1; i<3; i++) { if (mx(i,0) > maxVal) maxVal = mx(i,0);}
//    float scale = maxVal/saturateType;
//    printf("saturateType %llu maxVal %f scale %f \n", saturateType, maxVal, scale);
//    cv::Matx<uint8_t,3,1> vm(mx, saturateType/maxVal, cv::Matx_ScaleOp());
//    printf("Matx{ %u %u %u }\n", vm(0), vm(1), vm(2));
//    cv::Matx<int64_t, 3, 2> rdMat = rational_decomposition(mx, 255);
//    printf("rdMat{ %lli %lli %lli }\n", rdMat(0,0), rdMat(1,0), rdMat(2,0));
//    printf("rdMat{ %lli %lli %lli }\n", rdMat(0,1), rdMat(1,1), rdMat(2,1));
//
//    
//    cv::Matx<float, 3, 1> fMa{1.2, 2.2, 3.2};
//    cv::sVec<uint8_t, 3> fVa(fMa);
//    printf("fVa\n");
//    [self sVecPrint:fVa];
//
// //   std::string disp = fVa.toString();
// //   std::cout << disp;
//    cv::Matx<float, 3, 1> fMb{2.2, 2.2, 1.1};
//    cv::sVec<uint8_t, 3> fVb(fMb);
//    printf("fVb\n");
//    [self sVecPrint:fVb];
//
//    cv::Matx<float, 3, 1> fMc{1.2, 2.3, 3.7};
//    cv::sVec<uint8_t, 3> fVc(fMc);
//    printf("fVc\n");
//    [self sVecPrint:fVc];
//    
//}

-(IBAction)hsvImageAction:(id)sender
{
    using sWrkType = typename cv::Signed_Work_Type<CV_8U,CV_8U>::type;
    using wrkType  = typename cv::Work_Type<CV_8U,CV_8U>::type;
    using srcInfo = cv::Data_Type<CV_8U>;
    cv::Matx<sWrkType, 3, 3> fR;
    Vec<double, 3> rRScale, nRScale, fRScale;
    Vec<wrkType, 3> RRange;
    Vec<sWrkType, 3> RMin, RMax;
    sWrkType qfR[3][3];
    double fScale[3], scale[3];
    int srcInfo_max = srcInfo::max;

    thresholdSlider.hidden = YES;
    // R:239, G:208, B:207

    cv::Vec<double, 3> c(0.5, 0.4281, 0.3443);
    cv::Vec<double, 3> g(1.0, 18.0, 2.8);
    double theta=1.015896326794897;


    int nBits = 8 -1; // The number of bits in which to store the numeric value of the matrix (-1 to account for the sign bit)
    double rRange = std::pow(2,nBits);

    double Cos      = std::cos(theta);    double CosPlus  = std::cos(CV_PI/6. + theta);    double CosMinus = std::cos(CV_PI/6. - theta);
    double Sin      = std::sin(theta);    double SinPlus  = std::sin(CV_PI/6. + theta);    double SinMinus = std::sin(CV_PI/6. - theta);

    double Csc   = 1./std::sin(theta);    double CscPlus  = 1./std::sin(CV_PI/6. + theta);    double CscMinus = 1./std::sin(CV_PI/6. - theta);
    double Sec   = 1./std::cos(theta);    double SecPlus  = 1./std::cos(CV_PI/6. + theta);    double SecMinus = 1./std::cos(CV_PI/6. - theta);

    cv::Matx<double, 3, 3> rR = cv::Matx<double, 3, 3>( 1.0,      1.0,   1.0, \
                                -SinPlus,  Cos, -SinMinus, \
                                -CosPlus, -Sin,  CosMinus );

    //  rRScale scales to give the unscaled rotated ranges.
    rRScale = Vec<double, 3>(1./std::sqrt(3), std::sqrt(0.6666666666666666), std::sqrt(0.6666666666666666));

    //  nRScale is scaled to give ranges 0:1, -0.5:0.5 -0.5:0.5 with a unit RGB cube.
    nRScale = Vec<double, 3>(1/std::sqrt(3), \
                             (std::sqrt(1.5))/(2.*std::cos(CV_PI/6. - std::fmod(theta - CV_PI/6., CV_PI/3.))), \
                             (std::sqrt(1.5))/(2.*std::cos(CV_PI/6. - std::fmod(theta,            CV_PI/3.))));

    switch (int(std::floor(6* (std::fmod(theta, CV_PI/2.))/CV_PI)))
    {
        case 0:
            fRScale = Vec<double, 3>(1,(-2*SinPlus)/rRange,(-2*CosPlus)/rRange);
            fR = cv::Matx<sWrkType, 3, 3>(
                                          1,1,1,\
                                          sWrkType(rRange/2.), sWrkType(-(rRange*Cos*CscPlus)/2.), sWrkType( (rRange*CscPlus*SinMinus)/2.),\
                                          sWrkType(rRange/2.), sWrkType( (rRange*Sin*SecPlus)/2.), sWrkType(-(rRange*SecPlus*CosMinus)/2.)
                                          );
            RRange[0] =  sWrkType(srcInfo::max) * sWrkType(3);                           RMin[0] = 0;                           RMax[0] = RRange[0];
            RRange[1] =  sWrkType(srcInfo::max) * sWrkType(rRange * CscPlus * Cos);      RMin[1] = sWrkType(-1 * RRange[1]/2);  RMax[1] = RRange[1]/2;
            RRange[2] =  sWrkType(srcInfo::max) * sWrkType(rRange * SecPlus * CosMinus); RMin[2] = sWrkType(-1 * RRange[2]/2);  RMax[2] = RRange[2]/2;
            break;
        case 1:
            fRScale = Vec<double, 3>(1,(2*Cos)/rRange,(-2*Sin)/rRange);
            fR = cv::Matx<sWrkType, 3, 3>(
                                          1,1,1,\
                                          sWrkType(-(rRange*Sec*SinPlus)/2.), sWrkType(rRange/2.), sWrkType(-(rRange*Sec*SinMinus)/2.),\
                                          sWrkType( (rRange*Csc*CosPlus)/2.), sWrkType(rRange/2.), sWrkType(-(rRange*Csc*CosMinus)/2.)
                                          );
            RRange[0] = sWrkType(srcInfo::max) * sWrkType(3);                       RMin[0] = 0;                           RMax[0] = RRange[0];
            RRange[1] = sWrkType(srcInfo::max) * sWrkType(rRange * SinPlus  * Sec); RMin[1] = sWrkType(-1 * RRange[1]/2);  RMax[1] = RRange[1]/2;
            RRange[2] = sWrkType(srcInfo::max) * sWrkType(rRange * CosMinus * Csc); RMin[2] = sWrkType(-1 * RRange[2]/2);  RMax[2] = RRange[2]/2;


            break;
        case 2:
            fRScale = Vec<double, 3>(1,(-2*SinMinus)/rRange,(2*CosMinus)/rRange);
            fR = cv::Matx<sWrkType, 3, 3>(
                                          1,1,1,\
                                          sWrkType( (rRange*CscMinus*SinPlus)/2.), sWrkType(-(rRange*Cos*CscMinus)/2.), sWrkType(rRange/2.),\
                                          sWrkType(-(rRange*SecMinus*CosPlus)/2.), sWrkType(-(rRange*Sin*SecMinus)/2.), sWrkType(rRange/2.)
                                          );

            RRange[0] = sWrkType(srcInfo::max) * sWrkType( 3 );                              RMin[0] = 0;                           RMax[0] = RRange[0];
            RRange[1] = sWrkType(srcInfo::max) * sWrkType(-1 * rRange * CscMinus * SinPlus); RMin[1] = sWrkType(-1 * RRange[1]/2);  RMax[1] = RRange[1]/2;
            RRange[2] = sWrkType(srcInfo::max) * sWrkType(     rRange * SecMinus * Sin);     RMin[2] = sWrkType(-1 * RRange[2]/2);  RMax[2] = RRange[2]/2;

            break;
        default:
            fRScale = Vec<double, 3>();
            fR = cv::Matx<sWrkType, 3, 3>();
            RRange = Vec<sWrkType, 3>();  RMin = Vec<sWrkType, 3>();  RMax = Vec<sWrkType, 3>();
    };

    fScale[0] = rRScale[0] * fRScale[0];     fScale[1] = rRScale[1] * fRScale[1];     fScale[2] = rRScale[2] * fRScale[2];
    scale[0] = rRScale[0] * nRScale[0];      scale[1] = rRScale[1] * nRScale[1];      scale[2] = rRScale[2] * nRScale[2];

    qfR[0][0] = fR(0,0); qfR[0][1] = fR(0,1); qfR[0][2] = fR(0,2);
    qfR[1][0] = fR(1,0); qfR[1][1] = fR(1,1); qfR[1][2] = fR(1,2);
    qfR[2][0] = fR(2,0); qfR[2][1] = fR(2,1); qfR[2][2] = fR(2,2);

    // cv::Matx<int, 3, 3> T(76,-43,127, 127,-84,-107, 29,-127,21);
    // RGB2Rot(const int srcBlueIdx, const int dstBlueIdx, const double theta, cv::Vec<double, 3> newG, cv::Vec<double, 3> newC){

    cv::RGB2Rot_int<CV_8UC4,CV_8UC3> colSpace;
    colSpace.setTransformFromAngle(theta);
    colSpace.setRGBIndices(2, 2);
//    colSpace.c{c[0],c[1],c[2]};
//    colSpace.g{g[0],g[1],g[2]};
    colSpace.setuC(c); // asumes that C is in rotated color space and with a dstBlueIdx
    colSpace.setG(g);
    colSpace.setRedDistributionErf();
    colSpace.setGreenDistributionErf();
    colSpace.setBlueDistributionErf();
    //cv::RGB2Rot<CV_8UC4,CV_8UC3> colSpace(2, 2, theta, g, c);
    
    cv::convertColor<CV_8UC4,CV_8UC3>(imageHistory[currentImageIndex], imageHistory[nextImageIndex], colSpace);
    hsvImage = imageHistory[nextImageIndex];
    
    // Update Current Image Index and put up on screen.
    // convert cvMat to UIImage
    //[self forward];
}


-(IBAction)grayImageAction:(id)sender
{
    thresholdSlider.hidden = YES;
    [self backward];
}

-(IBAction)forwardImageAction:(id)sender
{
    thresholdSlider.hidden = YES;
    [self forward];
}

-(IBAction)resetImage:(id)sender
{
    thresholdSlider.hidden = YES;
    NSString *imageName = [[NSBundle mainBundle] pathForResource:@"hand_skin_test_3_back_1" ofType:@"jpg"];
    imageView.image = [UIImage imageWithContentsOfFile:imageName];
    inputMat =[self cvMatFromUIImage:imageView.image];
}

-(IBAction)saveImage:(id)sender
{
    UIImageWriteToSavedPhotosAlbum(imageView.image, nil, nil, nil);
}

-(IBAction)binaryImageAction:(id)sender
{
    cv::Mat binaryMatU, binaryMatL, greyMat;
    thresholdSlider.hidden = NO;
    thresholdSlider.continuous = YES;
    float threshold = thresholdSlider.value;
    
    cv::Vec<int, 3> c(128, 128, 128);
    cv::Matx<int, 3, 3> T(0, 1, 1, 0, 1, 1, 0, 1, 1);

    
//    cv::ABC2Metric<CV_8UC3,CV_8UC3> skinColorSpace(T, c);
//    cv::convertColor<CV_8UC3,CV_8UC3>(imageHistory[currentImageIndex], imageHistory[nextImageIndex], skinColorSpace);
    
    // Update Current Image Index and put up on screen.
    // convert cvMat to UIImage
    [self forward];

    
//    cv::cvtColor(imageHistory[currentImageIndex], greyMat, CV_BGR2GRAY);
//    cv::threshold(greyMat,binaryMatL,threshold,0,cv::THRESH_TOZERO);
//    cv::threshold(binaryMatL,binaryMatU,255-threshold,0,cv::THRESH_TOZERO_INV);
//    imageHistory[nextImageIndex] = binaryMatU;
//    [self forward];
//    // Garbage collect.
//    greyMat.release(); binaryMatL.release(); binaryMatU.release();
}

-(IBAction)binarySliderAction:(id)sender
{
    cv::Mat binaryMatU, binaryMatL, greyMat;
    thresholdSlider.hidden = NO;
    thresholdSlider.continuous = YES;
    float threshold = thresholdSlider.value;
    cv::cvtColor(imageHistory[previousImageIndex], greyMat, CV_BGR2GRAY);
    cv::threshold(greyMat,binaryMatL,threshold,0,cv::THRESH_TOZERO);
    cv::threshold(binaryMatL,binaryMatU,255-threshold,0,cv::THRESH_TOZERO_INV);
    imageHistory[currentImageIndex] = binaryMatU;
    imageView.image = [self UIImageFromCVMat:imageHistory[currentImageIndex]];
    // Garbage collect.
    greyMat.release(); binaryMatL.release(); binaryMatU.release();
}

- (IBAction)switchProcessingOnOff:(id)sender;
{
	enableProcessing = !enableProcessing;
	if (enableProcessing) {
		[self.videoCamera start];
	} else {
		[self.videoCamera stop];
	}
}

- (void)vibrate {
    AudioServicesPlaySystemSound (kSystemSoundID_Vibrate);
}


- (IBAction)switchCamera:(id)sender;
{
	[self.videoCamera switchCameras];
}

- (IBAction)showPhotoLibrary:(id)sender;
{
	NSLog(@"show photo library");
	
	self.imagePicker = [[ImagePickerController alloc] init];
	self.imagePicker.delegate = self;
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
  //  imagePicker.mediaTypes =
  //  [UIImagePickerController availableMediaTypesForSourceType:
  //   UIImagePickerControllerSourceTypeCamera];
	[self.imagePicker showPicker:self];
}

#pragma mark - Protocol UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info;
{
    
    
    UIImage* image = [info objectForKey:UIImagePickerControllerOriginalImage];
    cv::Mat m_image = [self cvMatFromUIImage:image];
    [self processImage:m_image];
    image = [self UIImageFromCVMat:m_image];
    self.imageView.image = image;
    
    UIImageWriteToSavedPhotosAlbum(self.imageView.image, nil, nil, nil);
    
    [self.imagePicker hidePicker:self];
}



- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;
{
    [self.imagePicker hidePicker:self];
}


-(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    printf("UIImageFromCVMat: cols : %i \n",cvMat.cols);
    printf("UIImageFromCVMat: rows : %i \n",cvMat.rows);
    
    printf("UIImageFromCVMat: cvMat.size(0) : %i \n",cvMat.size[0]);
    printf("UIImageFromCVMat: cvMat.size(1) : %i \n",cvMat.size[1]);
    printf("UIImageFromCVMat: cvMat.step(0) : %lu \n",cvMat.step[0]);
    printf("UIImageFromCVMat: cvMat.elemSize() : %lu \n",cvMat.elemSize());
    printf("UIImageFromCVMat: cvMat.elemSize1() : %lu \n",cvMat.elemSize1());
    printf("UIImageFromCVMat: cvMat.total() : %lu \n",cvMat.total());
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8 * cvMat.elemSize1(),                      //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage; 
}
- (cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    printf("cols : %f",cols);
    printf("rows : %f",rows);

    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
    printf("cvMat.size(0) : %i \n",cvMat.size[0]);
    printf("cvMat.size(1) : %i \n",cvMat.size[1]);
    printf("cvMat.step(0) : %lu \n",cvMat.step[0]);
    printf("cvMat.elemSize() : %lu \n",cvMat.elemSize());
    printf("cvMat.elemSize1() : %lu \n",cvMat.elemSize1());
    printf("cvMat.total() : %lu \n",cvMat.total());

    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    
    return cvMat;
}
- (cv::Mat)cvMatGrayFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC1); // 8 bits per component, 1 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    
    return cvMat;
}

#pragma mark - SettingsViewControllerDelegate
- (void)settingsViewControllerDidCancel:(SettingsViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)settingsViewControllerDidSave:(SettingsViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"Settings"])
    {
        UINavigationController *navigationController =
        segue.destinationViewController;
        SettingsViewController *settingsViewController = [[navigationController viewControllers] objectAtIndex:0];
        settingsViewController.delegate = self;
    }
}

- (IBAction)showImageOperations:(id)sender;
{
	[self.actionSheetImageOperations showInView:self.view];
}

- (IBAction)actionCanny:(id)sender;
{
    enableCanny = !enableCanny;
    vector<Mat> planes;
    split(imageHistory[currentImageIndex], planes);
    if (enableCanny) {
        for (int i=0; i<planes.size(); i++) {
            [UIImageCVMatConverter filterCanny:planes.at(i) withKernelSize:3 andLowThreshold:15];
        }

    }
    
    merge(planes, imageHistory[nextImageIndex]);
    [self forward];
}

- (IBAction)actionColorSpace:(id)sender;
{
    enableColorSpace = !enableColorSpace;
    cv::Mat image = imageHistory[currentImageIndex];
    if (enableColorSpace) {
        [self hsvImageAction:nil];
    }
    
    [self forward];
}

- (void)processImage:(cv::Mat&)image;
{
    const int& width = image.cols;
	const int& height = image.rows;
	const int& bytesPerRow = image.step;
    cv::Mat result;
    
    if (enableCanny) {
        std::vector<cv::Mat> planes;
            split(imageHistory[currentImageIndex], planes);
        for (int i=0; i<=planes.size(); i++) {
            [UIImageCVMatConverter filterCanny:planes.at(i) withKernelSize:12 andLowThreshold:35];
        }
            merge(planes, imageHistory[nextImageIndex]);
    }
    if (enableColorSpace){
        //result = [self.imageHistory[currentImageIndex] hsvImageAction:nil];
    }
    
    [self forward];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex;
{
    NSString *choice = [actionSheet buttonTitleAtIndex:buttonIndex];
	if (actionSheet.cancelButtonIndex == buttonIndex) {
         NSLog(@"Cancelled");
		return;
	}
	if ([choice isEqualToString:SKIN_DETECTION]) {
        [self actionColorSpace:nil];
		NSLog(@"Skin detection");
	} else if ([choice isEqualToString:PROBABILITY_MAP]) {
        [self binaryImageAction:nil];
		NSLog(@"Probability map");
    } else if ([choice isEqualToString:BLOB_DETECTION]) {
		NSLog(@"Blob detection");
    } else if ([choice isEqualToString:EDGE_DETECTION]) {
		NSLog(@"Edge detection");
        [self vibrate];
        [self actionCanny:nil];
    } else if ([choice isEqualToString:FEATURE_EXTRACTION]) {
		NSLog(@"Feature extraction");
    }
}

@end

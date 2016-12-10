#import "ViewController.h"

#ifdef __cplusplus
#include "opencv2/features2d/features2d.hpp"
#include "opencv2/nonfree/features2d.hpp"
#include <opencv2/opencv.hpp>
#include <iostream>
#include <string>

#endif

@interface ViewController(){
    UIImageView *imageView_; // Setup the image view
    UITextView *fpsView_; // Display the current FPS
    int64 curr_time_; // Store the current time
}
@end

@implementation ViewController

// Important as when you when you override a property of a superclass, you must explicitly synthesize it
@synthesize videoCamera;

- (void)viewDidLoad {
    [super viewDidLoad];
    // initialization
    tmp_cards=loadtmpCards();   // load templete cards
    monster_card=loadmonsCards();   // load projection cards
    // load 3d point cloud
    NSString *filepath0 = [[NSBundle mainBundle] pathForResource:@"sphere" ofType:@"txt"];
    NSString *filepath1 = [[NSBundle mainBundle] pathForResource:@"spiral" ofType:@"txt"];
    NSString *filepath2 = [[NSBundle mainBundle] pathForResource:@"gaussian" ofType:@"txt"];
    NSString *filepath3 = [[NSBundle mainBundle] pathForResource:@"moebius" ofType:@"txt"];
    NSError *error;
    NSString *fileContents0 = [NSString stringWithContentsOfFile:filepath0 encoding:NSUTF8StringEncoding error:&error];
    NSString *fileContents1 = [NSString stringWithContentsOfFile:filepath1 encoding:NSUTF8StringEncoding error:&error];
    NSString *fileContents2 = [NSString stringWithContentsOfFile:filepath2 encoding:NSUTF8StringEncoding error:&error];
    NSString *fileContents3 = [NSString stringWithContentsOfFile:filepath3 encoding:NSUTF8StringEncoding error:&error];
    std::string objectPtsCloud0 = std::string([fileContents0 UTF8String]);
    std::string objectPtsCloud1 = std::string([fileContents1 UTF8String]);
    std::string objectPtsCloud2 = std::string([fileContents2 UTF8String]);
    std::string objectPtsCloud3 = std::string([fileContents3 UTF8String]);
    std::vector<cv::Point3f> objjPts0=ReadPts3fFromTxt(objectPtsCloud0);
    std::vector<cv::Point3f> objjPts1=ReadPts3fFromTxt(objectPtsCloud1);
    std::vector<cv::Point3f> objjPts2=ReadPts3fFromTxt(objectPtsCloud2);
    std::vector<cv::Point3f> objjPts3=ReadPts3fFromTxt(objectPtsCloud3);
    objPtsSet.push_back(objjPts0);
    objPtsSet.push_back(objjPts1);
    objPtsSet.push_back(objjPts2);
    objPtsSet.push_back(objjPts3);
    
    
    // intrinsic and distortion
    intrinsics = cv::Mat::zeros(3,3,CV_64F);
    intrinsics.at<double>(0,0) = 593.09900;
    intrinsics.at<double>(1,1) = 590.09473;
    intrinsics.at<double>(2,2) = 1;
    intrinsics.at<double>(0,2) = 320.26862;
    intrinsics.at<double>(1,2) = 237.86729;
    distCoeffs = cv::Mat(4,1,cv::DataType<double>::type);
    distCoeffs.at<double>(0) = 0.1571472287;
    distCoeffs.at<double>(1) = -0.3774241507;
    distCoeffs.at<double>(2) = -0.0006767344;
    distCoeffs.at<double>(3) = 0.0022913516;

    float cam_width = 480; float cam_height = 640;
    int view_width = self.view.frame.size.width;
    int view_height = (int)(cam_height*self.view.frame.size.width/cam_width);
    int offset = (self.view.frame.size.height - view_height)/2;
    
    imageView_ = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, offset, view_width, view_height)];
    [self.view addSubview:imageView_]; // Add the view
    
    // Initialize the video camera
    self.videoCamera = [[CvVideoCamera alloc] initWithParentView:imageView_];
    self.videoCamera.delegate = self;
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self.videoCamera.defaultFPS = 30; // Set the frame rate
    self.videoCamera.grayscaleMode = NO;
    self.videoCamera.rotateVideo = YES; // Rotate video so everything looks correct
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset640x480;
    
    // Finally add the FPS text to the view
    fpsView_ = [[UITextView alloc] initWithFrame:CGRectMake(0,15,view_width,std::max(offset,35))];
    [fpsView_ setOpaque:false]; // Set to be Opaque
    [fpsView_ setBackgroundColor:[UIColor clearColor]]; // Set background color to be clear
    [fpsView_ setTextColor:[UIColor redColor]]; // Set text to be RED
    [fpsView_ setFont:[UIFont systemFontOfSize:18]]; // Set the Font size
    [self.view addSubview:fpsView_];
    
    [videoCamera start];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
bool compareContourAreas ( std::vector<cv::Point> contour1, std::vector<cv::Point> contour2 ) {
    double i = fabs( contourArea(cv::Mat(contour1)) );
    double j = fabs( contourArea(cv::Mat(contour2)) );
    return ( i > j );
}

- (void) processImage:(cv:: Mat &)image
{
    using namespace cv;
    Mat gray;
    if(image.channels() == 4){
        cvtColor(image, gray, CV_BGRA2GRAY);
        cvtColor(image, image, CV_BGRA2RGB);
    }
    else gray = image;

    Mat thresh;
    threshold(gray, thresh, 180, 255, THRESH_BINARY);
    vector<vector<cv::Point> > contours;
    vector<Vec4i> hierarchy;
    findContours(thresh, contours, hierarchy, CV_RETR_EXTERNAL, CV_CHAIN_APPROX_SIMPLE);
    
    std::sort(contours.begin(), contours.end(), compareContourAreas);
    const Scalar color(0,0,0);
    
    // here just find the biggest card on the desk
    // need to be changed, if necessary
    drawContours( image, contours, 0, color, 2, 8, hierarchy );


    Point2f  proCoords[4];
    proCoords[0] = Point2f(0,0);
    proCoords[3] = Point2f(299,0);
    proCoords[2] = Point2f(299,299);
    proCoords[1] = Point2f(0,299);
    
    if(contours.size()>0){
    vector<cv::Point>  card = contours[0];
    vector<cv::Point>  approCard;
    Point2f temp[4];
    double peri = arcLength(card, true);
    approxPolyDP(card,approCard,0.02*peri,true);
        
    cv::Mat test_image;
    if(approCard.size()==4){
        temp[0]=approCard[0];
        temp[1]=approCard[1];
        temp[2]=approCard[2];
        temp[3]=approCard[3];
            
        Mat lambda = getPerspectiveTransform(temp,proCoords);
        cv::Size ddsize(300,300);
        warpPerspective(image, test_image, lambda, ddsize);
        
        if(test_image.channels()>1){
            cvtColor(test_image,test_image,CV_RGB2GRAY);
            
        }

        threshold(test_image, test_image, 150, 255, THRESH_BINARY_INV);
        std::vector<double> diffs=imgDiff(test_image,tmp_cards);
        
        card_id=0;
        double tmpp=diffs[0];
        for(int i=1;i<tmp_cards.size();++i){
            if(tmpp>diffs[i]){
                tmpp=diffs[i];
                card_id=i;
            }
        }

    }
        
        
        
        cv::Mat tmpp_img=drawCard(image,approCard,card_id);
        std::vector<cv::Point2f> projectPts = draw3dObj(approCard,card_id);
        const cv::Scalar BLUE = cv::Scalar(0,0,255); // Set the RED color
        tmpp_img = DrawPts(tmpp_img, projectPts, BLUE);
        
        image=tmpp_img;
        
        
    }
    
    
    
    
    int64 next_time = getTickCount();
    float fps = (float)getTickFrequency()/(next_time - curr_time_);
    curr_time_ = next_time;
    NSString *fps_NSStr = [NSString stringWithFormat:@"FPS = %2.2f",fps];

    dispatch_sync(dispatch_get_main_queue(), ^{
        fpsView_.text = fps_NSStr;
    });
    
}

// card projection
cv::Mat drawCard(cv::Mat inputImg,std::vector<cv::Point> approCard,int card_id){
    cv::Mat res;
    cv::Mat m_card=monster_card[card_id];
    int rows=m_card.rows;
    int cols=m_card.cols;
    cv::Point2f temp[4];
    temp[0]=approCard[0];
    temp[1]=approCard[1];
    temp[2]=approCard[2];
    temp[3]=approCard[3];
    
    cv::Point2f  moncardCoords[4];
    moncardCoords[0] = cv::Point2f(0,0);
    moncardCoords[3] = cv::Point2f(cols-1,0);
    moncardCoords[2] = cv::Point2f(cols-1,rows-1);
    moncardCoords[1] = cv::Point2f(0,rows-1);

    cv::Mat H = getPerspectiveTransform(moncardCoords,temp);

    cv::Mat warped_card;
    cv::warpPerspective(m_card, warped_card, H, inputImg.size());

    cv::Mat gray,gray_inv,src1final,src2final;
    cvtColor(warped_card,gray,CV_BGR2GRAY);
    threshold(gray,gray,0,255,CV_THRESH_BINARY);
    bitwise_not ( gray, gray_inv );
    inputImg.copyTo(src1final,gray_inv);
    warped_card.copyTo(src2final,gray);
    cv::Mat finalImage = src1final+src2final;
    res=finalImage;

    return res;
}
//
//
std::vector<cv::Point2f> draw3dObj(std::vector<cv::Point> approCard,int card_id){
    cv::Mat m_card=monster_card[card_id];
    int rows=m_card.rows;
    int cols=m_card.cols;
    
    
    std::vector<cv::Point3f> shperePts=objPtsSet[card_id];
    //
    
    std::vector<cv::Point2f> temp(4);
    temp[0] = approCard[0];
    temp[1] = approCard[1];
    temp[2] = approCard[2];
    temp[3] = approCard[3];
    std::vector<cv::Point3f> proj_corners(4);
    proj_corners[0] = cv::Point3f(0,0,0);
    proj_corners[1] = cv::Point3f( cols-1, 0, 0 );
    proj_corners[2] = cv::Point3f( cols-1, rows-1, 0 );
    proj_corners[3] = cv::Point3f( 0, rows-1, 0 );

    cv::Mat rvec, tvec;
    cv::solvePnP(proj_corners, temp, intrinsics, distCoeffs, rvec, tvec);
    std::vector<cv::Point2f> sphere_proj_corners;
    cv::projectPoints(shperePts, rvec, tvec, intrinsics, distCoeffs, sphere_proj_corners);
    return sphere_proj_corners;
}

//
cv::Mat DrawPts(cv::Mat &display_im, std::vector<cv::Point2f> &cv_pts, const cv::Scalar &pts_clr)
{
    for(int i=0; i<cv_pts.size(); i++) {
        cv::circle(display_im, cv_pts[i], 1, pts_clr,1); // Draw the points
    }
    return display_im; // Return the display image
}

//
// cards difference
std::vector<double> imgDiff(cv::Mat test_image,std::vector<cv::Mat> tmp_cards){
    std::vector<double> res;
    unsigned long cards_num=tmp_cards.size();
    for(int i=0;i<cards_num;i++){
        cv::Mat diff;
        cv::Scalar summ;
        absdiff(test_image, tmp_cards[i], diff);
        summ=sum(diff);
        double tmp=summ[0];
        res.push_back(tmp);
    }
    return res;
}

std::vector<cv::Mat> loadmonsCards(){
    std::vector<cv::Mat> res;
    UIImage *image1 = [UIImage imageNamed:@"mons1.jpg"];
    cv::Mat cvImage1 = cvMatFromUIImage(image1);
    UIImage *image2 = [UIImage imageNamed:@"mons2.jpg"];
    cv::Mat cvImage2 = cvMatFromUIImage(image2);
    UIImage *image3 = [UIImage imageNamed:@"mons3.jpg"];
    cv::Mat cvImage3 = cvMatFromUIImage(image3);
    UIImage *image4 = [UIImage imageNamed:@"mons4.jpg"];
    cv::Mat cvImage4 = cvMatFromUIImage(image4);
    
    if(cvImage1.channels()>1){
        std::cout<<"channel number is "<<cvImage1.channels()<<std::endl;
        cvtColor(cvImage1, cvImage1, CV_RGBA2RGB);
        cvtColor(cvImage2, cvImage2, CV_RGBA2RGB);
        cvtColor(cvImage3, cvImage3, CV_RGBA2RGB);
        cvtColor(cvImage4, cvImage4, CV_RGBA2RGB);
    }
    
    res.push_back(cvImage1);
    res.push_back(cvImage2);
    res.push_back(cvImage3);
    res.push_back(cvImage4);
    
    return res;
}

std::vector<cv::Mat> loadtmpCards(){
    cv::Size ddsize(300 , 300);
    //    std::cout<<"call test function"<<std::endl;
    std::vector<cv::Mat> res;
    UIImage *image1 = [UIImage imageNamed:@"spade4.JPG"];
    cv::Mat cvImage1 = cvMatFromUIImage(image1);
    UIImage *image2 = [UIImage imageNamed:@"diamond6.JPG"];
    cv::Mat cvImage2 = cvMatFromUIImage(image2);
    UIImage *image3 = [UIImage imageNamed:@"heartA.JPG"];
    cv::Mat cvImage3 = cvMatFromUIImage(image3);
    UIImage *image4 = [UIImage imageNamed:@"clubs10.JPG"];
    cv::Mat cvImage4 = cvMatFromUIImage(image4);
    
    if(cvImage1.channels()>1){
        std::cout<<"channel number is "<<cvImage1.channels()<<std::endl;
        cvtColor(cvImage1, cvImage1, CV_RGBA2GRAY);
        cvtColor(cvImage2, cvImage2, CV_BGRA2GRAY);
        cvtColor(cvImage3, cvImage3, CV_RGBA2GRAY);
        cvtColor(cvImage4, cvImage4, CV_BGRA2GRAY);
    }
    
    
    resize(cvImage1, cvImage1, ddsize, 0, 0, cv::INTER_LINEAR);
    resize(cvImage2, cvImage2, ddsize, 0, 0, cv::INTER_LINEAR);
    resize(cvImage3, cvImage3, ddsize, 0, 0, cv::INTER_LINEAR);
    resize(cvImage4, cvImage4, ddsize, 0, 0, cv::INTER_LINEAR);
    threshold(cvImage1, cvImage1, 150, 255, cv::THRESH_BINARY_INV);
    threshold(cvImage2, cvImage2, 150, 255, cv::THRESH_BINARY_INV);
    threshold(cvImage3, cvImage3, 150, 255, cv::THRESH_BINARY_INV);
    threshold(cvImage4, cvImage4, 150, 255, cv::THRESH_BINARY_INV);
    
    res.push_back(cvImage1);
    res.push_back(cvImage2);
    res.push_back(cvImage3);
    res.push_back(cvImage4);
    
    return res;
}

// UIImage to cvMat
cv::Mat cvMatFromUIImage(UIImage *image)
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
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
    
    return cvMat;
}

std::vector<cv::Point3f> ReadPts3fFromTxt(std::string dataString)
{
    
    std::vector<double> m=SttoD(dataString);
    unsigned long data_sizee=m.size();
    data_sizee=data_sizee/3;
    std::cout<<"data size "<<m.size()<<std::endl;
    
    
    std::vector<cv::Point3f> res(data_sizee);
    for(int i=0;i<data_sizee;++i){
        res[i].x=m[i];
        res[i].y=m[i+data_sizee];
        res[i].z=m[i+data_sizee+data_sizee];
    }
    
    
    
    std::cout<<"size is "<<res.size()<<std::endl;
    return res;
}

std::vector<double> SttoD(std::string str){
    std::vector<double> vec;
    std::string temp;
    size_t i = 0, start = 0, end;
    
    do {
        end = str.find_first_of ( ' ', start );
        temp = str.substr( start, end );
        if ( isdigit ( temp[0] ) || temp[0]=='-')
        {
            vec.push_back (atof(temp.c_str())*30);
            ++i;
        }
        start = end + 1;
    } while ( start );
//    for ( i = 0; i < vec.size ( ); ++i )
//        std::cout << vec[i] << '\n';
    
    return vec;
}

@end

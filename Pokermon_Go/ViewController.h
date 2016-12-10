#import <UIKit/UIKit.h>
#import <opencv2/highgui/ios.h>

@interface ViewController : UIViewController<CvVideoCameraDelegate>
{
    CvVideoCamera *videoCamera; // OpenCV class for accessing the camera
}
// Declare internal property of videoCamera
@property (nonatomic, retain) CvVideoCamera *videoCamera;

@end


std::vector<cv::Mat> tmp_cards;
std::vector<cv::Mat> monster_card;
int card_id=0;
cv::Mat intrinsics;
cv::Mat distCoeffs;
std::vector<std::vector<cv::Point3f>> objPtsSet;





//
//  PISAnnotation.h
//  Pollution Index Scraper
//
//  Created by Ahmed Belal on 10/02/2015.
//  Copyright (c) 2015 Seena Studios. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
@interface PISAnnotation : NSObject <MKAnnotation>

@property (nonatomic) CLLocationCoordinate2D coordinate;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;



@end

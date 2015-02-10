//
//  ViewController.m
//  Pollution Index Scraper
//
//  Created by Ahmed Belal on 10/02/2015.
//  Copyright (c) 2015 Seena Studios. All rights reserved.
//

#import "ViewController.h"
#import "PISAnnotation.h"


#import "AFNetworking.h"
#import "HTMLParser.h"
#import <CoreLocation/CoreLocation.h>

@interface ViewController ()
{
    IBOutlet MKMapView *map;
    NSMutableArray *markers;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
    //This will hold our pollution index data temporarily
    markers = [NSMutableArray new];
    
    CLGeocoder *countryGeocoder = [[CLGeocoder alloc] init];
    [countryGeocoder geocodeAddressString:@"Malysia" completionHandler:^(NSArray *placemarks, NSError *error) {
        //We are pretty sure the Geocoder can find Malysia, so no error checking here for the moment.
        //In a proper project, error checking will be included in any case, to make sure network/internet
        //related problems don't make the program respond erroneously
        CLPlacemark *malaysia = [placemarks objectAtIndex:0];
        
        //Center map on Malaysia
        [map setCenterCoordinate:[[malaysia location] coordinate]];
        [self fetchPage];
    }];
    
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - AFNetworking stuff
- (void) fetchPage
{
    //Let's start up building the request
    AFHTTPRequestOperation *pageFetchOperation = [[AFHTTPRequestOperation alloc] initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://apims.doe.gov.my/apims/hourly2.php"]]];
    
    //Need to setup callback blocks for success and failure of request
    [pageFetchOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        //Convert response into a string
        NSString *pageContents = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        
        NSError *error = nil;
        
        //Parse string into a DOM object
        HTMLParser *htmlParser = [[HTMLParser alloc] initWithString:pageContents error:&error];
        
        //Block if error encountered
        if (error)
        {
            NSLog(@"%@", error.description);
        }
        
        //Happy path
        else
        {
            
            //Get body element from DOM
            HTMLNode *htmlBody = [htmlParser body];
            
            //Get the pollution index table element from body
            HTMLNode *table = [htmlBody findChildOfClass:@"table1"];
            
            //Extract all rows
            NSArray *rows = [table findChildTags:@"tr"];
            
            
            //Iterate on rows, skip header (index 0)
            for (int rowIndex = 1; rowIndex < [rows count]; rowIndex++)
            {
                //Each row represents a marker, so create a dictionary
                //for each marker
                //NOTE: Need to keep it mutable as data is entered on iterations, not only at
                //initialization time
                NSMutableDictionary *marker = [NSMutableDictionary new];
                
                
                //Extract all cells
                NSArray *cells = [(HTMLNode *)[rows objectAtIndex:rowIndex] findChildTags:@"td"];
                
                for (int cellIndex = 0; cellIndex < [cells count]; cellIndex++)
                {
                    //Grab the cell
                    HTMLNode *cell = (HTMLNode *)[cells objectAtIndex:cellIndex];
                    
                    
                    if (cellIndex == 0) //First cell is state
                    {
                        [marker setObject:[cell contents] forKey:@"state"];
                    }
                    else if (cellIndex == 1) //Second cell is area
                    {
                        [marker setObject:[cell contents] forKey:@"area"];
                        
                        CLGeocoder *forwardGeocoder = [[CLGeocoder alloc] init];
                        
                        //We will try to forward geocode the location name with formate <area>, <state>
                        //to get a location (coordinate) so we can add it to the map
                        [forwardGeocoder
                         geocodeAddressString:[NSString stringWithFormat:@"%@, %@",
                                               [marker objectForKey:@"area"],
                                               [marker objectForKey:@"state"]]
                         completionHandler:^(NSArray *placemarks, NSError *error) {
                            if (error == nil && [placemarks count] > 0)
                            {
                                //We are grabbing only the first marker for now
                                CLPlacemark *placemark = [placemarks objectAtIndex:0];
                                
                                //We will include only the markers that are inside Malaysia
                                if ([[placemark country] isEqualToString:@"Malaysia"] == YES)
                                {
                                    
                                    //Create an annotation for this place
                                    PISAnnotation *annotation = [[PISAnnotation alloc] init];
                                    
                                    //Set up the area
                                    [annotation setTitle:[marker objectForKey:@"area"]];
                                    
                                    //Grab the pollution index
                                    [annotation setSubtitle:[marker objectForKey:@"pollutionIndex"]];
                                    
                                    //If we didn't have a viable value, fill with '#' as on the web
                                    if ([annotation subtitle] == nil)
                                        [annotation setSubtitle:@"#"];
                                    
                                    //Set the coordinate
                                    [annotation setCoordinate:[[placemark location] coordinate]];
                                    
                                    //Add the annotation to the map
                                    [map addAnnotation:annotation];
                                }
                            }
                            else
                            {
                                NSLog(@"Could not locate %@, %@", [marker objectForKey:@"area"], [marker objectForKey:@"state"]);
                            }
                        }];
                        
                    }
                    else
                    {
                        //Pollution index is inside a <b></b> tag rather than plain text
                        HTMLNode *pollutionIndex = [cell findChildTag:@"b"];
                        
                        //Make sure you only overwrite with a viable pollution index
                        if ([[pollutionIndex contents] isEqualToString:@"#"] == NO)
                        {
                            [marker setObject:[pollutionIndex contents] forKey:@"pollutionIndex"];
                        }
                    }
                }
                
                
            }
        }
        
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"%@", error.description);
    }];
    
    [pageFetchOperation start];
}

#pragma mark - MKMapViewDelegate
- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[PISAnnotation class]] == YES)
    {
        MKPinAnnotationView *pin = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"pin"];
        if (pin == nil)
            pin = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"pin"];
        
        
        [pin setAnnotation:annotation];
        
        NSInteger pollutionIndex = [[annotation subtitle] integerValue];
        
        
        
        if ([[annotation subtitle] isEqualToString:@"#"] == YES)
            [pin setPinColor:MKPinAnnotationColorPurple];
        else if (pollutionIndex <= 50)
            [pin setPinColor:MKPinAnnotationColorGreen];
        else
            [pin setPinColor:MKPinAnnotationColorRed];
        
        [pin setCanShowCallout:YES];
        
        return pin;
    }
    else
        return nil;
}
@end

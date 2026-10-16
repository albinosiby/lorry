// Alternate source labels use the same reviewed UI meaning. These aliases are
// presentation-only: no stored enum, request payload or user text is rewritten.
const aliasRows = r'''
Fuel (Diesel)|fuel|diesel
Toll / Fastag|toll|fastag
Driver Allowance / Bata|allowance|bata
Freight Income|freight_income
Pending|submitted
Verified|approved
Declined|rejected
Select an open shipment|Match with open load
Gender|Gender:
Accepted|Booking accepted
Requested|Booking requested
Declined|Booking declined
In transit|Booking in transit
Items collected|Booking item collected
Delivery reported|Booking delivery reported
Delivery confirmed|Booking delivery confirmed
Report delivery issue|Booking delivery issue
Payment recorded|Booking payment recorded
Unloaded|Booking stop unloaded
Confirm the goods have been picked up. The customer will be notified.|Confirm you have picked up the goods. Your customer will be notified.
Confirm all goods have been unloaded. The customer will be asked to confirm receipt. Record any payment separately.|Confirm all goods have been unloaded. Payment collection is a separate action in Booking details.
When the truck is ready, start the trip and share your live location.|Your GPS location is ready. Starting the trip will share the first truck position with your customer.|Your GPS position is ready. Starting the trip will broadcast the first truck waypoint to your customer.|The driver can now start and share live location.|You will be assigned to this customer load and can start the trip when ready.
Trip started and your first location was shared.|Trip started! Navigation and delivery reporting are ready below.
The driver has started the trip. You can see the latest shared location.|The truck is on the road. You can follow its latest shared location.|Follow the trip progress and delivery updates.|Track active shipments from initial pickup to destination delivery.|Live location is shared while the driver keeps location access enabled.
Go to the pickup point, then confirm Item collected before starting the trip.|The driver will start the trip when the truck leaves pickup.
Trip has not started. Pickup and destination are shown on the map.|TRIP NOT STARTED · PICKUP LOCATION
Location sharing ended. This is the last shared trip point.|TRIP FINISHED · LAST SHARED LOCATION
No recent update. Showing the last shared point; the driver may be offline.|LOCATION UPDATE OVERDUE
We will update you when the customer responds.|Your bids have been submitted. Track customer responses.
Profile photo uploaded. Save your profile to apply it.|Profile photo updated. Tap "Save changes" below to apply it.
Please upload your Aadhaar card to continue.|Please upload your Aadhaar card image to continue.|Upload your Aadhaar card image to verify your customer account.|Government issued Aadhaar identification card|Front side or full image of Aadhaar
Driver identity documents|Aadhaar card and Driving Licence are mandatory to start driving sessions.|Upload your Aadhaar card and driving licence from your profile.|You selected: Get load for your truck. Fill in your driver address and upload your mandatory session documents.
Complete Profile|You selected: Get a truck for your load. Fill in your contact details and upload your Aadhaar image.
Upload and view your personal identity documents.|Upload your licence and truck papers privately. The verification team reviews each submission.
Truck Documents|Start with your driving licence, then add the RC, insurance, permit and fitness certificate for each truck.
Choose from gallery|Add a photo from your camera, pick an image from gallery, or select a PDF document file.
Add Truck|Add this truck before uploading its document.
Body dimensions and capacity|Enter vehicle registration and cargo specifications for automated load matching.|Payload capacity, body dimensions, and vehicle specs are needed before shippers can match loads with your truck.
Primary truck|PRIMARY VEHICLE|★ PRIMARY|★ PRIMARY TRUCK|This vehicle will be selected first for posting your driver availability.
Truck is busy|On assigned trip—not visible to customers. Post availability with your new location after delivery.
Pickup and destination cannot be the same place.|Destination must be different from pickup.
Freight budget offer (₹) *|Keep pickup route, weight, and freight offers accurate for drivers.
Post Load|Your load will be visible to verified transport operators immediately upon publishing.|Post parcels & cargo loads, discover nearby verified trucks, book instantly, and track shipments in real-time.
Find Loads|SPOT FREIGHT MARKETPLACE|Direct shipper contracts, high-paying return loads & instant spot matches.
Filters|Specify your target pickup hub, return destination, or vehicle capacity.
Loads Near Your Location|Available freight • Turn on GPS above to sort loads closest to you
Current location|Live status updates • Pull to refresh
Reason|Tell the other party why
Driving licence|Valid commercial or transport driving licence
Verified|Verified Customer|Verified Customer Account|Verified Driver|Verified Driver Account
Truck|COMMERCIAL TRUCK
View Details|DISPATCH COMMAND
Your truck capacity (tonnes)|Gross Capacity
Some details are invalid. Check the form and try again.|Could not remove the server push registration.|Could not save push registration.|Push registration failed; it will retry when the app resumes.
Post Load|Post New Load|Post a Load|Post a Load to Fleets|Post another load|Post any cargo or parcel load|Publish a load to connect with available truck owners.|Publish freight for another driver to transport.|Broadcast your cargo to verified fleet operators across India for quick quotes and prompt truck assignment.|Post a freight listing to connect with verified fleet operators.|Your first load starts here|Get a truck for your load|Getting trucks for your load
Find Loads|Browse Available Loads|Explore Loads|Available Freight Loads|Discover open loads along your route|Get load for your truck|Getting load for your truck|Browse available freight loads and send your booking requests to start your next journey.|Browse high-paying freight loads on your routes, accept bookings, navigate directly, and track daily earnings.
My Loads|My shipments & bookings|Your shipments|Your Active Shipments|Your Open Loads|Every listing, every request, in one place.|Manage your listings, driver requests and deliveries.|Track your posted freight and active truck assignments.
Find Trucks|Find available trucks|Find verified trucks near you|Instant Truck Discovery|Trucks Available Near Me|Connect directly with verified transport operators who have posted availability near your pickup.|Search nearby verified fleet ready for immediate dispatch.
My Trips|Your Journeys & Loads|Journey|All Trips
Profile|Primary role|PROFILE SETUP
Driver|FLEET DRIVER|DRIVER SIGN UP|Transporter / Driver|Transporter / Driver Account|Driver booking
Customer|Customer / Shipper|Customer / Shipper Account|Commercial Cargo Shipper|CUSTOMER SIGN UP|Customer load
Save changes|Change
Complete Profile|Complete Customer Profile|Complete Driver Profile|Complete Profile & Go to Home|Complete Profile & Start Driving
Full name|Your name
Phone number|Mobile number
Address|Driver address|Pickup / Business address|Your business or pickup address|Your residential or operating base address|Your warehouse, factory, office or pickup address
Personal Information|Name, phone, address, company
Create account|New to LORRY LINK? Create account|A fresh start.|Create your account to connect with verified trucks and ship easily.|Create your account to find high-paying freight and start hauling.
Sign in|I already have an account|Already registered? Sign in|Already have an account?|Sign in and pick up where you left off.
Forgot password?|Forgot your password?
Send reset link|We’ll send a link to help you get back in.
New password|Choose a new password for your account.
Get started|Your journey starts here|What brings you to LORRY LINK?|Select how you want to use the platform. We will customize your experience accordingly.
Profile saved.|Profile setup completed successfully!
Terms & Conditions|Agree to Terms & Conditions|Booking, location and verification terms.|Please read these terms before using your customer or driver account.
Support|Account help|We are here to help|Get help with a booking or active trip.
Load details|View Load|Manage this load|LOAD LISTING|Active Freight Cargo
Booking details|Trip Details|Your booking|View your booking|View assigned booking|Review the latest booking details.|Open your booking for trip status, contact and next steps.|Booking timeline
Load requirements|Cargo & Fleet|Compatible vehicle|Capacity, length and verification information.
Vehicle Body Type|Truck Body / Type|Truck Body Type|Body Build|BODY TYPE|REQUIRED VEHICLE TYPE|DISPATCH TYPE
Vehicle deck length|Vehicle Deck Length|TRUCK LENGTH|Cargo Length
Length|TRUCK LENGTH
Any length|Any Return Corridor|Open to any destination corridor|Open to any destination corridor
Destination|FINAL DESTINATION|FINAL DROP|DROP|Drop-off Destination|PREFERRED CORRIDOR|Route Corridor|Destination / Drop City (e.g. Delhi, Chennai)
Pickup|PICKUP ORIGIN|Origin / Pickup City (e.g. Pune, Bhiwandi)
Pin on map|Tap "Pin on map" to confirm location coordinates.|Exact location pins are saved with this load.
Schedule & Pricing|Schedule & Bid|Pickup & payment|Schedule pickup timing and provide your freight budget.
Route & unloading plan|Set Route & Specifications|Specify where goods are picked up and where they are delivered.
Cargo & Vehicle|Specify what materials are carried and the required truck body.
Freight budget offer (₹) *|FREIGHT OFFER|Enter your freight budget amount (Mandatory)
Negotiable|Price is negotiable|Price on discussion|Transporters and drivers can submit counter-offers|Real-time rates
Fixed|Fixed dispatch|Fixed budget offer — no counter-negotiations accepted
Special note|NOTES & DETAILS (OPTIONAL)|SPECIAL INSTRUCTIONS|Instructions & contact|4. FREIGHT PREFERENCES & REMARKS
Pickup time|Tap for fixed time
Select Date|Tap to pick date
Edit listing|Edit Shipment|EDIT SHIPMENT POSTING|Update Your Cargo Load
Manage my trucks|Manage My Trucks|My Fleet & Trucks|Your Verified Fleet|FLEET COMMAND|FLEET COMMAND|Keep your truck ready for every route
Add Truck|Add Vehicle|Add Your First Truck|Register New Truck|Save & Register Truck|Register a Truck to Start Broadcasting|Add your first vehicle with registration number and tonnage capacity to receive load match alerts.|Add your trucks with RC & dimensions to match loads and boost trip earnings.
Edit Truck Details|Edit truck specs|Update Truck Specs
Truck Documents|Driver & vehicle documents|RC & Compliance Vault|Compliance|Tap truck for RC & Vault|All 4 vehicle documents uploaded and active for verified load allocation.
Identity verification|Verify your identity|Keep your identity ready for verification|BUILD TRUST BEFORE BOOKING
Identity document type|Document type|Identity document|Verification Document
Upload document|Upload selected ID|Upload certified digital document|Choose file and submit
Upload|Add more
Uploading…|Uploading document…|Sending to secure vault…
Take a photo|Take photo with camera
Choose from gallery|Choose from gallery or files
Attached|File attached
Driver identity documents|Driver documents|Required Driver Documents|Aadhaar & driving licence
Post truck availability|Broadcast Truck|Broadcast Truck Availability|Broadcast Truck Now|Start Live Broadcast|Truck Availability Radar|Route Availability Radar|FREIGHT BROADCAST RADAR|Tell customers where your truck is ready to move.|Broadcast empty vehicles to shippers along your return corridor. Avoid empty running and secure instant spot loads.|Broadcast where your truck is currently stationed. Shippers in your corridor can immediately invite you to spot loads.|Make vehicle discoverable to spot shippers
Current location|2. CURRENT STATION & GPS LOCATION
Select truck for this load|1. SELECT TRUCK FROM FLEET|Choose the truck this document belongs to.
Destination city or corridor|3. PREFERRED HEADING / CORRIDOR (OPTIONAL)
Available Trucks|All Trucks|Active Trucks|All Vehicles|LIVE FLEET RADAR
Available|Ready|READY TO DISPATCH|Immediate dispatch ready|Fleet Ready|Available after 3 PM
Active|Live Only|Live Broadcasts|LIVE BROADCAST|Active bookings
Accepted|READY / ACCEPTED|Driver is ready|Ready to start the trip
In transit|IN TRANSIT 🚚|ACTIVE CONSIGNMENT IN TRANSIT|LIVE SHIPMENT IN TRANSIT|Live In-Transit Shipment|CURRENT ONGOING TRIP|Shipment in transit|Shipment is on the road|Trip in progress
Completed|COMPLETED 🏁|This shipment has been successfully closed.
Closed|CLOSED / EXPIRED
Pending|MATCH STATUS|Pending Approvals|REQUEST PENDING
Booking Requests|CARRIER REQUESTS|Incoming Requests|View All Incoming Booking Requests|View booking requests
Review Requests|Review driver request|Connect with verified carriers who requested your freight loads.|Drivers have requested to transport your freight. Review bids.|Review this request and choose a driver for your shipment.|Review driver requests or update this open listing.|Choose whether to assign this load.
Request booking|Request this load?|Ready to carry this load?
Request again|Request this load again?
Request sent|Booking requested.|Booking request resubmitted.
Declined|Request declined
Accept booking|Accept this driver?
Accept truck invitation|Accept this invitation?|Accept this invitation to take the customer’s load.
Invite for this Load|Invite for a Load|Customer invitation
Item collected|Items collected?
Items collected|Items collected. Your customer has been notified.
Start trip|Start trip and share location?
Report delivery|Report delivery?
Confirm delivery|Confirm delivery?|Confirm delivery in booking details|View delivery details
Unloaded|Stop unloaded|Confirm unloading?
Call|Call contact
Track Live GPS|Track|Track truck location|Track Load Location|Live 24/7 GPS load tracking
View directions|View Directions|Navigate delivery route|Navigate this route section?|Open Google Maps|Turn-by-turn Google Maps navigation
View Details|View|Next step
Driver Essentials|Highway roadside services & amenities|Driver tools|Highway roadside services & amenities
Services|Shipper tools
Fuel pump|Fuel Only
Toll / Fastag|Tolls Only|Toll & Fastag|Highway Toll / Fastag
Enable GPS|Acquire GPS|Enable|LOCATION REQUIRED|Live GPS Coordinate Required|Turn on GPS to find essentials|Turn on GPS, then return to discover highway essentials.|GPS is disabled. Turn it on for nearby matching.|GPS signal not available. Please ensure location service is turned on.|Turn on GPS/location services, then start the trip again.|Turn on location when you start the journey.|Please tap "Acquire GPS" to link your live coordinates before broadcasting.
Open Phone Location Settings|Enable location permission in phone settings.|Location blocked. Enable in phone settings.|Location access is blocked. Enable it for LORRY LINK in your phone settings, then try again.
Allow location access|Allow location access to find roadside assistance.|Allow location access to start the trip and share the truck position.|Turn on location permission to share your trip position.|Location permission required for driver tools.|Turn on GPS and allow location access to find trucks near you.|We could not access your location. Turn on GPS and allow location access, then try again.
Location off|Location Services Offline|Location telemetry currently offline.|LOCATION OFF · LAST KNOWN POINT
Waiting for driver location|WAITING FOR DRIVER LOCATION|Waiting for the first live GPS broadcast from driver...
GPS updates every 2 minutes during the active trip.|GPS UPDATES EVERY 2 MIN|LORRY LINK shares your trip location every 2 minutes.
Live GPS|LIVE GPS ACTIVE|GPS Location Active|GPS Network|GPS Position Verified|GPS Sorted|Live trip location updated.|Share trip location|Trip location sharing active
Locating your truck…|Pinpointing your truck position…
Finding nearby services…|Use your current location to discover roadside stops along your route.
Highway SOS|Highway Emergency Helplines (Toll-Free)
Finance tracker|Fleet & Trip Finance Tracker|Freight payment & finance tracker|Keep your trip revenue and costs accurate|Record freight earnings, diesel receipts, toll debits, and trip expenses to keep your transport accounts organized.|Record freight income, fuel, toll and maintenance.
Income|INCOME|Other Income
Expenses|EXPENSE|Fleet Expense|Trip Expenses|Other Cost
Freight Income|Record Freight Revenue|Freight Pay|Direct Payout
Fuel (Diesel)|Diesel / Fuel
Maintenance|Vehicle Maintenance
Driver Allowance / Bata|Driver Bata
Record payment collected|SETTLEMENT|Freight Settlement|Truck, delivery & payment
Add Entry|Add Entry Now|Add Finance Entry|Record Fleet Expense
Amount in ₹|AMOUNT IN RUPEES (INR)
Your updates|Stay in the loop|Booking update|Booking updated.|Booking and shipment updates|Booking decisions and shipment progress, all together.|Booking updates are shared with both parties here.|New requests, decisions, and trip updates will appear here.|Recent load postings and incoming vehicle offers
Notifications|LORRY LINK update|LORRY LINK updates
Filters|Filter Route|Route & Truck Filters|Filter Available Trucks|SEARCH RADIUS|Radar Range|SORT RESULTS BY
Apply Filters|Apply Route Filters
Reset All Filters|Reset all|Reset search filters|Reset All Filters & Show All|Clear all|Clear filters
Search by driver, truck number, or city...|Filter trucks near your GPS location
Nearest distance|Closest first · Approximate straight-line distances|Prioritized by proximity to your current truck position
Your truck capacity (tonnes)|MINIMUM PAYLOAD CAPACITY|Gross Capacity
All|All open loads (no filter)|Across all regions|Pan India|MARKET COVERAGE|Showing trucks across all regions.|Click to show all regions
Refresh|Refresh Broadcasts|Refresh Ledger|Refresh nearby essentials|Refresh position|Refresh trucks
Try again|Retry
Load more|Load More Freight Loads|Load More Trips
No loads found right now|No matching loads on this route|No shipments posted yet
No trucks match your criteria|No trucks online|No broadcasts match this filter|No Active Availability Broadcasts
No trucks registered yet|No trucks registered yet
No documents submitted|Cargo details pending|Customer details pending|Contact details pending|Destination pending|Pickup location pending|Truck details not recorded for this booking
No further action is needed for this booking.|No further action is available for this booking.|This booking is no longer active.|This request was not assigned.
Waiting for customer delivery confirmation.|Delivery is reported. Waiting for the customer to confirm receipt.|Delivery reported. Awaiting customer confirmation. Record payment in Booking details.|Delivery reported. Awaiting customer confirmation. Record payment separately.|The driver has reported delivery. Confirm after receiving the goods.|The driver reported delivery. Open the booking to confirm receipt.
This field is required.|Mobile number is required.|Phone number is required.|Pickup location name is mandatory.|Destination location name is mandatory.|Payload weight is mandatory.|Payload weight is mandatory. Please enter a valid weight.|Freight budget amount is mandatory.|Freight budget is mandatory. Please enter a valid amount.|Cargo description is mandatory (at least 3 characters).|Please enter your driver address.|Please enter your pickup or delivery address.
Enter a valid 10-digit Indian mobile number.|Please enter a valid 10-digit Indian mobile number.
Enter a valid amount.|Enter a valid collection amount.|Enter a valid freight budget amount greater than ₹0.|Enter the agreed total freight.|Enter your freight budget amount (Mandatory)
Enter a positive weight.|Enter a valid weight in tonnes.
Choose a pickup date.|Please select a pickup date.
Choose a truck length|Choose a truck length
Vehicle Body Type|Please select a required vehicle type.
Enter at least 2 characters.|Enter at least two characters to search.|Enter a pickup or destination place.
Cannot exceed total load weight.|The combined unloading weight cannot exceed the total load weight.
Enter a length greater than 0 and up to 80 ft (max. 2 decimals)|Greater than 0, up to 80 ft; max. 2 decimal places
Pin on map|Please pin the pickup location on the map.|Please pin the destination location on the map.
Some details are invalid. Check the form and try again.|Authentication could not be completed. Check your details and try again.
Please sign in again to use this service.|Please sign in to upload a document.|Please sign in to upload a photo.
Unable to connect. Check your connection and try again.|This service is temporarily unavailable. Please try again.|Could not load this category.|Could not load your trucks. Please try again.|Could not load your trucks. Try again.|Unable to load truck details
Could not open the selected application.|Could not open Google Maps.|Could not open Google Maps. Please try again.|Could not open the phone dialler.|Could not open your phone app. You can copy the number instead.
Document upload failed. Please try again.|Document upload could not be processed.|Upload Failed|Failed to upload photo. Please try again.|There was a problem uploading your document to the server:
This document is no longer available. Please upload it again.|This uploaded document is not available. Please upload it again.|Unable to display image preview.|Unable to load this document image.|Unable to load this document image. Please try again.|Unable to open this PDF document.
Please upload a clearer document.|Please upload a clearer replacement.|The selected image is empty. Please capture it again.
Saved—refresh pending. Do not submit again; refresh to see the latest status.|Saved—refresh pending. Refresh this booking before taking another action.|This action was already submitted. Refresh to see the latest status.
Could not save your language. Please try again.|Could not save language. Please try again.
This page is unavailable|Page unavailable|The link may be incomplete or no longer available.
Load unavailable|This load is no longer available for new requests.|This request was cancelled and the load is no longer open.
Choose language|Choose language / भाषा / ഭാഷ
''';

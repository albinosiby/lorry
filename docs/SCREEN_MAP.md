# Screen, model and repository map

Each data-driven screen renders Cubit state. Screens do not call Supabase directly. Closely related screens share feature repositories and entity models so business rules remain consistent. Static Welcome UI uses session routing and has no artificial data repository.

| Screen | Screen/input model | State owner | Repository |
| --- | --- | --- | --- |
| Splash / Welcome | SessionModel | SessionCubit | IAuthRepository |
| Sign In | SignInModel, ResourceState<bool> | AuthFormCubit | IAuthRepository |
| Create Account | SignUpModel, ResourceState<bool> | AuthFormCubit | IAuthRepository |
| Forgot / Reset Password | PasswordResetModel, ResourceState<bool> | AuthFormCubit | IAuthRepository |
| Profile / Complete Setup | ProfileScreenModel, ProfileModel | ProfileCubit | IProfileRepository, IAuthRepository |
| Notifications / Updates | NotificationsScreenModel, NotificationModel | NotificationsCubit | INotificationRepository |
| Home | HomeModel | HomeCubit | IHomeRepository |
| Post / Edit Load | LoadFormModel, LoadDraft | LoadFormCubit | ILoadRepository |
| Find Loads | LoadsScreenModel, LoadFilter, LoadModel | LoadsCubit | ILoadRepository |
| Load Details | LoadDetailsModel | LoadDetailsCubit | ILoadRepository, IBookingRepository |
| My Loads / Requests | LoadsScreenModel, TripsScreenModel | LoadsCubit, TripsCubit | ILoadRepository, IBookingRepository |
| My Trips | TripsScreenModel, BookingModel | TripsCubit | IBookingRepository |
| Booking Details | BookingDetailsModel, BookingModel, BookingEvent | BookingDetailsCubit | IBookingRepository |

All repository contracts are in `lib/modules/<feature>/repositories/*_interface.dart`. Supabase implementations sit beside them. Infrastructure lives in `lib/utils/services/`. `lib/di/injection.dart` binds contracts to implementations and registers feature Cubits as factories.

## Commands

| Feature | Backend commands |
| --- | --- |
| Profile | profile.get, profile.save |
| Home | home.get |
| Loads | loads.list, loads.get, loads.create, loads.edit, loads.cancel |
| Bookings | bookings.request, bookings.list, bookings.get, bookings.transition |
| Notifications | notifications.list, notifications.read |
| Authentication | Supabase Auth SDK: signInWithPassword, signUp, resetPasswordForEmail, updateUser, signOut; Google OAuth behind configuration |

Input validation runs in forms for usability and again in database constraints/commands for correctness. One immutable ResourceState carries loading, busy, data, errors and notices. Generation checks discard stale requests, and actions prevent duplicate submissions.

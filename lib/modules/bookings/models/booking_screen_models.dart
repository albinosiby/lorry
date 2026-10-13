import 'booking_model.dart';

class TripsScreenModel {
  const TripsScreenModel(this.bookings, this.hasMore);
  final List<BookingModel> bookings;
  final bool hasMore;
}

class BookingDetailsModel {
  const BookingDetailsModel(this.booking);
  final BookingModel booking;
}

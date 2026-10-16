/// Shared operational terms for authentication and Profile.
/// App-owner/legal review is required before public distribution. This is not
/// a substitute for a complete privacy notice or a server-side consent record.
abstract final class TermsContent {
  static const sections = <({String title, String text})>[
    (
      title: '1. Using LORRY LINK',
      text:
          'LORRY LINK helps load owners and drivers find each other and coordinate transport. '
          'A driver may also post a load for another driver to carry. Confirm the route, cargo, '
          'truck suitability, freight amount and timing with the other party before accepting a booking.',
    ),
    (
      title: '2. Your account and documents',
      text:
          'Provide accurate contact, identity and vehicle information and keep it up to date. '
          'Upload only documents you are entitled to use. Keep your login details secure and '
          'do not impersonate another person or misuse another account.',
    ),
    (
      title: '3. Cargo and vehicle information',
      text:
          'Load owners must describe goods, weight, handling needs, pickup, destination and '
          'intermediate unloading stops accurately. Drivers must check truck capacity, dimensions '
          'and required vehicle documents. Do not arrange unlawful cargo or unsafe or overloaded transport.',
    ),
    (
      title: '4. Requests and booking confirmation',
      text:
          'A request alone does not confirm a trip. Assignment occurs after the load owner accepts '
          'a driver request or the invited driver accepts an invitation. Check the booking status '
          'and resolve any change in route, price or timing with the other party before collection.',
    ),
    (
      title: '5. Collection, unloading and delivery',
      text:
          'Mark items collected and start the trip only when those events occur. Confirm each '
          'intermediate stop as Unloaded after the goods for that stop have been unloaded. '
          'The driver reports final delivery; the load owner confirms receipt or reports an issue. '
          'Do not mark events completed before they happen.',
    ),
    (
      title: '6. Freight, expenses and payment records',
      text:
          'Agree the freight and payment arrangements directly with the other party. Record only '
          'amounts actually collected. Finance entries and payment balances are records, not proof '
          'that the app transferred money. Keep your own receipts and resolve payment differences '
          'with the other party before treating the balance as settled.',
    ),
    (
      title: '7. Cancellations and disputes',
      text:
          'If you cannot fulfil a booking, notify the other party promptly and use the available '
          'cancellation flow with an accurate reason. Do not abandon an active shipment. '
          'Discuss delays, damage, missing goods or payment issues with the other party and use '
          'in-app support to report unresolved problems.',
    ),
    (
      title: '8. Location and navigation',
      text:
          'Location permission enables nearby search and trip tracking. Trip participants can see '
          'the latest shared driver location; it may be delayed or unavailable when GPS or the '
          'network is off. Location sharing begins with collection and trip activity. External '
          'navigation does not confirm unloading, and ordinary driving directions do not guarantee '
          'truck clearance or legal access. Drivers must follow road restrictions and drive safely.',
    ),
    (
      title: '9. Account data and respectful contact',
      text:
          'The app uses account details, uploaded documents, booking records and permitted location '
          'data to provide its services. Contact information is available in the load and booking '
          'workflow for coordination. Do not use it for harassment, spam or unrelated purposes. '
          'Identity documents are not public load listings. Contact support for account or data concerns.',
    ),
    (
      title: '10. Notifications and service availability',
      text:
          'Booking and shipment events may generate in-app and Android notifications. Delivery '
          'depends on permission, connectivity and device settings; do not rely on an alert alone '
          'for an urgent update. Review booking details and contact the other party when needed. '
          'For an emergency, contact local emergency services first.',
    ),
  ];
}

# Truck capacity and custom lengths

A truck's capacity is a maximum, not an exact cargo weight. A 4-tonne truck
can request 1, 1.5, 2, 3 or 4-tonne loads if its deck is long enough.

With client approval, Mini truck, Pickup, LCV and Open truck are compatible
general-cargo classes. Container, Refrigerated and Trailer remain exact body
requirements. Marketplace filters, truck selection, booking assignment,
customer load-specific truck discovery and invitations share this rule.
Explicit customer truck-type search filters remain exact.

Truck add/edit and load post/edit offer preset feet and Custom length.
Custom values must be greater than zero and at most 80 ft, with up to two
decimal places. Existing non-preset lengths reopen without rounding.
Load required length is optional; a selected truck must meet or exceed it.
Find Loads capacity and deck filters are upper limits on cargo requirements.

Database migration: `20261016150303_compatible_general_cargo_and_custom_lengths.sql`.
Regression tests: `test/truck_compatibility_test.dart` and
`supabase/tests/truck_compatibility.sql` (run inside BEGIN/ROLLBACK).

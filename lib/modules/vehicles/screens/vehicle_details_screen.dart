import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import 'package:lorry_link/design_system/design_system.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../driver_documents/cubit/driver_documents_cubit.dart';
import '../../driver_documents/models/driver_document_model.dart';
import '../../driver_documents/models/driver_documents_screen_model.dart';
import '../cubit/vehicles_cubit.dart';
import '../models/vehicle_model.dart';
import 'vehicles_screen.dart';

class VehicleDetailsScreen extends StatelessWidget {
  const VehicleDetailsScreen({super.key, required this.vehicleId});

  final String vehicleId;

  static const _vehicleDocumentTypes = [
    DriverDocumentType.vehicleRegistration,
    DriverDocumentType.insurance,
    DriverDocumentType.permit,
    DriverDocumentType.fitnessCertificate,
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Truck details'),
      actions: [
        BlocBuilder<VehiclesCubit, ResourceState<List<VehicleModel>>>(
          builder: (context, vehicleState) {
            final truck = vehicleState.data
                ?.where((item) => item.id == vehicleId)
                .firstOrNull;
            if (truck == null) return const SizedBox.shrink();
            return TextButton.icon(
              onPressed: () => _editTruck(context, truck),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            );
          },
        ),
      ],
    ),
    body: PageBody(
      narrow: true,
      onRefresh: () async {
        await Future.wait([
          context.read<VehiclesCubit>().load(),
          context.read<DriverDocumentsCubit>().load(),
        ]);
      },
      child:
          BlocListener<
            DriverDocumentsCubit,
            ResourceState<DriverDocumentsScreenModel>
          >(
            listener: (context, state) {
              if (state.error != null) {
                debugPrint(
                  '[TRUCK_DETAILS] DriverDocuments error: ${state.error}',
                );
                showNotice(context, state.error!);
              }
              if (state.notice != null) {
                debugPrint(
                  '[TRUCK_DETAILS] DriverDocuments notice: ${state.notice}',
                );
                showNotice(context, state.notice!);
              }
            },
            child: BlocBuilder<VehiclesCubit, ResourceState<List<VehicleModel>>>(
              builder: (context, vehicleState) =>
                  BlocBuilder<
                    DriverDocumentsCubit,
                    ResourceState<DriverDocumentsScreenModel>
                  >(
                    builder: (context, documentState) {
                      if (vehicleState.loading || documentState.loading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (vehicleState.error != null ||
                          documentState.error != null) {
                        return AppEmptyState(
                          'Unable to load truck details',
                          vehicleState.error ?? documentState.error!,
                          icon: Icons.error_outline,
                          action: OutlinedButton(
                            onPressed: () async {
                              await Future.wait([
                                context.read<VehiclesCubit>().load(),
                                context.read<DriverDocumentsCubit>().load(),
                              ]);
                            },
                            child: const Text('Try again'),
                          ),
                        );
                      }
                      final truck = vehicleState.data
                          ?.where((item) => item.id == vehicleId)
                          .firstOrNull;
                      if (truck == null) {
                        return const AppEmptyState(
                          'Truck unavailable',
                          'This truck may have been removed. Return to My trucks and refresh the list.',
                          icon: Icons.local_shipping_outlined,
                        );
                      }
                      final documents =
                          documentState.data?.documents ?? const [];
                      return _TruckContent(truck: truck, documents: documents);
                    },
                  ),
            ),
          ),
    ),
  );

  static Future<void> _editTruck(
    BuildContext context,
    VehicleModel truck,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<VehiclesCubit>(),
        child: VehicleForm(truck: truck),
      ),
    );
    if (saved == true && context.mounted) {
      await context.read<VehiclesCubit>().load();
    }
  }
}

enum _TruckDocumentSource { camera, gallery, file }

// ─── Truck Content ───────────────────────────────────────────────────────────

class _TruckContent extends StatelessWidget {
  const _TruckContent({required this.truck, required this.documents});

  final VehicleModel truck;
  final List<DriverDocumentModel> documents;

  @override
  Widget build(BuildContext context) {
    final truckDocuments = documents
        .where((document) => document.vehicleId == truck.id)
        .toList();

    final uploadedTypesCount = VehicleDetailsScreen._vehicleDocumentTypes
        .where((t) => truckDocuments.any((doc) => doc.type == t))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Truck Hero Header Card
        _buildTruckHero(context),
        const SizedBox(height: 18),

        // 2. Specifications Dashboard Grid
        _buildSpecGrid(context, uploadedTypesCount),
        const SizedBox(height: 18),

        // 3. Compliance Progress Banner
        _buildComplianceBanner(context, uploadedTypesCount),
        const SizedBox(height: 24),

        // 4. Documents Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Truck Documents',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Upload both sides or extra pages as needed.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:
                    (uploadedTypesCount == 4
                            ? const Color(0xFF2E7D32)
                            : AppTheme.orange)
                        .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$uploadedTypesCount / 4 VERIFIED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: uploadedTypesCount == 4
                      ? const Color(0xFF2E7D32)
                      : AppTheme.orange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 5. Document Type Cards
        ...VehicleDetailsScreen._vehicleDocumentTypes.map(
          (type) => _DocumentGroup(
            type: type,
            documents: truckDocuments
                .where((item) => item.type == type)
                .toList(),
            truck: truck,
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  // ─── Hero Header ───────────────────────────────────────────────────────────

  Widget _buildTruckHero(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF13362D), const Color(0xFF1C463A)]
              : [const Color(0xFF193F35), const Color(0xFF2E6553)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF193F35).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Stack(
          children: [
            // Decorative background graphics
            Positioned(
              right: -20,
              bottom: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            Positioned(
              right: 18,
              bottom: 16,
              child: Icon(
                Icons.local_shipping_rounded,
                size: 96,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Subtitle chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFD5E9A9,
                          ).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFFD5E9A9,
                            ).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          'REGISTERED FLEET TRUCK',
                          style: const TextStyle(
                            color: Color(0xFFD5E9A9),
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (truck.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.orange.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.orange.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Text(
                            '★ PRIMARY TRUCK',
                            style: TextStyle(
                              color: Color(0xFFFFB899),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Indian Number Plate Representation
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF111111),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Left IND chip
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF0038A8),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'IND',
                              style: TextStyle(
                                color: Color(0xFF0038A8),
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        // Number
                        Text(
                          truck.registrationNumber.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Truck Subtitle
                  Text(
                    '${truck.vehicleType} • ${truck.bodyType}',
                    style: const TextStyle(
                      color: Color(0xFFE0EFE8),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Specs Grid ────────────────────────────────────────────────────────────

  Widget _buildSpecGrid(BuildContext context, int uploadedCount) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final specs = [
      (
        icon: Icons.straighten_rounded,
        label: 'Cargo Length',
        value: '${truck.lengthFt.toStringAsFixed(0)} ft',
        color: AppTheme.green,
      ),
      (
        icon: Icons.scale_rounded,
        label: 'Gross Capacity',
        value: '${truck.capacityTonnes.toStringAsFixed(1)} T',
        color: AppTheme.orange,
      ),
      (
        icon: Icons.view_in_ar_rounded,
        label: 'Body Build',
        value: truck.bodyType,
        color: const Color(0xFF1E88E5),
      ),
      (
        icon: Icons.verified_user_rounded,
        label: 'Compliance',
        value: '$uploadedCount/4 Docs',
        color: uploadedCount == 4
            ? const Color(0xFF2E7D32)
            : const Color(0xFFE65100),
      ),
    ];

    return Row(
      children: specs.map((spec) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF172821)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: spec.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(spec.icon, color: spec.color, size: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    spec.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spec.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Compliance Banner ─────────────────────────────────────────────────────

  Widget _buildComplianceBanner(BuildContext context, int count) {
    final ready = count == 4;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: ready
            ? (isDark ? const Color(0xFF163327) : const Color(0xFFE8F5E9))
            : (isDark ? const Color(0xFF332616) : const Color(0xFFFFF8E1)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ready
              ? const Color(0xFF2E7D32).withValues(alpha: 0.3)
              : const Color(0xFFF57F17).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ready ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: ready ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ready
                  ? 'All 4 vehicle documents uploaded and active for verified load allocation.'
                  : '$count of 4 documents uploaded. Add remaining papers to unlock instant customer booking.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Document Group ──────────────────────────────────────────────────────────

class _DocumentGroup extends StatefulWidget {
  const _DocumentGroup({
    required this.type,
    required this.documents,
    required this.truck,
  });

  final DriverDocumentType type;
  final List<DriverDocumentModel> documents;
  final VehicleModel truck;

  @override
  State<_DocumentGroup> createState() => _DocumentGroupState();
}

class _DocumentGroupState extends State<_DocumentGroup> {
  bool _isUploading = false;
  String? _uploadStatusText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasDocuments = widget.documents.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF172821) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasDocuments
              ? AppTheme.green.withValues(alpha: 0.25)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (hasDocuments ? AppTheme.green : AppTheme.orange)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  hasDocuments
                      ? Icons.verified_rounded
                      : Icons.upload_file_outlined,
                  color: hasDocuments ? AppTheme.green : AppTheme.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.type.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isUploading
                          ? (_uploadStatusText ?? 'Uploading document…')
                          : (hasDocuments
                                ? '${widget.documents.length} file${widget.documents.length == 1 ? '' : 's'} recorded'
                                : 'Missing — add document'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _isUploading
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _isUploading
                            ? AppTheme.green
                            : (hasDocuments
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isUploading)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.green.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Uploading…',
                        style: TextStyle(
                          color: AppTheme.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                )
              else
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _chooseAndUpload(context),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                  label: Text(hasDocuments ? 'Add more' : 'Upload'),
                ),
            ],
          ),

          // Uploading progress bar
          if (_isUploading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(minHeight: 4),
            ),
          ],

          // Uploaded file list
          for (final document in widget.documents) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    (document.storagePath ?? '').toLowerCase().endsWith('.pdf')
                        ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Added ${DateFormat('d MMM yyyy, h:mm a').format(document.createdAt)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (document.expiresOn != null)
                          Text(
                            'Expires ${DateFormat('d MMM yyyy').format(document.expiresOn!)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(60, 32),
                    ),
                    onPressed: () => _view(context, document),
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text('View', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _chooseAndUpload(BuildContext context) async {
    debugPrint(
      '[TRUCK_DOC] Opening bottom sheet selector for ${widget.type.label}',
    );
    final source = await showModalBottomSheet<_TruckDocumentSource>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.type.label,
                style: Theme.of(
                  sheet,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Add a photo from your camera, pick an image from gallery, or select a PDF document file.',
              ),
              const SizedBox(height: 16),

              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.upload_file_outlined),
                ),
                title: const Text('Choose document file (PDF / PNG)'),
                subtitle: const Text('Upload certified digital document'),
                onTap: () => Navigator.pop(sheet, _TruckDocumentSource.file),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) {
      debugPrint('[TRUCK_DOC] Document picker modal dismissed.');
      return;
    }

    // Crucial: Give Android InsetsController / WindowManager 300ms to complete
    // the modal sheet dismissal animation and IME hide before launching any activity!
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (source == _TruckDocumentSource.file) {
      debugPrint('[TRUCK_DOC] Launching FilePicker (PDF / Image)...');
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (file == null || !mounted) {
        debugPrint('[TRUCK_DOC] FilePicker cancelled by user.');
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await _submit(
        bytes: bytes,
        filename: file.name,
        contentType: switch (file.extension?.toLowerCase()) {
          'pdf' => 'application/pdf',
          'png' => 'image/png',
          _ => 'image/jpeg',
        },
      );
      return;
    }

    if (source == _TruckDocumentSource.gallery) {
      debugPrint('[TRUCK_DOC] Launching Gallery picker...');
      // 1. Try FilePicker first: 100% reliable on Android across all API levels
      // and never cancelled by Android InsetsController / PhotoPicker transitions.
      PlatformFile? file;
      try {
        file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        );
      } catch (e) {
        debugPrint('[TRUCK_DOC] FilePicker image pick error: $e');
      }

      if (file != null && mounted) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        await _submit(
          bytes: bytes,
          filename: file.name,
          contentType: switch (file.extension?.toLowerCase()) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            _ => 'image/jpeg',
          },
        );
        return;
      }

      // 2. Fallback to ImagePicker gallery if FilePicker wasn't picked
      debugPrint('[TRUCK_DOC] Trying ImagePicker gallery fallback...');
      try {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 75,
          maxWidth: 1600,
        );
        if (image == null || !mounted) {
          debugPrint('[TRUCK_DOC] ImagePicker gallery cancelled.');
          return;
        }
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        await _submit(
          bytes: bytes,
          filename: image.name,
          contentType: 'image/jpeg',
        );
      } catch (e) {
        debugPrint('[TRUCK_DOC_GALLERY_ERROR] $e');
        if (mounted) {
          _showErrorDialog('Could not load gallery image: $e');
        }
      }
      return;
    }

    if (source == _TruckDocumentSource.camera) {
      debugPrint('[TRUCK_DOC] Launching Camera via ImagePicker...');
      try {
        final picker = ImagePicker();
        final image = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 75,
          maxWidth: 1600,
        );

        XFile? finalImage = image;
        if (finalImage == null) {
          debugPrint('[TRUCK_DOC] Checking retrieveLostData() for camera...');
          final response = await picker.retrieveLostData();
          if (!response.isEmpty && response.file != null) {
            debugPrint(
              '[TRUCK_DOC] Retrieved lost camera photo: ${response.file!.name}',
            );
            finalImage = response.file;
          }
        }

        if (finalImage == null || !mounted) {
          debugPrint(
            '[TRUCK_DOC] Camera capture cancelled or returned no image.',
          );
          return;
        }

        final bytes = await finalImage.readAsBytes();
        if (!mounted) return;
        await _submit(
          bytes: bytes,
          filename: finalImage.name.isNotEmpty
              ? finalImage.name
              : 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: 'image/jpeg',
        );
      } catch (e, st) {
        debugPrint('[TRUCK_DOC_CAMERA_ERROR] $e');
        debugPrint('[TRUCK_DOC_CAMERA_STACK] $st');
        if (mounted) {
          _showErrorDialog(
            'Could not open camera: $e\n\nPlease check camera permissions in device settings.',
          );
        }
      }
      return;
    }
  }

  Future<void> _submit({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    debugPrint(
      '[TRUCK_DOC_SUBMIT] Initiating upload of "$filename" (${bytes.lengthInBytes} bytes, $contentType) for truck ${widget.truck.id}',
    );
    setState(() {
      _isUploading = true;
      _uploadStatusText = 'Sending to secure vault…';
    });

    try {
      final success = await context.read<DriverDocumentsCubit>().upload(
        DriverDocumentDraft(
          type: widget.type,
          bytes: bytes,
          filename: filename,
          contentType: contentType,
          vehicleId: widget.truck.id,
        ),
      );

      debugPrint('[TRUCK_DOC_SUBMIT] Cubit.upload returned: $success');

      if (!mounted) return;

      if (success) {
        showNotice(context, '${widget.type.label} uploaded successfully.');
      } else {
        final err = context.read<DriverDocumentsCubit>().state.error;
        debugPrint('[TRUCK_DOC_SUBMIT_FAIL] Cubit state error: $err');
        _showErrorDialog(err ?? 'Document upload could not be processed.');
      }
    } catch (e, stack) {
      debugPrint('[TRUCK_DOC_SUBMIT_EXCEPTION] Caught: $e');
      debugPrint('[TRUCK_DOC_SUBMIT_EXCEPTION] Stack: $stack');
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatusText = null;
        });
      }
    }
  }

  void _showErrorDialog(String errorDetails) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Upload Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'There was a problem uploading your document to the server:',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
              ),
              child: Text(
                errorDetails,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  Future<void> _view(BuildContext context, DriverDocumentModel document) async {
    debugPrint(
      '[TRUCK_DOC_VIEW] Requesting signed URL for document ${document.id} (path: ${document.storagePath})',
    );
    final url = await context.read<DriverDocumentsCubit>().viewUrl(document);
    if (!context.mounted) return;
    if (url == null) {
      debugPrint('[TRUCK_DOC_VIEW_ERROR] Signed URL returned null!');
      showNotice(
        context,
        'This document is no longer available. Please upload it again.',
      );
      return;
    }
    debugPrint('[TRUCK_DOC_VIEW_SUCCESS] Signed URL obtained: $url');

    if ((document.storagePath ?? '').toLowerCase().endsWith('.pdf')) {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
          context.mounted) {
        showNotice(context, 'Unable to open this PDF document.');
      }
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.type.label,
                      style: Theme.of(sheet).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheet),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ColoredBox(
                      color: Theme.of(
                        sheet,
                      ).colorScheme.surfaceContainerHighest,
                      child: InteractiveViewer(
                        child: Center(
                          child: Image.network(
                            url.toString(),
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint(
                                '[IMAGE_NETWORK_ERROR] Error loading: $error',
                              );
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.broken_image_outlined,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Unable to display image preview.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        error.toString(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

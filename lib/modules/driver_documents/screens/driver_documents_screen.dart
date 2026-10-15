import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import 'package:lorry_link/design_system/design_system.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../vehicles/models/vehicle_model.dart';
import '../cubit/driver_documents_cubit.dart';
import '../models/driver_document_model.dart';
import '../models/driver_documents_screen_model.dart';

class DriverDocumentsScreen extends StatelessWidget {
  const DriverDocumentsScreen({super.key, this.identityOnly = false});

  final bool identityOnly;

  static const _identityTypes = <DriverDocumentType>{
    DriverDocumentType.identity,
    DriverDocumentType.drivingLicense,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        identityOnly ? 'Driver identity documents' : 'Driver documents',
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _upload(context),
      icon: const Icon(Icons.upload_file_outlined),
      label: const Text('Upload document'),
    ),
    body: PageBody(
      narrow: true,
      onRefresh: () => context.read<DriverDocumentsCubit>().load(),
      child: BlocConsumer<DriverDocumentsCubit, ResourceState<DriverDocumentsScreenModel>>(
        listener: (context, state) {
          if (state.error != null) showNotice(context, state.error!);
          if (state.notice != null) showNotice(context, state.notice!);
        },
        builder: (context, state) => ResourceView<DriverDocumentsScreenModel>(
          state: state,
          retry: () => context.read<DriverDocumentsCubit>().load(),
          builder: (model) {
            final documents = identityOnly
                ? model.documents
                      .where((item) => _identityTypes.contains(item.type))
                      .toList()
                : model.documents;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeading(
                  identityOnly
                      ? 'Keep your identity ready for verification'
                      : 'Keep your truck ready for every route',
                  identityOnly
                      ? 'Aadhaar & driving licence'
                      : 'Driver & vehicle documents',
                  identityOnly
                      ? 'Upload your Aadhaar card and driving licence privately. You can view every submitted file here.'
                      : 'Upload your licence and truck papers privately. The verification team reviews each submission.',
                ),
                _reviewCard(context, documents),
                const SizedBox(height: 20),
                if (documents.isEmpty)
                  AppEmptyState(
                    'No documents submitted',
                    identityOnly
                        ? 'Upload your Aadhaar card and driving licence from your profile.'
                        : 'Start with your driving licence, then add the RC, insurance, permit and fitness certificate for each truck.',
                    icon: Icons.folder_open_outlined,
                  )
                else
                  ...documents.map(
                    (document) => _documentCard(context, document),
                  ),
                const SizedBox(height: 86),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _reviewCard(
    BuildContext context,
    List<DriverDocumentModel> documents,
  ) {
    final verified = documents
        .where((item) => item.status == 'verified')
        .length;
    final expiring = documents
        .where((item) => item.expiresSoon || item.isExpired)
        .length;
    return Card(
      color: expiring > 0
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: Icon(
          expiring > 0
              ? Icons.warning_amber_outlined
              : Icons.verified_user_outlined,
        ),
        title: Text('$verified document${verified == 1 ? '' : 's'} verified'),
        subtitle: Text(
          expiring > 0
              ? '$expiring document${expiring == 1 ? '' : 's'} need attention before your next trip.'
              : 'Review status is updated by the LORRY LINK verification team.',
        ),
      ),
    );
  }

  Widget _documentCard(BuildContext context, DriverDocumentModel document) {
    final expiry = document.expiresOn;
    final expiryText = expiry == null
        ? null
        : document.isExpired
        ? 'Expired ${DateFormat('d MMM yyyy').format(expiry)}'
        : document.expiresSoon
        ? 'Expires soon · ${DateFormat('d MMM yyyy').format(expiry)}'
        : 'Expires ${DateFormat('d MMM yyyy').format(expiry)}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            document.isExpired
                ? Icons.error_outline
                : Icons.description_outlined,
          ),
        ),
        title: Text(document.type.label),
        subtitle: Text(
          document.status == 'rejected'
              ? document.rejectionReason ??
                    'Please upload a clearer replacement.'
              : ['Status: ${document.status}', ?expiryText].join('\n'),
        ),
        isThreeLine: expiryText != null || document.status == 'rejected',
        trailing: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusBadge(document.status),
            IconButton(
              tooltip: 'View document',
              onPressed: () => _view(context, document),
              icon: const Icon(Icons.visibility_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _upload(BuildContext context) async {
    final model = context.read<DriverDocumentsCubit>().state.data;
    if (model == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<DriverDocumentsCubit>(),
        child: _UploadDocumentForm(
          vehicles: model.vehicles,
          allowedTypes: identityOnly
              ? _identityTypes.toList(growable: false)
              : DriverDocumentType.values,
        ),
      ),
    );
  }

  Future<void> _view(BuildContext context, DriverDocumentModel document) async {
    final url = await context.read<DriverDocumentsCubit>().viewUrl(document);
    if (!context.mounted) return;
    if (url == null) {
      showNotice(
        context,
        'This document is no longer available. Please upload it again.',
      );
      return;
    }
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
                Text(
                  document.type.label,
                  style: Theme.of(sheet).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ColoredBox(
                      color: Theme.of(
                        sheet,
                      ).colorScheme.surfaceContainerHighest,
                      child: InteractiveViewer(
                        child: Center(
                          child: Image.network(
                            url.toString(),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Unable to load this document image.',
                                textAlign: TextAlign.center,
                              ),
                            ),
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

class _UploadDocumentForm extends StatefulWidget {
  const _UploadDocumentForm({
    required this.vehicles,
    required this.allowedTypes,
  });
  final List<VehicleModel> vehicles;
  final List<DriverDocumentType> allowedTypes;

  @override
  State<_UploadDocumentForm> createState() => _UploadDocumentFormState();
}

class _UploadDocumentFormState extends State<_UploadDocumentForm> {
  late DriverDocumentType type;
  String? vehicleId;
  DateTime? expiresOn;

  @override
  void initState() {
    super.initState();
    type = widget.allowedTypes.contains(DriverDocumentType.drivingLicense)
        ? DriverDocumentType.drivingLicense
        : widget.allowedTypes.first;
  }

  Future<void> _submit() async {
    if (type.needsVehicle && vehicleId == null) {
      showNotice(context, 'Choose the truck this document belongs to.');
      return;
    }
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final contentType = switch (file.extension?.toLowerCase()) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      _ => 'image/jpeg',
    };
    final ok = await context.read<DriverDocumentsCubit>().upload(
      DriverDocumentDraft(
        type: type,
        bytes: bytes,
        filename: file.name,
        contentType: contentType,
        vehicleId: vehicleId,
        expiresOn: expiresOn,
      ),
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      24,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Upload document',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<DriverDocumentType>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Document type'),
            items: widget.allowedTypes
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.label)),
                )
                .toList(),
            onChanged: (value) => setState(() {
              type = value!;
              if (!type.needsVehicle) vehicleId = null;
            }),
          ),
          if (type.needsVehicle) ...[
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: vehicleId,
              decoration: const InputDecoration(labelText: 'Truck'),
              items: widget.vehicles
                  .map(
                    (truck) => DropdownMenuItem(
                      value: truck.id,
                      child: Text(truck.registrationNumber),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => vehicleId = value),
            ),
            if (widget.vehicles.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Add this truck before uploading its document.'),
              ),
          ],
          const SizedBox(height: 18),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(
              expiresOn == null
                  ? 'Expiry date (optional)'
                  : 'Expires ${DateFormat('d MMM yyyy').format(expiresOn!)}',
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final value = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                initialDate:
                    expiresOn ?? DateTime.now().add(const Duration(days: 365)),
              );
              if (value != null) setState(() => expiresOn = value);
            },
          ),
          const SizedBox(height: 18),
          BlocBuilder<
            DriverDocumentsCubit,
            ResourceState<DriverDocumentsScreenModel>
          >(
            builder: (context, state) => AppButton(
              label: 'Choose file and submit',
              icon: Icons.upload_file_outlined,
              busy: state.busy,
              onPressed: state.busy ? null : _submit,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Accepted: JPG, PNG or PDF · Maximum file size 8 MB',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

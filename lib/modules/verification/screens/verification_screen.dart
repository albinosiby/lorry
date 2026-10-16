import 'package:lorry_link/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import 'package:lorry_link/design_system/design_system.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cubit/profile_documents_cubit.dart';
import '../models/profile_document_model.dart';

const customerIdentityTypes = <String, String>{
  'aadhaar': 'Aadhaar card',
  'pan': 'PAN card',
  'driving_licence': 'Driving licence',
};

String customerIdentityLabel(String type) =>
    customerIdentityTypes[type] ?? 'Identity document';

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const LocalizedText('Identity verification')),
    body: PageBody(
      narrow: true,
      onRefresh: () => context.read<ProfileDocumentsCubit>().load(),
      child: const CustomerIdentityDocumentSection(),
    ),
  );
}

class CustomerIdentityDocumentSection extends StatefulWidget {
  const CustomerIdentityDocumentSection({
    super.key,
    this.showHeading = true,
    this.onSubmitted,
  });

  final bool showHeading;
  final VoidCallback? onSubmitted;

  @override
  State<CustomerIdentityDocumentSection> createState() =>
      _CustomerIdentityDocumentSectionState();
}

class _CustomerIdentityDocumentSectionState
    extends State<CustomerIdentityDocumentSection> {
  String selectedType = 'aadhaar';
  bool documentSelectionLoaded = false;

  Future<void> _pick([String? type]) async {
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
    final submitted = await context.read<ProfileDocumentsCubit>().upload(
      ProfileDocumentDraft(
        bytes: bytes,
        filename: file.name,
        contentType: contentType,
        type: type ?? selectedType,
      ),
    );
    if (submitted && mounted) widget.onSubmitted?.call();
  }

  Future<void> _remove(ProfileDocumentModel document) async {
    if (!await confirmAction(
          context,
          'Remove identity document?',
          'You will need to upload another document before identity verification can continue.',
          confirm: 'Remove',
        ) ||
        !mounted) {
      return;
    }
    await context.read<ProfileDocumentsCubit>().remove(document);
  }

  Future<void> _view(ProfileDocumentModel document) async {
    final url = await context.read<ProfileDocumentsCubit>().viewUrl(document);
    if (!mounted) return;
    if (url == null) {
      showNotice(
        context,
        'This uploaded document is not available. Please upload it again.',
      );
      return;
    }

    final isPdf = (document.storagePath ?? '').toLowerCase().endsWith('.pdf');
    if (isPdf) {
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        showNotice(context, 'Unable to open this PDF document.');
      }
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LocalizedText(
                  customerIdentityLabel(document.type),
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ColoredBox(
                      color: Theme.of(
                        sheetContext,
                      ).colorScheme.surfaceContainerHighest,
                      child: InteractiveViewer(
                        child: Center(
                          child: Image.network(
                            url.toString(),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Padding(
                              padding: EdgeInsets.all(24),
                              child: LocalizedText(
                                'Unable to load this document image. Please try again.',
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

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ProfileDocumentsCubit, ResourceState<List<ProfileDocumentModel>>>(
    listener: (context, state) {
      if (state.error != null) showNotice(context, state.error!);
      if (state.notice != null) showNotice(context, state.notice!);
      final documents = state.data;
      if (documents == null) return;
      if (documents.isEmpty) {
        documentSelectionLoaded = false;
        return;
      }
      final type = documents.first.type;
      if (!documentSelectionLoaded && customerIdentityTypes.containsKey(type)) {
        documentSelectionLoaded = true;
        if (selectedType != type) setState(() => selectedType = type);
      }
    },
    builder: (context, state) => ResourceView<List<ProfileDocumentModel>>(
      state: state,
      retry: () => context.read<ProfileDocumentsCubit>().load(),
      builder: (documents) {
        final document = documents.isEmpty ? null : documents.first;
        final type = selectedType;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showHeading)
              const PageHeading(
                'BUILD TRUST BEFORE BOOKING',
                'Verify your identity',
                'Choose and upload one government-issued ID. Your document stays private and is reviewed before verification.',
              ),
            if (document != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(child: Icon(Icons.badge_outlined)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LocalizedText(
                                  customerIdentityLabel(document.type),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                LocalizedText(
                                  document.status == 'rejected'
                                      ? document.rejectionReason ??
                                            'Please upload a clearer document.'
                                      : 'Status: ${document.status}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(document.status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          TextButton.icon(
                            onPressed: () => _view(document),
                            icon: const Icon(Icons.visibility_outlined),
                            label: const LocalizedText('View'),
                          ),
                          TextButton.icon(
                            onPressed: state.busy ? null : () => _pick(type),
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const LocalizedText('Update'),
                          ),
                          TextButton.icon(
                            onPressed: state.busy
                                ? null
                                : () => _remove(document),
                            icon: const Icon(Icons.delete_outline),
                            label: const LocalizedText('Remove'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            DropdownButtonFormField<String>(
              key: ValueKey('identity-type-$type'),
              initialValue: type,
              isExpanded: true,
              decoration: localizedDecoration(
                context,
                InputDecoration(labelText: 'Identity document type'),
              ),
              items: customerIdentityTypes.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: LocalizedText(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: state.busy
                  ? null
                  : (value) =>
                        setState(() => selectedType = value ?? selectedType),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: document == null
                  ? 'Upload selected ID'
                  : 'Replace with selected ID',
              icon: Icons.upload_file_outlined,
              busy: state.busy,
              onPressed: state.busy ? null : () => _pick(type),
            ),
            const SizedBox(height: 12),
            const LocalizedText(
              'Upload one: Aadhaar card, PAN card or driving licence. Accepted: JPG, PNG or PDF · Maximum file size 8 MB',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        );
      },
    ),
  );
}

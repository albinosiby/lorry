import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lorry_link/design_system/design_system.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../auth/cubit/session_cubit.dart';
import '../cubit/profile_cubit.dart';
import '../models/profile_screen_model.dart';
import '../models/profile_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.setup = false});
  final bool setup;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), phone = TextEditingController();
  final address = TextEditingController(),
      companyName = TextEditingController();
  UserRole role = UserRole.shipper;
  String? photoPath;
  Uint8List? _localPhotoBytes;
  bool _isUploadingPhoto = false;
  bool populated = false;
  bool _editExpanded = false;
  late final AnimationController _editAnim;
  late final Animation<double> _editFade;

  @override
  void initState() {
    super.initState();
    _editAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _editFade = CurvedAnimation(parent: _editAnim, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    companyName.dispose();
    _editAnim.dispose();
    super.dispose();
  }

  void populate(ProfileScreenModel? model) {
    if (!populated && model != null) {
      name.text = model.profile?.name ?? model.suggestedName;
      phone.text = ProfileModel.indianMobileForInput(
        model.profile?.phone ?? '',
      );
      role = model.profile?.role ?? model.suggestedRole;
      address.text = model.profile?.address ?? '';
      companyName.text = model.profile?.companyName ?? '';
      photoPath = model.profile?.photoPath;
      populated = true;
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (photoPath?.trim().isEmpty ?? true) {
      showNotice(context, 'Add a profile photo to complete your account.');
      return;
    }
    final session = context.read<SessionCubit>();
    if (await context.read<ProfileCubit>().save(
      name.text,
      ProfileModel.normalizeIndianMobile(phone.text),
      widget.setup ? role : null,
      address: address.text,
      companyName: companyName.text,
      photoPath: photoPath,
    )) {
      if (!mounted) return;
      await session.refresh();
    }
  }

  Future<void> _uploadPhotoBytes(Uint8List bytes) async {
    setState(() {
      _localPhotoBytes = bytes;
      _isUploadingPhoto = true;
    });
    try {
      final uploaded = await context.read<ProfileCubit>().uploadPhoto(bytes);
      if (!mounted) return;
      if (uploaded != null) {
        setState(() => photoPath = uploaded);
        showNotice(
          context,
          'Profile photo updated. Tap "Save changes" below to apply it.',
        );
      } else {
        showNotice(context, 'Failed to upload photo. Please try again.');
      }
    } catch (e) {
      if (mounted) showNotice(context, 'Photo upload error: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> pickPhoto(ImageSource source) async {
    // Give Android InsetsController time to settle the bottom sheet dismissal
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (source == ImageSource.gallery) {
      // 1. Try FilePicker first: 100% reliable on Android across all API levels
      try {
        final file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        );
        if (file != null && mounted) {
          final bytes = await file.readAsBytes();
          if (mounted) await _uploadPhotoBytes(bytes);
          return;
        }
      } catch (e) {
        debugPrint('[PROFILE_PHOTO] FilePicker error: $e');
      }

      // 2. Fallback to ImagePicker gallery
      try {
        final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 82,
          maxWidth: 1200,
        );
        if (file != null && mounted) {
          final bytes = await file.readAsBytes();
          if (mounted) await _uploadPhotoBytes(bytes);
        }
      } catch (e) {
        debugPrint('[PROFILE_PHOTO] ImagePicker gallery error: $e');
        if (mounted) showNotice(context, 'Could not pick image: $e');
      }
      return;
    }

    if (source == ImageSource.camera) {
      try {
        final picker = ImagePicker();
        final file = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 82,
          maxWidth: 1200,
        );

        XFile? finalFile = file;
        if (finalFile == null) {
          final response = await picker.retrieveLostData();
          if (!response.isEmpty && response.file != null) {
            finalFile = response.file;
          }
        }

        if (finalFile != null && mounted) {
          final bytes = await finalFile.readAsBytes();
          if (mounted) await _uploadPhotoBytes(bytes);
        }
      } catch (e) {
        debugPrint('[PROFILE_PHOTO] Camera error: $e');
        if (mounted) {
          showNotice(context, 'Could not open camera: $e');
        }
      }
    }
  }

  Future<void> choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
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
                'Profile photo',
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(sheet, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(sheet, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null && mounted) await pickPhoto(source);
  }

  void _toggleEdit() {
    setState(() => _editExpanded = !_editExpanded);
    if (_editExpanded) {
      _editAnim.forward();
    } else {
      _editAnim.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = PageBody(
      narrow: true,
      child: BlocConsumer<ProfileCubit, ResourceState<ProfileScreenModel>>(
        listener: (context, state) {
          populate(state.data);
          if (state.error != null) showNotice(context, state.error!);
          if (state.notice != null) showNotice(context, state.notice!);
        },
        builder: (context, state) {
          populate(state.data);
          return ResourceView<ProfileScreenModel>(
            state: state,
            retry: () => context.read<ProfileCubit>().load(),
            builder: (model) {
              final isShipper =
                  !widget.setup && model.profile?.role == UserRole.shipper;

              return Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.setup) ...[
                      PageHeading(
                        'Your account',
                        'Make it yours.',
                        'Choose how you\'ll use LORRY LINK. Your primary role stays fixed.',
                      ),
                      _buildSetupAvatarSection(state),
                      const SizedBox(height: 24),
                      _buildFormFields(model, state),
                      const SizedBox(height: 16),
                      ..._buildRoleSelector(),
                      const SizedBox(height: 24),
                      _buildSetupActions(model, state),
                    ] else ...[
                      _buildProfileHero(model, state, isShipper: isShipper),
                      const SizedBox(height: 20),
                      _buildEditProfileTile(model, state),
                      const SizedBox(height: 20),
                      if (isShipper)
                        _buildShipperActionsSection(context, model.profile)
                      else
                        _buildDriverActionsSection(context),
                      const SizedBox(height: 20),
                      _buildAccountHelpSection(context),
                      const SizedBox(height: 28),
                      _buildSignOutFooter(state),
                    ],
                    const SizedBox(height: 12),
                    const Divider(),
                    const Text(
                      'LORRY LINK · Version 1.0.0',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
    return widget.setup
        ? Scaffold(
            appBar: AppBar(title: const Brand()),
            body: body,
          )
        : body;
  }

  // ─── Profile Hero Header ───────────────────────────────────────────────────

  Widget _buildProfileHero(
    ProfileScreenModel model,
    ResourceState<ProfileScreenModel> state, {
    required bool isShipper,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hasPhoto =
        _localPhotoBytes != null || (photoPath?.startsWith('http') == true);
    final initials = name.text.trim().isEmpty
        ? 'L'
        : name.text.trim()[0].toUpperCase();

    final gradientColors = isShipper
        ? (dark
              ? [const Color(0xFF132832), const Color(0xFF091419)]
              : [const Color(0xFF183D48), const Color(0xFF265A68)])
        : (dark
              ? [const Color(0xFF1C3A2F), const Color(0xFF0F2018)]
              : [const Color(0xFF193F35), const Color(0xFF2A5E4A)]);

    final shadowColor = isShipper
        ? const Color(0xFF183D48).withValues(alpha: .35)
        : const Color(0xFF193F35).withValues(alpha: .35);

    final avatarBgColor = isShipper
        ? const Color(0xFF265A68)
        : const Color(0xFF2A5E4A);

    final accentBadgeColor = isShipper
        ? const Color(0xFF0284C7)
        : const Color(0xFFD5693C);

    final badgeTextColor = isShipper
        ? const Color(0xFFBAE6FD)
        : const Color(0xFFFFB899);

    final roleLabel = isShipper
        ? 'Commercial Cargo Shipper'
        : 'Transporter / Driver';

    final roleIcon = isShipper
        ? Icons.inventory_2_outlined
        : Icons.local_shipping_outlined;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              GestureDetector(
                onTap: state.busy ? null : choosePhoto,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .25),
                          width: 3,
                        ),
                        image: hasPhoto
                            ? DecorationImage(
                                image: _localPhotoBytes != null
                                    ? MemoryImage(_localPhotoBytes!)
                                          as ImageProvider
                                    : NetworkImage(photoPath!),
                                fit: BoxFit.cover,
                              )
                            : null,
                        color: avatarBgColor,
                      ),
                      child: _isUploadingPhoto
                          ? Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: .5),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : hasPhoto
                          ? null
                          : Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: accentBadgeColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: dark
                                ? (isShipper
                                      ? const Color(0xFF091419)
                                      : const Color(0xFF0F2018))
                                : (isShipper
                                      ? const Color(0xFF183D48)
                                      : const Color(0xFF193F35)),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name.text.isEmpty ? 'Your name' : name.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.4,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: isShipper
                              ? 'Verified Customer Account'
                              : 'Verified Driver Account',
                          child: const Icon(
                            Icons.verified,
                            color: Color(0xFF6BDB9C),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentBadgeColor.withValues(alpha: .25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accentBadgeColor.withValues(alpha: .5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(roleIcon, size: 13, color: badgeTextColor),
                          const SizedBox(width: 5),
                          Text(
                            roleLabel,
                            style: TextStyle(
                              color: badgeTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (model.profile?.companyName?.isNotEmpty == true)
                      Row(
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 13,
                            color: Colors.white.withValues(alpha: .55),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              model.profile!.companyName!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .65),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Info strip
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: .1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _heroInfoChip(Icons.mail_outline, model.email),
                const _HeroInfoDivider(),
                _heroInfoChip(
                  Icons.verified_rounded,
                  isShipper ? 'Verified Customer' : 'Verified Driver',
                  color: const Color(0xFF6BDB9C),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroInfoChip(IconData icon, String text, {Color? color}) {
    final c = color ?? Colors.white.withValues(alpha: .65);
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: c,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Edit Profile Collapsible ──────────────────────────────────────────────

  Widget _buildEditProfileTile(
    ProfileScreenModel model,
    ResourceState<ProfileScreenModel> state,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toggle tile
        GestureDetector(
          onTap: _toggleEdit,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              color: _editExpanded
                  ? cs.primaryContainer.withValues(alpha: .35)
                  : cs.surface,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(
                color: _editExpanded
                    ? cs.primary.withValues(alpha: .4)
                    : cs.outlineVariant.withValues(alpha: .65),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.edit_outlined, size: 18, color: cs.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit profile details',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        'Name, phone, address, company',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _editExpanded ? .5 : 0,
                  duration: const Duration(milliseconds: 260),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Expandable form
        SizeTransition(
          sizeFactor: _editFade,
          child: FadeTransition(
            opacity: _editFade,
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: .65),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFormFields(model, state),
                  InfoRow(
                    Icons.badge_outlined,
                    'Primary role',
                    model.profile?.role.label ?? '',
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Save changes',
                    busy: state.busy,
                    onPressed: save,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Driver Actions Section ────────────────────────────────────────────────

  Widget _buildDriverActionsSection(BuildContext context) {
    return _SectionGroup(
      label: 'Driver tools',
      icon: Icons.local_shipping_outlined,
      children: [
        _ActionTile(
          icon: Icons.add_location_alt_outlined,
          iconColor: const Color(0xFF2196F3),
          title: 'Post truck availability',
          subtitle: 'Tell customers where your truck is ready to move.',
          onTap: () => context.push('/driver/availability'),
        ),
        _ActionTile(
          icon: Icons.local_shipping_outlined,
          iconColor: const Color(0xFF4CAF50),
          title: 'Manage my trucks',
          subtitle: 'Capacity, length and verification information.',
          onTap: () => context.push('/driver/vehicles'),
        ),
        _ActionTile(
          icon: Icons.assignment_turned_in_outlined,
          iconColor: const Color(0xFFFF9800),
          title: 'Aadhaar & driving licence',
          subtitle: 'Upload and view your personal identity documents.',
          onTap: () => context.push('/driver/documents?identity=true'),
        ),
        _ActionTile(
          icon: Icons.account_balance_wallet_outlined,
          iconColor: const Color(0xFF9C27B0),
          title: 'Finance tracker',
          subtitle: 'Record freight income, fuel, toll and maintenance.',
          onTap: () => context.push('/driver/finance'),
          isLast: true,
        ),
      ],
    );
  }

  // ─── Shipper Actions Section ───────────────────────────────────────────────

  Widget _buildShipperActionsSection(
    BuildContext context,
    ProfileModel? profile,
  ) {
    return _SectionGroup(
      label: 'Shipper tools',
      icon: Icons.inventory_2_outlined,
      children: [
        _ActionTile(
          icon: Icons.local_shipping_outlined,
          iconColor: const Color(0xFF2196F3),
          title: 'Find available trucks',
          subtitle:
              'Search nearby verified fleet ready for immediate dispatch.',
          onTap: () => context.push('/customer/trucks'),
        ),

        _ActionTile(
          icon: Icons.inventory_2_outlined,
          iconColor: const Color(0xFFFF9800),
          title: 'My shipments & bookings',
          subtitle: 'Track your posted freight and active truck assignments.',
          onTap: () => context.push('/loads/mine'),
          isLast: true,
        ),
      ],
    );
  }

  // ─── Account Help Section ─────────────────────────────────────────────────

  Widget _buildAccountHelpSection(BuildContext context) {
    return _SectionGroup(
      label: 'Account help',
      icon: Icons.help_outline_rounded,
      children: [
        _ActionTile(
          icon: Icons.gavel_outlined,
          iconColor: const Color(0xFF607D8B),
          title: 'Terms & privacy',
          subtitle: 'Booking, location and verification terms.',
          onTap: () => context.push('/profile/terms'),
        ),
        _ActionTile(
          icon: Icons.support_agent_outlined,
          iconColor: const Color(0xFF009688),
          title: 'Support',
          subtitle: 'Get help with a booking or active trip.',
          onTap: () => context.push('/profile/support'),
          isLast: true,
        ),
      ],
    );
  }

  // ─── Sign out footer ──────────────────────────────────────────────────────

  Widget _buildSignOutFooter(ResourceState<ProfileScreenModel> state) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.error,
          side: BorderSide(color: cs.error.withValues(alpha: .4)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: state.busy
            ? null
            : () async {
                final cubit = context.read<ProfileCubit>();
                if (await confirmAction(
                      context,
                      'Sign out?',
                      'You can sign back in at any time.',
                      confirm: 'Sign out',
                    ) &&
                    context.mounted) {
                  await cubit.signOut();
                }
              },
        icon: const Icon(Icons.logout, size: 18),
        label: const Text('Sign out'),
      ),
    );
  }

  // ─── Setup avatar section ─────────────────────────────────────────────────

  Widget _buildSetupAvatarSection(ResourceState<ProfileScreenModel> state) {
    final hasPhoto =
        _localPhotoBytes != null || (photoPath?.startsWith('http') == true);
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundImage: hasPhoto
                    ? (_localPhotoBytes != null
                          ? MemoryImage(_localPhotoBytes!) as ImageProvider
                          : NetworkImage(photoPath!))
                    : null,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: hasPhoto
                    ? null
                    : Text(
                        name.text.isEmpty ? 'L' : name.text[0].toUpperCase(),
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
              ),
              if (_isUploadingPhoto)
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: .45),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          TextButton.icon(
            onPressed: state.busy || _isUploadingPhoto ? null : choosePhoto,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Add profile photo'),
          ),
        ],
      ),
    );
  }

  // ─── Form fields ──────────────────────────────────────────────────────────

  Widget _buildFormFields(
    ProfileScreenModel model,
    ResourceState<ProfileScreenModel> state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: name,
          label: 'Full name',
          validator: Validators.name,
          maxLength: 80,
        ),
        AppTextField(
          controller: phone,
          label: 'Mobile number',
          hint: '98765 43210',
          prefixText: '+91 ',
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            final value = v?.trim() ?? '';
            if (value.isEmpty) return 'Mobile number is required.';
            return ProfileModel.isValidIndianMobile(value)
                ? null
                : 'Enter a valid 10-digit Indian mobile number.';
          },
        ),
        InfoRow(Icons.mail_outline, 'Email address', model.email),
        AppTextField(
          controller: address,
          label: 'Address',
          hint: 'Your business or pickup address',
          lines: 2,
          maxLength: 300,
          validator: Validators.required,
        ),
        AppTextField(
          controller: companyName,
          label: 'Company / business name',
          hint: 'Optional',
          maxLength: 120,
        ),
      ],
    );
  }

  // ─── Role selector (setup only) ───────────────────────────────────────────

  List<Widget> _buildRoleSelector() {
    return UserRole.values
        .map(
          (r) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(
                r == UserRole.shipper
                    ? Icons.inventory_2_outlined
                    : Icons.local_shipping_outlined,
              ),
              title: Text(r.label),
              subtitle: Text(
                r == UserRole.shipper
                    ? 'Post parcels or loads and choose a driver'
                    : 'Find loads and manage trips',
              ),
              trailing: Icon(
                role == r ? Icons.radio_button_checked : Icons.radio_button_off,
              ),
              onTap: () => setState(() => role = r),
            ),
          ),
        )
        .toList();
  }

  // ─── Setup actions ────────────────────────────────────────────────────────

  Widget _buildSetupActions(
    ProfileScreenModel model,
    ResourceState<ProfileScreenModel> state,
  ) {
    return AppButton(
      label: widget.setup ? 'Start my journey' : 'Save changes',
      busy: state.busy,
      onPressed: save,
    );
  }
}

// ─── Shared section group widget ──────────────────────────────────────────────

class _SectionGroup extends StatelessWidget {
  const _SectionGroup({
    required this.label,
    required this.icon,
    required this.children,
  });
  final String label;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 2),
          child: Row(
            children: [
              Icon(icon, size: 15, color: cs.primary),
              const SizedBox(width: 7),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: .65)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ─── Action tile inside a section group ──────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.vertical(
            top: isLast ? Radius.zero : Radius.zero,
            bottom: isLast ? const Radius.circular(20) : Radius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 70,
            color: cs.outlineVariant.withValues(alpha: .5),
          ),
      ],
    );
  }
}

// ─── Divider for hero info strip ──────────────────────────────────────────────

class _HeroInfoDivider extends StatelessWidget {
  const _HeroInfoDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 18,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: Colors.white.withValues(alpha: .2),
  );
}

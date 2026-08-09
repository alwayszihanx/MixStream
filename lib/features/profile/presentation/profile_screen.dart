import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/custom_widgets.dart';
import 'profile_provider.dart';
import 'switch_account_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  static Future<void> show(BuildContext context) async {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ProfileScreen(),
    );
  }

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    _nameController = TextEditingController(text: profile.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      ref
          .read(userProfileProvider.notifier)
          .updateImage(result.files.single.path!);
    }
  }

  void _showAvatarPicker() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final cs = Theme.of(context).colorScheme;
        final profile = ref.watch(userProfileProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const AppIcon('image', size: 22),
                  title: const Text('Upload Photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage();
                  },
                ),
                if (profile.hasCustomImage)
                  ListTile(
                    leading: const AppIcon('delete_outline', size: 22,
                      color: Colors.red,
                    ),
                    title: const Text('Remove Photo',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(userProfileProvider.notifier).clearImage();
                    },
                  ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(
                      UserProfileData.avatarIcons.length,
                      (index) {
                        final isSelected = profile.avatarIndex == index &&
                            !profile.hasCustomImage;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(userProfileProvider.notifier)
                                .updateAvatar(index);
                            Navigator.pop(ctx);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? profile.color.withValues(alpha: 0.2)
                                  : cs.onSurface.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(color: profile.color, width: 2)
                                  : null,
                            ),
                            child: AppIcon(
                              UserProfileData.avatarIcons[index],
                              size: 22,
                              color: isSelected ? profile.color : cs.onSurface,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Center(
                child: Text(
                  'Edit Profile',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: GestureDetector(
                  onTap: _showAvatarPicker,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: profile.color,
                        backgroundImage: profile.hasCustomImage
                            ? FileImage(File(profile.imagePath!))
                            : null,
                        child: profile.hasCustomImage
                            ? null
                            : AppIcon(
                                UserProfileData.avatarIcons[
                                    profile.avatarIndex %
                                        UserProfileData
                                            .avatarIcons.length],
                                size: 40,
                                color: Colors.white,
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: cs.surface, width: 2),
                          ),
                          child: const AppIcon(
                            'edit',
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    ref
                        .read(userProfileProvider.notifier)
                        .updateName(value.trim());
                  }
                },
              ),
              const SizedBox(height: 28),
              Text(
                'Avatar Color',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(
                  UserProfileData.avatarColors.length,
                  (index) {
                    final color = UserProfileData.avatarColors[index];
                    final isSelected = profile.colorIndex == index;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(userProfileProvider.notifier)
                            .updateColor(index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color:
                                        color.withValues(alpha: 0.5),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              CustomButton(
                isPrimary: true,
                onPressed: () {
                  if (_nameController.text.trim().isNotEmpty) {
                    ref
                        .read(userProfileProvider.notifier)
                        .updateName(_nameController.text.trim());
                  }
                  Navigator.pop(context);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: Text('Save')),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  SwitchAccountScreen.show(context);
                },
                icon: const AppIcon('swap_horiz_rounded', size: 18),
                label: const Text('Switch Account'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

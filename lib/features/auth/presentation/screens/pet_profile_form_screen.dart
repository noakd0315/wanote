import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../shared/models/pet_profile.dart';
import '../../../../shared/widgets/dog_silhouette_background.dart';
import '../auth_controller.dart';

/// Create or edit a single pet profile (spec 1.2 -
/// ペットプロフィール登録：犬種、名前、生年月日、性別、体重（初期値）、
/// 避妊去勢有無). Name/breed/birthday/sex/neutered are required; weight is
/// optional and can be filled in later from the weight-tracking feature
/// (see PetProfile's doc comment for the reasoning).
///
/// Pass [existingPet] to edit a pet already on the account; omit it to
/// create a new one. When pushed as a route it pops itself on success; when
/// shown inline by LaunchGateScreen as the forced first-pet step (no route
/// to pop) it just relies on AuthController's pet stream to move the app
/// forward once a pet exists.
class PetProfileFormScreen extends StatefulWidget {
  const PetProfileFormScreen({super.key, this.existingPet});

  final PetProfile? existingPet;

  @override
  State<PetProfileFormScreen> createState() => _PetProfileFormScreenState();
}

class _PetProfileFormScreenState extends State<PetProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _breedController;
  late final TextEditingController _weightController;
  late DateTime? _birthday;
  late PetSex _sex;
  late bool _neutered;
  String? _existingPhotoUrl;
  Uint8List? _pickedPhotoBytes;
  bool _isBusy = false;

  bool get _isEditing => widget.existingPet != null;

  @override
  void initState() {
    super.initState();
    final pet = widget.existingPet;
    _nameController = TextEditingController(text: pet?.name ?? '');
    _breedController = TextEditingController(text: pet?.breed ?? '');
    _weightController = TextEditingController(
      text: pet?.weightKg?.toString() ?? '',
    );
    _birthday = pet?.birthday;
    _sex = pet?.sex ?? PetSex.male;
    _neutered = pet?.neutered ?? false;
    _existingPhotoUrl = pet?.photoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await _imagePicker.pickImage(source: source);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _pickedPhotoBytes = bytes);
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 1, now.month, now.day),
      firstDate: DateTime(now.year - 30),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _birthday = picked);
    }
  }

  Future<void> _submit(AuthController controller) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_birthday == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a birthday')));
      return;
    }

    setState(() => _isBusy = true);
    final weightText = _weightController.text.trim();
    final weightKg = weightText.isEmpty ? null : double.tryParse(weightText);

    try {
      if (_isEditing) {
        var updated = widget.existingPet!.copyWith(
          name: _nameController.text.trim(),
          breed: _breedController.text.trim(),
          birthday: _birthday,
          sex: _sex,
          neutered: _neutered,
          weightKg: weightKg,
        );
        if (_pickedPhotoBytes != null) {
          final url = await controller.uploadPetPhoto(
            petId: updated.petId,
            bytes: _pickedPhotoBytes!,
          );
          updated = updated.copyWith(photoUrl: url);
        }
        await controller.updatePet(updated);
      } else {
        final created = await controller.createPet(
          name: _nameController.text.trim(),
          breed: _breedController.text.trim(),
          birthday: _birthday!,
          sex: _sex,
          neutered: _neutered,
          weightKg: weightKg,
        );
        // A new pet has no id until createPet() returns, so the photo
        // upload (keyed by pet id) has to happen as a follow-up update --
        // same two-step pattern as the prevention-certificate upload flow.
        if (_pickedPhotoBytes != null) {
          final url = await controller.uploadPetPhoto(
            petId: created.petId,
            bytes: _pickedPhotoBytes!,
          );
          await controller.updatePet(created.copyWith(photoUrl: url));
        }
      }
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit pet' : 'Add a pet')),
      body: Stack(
        children: [
          const Positioned.fill(child: DogSilhouetteBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundImage: _pickedPhotoBytes != null
                                    ? MemoryImage(_pickedPhotoBytes!)
                                          as ImageProvider
                                    : (_existingPhotoUrl != null
                                          ? CachedNetworkImageProvider(
                                              _existingPhotoUrl!,
                                            )
                                          : null),
                                child:
                                    (_pickedPhotoBytes == null &&
                                        _existingPhotoUrl == null)
                                    ? const Icon(Icons.pets, size: 40)
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: IconButton.filled(
                                  icon: const Icon(Icons.camera_alt, size: 18),
                                  onPressed: _pickPhoto,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Name'),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'Name is required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _breedController,
                          decoration: const InputDecoration(labelText: 'Breed'),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'Breed is required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _birthday == null
                                ? 'Select birthday'
                                : 'Birthday: ${_birthday!.toLocal()}'
                                      .split(' ')
                                      .first,
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: _pickBirthday,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<PetSex>(
                          initialValue: _sex,
                          decoration: const InputDecoration(labelText: 'Sex'),
                          items: PetSex.values
                              .map(
                                (sex) => DropdownMenuItem(
                                  value: sex,
                                  child: Text(sex.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _sex = value);
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Neutered / spayed'),
                          value: _neutered,
                          onChanged: (value) =>
                              setState(() => _neutered = value),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Weight (kg) - optional',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty)
                              return null;
                            return double.tryParse(value.trim()) == null
                                ? 'Enter a valid number'
                                : null;
                          },
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: (_isBusy || controller.isLoading)
                              ? null
                              : () => _submit(controller),
                          child: Text(_isEditing ? 'Save' : 'Add pet'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../shared/models/pet_profile.dart';
import '../../../../shared/widgets/dog_silhouette_background.dart';
import '../../../../shared/widgets/image_source_sheet.dart';
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
///
/// Photo handling covers 3 PM requests together: separate background vs.
/// icon images ("愛犬アイコンと背景は別々の画像を設定できるようにしたい"),
/// deleting either one ("愛犬の写真を削除する機能を追加したい"), and
/// repositioning/zooming the icon's crop ("出力するアイコンについて表示位置
/// やサイズを設定できるようにしたい").
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
  bool _isBusy = false;

  // Background photo (Home screen full-bleed image).
  Uint8List? _pickedBackgroundBytes;
  String? _backgroundUrl;
  bool _backgroundWasDeleted = false;

  // Icon/avatar photo (settings, pet switcher) -- independent of the
  // background, per the PM's request.
  Uint8List? _pickedIconBytes;
  String? _iconUrl;
  bool _iconWasDeleted = false;
  late double _iconAlignmentX;
  late double _iconAlignmentY;
  late double _iconZoom;

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
    _backgroundUrl = pet?.photoUrl;
    _iconUrl = pet?.iconPhotoUrl;
    _iconAlignmentX = pet?.iconAlignmentX ?? 0.0;
    _iconAlignmentY = pet?.iconAlignmentY ?? 0.0;
    _iconZoom = pet?.iconZoom ?? 1.0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  /// Shows the camera/gallery choice, then hands the picked bytes (if any)
  /// to [onPicked]. See `shared/widgets/image_source_sheet.dart`'s doc
  /// comment for why the picker calls happen where they do (iOS Safari
  /// gesture requirements).
  void _pickImage(void Function(Uint8List bytes) onPicked) {
    showImageSourceSheet(
      context: context,
      onCamera: () => unawaited(_pickAndDeliver(ImageSource.camera, onPicked)),
      onGallery: () =>
          unawaited(_pickAndDeliver(ImageSource.gallery, onPicked)),
    );
  }

  Future<void> _pickAndDeliver(
    ImageSource source,
    void Function(Uint8List bytes) onPicked,
  ) async {
    final picked = await _imagePicker.pickImage(source: source);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    onPicked(bytes);
  }

  void _pickBackgroundPhoto() {
    _pickImage((bytes) {
      setState(() {
        _pickedBackgroundBytes = bytes;
        _backgroundWasDeleted = false;
      });
    });
  }

  void _deleteBackgroundPhoto() {
    setState(() {
      _pickedBackgroundBytes = null;
      _backgroundUrl = null;
      _backgroundWasDeleted = widget.existingPet?.photoUrl != null;
    });
  }

  void _pickIconPhoto() {
    _pickImage((bytes) {
      setState(() {
        _pickedIconBytes = bytes;
        _iconWasDeleted = false;
      });
    });
  }

  void _deleteIconPhoto() {
    setState(() {
      _pickedIconBytes = null;
      _iconUrl = null;
      _iconWasDeleted = widget.existingPet?.iconPhotoUrl != null;
    });
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
      PetProfile pet;
      if (_isEditing) {
        pet = widget.existingPet!.copyWith(
          name: _nameController.text.trim(),
          breed: _breedController.text.trim(),
          birthday: _birthday,
          sex: _sex,
          neutered: _neutered,
          weightKg: weightKg,
          iconAlignmentX: _iconAlignmentX,
          iconAlignmentY: _iconAlignmentY,
          iconZoom: _iconZoom,
        );
      } else {
        // A new pet has no id until createPet() returns, so any photo
        // upload (keyed by pet id) has to happen as a follow-up update --
        // same two-step pattern as the prevention-certificate upload flow.
        pet = await controller.createPet(
          name: _nameController.text.trim(),
          breed: _breedController.text.trim(),
          birthday: _birthday!,
          sex: _sex,
          neutered: _neutered,
          weightKg: weightKg,
        );
      }

      if (_pickedBackgroundBytes != null) {
        final url = await controller.uploadPetPhoto(
          petId: pet.petId,
          bytes: _pickedBackgroundBytes!,
        );
        pet = pet.copyWith(photoUrl: url);
      } else if (_backgroundWasDeleted) {
        await controller.deletePetPhoto(pet.petId);
        pet = pet.copyWith(clearPhotoUrl: true);
      }

      if (_pickedIconBytes != null) {
        final url = await controller.uploadPetIconPhoto(
          petId: pet.petId,
          bytes: _pickedIconBytes!,
        );
        pet = pet.copyWith(iconPhotoUrl: url);
      } else if (_iconWasDeleted) {
        await controller.deletePetIconPhoto(pet.petId);
        pet = pet.copyWith(clearIconPhotoUrl: true);
      }

      await controller.updatePet(pet);

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
                        _buildIconSection(),
                        const SizedBox(height: 24),
                        _buildBackgroundSection(),
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
                                : 'Birthday: ${DateFormat('yyyy/MM/dd').format(_birthday!)}',
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
                            if (value == null || value.trim().isEmpty) {
                              return null;
                            }
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

  ImageProvider? _iconImageProvider() {
    if (_pickedIconBytes != null) return MemoryImage(_pickedIconBytes!);
    if (_iconUrl != null) return CachedNetworkImageProvider(_iconUrl!);
    return null;
  }

  Widget _buildIconSection() {
    final iconImage = _iconImageProvider();
    const previewSize = 96.0;
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('アイコン写真', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Stack(
            children: [
              ClipOval(
                child: SizedBox(
                  width: previewSize,
                  height: previewSize,
                  child: iconImage == null
                      ? const ColoredBox(
                          color: Color(0x1F000000),
                          child: Icon(Icons.pets, size: 40),
                        )
                      : Transform.scale(
                          scale: _iconZoom,
                          alignment: Alignment(
                            _iconAlignmentX,
                            _iconAlignmentY,
                          ),
                          child: Image(
                            image: iconImage,
                            width: previewSize,
                            height: previewSize,
                            fit: BoxFit.cover,
                            alignment: Alignment(
                              _iconAlignmentX,
                              _iconAlignmentY,
                            ),
                          ),
                        ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: IconButton.filled(
                  icon: const Icon(Icons.camera_alt, size: 18),
                  onPressed: _pickIconPhoto,
                ),
              ),
            ],
          ),
        ),
        if (iconImage != null) ...[
          TextButton.icon(
            onPressed: _deleteIconPhoto,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('アイコン写真を削除'),
          ),
          // Reposition/zoom controls -- PM request: "出力するアイコンに
          // ついて表示位置やサイズを設定できるようにしたい".
          Row(
            children: [
              const SizedBox(
                width: 56,
                child: Text('左右', style: TextStyle(fontSize: 12)),
              ),
              Expanded(
                child: Slider(
                  value: _iconAlignmentX,
                  min: -1,
                  max: 1,
                  onChanged: (value) => setState(() => _iconAlignmentX = value),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(
                width: 56,
                child: Text('上下', style: TextStyle(fontSize: 12)),
              ),
              Expanded(
                child: Slider(
                  value: _iconAlignmentY,
                  min: -1,
                  max: 1,
                  onChanged: (value) => setState(() => _iconAlignmentY = value),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(
                width: 56,
                child: Text('ズーム', style: TextStyle(fontSize: 12)),
              ),
              Expanded(
                child: Slider(
                  value: _iconZoom,
                  min: 1,
                  max: 3,
                  onChanged: (value) => setState(() => _iconZoom = value),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  ImageProvider? _backgroundImageProvider() {
    if (_pickedBackgroundBytes != null) {
      return MemoryImage(_pickedBackgroundBytes!);
    }
    if (_backgroundUrl != null) {
      return CachedNetworkImageProvider(_backgroundUrl!);
    }
    return null;
  }

  Widget _buildBackgroundSection() {
    final backgroundImage = _backgroundImageProvider();
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '背景写真（ホーム画面）',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: double.infinity,
            height: 120,
            child: backgroundImage == null
                ? const ColoredBox(
                    color: Color(0x1F000000),
                    child: Icon(Icons.image_outlined, size: 32),
                  )
                : Image(image: backgroundImage, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _pickBackgroundPhoto,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('変更'),
            ),
            if (backgroundImage != null) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _deleteBackgroundPhoto,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('削除'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

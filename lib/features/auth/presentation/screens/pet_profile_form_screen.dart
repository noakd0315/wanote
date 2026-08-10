import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/models/pet_profile.dart';
import '../../../../shared/widgets/dog_silhouette_background.dart';
import '../../../../shared/widgets/image_source_sheet.dart';
import '../auth_controller.dart';
import 'photo_crop_screen.dart';

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
  late double _backgroundAlignmentX;
  late double _backgroundAlignmentY;
  late double _backgroundZoom;

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
    _backgroundAlignmentX = pet?.backgroundAlignmentX ?? 0.0;
    _backgroundAlignmentY = pet?.backgroundAlignmentY ?? 0.0;
    _backgroundZoom = pet?.backgroundZoom ?? 1.0;
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
      unawaited(_openBackgroundCrop(bytes, initial: null));
    });
  }

  /// Frames the Home background against the device's own aspect ratio, so
  /// the preview matches what the Home screen will show.
  Future<void> _openBackgroundCrop(
    Uint8List bytes, {
    required PhotoCropResult? initial,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final screen = MediaQuery.sizeOf(context);
    final result = await Navigator.of(context).push<PhotoCropResult>(
      MaterialPageRoute(
        builder: (_) => PhotoCropScreen(
          imageBytes: bytes,
          initial: initial,
          title: l10n.backgroundCropTitle,
          confirmLabel: l10n.photoCropConfirmButton,
          hint: l10n.backgroundCropHint,
          frameAspectRatio: screen.width / screen.height,
          circular: false,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _backgroundAlignmentX = result.alignmentX;
      _backgroundAlignmentY = result.alignmentY;
      _backgroundZoom = result.zoom;
    });
  }

  /// Re-frames the background already on the form. Only offered for a
  /// just-picked photo, for the same reason as [_adjustPickedIcon].
  void _adjustPickedBackground() {
    final bytes = _pickedBackgroundBytes;
    if (bytes == null) return;
    unawaited(
      _openBackgroundCrop(
        bytes,
        initial: PhotoCropResult(
          alignmentX: _backgroundAlignmentX,
          alignmentY: _backgroundAlignmentY,
          zoom: _backgroundZoom,
        ),
      ),
    );
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
      // Frame it straight away rather than dropping the user back on the
      // form to fiddle with sliders (PM request: adjust inside the image
      // like LINE/Facebook). Newly picked photos start centred at 1x.
      unawaited(_openIconCrop(bytes, initial: null));
    });
  }

  /// Opens the pinch-to-frame screen and stores whatever framing comes back.
  /// Cancelling leaves the current framing untouched.
  Future<void> _openIconCrop(
    Uint8List bytes, {
    required PhotoCropResult? initial,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await Navigator.of(context).push<PhotoCropResult>(
      MaterialPageRoute(
        builder: (_) => PhotoCropScreen(
          imageBytes: bytes,
          initial: initial,
          title: l10n.iconCropTitle,
          confirmLabel: l10n.photoCropConfirmButton,
          hint: l10n.iconCropHint,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _iconAlignmentX = result.alignmentX;
      _iconAlignmentY = result.alignmentY;
      _iconZoom = result.zoom;
    });
  }

  /// Re-frames the icon already on the form. Only offered for a
  /// just-picked photo: a previously saved icon is a URL, and the crop
  /// screen works on bytes.
  void _adjustPickedIcon() {
    final bytes = _pickedIconBytes;
    if (bytes == null) return;
    unawaited(
      _openIconCrop(
        bytes,
        initial: PhotoCropResult(
          alignmentX: _iconAlignmentX,
          alignmentY: _iconAlignmentY,
          zoom: _iconZoom,
        ),
      ),
    );
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
    // Defaults the calendar to today rather than a year ago -- a lot of
    // pets registered here will be puppies, so "one year old" was a worse
    // starting guess than "born today" (PM report).
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? now,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _birthday = picked);
    }
  }

  Future<void> _submit(AuthController controller) async {
    final l10n = AppLocalizations.of(context)!;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_birthday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.petProfileFormBirthdayRequiredMessage)),
      );
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

      // Applied here rather than in the edit branch above so a brand-new
      // pet keeps its framing too -- createPet() takes no framing arguments,
      // so doing it there silently dropped it.
      pet = pet.copyWith(
        iconAlignmentX: _iconAlignmentX,
        iconAlignmentY: _iconAlignmentY,
        iconZoom: _iconZoom,
        backgroundAlignmentX: _backgroundAlignmentX,
        backgroundAlignmentY: _backgroundAlignmentY,
        backgroundZoom: _backgroundZoom,
      );

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
    final l10n = AppLocalizations.of(context)!;

    // Blocks back-navigation while a save (incl. photo upload) is in
    // flight -- otherwise leaving mid-upload (e.g. a system back gesture)
    // could land the user on another screen before the pet's photo URL is
    // actually persisted, making it look like the photo silently failed to
    // save (PM report: "写真データの送信が完了する前にほかの画面に移ると、
    // 写真登録がされません").
    return PopScope(
      canPop: !_isBusy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.petProfileFormSavingInProgressMessage)),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing
                ? l10n.petProfileFormEditTitle
                : l10n.petProfileFormAddTitle,
          ),
        ),
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
                          _buildIconSection(l10n),
                          const SizedBox(height: 24),
                          _buildBackgroundSection(l10n),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: l10n.petProfileFormNameLabel,
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? l10n.petProfileFormNameRequiredError
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _breedController,
                            decoration: InputDecoration(
                              labelText: l10n.petProfileFormBreedLabel,
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? l10n.petProfileFormBreedRequiredError
                                : null,
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              _birthday == null
                                  ? l10n.petProfileFormSelectBirthdayLabel
                                  : l10n.petProfileFormBirthdayLabel(
                                      DateFormat(
                                        'yyyy/MM/dd',
                                      ).format(_birthday!),
                                    ),
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: _pickBirthday,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<PetSex>(
                            initialValue: _sex,
                            decoration: InputDecoration(
                              labelText: l10n.petProfileFormSexLabel,
                            ),
                            items: PetSex.values
                                .map(
                                  (sex) => DropdownMenuItem(
                                    value: sex,
                                    child: Text(_sexLabel(l10n, sex)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) setState(() => _sex = value);
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.petProfileFormNeuteredLabel),
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
                            decoration: InputDecoration(
                              labelText: l10n.petProfileFormWeightLabel,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null;
                              }
                              return double.tryParse(value.trim()) == null
                                  ? l10n.petProfileFormWeightValidationError
                                  : null;
                            },
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: (_isBusy || controller.isLoading)
                                ? null
                                : () => _submit(controller),
                            child: Text(
                              _isEditing
                                  ? l10n.petProfileFormSaveButton
                                  : l10n.addPetButton,
                            ),
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
      ),
    );
  }

  /// [PetSex]'s own `.name` doubles as its display text (see the enum's doc
  /// comment), so localizing it means mapping the enum value to a
  /// translated string rather than swapping a literal in this file.
  String _sexLabel(AppLocalizations l10n, PetSex sex) {
    switch (sex) {
      case PetSex.male:
        return l10n.petSexOptionMale;
      case PetSex.female:
        return l10n.petSexOptionFemale;
    }
  }

  ImageProvider? _iconImageProvider() {
    if (_pickedIconBytes != null) return MemoryImage(_pickedIconBytes!);
    if (_iconUrl != null) return CachedNetworkImageProvider(_iconUrl!);
    return null;
  }

  Widget _buildIconSection(AppLocalizations l10n) {
    final iconImage = _iconImageProvider();
    const previewSize = 96.0;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.petProfileFormIconSectionTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
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
            label: Text(l10n.petProfileFormDeleteIconButton),
          ),
          // Framing happens on the crop screen now (PM request: pinch
          // inside the image like LINE/Facebook) instead of three sliders
          // under the preview. Only shown for a freshly picked photo --
          // an already-saved icon is a URL, and the crop screen needs bytes.
          if (_pickedIconBytes != null)
            TextButton.icon(
              onPressed: _adjustPickedIcon,
              icon: const Icon(Icons.crop_rotate, size: 18),
              label: Text(l10n.petProfileFormAdjustIconButton),
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

  Widget _buildBackgroundSection(AppLocalizations l10n) {
    final backgroundImage = _backgroundImageProvider();
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.petProfileFormBackgroundSectionTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
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
                : Transform.scale(
                    scale: _backgroundZoom,
                    alignment: Alignment(
                      _backgroundAlignmentX,
                      _backgroundAlignmentY,
                    ),
                    child: Image(
                      image: backgroundImage,
                      fit: BoxFit.cover,
                      alignment: Alignment(
                        _backgroundAlignmentX,
                        _backgroundAlignmentY,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _pickBackgroundPhoto,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: Text(l10n.petProfileFormChangeBackgroundButton),
            ),
            // Only for a freshly picked photo -- an already-saved
            // background is a URL, and the crop screen needs bytes.
            if (_pickedBackgroundBytes != null) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _adjustPickedBackground,
                icon: const Icon(Icons.crop_rotate, size: 18),
                label: Text(l10n.petProfileFormAdjustBackgroundButton),
              ),
            ],
            if (backgroundImage != null) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _deleteBackgroundPhoto,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(l10n.petProfileFormDeleteBackgroundButton),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

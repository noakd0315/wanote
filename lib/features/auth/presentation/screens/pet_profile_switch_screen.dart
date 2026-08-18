import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/models/pet_profile.dart';
import '../../../../shared/widgets/dog_silhouette_background.dart';
import '../../../../shared/widgets/pet_icon_avatar.dart';
import '../auth_controller.dart';
import 'pet_profile_form_screen.dart';

/// Lists every pet on the account and lets the user switch which one is
/// active, or add/edit/remove a pet (spec 1.4 - 多頭飼い対応：1アカウントで
/// 複数ペットプロフィールを切り替えられるようにする).
class PetProfileSwitchScreen extends StatelessWidget {
  const PetProfileSwitchScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    AppLocalizations l10n,
    AuthController controller,
    PetProfile pet,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removePetDialogTitle),
        content: Text(l10n.removePetDialogContent(pet.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.removePetDialogCancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.removePetDialogConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await controller.deletePet(pet.petId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();
    final l10n = AppLocalizations.of(context)!;
    final pets = controller.pets;
    final activePetId = controller.activePet?.petId;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.yourPetsScreenTitle)),
      body: Stack(
        children: [
          const Positioned.fill(child: DogSilhouetteBackground()),
          pets.isEmpty
              ? Center(child: Text(l10n.noPetsYetMessage))
              : ListView.builder(
                  itemCount: pets.length,
                  itemBuilder: (context, index) {
                    final pet = pets[index];
                    final isActive = pet.petId == activePetId;
                    return ListTile(
                      leading: PetIconAvatar(pet: pet),
                      // The name opens the pet's form, the way it does on
                      // Home (PM request, 2026-08-18). The rest of the row
                      // still switches -- that is what this screen is for
                      // -- so the two live side by side rather than one
                      // replacing the other.
                      title: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PetProfileFormScreen(existingPet: pet),
                          ),
                        ),
                        child: Text(pet.name),
                      ),
                      subtitle: Text(pet.breed),
                      selected: isActive,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isActive)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.check_circle),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PetProfileFormScreen(existingPet: pet),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                _confirmDelete(context, l10n, controller, pet),
                          ),
                        ],
                      ),
                      onTap: () => controller.switchActivePet(pet.petId),
                    );
                  },
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PetProfileFormScreen())),
        icon: const Icon(Icons.add),
        label: Text(l10n.addPetButton),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/models/pet_profile.dart';
import '../auth_controller.dart';
import 'pet_profile_form_screen.dart';

/// Lists every pet on the account and lets the user switch which one is
/// active, or add/edit/remove a pet (spec 1.4 - 多頭飼い対応：1アカウントで
/// 複数ペットプロフィールを切り替えられるようにする).
class PetProfileSwitchScreen extends StatelessWidget {
  const PetProfileSwitchScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    AuthController controller,
    PetProfile pet,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove pet'),
        content: Text('Remove ${pet.name} from this account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
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
    final pets = controller.pets;
    final activePetId = controller.activePet?.petId;

    return Scaffold(
      appBar: AppBar(title: const Text('Your pets')),
      body: pets.isEmpty
          ? const Center(child: Text('No pets yet. Add your first pet below.'))
          : ListView.builder(
              itemCount: pets.length,
              itemBuilder: (context, index) {
                final pet = pets[index];
                final isActive = pet.petId == activePetId;
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      pet.name.isNotEmpty ? pet.name[0].toUpperCase() : '?',
                    ),
                  ),
                  title: Text(pet.name),
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
                            _confirmDelete(context, controller, pet),
                      ),
                    ],
                  ),
                  onTap: () => controller.switchActivePet(pet.petId),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PetProfileFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add pet'),
      ),
    );
  }
}

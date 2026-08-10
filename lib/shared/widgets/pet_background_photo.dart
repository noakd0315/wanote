import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/pet_profile.dart';

/// The pet's full-bleed Home screen photo, framed by the owner.
///
/// Mirrors [PetIconAvatar]'s composition exactly -- cover-fit with an
/// alignment, then `Transform.scale` about that same alignment -- and
/// `PhotoCropScreen` rebuilds the same tree for its preview, so what the
/// owner frames is what appears here. Change one of the three and the other
/// two have to follow.
class PetBackgroundPhoto extends StatelessWidget {
  const PetBackgroundPhoto({
    super.key,
    required this.pet,
    required this.errorWidget,
  });

  final PetProfile pet;

  /// Shown when the photo can't be loaded -- the Home screen falls back to
  /// its default illustration rather than a broken-image icon.
  final Widget errorWidget;

  @override
  Widget build(BuildContext context) {
    final alignment = Alignment(
      pet.backgroundAlignmentX,
      pet.backgroundAlignmentY,
    );
    return ClipRect(
      child: Transform.scale(
        scale: pet.backgroundZoom,
        alignment: alignment,
        child: CachedNetworkImage(
          imageUrl: pet.photoUrl!,
          fit: BoxFit.cover,
          alignment: alignment,
          errorWidget: (context, url, error) => errorWidget,
        ),
      ),
    );
  }
}

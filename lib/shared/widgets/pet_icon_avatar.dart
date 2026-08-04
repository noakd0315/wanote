import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/pet_profile.dart';

/// Small circular pet icon/avatar, used wherever a pet needs a compact
/// representation (settings, pet switcher) rather than the Home screen's
/// full-bleed background photo.
///
/// Prefers [PetProfile.iconPhotoUrl]; falls back to [PetProfile.photoUrl]
/// so a pet that only ever had a background photo uploaded still shows
/// *something* here instead of a blank placeholder (PM request: "愛犬アイ
/// コンと背景は別々の画像を設定できるようにしたい" -- separate fields, but a
/// sane fallback for pets created before this distinction existed).
/// [PetProfile.iconAlignmentX]/[iconAlignmentY]/[iconZoom] control how that
/// source photo is cropped within the circle (PM request: "出力するアイコン
/// について表示位置やサイズを設定できるように").
class PetIconAvatar extends StatelessWidget {
  const PetIconAvatar({super.key, required this.pet, this.radius = 24});

  final PetProfile pet;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = pet.iconPhotoUrl ?? pet.photoUrl;
    if (url == null || url.isEmpty) {
      return CircleAvatar(radius: radius, child: const Icon(Icons.pets));
    }
    final size = radius * 2;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Transform.scale(
          scale: pet.iconZoom,
          alignment: Alignment(pet.iconAlignmentX, pet.iconAlignmentY),
          child: CachedNetworkImage(
            imageUrl: url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            alignment: Alignment(pet.iconAlignmentX, pet.iconAlignmentY),
            errorWidget: (context, url, error) =>
                const Icon(Icons.pets, size: 20),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'app_colors.dart';

class BillerOption {
  final String serviceId;
  final String name;
  final Color color;

  const BillerOption({
    required this.serviceId,
    required this.name,
    required this.color,
  });

  /// Short label for the circle avatar — first letters, uppercase.
  String get shortLabel {
    final words = name.split(' ');
    if (words.length == 1)
      return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }
}

/// The Opay-style grid of provider logos (network/DISCO/cable provider)
/// — a circular colored avatar with initials (no bundled logo assets),
/// name below, selected state highlighted with a teal ring.
class BillerGrid extends StatelessWidget {
  final List<BillerOption> options;
  final BillerOption? selected;
  final void Function(BillerOption) onSelect;

  const BillerGrid({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      mainAxisSpacing: 16,
      crossAxisSpacing: 8,
      childAspectRatio: 0.8,
      physics: const NeverScrollableScrollPhysics(),
      children: options.map((option) {
        final isSelected = selected?.serviceId == option.serviceId;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onSelect(option),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: option.color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: AppColors.teal, width: 3)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  option.shortLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                option.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.teal : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

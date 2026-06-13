import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/village_model.dart';

class VillageSelectorSheet extends StatefulWidget {
  final List<VillageModel> villages;
  final String? excludeVillageId;
  final ValueChanged<VillageModel> onSelected;

  const VillageSelectorSheet({
    super.key,
    required this.villages,
    required this.onSelected,
    this.excludeVillageId,
  });

  static Future<VillageModel?> show(
    BuildContext context, {
    required List<VillageModel> villages,
    String? excludeVillageId,
  }) {
    return showModalBottomSheet<VillageModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => VillageSelectorSheet(
        villages: villages,
        excludeVillageId: excludeVillageId,
        onSelected: (v) => Navigator.pop(context, v),
      ),
    );
  }

  @override
  State<VillageSelectorSheet> createState() => _VillageSelectorSheetState();
}

class _VillageSelectorSheetState extends State<VillageSelectorSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.villages
        .where((v) =>
            v.id != widget.excludeVillageId &&
            (v.name.toLowerCase().contains(_search.toLowerCase()) ||
                v.nameGu.contains(_search)))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'ગામ શોધો / Search village',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final v = filtered[i];
                return ListTile(
                  leading: const Icon(Icons.location_on,
                      color: AppColors.primaryGreen),
                  title: Text(v.nameGu,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(v.name),
                  onTap: () => widget.onSelected(v),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

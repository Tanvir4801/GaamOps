import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/village_model.dart';

class VillageSelectorSheet extends StatefulWidget {
  final List<VillageModel> villages;
  final String? excludeVillageId;
  final String? currentVillageName;
  final ValueChanged<VillageModel> onSelected;

  const VillageSelectorSheet({
    super.key,
    required this.villages,
    required this.onSelected,
    this.excludeVillageId,
    this.currentVillageName,
  });

  static Future<VillageModel?> show(
    BuildContext context, {
    required List<VillageModel> villages,
    String? excludeVillageId,
    String? currentVillageName,
  }) {
    return showModalBottomSheet<VillageModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VillageSelectorSheet(
        villages: villages,
        excludeVillageId: excludeVillageId,
        currentVillageName: currentVillageName,
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              'ક્યાં જવું છે? / Where to go?',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: AppColors.textGrey),
                hintText: 'ગામ શોધો / Search village',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_off,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        const Text(
                          'No village found',
                          style: TextStyle(color: AppColors.textGrey),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, thickness: 0.5),
                    itemBuilder: (_, i) {
                      final v = filtered[i];
                      final isCurrent =
                          widget.currentVillageName != null &&
                              v.name == widget.currentVillageName;
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        leading: CircleAvatar(
                          backgroundColor: isCurrent
                              ? Colors.grey.shade200
                              : AppColors.bgGreen,
                          child: Text(
                            v.nameGu.isNotEmpty ? v.nameGu[0] : v.name[0],
                            style: TextStyle(
                              color: isCurrent
                                  ? Colors.grey
                                  : AppColors.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          v.nameGu,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          v.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: isCurrent
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'તમે અહીં છો',
                                  style: TextStyle(fontSize: 10),
                                ),
                              )
                            : const Icon(Icons.chevron_right,
                                color: AppColors.textLight, size: 18),
                        enabled: !isCurrent,
                        onTap: isCurrent
                            ? null
                            : () => widget.onSelected(v),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

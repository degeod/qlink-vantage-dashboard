import 'package:flutter/material.dart';

import '../device_icons.dart';
import '../theme/app_theme.dart';
import 'device_icon_view.dart';

Future<String?> showIconTypePicker(
  BuildContext context, {
  required String currentType,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.charcoalElevated,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.muted.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text('Type / icoon', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text(
                'Material-iconen + PNG-varianten (… 1, wit)',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.55,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: DeviceIcons.all.length,
                  itemBuilder: (_, i) {
                    final t = DeviceIcons.all[i];
                    final selected = t.id == currentType;
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(ctx, t.id),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected ? AppColors.amberSoft : const Color(0x2212151A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? AppColors.amber : Colors.transparent,
                          ),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DeviceIconView(
                              typeId: t.id,
                              isOn: true,
                              size: 25,
                              color: selected ? AppColors.amber : AppColors.ink,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: selected ? AppColors.amber : AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

import 'package:flutter/material.dart';

import 'models.dart';
import 'state.dart';
import 'utils.dart';

Color levelColor(DueLevel l, BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  switch (l) {
    case DueLevel.overdue:
      return dark ? const Color(0xFFFF8A80) : const Color(0xFFC62828);
    case DueLevel.soon:
      return dark ? const Color(0xFFFFCC80) : const Color(0xFFE65100);
    case DueLevel.ok:
      return dark ? const Color(0xFFA5D6A7) : const Color(0xFF2E7D32);
    case DueLevel.unknown:
      return Theme.of(context).colorScheme.outline;
  }
}

String levelLabel(DueLevel l) => switch (l) {
      DueLevel.overdue => 'متأخر',
      DueLevel.soon => 'قرّب',
      DueLevel.ok => 'تمام',
      DueLevel.unknown => 'غير محدد',
    };

class LevelChip extends StatelessWidget {
  final DueLevel level;
  const LevelChip(this.level, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = levelColor(level, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(levelLabel(level),
          style: TextStyle(
              color: c, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState(
      {super.key,
      required this.icon,
      required this.text,
      this.actionLabel,
      this.onAction});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: cs.outline),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add),
                  label: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  const StatCard(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// حقل تاريخ
class DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.clearable = false,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: firstDate ?? DateTime(1990),
          lastDate: lastDate ?? DateTime(2100),
        );
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event),
          suffixIcon: clearable && value != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(null))
              : null,
        ),
        child: Text(value == null ? 'اختار تاريخ' : fmtDate(value)),
      ),
    );
  }
}

/// حقل رقم
class NumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final IconData? icon;
  final bool decimal;
  final bool required;
  final ValueChanged<String>? onChanged;

  const NumField({
    super.key,
    required this.controller,
    required this.label,
    this.suffix,
    this.icon,
    this.decimal = false,
    this.required = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
      onChanged: onChanged,
      validator: (v) {
        final t = v ?? '';
        if (t.trim().isEmpty) return required ? 'مطلوب' : null;
        final n = decimal ? parseDouble(t) : parseInt(t);
        if (n == null) return 'رقم غير صحيح';
        if (n < 0) return 'لازم يكون رقم موجب';
        return null;
      },
    );
  }
}

class VehicleDropdown extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  const VehicleDropdown(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final vs = AppData.instance.vehicles;
    return DropdownButtonFormField<int>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'المركبة'),
      items: [
        for (final v in vs)
          DropdownMenuItem(
            value: v.id!,
            child: Row(children: [
              Icon(vehicleTypeIcon(v.type), size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(v.displayName, overflow: TextOverflow.ellipsis)),
            ]),
          ),
      ],
      onChanged: onChanged,
      validator: (v) => v == null ? 'اختار المركبة' : null,
    );
  }
}

/// رسم أعمدة بسيط
class BarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final String Function(double)? format;
  final double height;
  const BarChart(
      {super.key,
      required this.labels,
      required this.values,
      this.format,
      this.height = 180});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxV = values.fold<double>(0, (a, b) => b > a ? b : a);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Tooltip(
                message: format?.call(values[i]) ?? fmtNum(values[i]),
                triggerMode: TooltipTriggerMode.tap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: maxV <= 0
                              ? 0.01
                              : (values[i] / maxV).clamp(0.01, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: values[i] > 0
                                  ? cs.primary
                                  : cs.surfaceContainerHighest,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                              fontSize: 9, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// شريط نسبة لتوزيع التكاليف
class ShareRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final double total;
  final String cur;
  const ShareRow(
      {super.key,
      required this.label,
      required this.icon,
      required this.value,
      required this.total,
      required this.cur});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = total <= 0 ? 0.0 : value / total;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(label)),
                  Text(fmtMoney(value, cur),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
              width: 40,
              child: Text('${(pct * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
        ],
      ),
    );
  }
}

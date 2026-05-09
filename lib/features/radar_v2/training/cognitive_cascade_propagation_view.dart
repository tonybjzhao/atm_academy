import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'cognitive_cascade_propagation.dart';

class CognitiveCascadePropagationView extends StatefulWidget {
  final CognitiveCascadePropagationData data;
  final Duration selectedElapsed;
  final ValueChanged<Duration> onJump;

  const CognitiveCascadePropagationView({
    super.key,
    required this.data,
    required this.selectedElapsed,
    required this.onJump,
  });

  @override
  State<CognitiveCascadePropagationView> createState() =>
      _CognitiveCascadePropagationViewState();
}

class _CognitiveCascadePropagationViewState
    extends State<CognitiveCascadePropagationView> {
  String? _selectedNodeId;

  @override
  Widget build(BuildContext context) {
    if (widget.data.chains.isEmpty) {
      return const Text(
        'No cascade propagation detected in this replay.',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Cascade Propagation',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${widget.data.chains.length} chain(s)  T+${widget.selectedElapsed.inSeconds}s',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final chain in widget.data.chains) ...[
          _ChainHeader(title: chain.title),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < chain.nodes.length; i++) ...[
                  _PropagationNodeCard(
                    node: chain.nodes[i],
                    selected: _selectedNodeId == chain.nodes[i].id,
                    onTap: () => _selectNode(chain.nodes[i]),
                  ),
                  if (i < chain.nodes.length - 1)
                    _PropagationEdgeColumn(
                      edge: chain.edges[i],
                      expanded: _selectedNodeId == chain.nodes[i].id ||
                          _selectedNodeId == chain.nodes[i + 1].id,
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  void _selectNode(CascadePropagationNode node) {
    setState(() => _selectedNodeId = node.id);
    widget.onJump(node.timestamp);
  }
}

class _ChainHeader extends StatelessWidget {
  final String title;

  const _ChainHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _PropagationNodeCard extends StatelessWidget {
  final CascadePropagationNode node;
  final bool selected;
  final VoidCallback onTap;

  const _PropagationNodeCard({
    required this.node,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _nodeColor(node.type);
    final width = 126 + node.visualWeight * 36;
    final glowAlpha = selected ? 0.28 : 0.08 + node.visualWeight * 0.08;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        constraints: const BoxConstraints(minHeight: 118),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF071625),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? accent
                : accent.withValues(alpha: 0.42 + node.visualWeight * 0.3),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: glowAlpha),
              blurRadius: selected ? 18 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_nodeIcon(node.type), color: accent, size: 16),
                const Spacer(),
                Text(
                  'T+${node.timestamp.inSeconds}s',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              node.label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              node.detail,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                height: 1.25,
              ),
            ),
            const Spacer(),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: node.visualWeight,
              minHeight: 3,
              backgroundColor: AppTheme.borderColor.withValues(alpha: 0.45),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _PropagationEdgeColumn extends StatelessWidget {
  final CascadePropagationEdge edge;
  final bool expanded;

  const _PropagationEdgeColumn({
    required this.edge,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expanded ? 152 : 48,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
        child: Column(
          children: [
            Icon(
              Icons.arrow_forward,
              color: AppTheme.primary.withValues(alpha: 0.75),
              size: 18,
            ),
            const SizedBox(height: 8),
            if (expanded)
              Text(
                edge.explanation,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  height: 1.25,
                ),
              )
            else
              Container(
                height: 3,
                width: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(
                    alpha: 0.28 + edge.confidence * 0.34,
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Color _nodeColor(CascadePropagationNodeType type) {
  return switch (type) {
    CascadePropagationNodeType.fixation => Colors.amberAccent,
    CascadePropagationNodeType.scanNeglect => AppTheme.warning,
    CascadePropagationNodeType.workingMemoryFailure => Colors.lightBlueAccent,
    CascadePropagationNodeType.expectationDrift => Colors.cyanAccent,
    CascadePropagationNodeType.missedConflict => AppTheme.danger,
    CascadePropagationNodeType.overloadIncrease => Colors.deepOrangeAccent,
    CascadePropagationNodeType.confidenceErosion => Colors.purpleAccent,
    CascadePropagationNodeType.delayedIntervention => AppTheme.warning,
    CascadePropagationNodeType.recoveryInterruption => Colors.orangeAccent,
    CascadePropagationNodeType.stabilization => Colors.greenAccent,
    CascadePropagationNodeType.recoveryBreakdown => AppTheme.danger,
  };
}

IconData _nodeIcon(CascadePropagationNodeType type) {
  return switch (type) {
    CascadePropagationNodeType.fixation => Icons.center_focus_strong,
    CascadePropagationNodeType.scanNeglect => Icons.visibility_off_outlined,
    CascadePropagationNodeType.workingMemoryFailure => Icons.pending_actions,
    CascadePropagationNodeType.expectationDrift => Icons.route_outlined,
    CascadePropagationNodeType.missedConflict => Icons.warning_amber_rounded,
    CascadePropagationNodeType.overloadIncrease => Icons.speed,
    CascadePropagationNodeType.confidenceErosion => Icons.trending_down,
    CascadePropagationNodeType.delayedIntervention => Icons.timer_outlined,
    CascadePropagationNodeType.recoveryInterruption => Icons.call_split,
    CascadePropagationNodeType.stabilization => Icons.healing,
    CascadePropagationNodeType.recoveryBreakdown => Icons.report_problem,
  };
}

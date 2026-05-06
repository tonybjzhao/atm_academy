import '../core/models/localized_text.dart';
import '../core/models/scenario.dart';

const List<Scenario> allScenarios = [

  // ── S1: Same-level crossing ─────────────────────────────────────────────
  // QFA heading east, UAE heading west, same FL320.
  // Start 250 px apart → ~7 s to LOS at default speed.
  // Lesson: any early heading change creates lateral separation.
  Scenario(
    id: 'basic_crossing_same_level',
    level: 1,
    skill: 'separation',
    timeLimitSeconds: 30,
    title: LocalizedText(
      en: 'Crossing Traffic at Same Level',
      zh: '同高度交叉冲突',
      fr: 'Trafic croisé au même niveau',
    ),
    objective: LocalizedText(
      en: 'Resolve the conflict before the aircraft lose separation.',
      zh: '在飞机失去间隔前解除冲突。',
      fr: 'Résolvez le conflit avant que les aéronefs perdent leur séparation.',
    ),
    aircraft: [
      ScenarioAircraftConfig(callsign: 'QFA123', x: 60,  y: 210, heading: 90,  speed: 0.80, altitude: 320),
      ScenarioAircraftConfig(callsign: 'UAE406', x: 310, y: 210, heading: 270, speed: 0.80, altitude: 320),
    ],
    conflictRules: ConflictRules(
      minHorizontalDistancePx: 55,
      minVerticalSeparationFL: 10,
    ),
    maintainSafeSeparationForSeconds: 5,
    feedback: ScenarioFeedbackMessages(
      success: LocalizedText(
        en: 'Good control. Turning QFA123 early created lateral separation before the conflict developed.',
        zh: '处理正确。提前让 QFA123 转向，在冲突形成前建立了横向间隔。',
        fr: 'Bon contrôle. Virer QFA123 tôt a créé une séparation latérale avant que le conflit se développe.',
      ),
      late: LocalizedText(
        en: 'Action came late. The aircraft were already inside the warning zone when you acted.',
        zh: '动作太晚。当你行动时，飞机已经进入警告区。',
        fr: 'Action tardive. Les aéronefs étaient déjà dans la zone d\'alerte lorsque vous avez agi.',
      ),
      wrong: LocalizedText(
        en: 'That command did not improve separation. Try turning one aircraft away from the other.',
        zh: '该指令未改善间隔。尝试让一架飞机转向远离另一架。',
        fr: 'Cette instruction n\'a pas amélioré la séparation. Essayez de virer un aéronef pour l\'éloigner de l\'autre.',
      ),
      los: LocalizedText(
        en: 'Loss of separation occurred. Act earlier next time — turn before entering the warning zone.',
        zh: '发生了间隔丢失。下次要更早行动——在进入警告区之前转向。',
        fr: 'Perte de séparation. Agissez plus tôt la prochaine fois — virez avant d\'entrer dans la zone d\'alerte.',
      ),
    ),
  ),

  // ── S2: Head-on, urgent altitude fix ────────────────────────────────────
  // Direct head-on, 130 px apart, fast speed → conflict in ~2 s.
  // Heading alone is too slow; altitude change resolves it instantly.
  Scenario(
    id: 'head_on_altitude',
    level: 2,
    skill: 'altitude',
    timeLimitSeconds: 25,
    title: LocalizedText(
      en: 'Head-On Traffic — Altitude Solution',
      zh: '迎头冲突——高度解决方案',
      fr: 'Trafic en face — Solution d\'altitude',
    ),
    objective: LocalizedText(
      en: 'Aircraft are head-on at the same altitude. Climb or descend one aircraft immediately.',
      zh: '飞机在同一高度迎头飞行。立即让一架飞机爬升或下降。',
      fr: 'Les aéronefs sont face à face à la même altitude. Montez ou descendez un aéronef immédiatement.',
    ),
    aircraft: [
      ScenarioAircraftConfig(callsign: 'QFA123', x: 120, y: 205, heading: 90,  speed: 0.90, altitude: 320),
      ScenarioAircraftConfig(callsign: 'UAE406', x: 250, y: 210, heading: 270, speed: 0.90, altitude: 320),
    ],
    conflictRules: ConflictRules(
      minHorizontalDistancePx: 55,
      minVerticalSeparationFL: 10,
    ),
    maintainSafeSeparationForSeconds: 5,
    feedback: ScenarioFeedbackMessages(
      success: LocalizedText(
        en: 'Correct. Vertical separation provides instant protection when horizontal distance is small.',
        zh: '正确。当横向距离很小时，垂直间隔能提供即时保护。',
        fr: 'Correct. La séparation verticale offre une protection instantanée quand la distance horizontale est faible.',
      ),
      late: LocalizedText(
        en: 'Too late. The aircraft needed immediate action — a heading change alone is too slow head-on.',
        zh: '太晚了。飞机需要立即行动——迎头时单纯改变航向太慢。',
        fr: 'Trop tard. Un virage seul est trop lent en face à face — agissez immédiatement.',
      ),
      wrong: LocalizedText(
        en: 'Heading change is too slow here. Use climb or descend for instant vertical separation.',
        zh: '这里改变航向太慢。使用爬升或下降来立即建立垂直间隔。',
        fr: 'Le changement de cap est trop lent ici. Utilisez la montée ou la descente.',
      ),
      los: LocalizedText(
        en: 'Loss of separation. In a head-on scenario altitude change must come within 2–3 seconds.',
        zh: '间隔丢失。在迎头场景中，高度调整必须在2-3秒内完成。',
        fr: 'Perte de séparation. Dans un face à face, le changement d\'altitude doit intervenir en 2–3 secondes.',
      ),
    ),
  ),

  // ── S3: Converging, altitude preferred ──────────────────────────────────
  // Two aircraft converging at ~30° angle. AltDiff = 5 FL (below 10 FL min).
  // Either heading or altitude works, but altitude is faster at this speed.
  Scenario(
    id: 'converging_altitude_option',
    level: 3,
    skill: 'mixed',
    timeLimitSeconds: 35,
    title: LocalizedText(
      en: 'Converging Traffic — Altitude or Heading',
      zh: '汇聚冲突——高度或航向',
      fr: 'Trafic convergent — Altitude ou cap',
    ),
    objective: LocalizedText(
      en: 'Two aircraft are converging with only 5 FL vertical gap. Use heading or altitude to separate.',
      zh: '两架飞机正在汇聚，垂直间隔仅5个飞行高度层。用航向或高度来分离它们。',
      fr: 'Deux aéronefs convergent avec seulement 5 FL d\'écart vertical. Utilisez le cap ou l\'altitude.',
    ),
    aircraft: [
      ScenarioAircraftConfig(callsign: 'QFA123', x: 80,  y: 260, heading: 45,  speed: 0.75, altitude: 320),
      ScenarioAircraftConfig(callsign: 'UAE406', x: 275, y: 160, heading: 225, speed: 0.75, altitude: 325),
      ScenarioAircraftConfig(callsign: 'THA789', x: 90,  y: 90,  heading: 150, speed: 0.55, altitude: 280),
    ],
    conflictRules: ConflictRules(
      minHorizontalDistancePx: 55,
      minVerticalSeparationFL: 10,
    ),
    maintainSafeSeparationForSeconds: 5,
    feedback: ScenarioFeedbackMessages(
      success: LocalizedText(
        en: 'Well handled. Either a heading change or a 5+ FL altitude adjustment restores full separation.',
        zh: '处理得当。航向变化或5个飞行高度层以上的高度调整都能恢复完整间隔。',
        fr: 'Bien géré. Un changement de cap ou un ajustement de 5+ FL restaure la séparation complète.',
      ),
      late: LocalizedText(
        en: 'You acted after the conflict was already inside the warning zone. Earlier action is safer.',
        zh: '你在冲突已进入警告区后才行动。更早行动更安全。',
        fr: 'Vous avez agi après que le conflit était déjà dans la zone d\'alerte. Agir plus tôt est plus sûr.',
      ),
      wrong: LocalizedText(
        en: 'That command worsened or did not improve separation. Try heading away or climbing 5+ FL.',
        zh: '该指令使间隔变差或没有改善。尝试转向远离或爬升5个飞行高度层以上。',
        fr: 'Cette instruction a aggravé ou n\'a pas amélioré la séparation. Essayez de virer ou de monter 5+ FL.',
      ),
      los: LocalizedText(
        en: 'Loss of separation. Remember: only 5 FL gap existed — either heading or altitude must be used earlier.',
        zh: '间隔丢失。记住：初始间隔只有5个飞行高度层——航向或高度调整必须更早执行。',
        fr: 'Perte de séparation. Seulement 5 FL d\'écart au départ — agissez plus tôt.',
      ),
    ),
  ),

  // ── S4: Overtaking traffic ───────────────────────────────────────────────
  // QFA (fast) is catching UAE (slow) on the same heading.
  // Speed reduction on QFA is the intended solution.
  Scenario(
    id: 'overtaking_speed_control',
    level: 4,
    skill: 'speed',
    timeLimitSeconds: 35,
    title: LocalizedText(
      en: 'Overtaking Traffic — Speed Control',
      zh: '追及交通——速度控制',
      fr: 'Dépassement — Contrôle de vitesse',
    ),
    objective: LocalizedText(
      en: 'QFA123 is catching UAE406. Slow QFA123 to restore longitudinal spacing.',
      zh: 'QFA123 正在追上 UAE406。减慢 QFA123 的速度，恢复纵向间隔。',
      fr: 'QFA123 rattrape UAE406. Ralentissez QFA123 pour restaurer l\'espacement longitudinal.',
    ),
    aircraft: [
      ScenarioAircraftConfig(callsign: 'QFA123', x: 55,  y: 210, heading: 90, speed: 1.25, altitude: 320),
      ScenarioAircraftConfig(callsign: 'UAE406', x: 155, y: 210, heading: 90, speed: 0.70, altitude: 320),
      ScenarioAircraftConfig(callsign: 'THA789', x: 240, y: 130, heading: 210, speed: 0.60, altitude: 280),
    ],
    conflictRules: ConflictRules(
      minHorizontalDistancePx: 55,
      minVerticalSeparationFL: 10,
    ),
    maintainSafeSeparationForSeconds: 5,
    feedback: ScenarioFeedbackMessages(
      success: LocalizedText(
        en: 'Correct speed management. Slowing QFA123 restored the longitudinal gap without a heading change.',
        zh: '速度管理正确。减慢 QFA123 恢复了纵向间隔，无需改变航向。',
        fr: 'Bonne gestion de la vitesse. Ralentir QFA123 a restauré l\'écart longitudinal sans changement de cap.',
      ),
      late: LocalizedText(
        en: 'You acted too late. Speed corrections need more lead time than heading changes.',
        zh: '行动太晚。速度修正比航向改变需要更多的提前时间。',
        fr: 'Trop tard. Les corrections de vitesse nécessitent plus d\'anticipation que les changements de cap.',
      ),
      wrong: LocalizedText(
        en: 'Heading change moves aircraft off track. Use Slow on the trailing aircraft instead.',
        zh: '改变航向会使飞机偏离航迹。对后方飞机使用减速指令。',
        fr: 'Le changement de cap fait dévier l\'aéronef. Utilisez Ralentir sur l\'aéronef qui suit.',
      ),
      los: LocalizedText(
        en: 'Loss of separation. With a 100 px gap and speed difference of 0.55, you had about 3–4 seconds to act.',
        zh: '间隔丢失。100像素间隔，速差0.55，只有约3-4秒的反应时间。',
        fr: 'Perte de séparation. Avec 100 px et une différence de vitesse de 0.55, vous aviez 3–4 secondes.',
      ),
    ),
  ),

  // ── S5: Three-aircraft, two pairs ────────────────────────────────────────
  // QFA and UAE crossing (same FL), THA approaching from north.
  // Requires managing workload: resolve the closest conflict first.
  Scenario(
    id: 'three_aircraft_complexity',
    level: 5,
    skill: 'mixed',
    timeLimitSeconds: 45,
    title: LocalizedText(
      en: 'Three Aircraft — Manage Workload',
      zh: '三机场景——工作负荷管理',
      fr: 'Trois aéronefs — Gérer la charge de travail',
    ),
    objective: LocalizedText(
      en: 'Three aircraft are converging. Prioritise the most critical pair and resolve each conflict.',
      zh: '三架飞机正在汇聚。优先处理最关键的一对，逐步解除每个冲突。',
      fr: 'Trois aéronefs convergent. Priorisez la paire la plus critique et résolvez chaque conflit.',
    ),
    aircraft: [
      ScenarioAircraftConfig(callsign: 'QFA123', x: 70,  y: 205, heading: 85,  speed: 0.80, altitude: 320),
      ScenarioAircraftConfig(callsign: 'UAE406', x: 300, y: 210, heading: 265, speed: 0.75, altitude: 320),
      ScenarioAircraftConfig(callsign: 'THA789', x: 185, y: 75,  heading: 155, speed: 0.65, altitude: 320),
    ],
    conflictRules: ConflictRules(
      minHorizontalDistancePx: 55,
      minVerticalSeparationFL: 10,
    ),
    maintainSafeSeparationForSeconds: 5,
    feedback: ScenarioFeedbackMessages(
      success: LocalizedText(
        en: 'Excellent situational awareness. Scanning all aircraft and prioritising correctly is the key controller skill.',
        zh: '情景意识出色。扫描所有飞机并正确排列优先级是管制员的核心技能。',
        fr: 'Excellente conscience situationnelle. Scanner tous les aéronefs et prioriser correctement est la compétence clé.',
      ),
      late: LocalizedText(
        en: 'You focused on one conflict but the other developed. Keep scanning — do not fixate on a single pair.',
        zh: '你专注于一个冲突，但另一个冲突出现了。保持扫描——不要只盯着一对飞机。',
        fr: 'Vous vous êtes concentré sur un conflit mais l\'autre s\'est développé. Continuez à scanner.',
      ),
      wrong: LocalizedText(
        en: 'That command moved the wrong aircraft or worsened the situation. Identify the closest pair first.',
        zh: '该指令移动了错误的飞机或使情况变糟。先确定最近的一对。',
        fr: 'Cette instruction a déplacé le mauvais aéronef. Identifiez d\'abord la paire la plus proche.',
      ),
      los: LocalizedText(
        en: 'Loss of separation. In complex traffic, resolve the highest-priority conflict first, then reassess.',
        zh: '间隔丢失。在复杂交通中，先解决最高优先级的冲突，然后重新评估。',
        fr: 'Perte de séparation. En trafic complexe, résolvez d\'abord le conflit de plus haute priorité.',
      ),
    ),
  ),
];

import '../core/models/lesson.dart';
import '../core/models/localized_text.dart';
import '../core/models/quiz_question.dart';

final List<Lesson> lessonsData = [
  Lesson(
    id: 'what_is_atm',
    level: LessonLevel.beginner,
    animationType: AnimationType.none,
    title: LocalizedText(
      en: 'What is ATM?',
      zh: '什么是空中交通管理？',
      fr: 'Qu\'est-ce que la GTA ?',
    ),
    summary: LocalizedText(
      en: 'Air Traffic Management keeps aircraft moving safely and efficiently across the world.',
      zh: '空中交通管理确保全球航空器安全高效地运行。',
      fr: 'La gestion du trafic aérien assure un mouvement sûr et efficace des aéronefs dans le monde.',
    ),
    keyPoints: [
      LocalizedText(
        en: 'ATM = Air Traffic Management: the dynamic, integrated management of air traffic.',
        zh: 'ATM即空中交通管理：对空中交通进行动态综合管理。',
        fr: 'GTA = Gestion du Trafic Aérien : gestion intégrée et dynamique du trafic aérien.',
      ),
      LocalizedText(
        en: 'Three pillars: Air Traffic Control (ATC), Airspace Management (ASM), Air Traffic Flow Management (ATFM).',
        zh: '三大支柱：空中交通管制（ATC）、空域管理（ASM）、空中交通流量管理（ATFM）。',
        fr: 'Trois piliers : Contrôle du trafic aérien (ATC), Gestion de l\'espace aérien (ASM), Gestion des flux (ATFM).',
      ),
      LocalizedText(
        en: 'Core goals: Safety, Efficiency, Order, and Capacity.',
        zh: '核心目标：安全、效率、秩序和容量。',
        fr: 'Objectifs fondamentaux : Sécurité, Efficacité, Ordre et Capacité.',
      ),
    ],
    quiz: [
      QuizQuestion(
        question: LocalizedText(
          en: 'What does ATM stand for?',
          zh: 'ATM代表什么？',
          fr: 'Que signifie GTA ?',
        ),
        options: [
          LocalizedText(en: 'Automated Teller Machine', zh: '自动取款机', fr: 'Distributeur automatique'),
          LocalizedText(en: 'Air Traffic Management', zh: '空中交通管理', fr: 'Gestion du Trafic Aérien'),
          LocalizedText(en: 'Aircraft Terminal Monitor', zh: '航空终端监控', fr: 'Moniteur terminal d\'aéronef'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'ATM stands for Air Traffic Management — the system that keeps all aircraft safe and efficient.',
          zh: 'ATM代表空中交通管理——保障所有航空器安全高效运行的系统。',
          fr: 'GTA signifie Gestion du Trafic Aérien — le système qui assure la sécurité et l\'efficacité de tous les aéronefs.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'Which of these is NOT one of the three pillars of ATM?',
          zh: '以下哪项不是ATM的三大支柱之一？',
          fr: 'Lequel de ces éléments n\'est PAS l\'un des trois piliers de la GTA ?',
        ),
        options: [
          LocalizedText(en: 'Air Traffic Control', zh: '空中交通管制', fr: 'Contrôle du trafic aérien'),
          LocalizedText(en: 'Airline ticketing', zh: '航空售票', fr: 'Vente de billets'),
          LocalizedText(en: 'Airspace Management', zh: '空域管理', fr: 'Gestion de l\'espace aérien'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'Airline ticketing is a commercial function, not part of ATM. The three pillars are ATC, ASM, and ATFM.',
          zh: '航空售票是商业功能，不属于ATM。三大支柱是ATC、ASM和ATFM。',
          fr: 'La vente de billets est une fonction commerciale, pas une partie de la GTA. Les trois piliers sont ATC, ASM et ATFM.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'What is the primary goal of ATM?',
          zh: 'ATM的首要目标是什么？',
          fr: 'Quel est l\'objectif principal de la GTA ?',
        ),
        options: [
          LocalizedText(en: 'Maximize airline profit', zh: '最大化航空公司利润', fr: 'Maximiser les profits des compagnies aériennes'),
          LocalizedText(en: 'Safety and efficient movement of aircraft', zh: '航空器的安全高效运行', fr: 'Sécurité et mouvement efficace des aéronefs'),
          LocalizedText(en: 'Reduce fuel prices', zh: '降低燃油价格', fr: 'Réduire les prix du carburant'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'Safety is always the first priority in ATM, followed by efficiency and order.',
          zh: '安全始终是ATM的首要优先级，其次是效率和秩序。',
          fr: 'La sécurité est toujours la première priorité en GTA, suivie de l\'efficacité et de l\'ordre.',
        ),
      ),
    ],
  ),

  Lesson(
    id: 'airspace_basics',
    level: LessonLevel.beginner,
    animationType: AnimationType.none,
    title: LocalizedText(en: 'Airspace Basics', zh: '空域基础', fr: 'Bases de l\'espace aérien'),
    summary: LocalizedText(
      en: 'Airspace is divided into classes and regions to manage traffic safely.',
      zh: '空域被划分为不同类别和区域，以安全管理交通。',
      fr: 'L\'espace aérien est divisé en classes et régions pour gérer le trafic en toute sécurité.',
    ),
    keyPoints: [
      LocalizedText(
        en: 'Airspace classes A–G define rules for who can fly there and what services they receive.',
        zh: 'A至G类空域规定了谁可以在其中飞行以及可获得哪些服务。',
        fr: 'Les classes d\'espace aérien A–G définissent les règles pour qui peut y voler et les services disponibles.',
      ),
      LocalizedText(
        en: 'Controlled airspace requires ATC clearance. Uncontrolled airspace (Class G) does not.',
        zh: '管制空域需要ATC许可。非管制空域（G类）则不需要。',
        fr: 'L\'espace aérien contrôlé nécessite une autorisation ATC. L\'espace non contrôlé (Classe G) non.',
      ),
      LocalizedText(
        en: 'A Flight Information Region (FIR) is a large volume of airspace managed by one centre.',
        zh: '飞行情报区（FIR）是由一个中心管理的大块空域。',
        fr: 'Une Région d\'Information de Vol (FIR) est un grand volume d\'espace aérien géré par un seul centre.',
      ),
    ],
    quiz: [
      QuizQuestion(
        question: LocalizedText(en: 'Class A airspace is:', zh: 'A类空域是：', fr: 'L\'espace aérien de classe A est :'),
        options: [
          LocalizedText(en: 'Fully controlled, IFR only', zh: '全管制，仅IFR', fr: 'Entièrement contrôlé, IFR uniquement'),
          LocalizedText(en: 'Uncontrolled, VFR only', zh: '非管制，仅VFR', fr: 'Non contrôlé, VFR uniquement'),
          LocalizedText(en: 'Open to all without clearance', zh: '无需许可对所有人开放', fr: 'Ouvert à tous sans autorisation'),
        ],
        correctIndex: 0,
        explanation: LocalizedText(
          en: 'Class A is the most restrictive: only IFR flights with ATC clearance are allowed.',
          zh: 'A类是限制最严格的：只允许持有ATC许可的IFR飞行。',
          fr: 'La classe A est la plus restrictive : seuls les vols IFR avec autorisation ATC sont autorisés.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(en: 'What is a FIR?', zh: '什么是FIR？', fr: 'Qu\'est-ce qu\'une FIR ?'),
        options: [
          LocalizedText(en: 'A type of aircraft radar', zh: '一种飞机雷达', fr: 'Un type de radar d\'aéronef'),
          LocalizedText(en: 'Flight Information Region', zh: '飞行情报区', fr: 'Région d\'Information de Vol'),
          LocalizedText(en: 'A runway marking system', zh: '跑道标志系统', fr: 'Un système de marquage de piste'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'A FIR (Flight Information Region) is a defined volume of airspace managed by an air traffic services provider.',
          zh: 'FIR（飞行情报区）是由空中交通服务提供者管理的定义空域。',
          fr: 'Une FIR est un volume défini d\'espace aérien géré par un prestataire de services de navigation aérienne.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'Which class requires no ATC clearance?',
          zh: '哪类空域不需要ATC许可？',
          fr: 'Quelle classe ne nécessite pas d\'autorisation ATC ?',
        ),
        options: [
          LocalizedText(en: 'Class A', zh: 'A类', fr: 'Classe A'),
          LocalizedText(en: 'Class C', zh: 'C类', fr: 'Classe C'),
          LocalizedText(en: 'Class G', zh: 'G类', fr: 'Classe G'),
        ],
        correctIndex: 2,
        explanation: LocalizedText(
          en: 'Class G is uncontrolled airspace — flights operate without ATC clearance, though information services may exist.',
          zh: 'G类是非管制空域——飞行无需ATC许可，但可能存在信息服务。',
          fr: 'La classe G est un espace aérien non contrôlé — les vols opèrent sans autorisation ATC.',
        ),
      ),
    ],
  ),

  Lesson(
    id: 'radar_basics',
    level: LessonLevel.beginner,
    animationType: AnimationType.radarSweep,
    title: LocalizedText(en: 'Radar Basics', zh: '雷达基础', fr: 'Bases du radar'),
    summary: LocalizedText(
      en: 'Radar is the primary tool controllers use to see aircraft position and movement.',
      zh: '雷达是管制员用来查看航空器位置和运动的主要工具。',
      fr: 'Le radar est l\'outil principal que les contrôleurs utilisent pour voir la position et le mouvement des aéronefs.',
    ),
    keyPoints: [
      LocalizedText(
        en: 'Primary Surveillance Radar (PSR) detects reflections of radio waves off aircraft.',
        zh: '一次监视雷达（PSR）探测无线电波在航空器上的反射。',
        fr: 'Le Radar de Surveillance Primaire (PSR) détecte les réflexions des ondes radio sur les aéronefs.',
      ),
      LocalizedText(
        en: 'Secondary Surveillance Radar (SSR) interrogates transponders — giving callsign, altitude, and speed.',
        zh: '二次监视雷达（SSR）询问应答机——提供呼号、高度和速度。',
        fr: 'Le Radar de Surveillance Secondaire (SSR) interroge les transpondeurs — donnant l\'indicatif, l\'altitude et la vitesse.',
      ),
      LocalizedText(
        en: 'Aircraft appear as "blips" on the display, updated each radar rotation (typically 4–12 seconds).',
        zh: '航空器在显示屏上显示为"光点"，每次雷达旋转（通常4-12秒）更新一次。',
        fr: 'Les aéronefs apparaissent comme des "blips" sur l\'écran, mis à jour à chaque rotation radar (typiquement 4–12 secondes).',
      ),
    ],
    quiz: [
      QuizQuestion(
        question: LocalizedText(
          en: 'What does SSR stand for?',
          zh: 'SSR代表什么？',
          fr: 'Que signifie SSR ?',
        ),
        options: [
          LocalizedText(en: 'Secondary Surveillance Radar', zh: '二次监视雷达', fr: 'Radar de Surveillance Secondaire'),
          LocalizedText(en: 'Speed and Separation Record', zh: '速度与间隔记录', fr: 'Enregistrement de vitesse et séparation'),
          LocalizedText(en: 'Standard Separation Rule', zh: '标准间隔规则', fr: 'Règle de séparation standard'),
        ],
        correctIndex: 0,
        explanation: LocalizedText(
          en: 'SSR (Secondary Surveillance Radar) interrogates aircraft transponders to provide identification and altitude data.',
          zh: 'SSR（二次监视雷达）询问航空器应答机以提供识别和高度数据。',
          fr: 'SSR interroge les transpondeurs des aéronefs pour fournir des données d\'identification et d\'altitude.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'What is an aircraft "blip" on radar?',
          zh: '雷达上航空器的"光点"是什么？',
          fr: 'Qu\'est-ce qu\'un "blip" d\'aéronef sur le radar ?',
        ),
        options: [
          LocalizedText(en: 'A sound the controller hears', zh: '管制员听到的声音', fr: 'Un son que le contrôleur entend'),
          LocalizedText(en: 'A visual indicator of the aircraft position', zh: '航空器位置的视觉指示', fr: 'Un indicateur visuel de la position de l\'aéronef'),
          LocalizedText(en: 'An error in the radar system', zh: '雷达系统的错误', fr: 'Une erreur dans le système radar'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'A blip is the return shown on the radar display representing the aircraft\'s detected position.',
          zh: '光点是雷达显示屏上显示的代表航空器探测位置的回波。',
          fr: 'Un blip est le retour affiché sur l\'écran radar représentant la position détectée de l\'aéronef.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'Primary radar works by:',
          zh: '一次雷达的工作原理是：',
          fr: 'Le radar primaire fonctionne en :',
        ),
        options: [
          LocalizedText(en: 'Asking aircraft to send their position', zh: '要求航空器发送位置', fr: 'Demandant aux aéronefs d\'envoyer leur position'),
          LocalizedText(en: 'Detecting reflected radio waves off the aircraft', zh: '探测无线电波在航空器上的反射', fr: 'Détectant les ondes radio réfléchies par l\'aéronef'),
          LocalizedText(en: 'Using GPS satellite data', zh: '使用GPS卫星数据', fr: 'Utilisant des données satellites GPS'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'Primary radar emits radio pulses and detects the echo reflected back from aircraft.',
          zh: '一次雷达发射无线电脉冲并探测从航空器反射回来的回波。',
          fr: 'Le radar primaire émet des impulsions radio et détecte l\'écho réfléchi par les aéronefs.',
        ),
      ),
    ],
  ),

  Lesson(
    id: 'separation_basics',
    level: LessonLevel.beginner,
    animationType: AnimationType.separationDemo,
    title: LocalizedText(en: 'Separation Basics', zh: '间隔基础', fr: 'Bases de la séparation'),
    summary: LocalizedText(
      en: 'Maintaining separation between aircraft is the core safety task of ATC.',
      zh: '保持航空器之间的间隔是ATC的核心安全任务。',
      fr: 'Maintenir la séparation entre aéronefs est la tâche de sécurité centrale de l\'ATC.',
    ),
    keyPoints: [
      LocalizedText(
        en: 'Vertical separation: aircraft at different altitudes (e.g., 1000 ft minimum below FL290).',
        zh: '垂直间隔：航空器位于不同高度（如FL290以下最低1000英尺）。',
        fr: 'Séparation verticale : aéronefs à des altitudes différentes (ex. 1000 ft minimum sous FL290).',
      ),
      LocalizedText(
        en: 'Horizontal separation: lateral (side-by-side) and longitudinal (one behind another).',
        zh: '水平间隔：侧向（并排）和纵向（前后）。',
        fr: 'Séparation horizontale : latérale (côte à côte) et longitudinale (l\'un derrière l\'autre).',
      ),
      LocalizedText(
        en: 'A Loss of Separation (LOS) is a serious incident and must be reported and investigated.',
        zh: '间隔丢失（LOS）是严重事件，必须报告和调查。',
        fr: 'Une perte de séparation (LOS) est un incident grave qui doit être signalé et investigué.',
      ),
    ],
    quiz: [
      QuizQuestion(
        question: LocalizedText(
          en: 'What is vertical separation?',
          zh: '什么是垂直间隔？',
          fr: 'Qu\'est-ce que la séparation verticale ?',
        ),
        options: [
          LocalizedText(en: 'Aircraft side by side at same altitude', zh: '航空器在同一高度并排', fr: 'Aéronefs côte à côte à la même altitude'),
          LocalizedText(en: 'Aircraft at different altitudes', zh: '航空器位于不同高度', fr: 'Aéronefs à des altitudes différentes'),
          LocalizedText(en: 'Aircraft separated by time only', zh: '仅靠时间分开的航空器', fr: 'Aéronefs séparés uniquement par le temps'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'Vertical separation keeps aircraft at different flight levels to prevent collision.',
          zh: '垂直间隔使航空器保持在不同飞行高度层以防止碰撞。',
          fr: 'La séparation verticale maintient les aéronefs à des niveaux de vol différents pour éviter les collisions.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'A Loss of Separation means:',
          zh: '间隔丢失意味着：',
          fr: 'Une perte de séparation signifie :',
        ),
        options: [
          LocalizedText(en: 'An aircraft changed frequency', zh: '航空器更改了频率', fr: 'Un aéronef a changé de fréquence'),
          LocalizedText(en: 'The minimum required distance was not maintained', zh: '未保持最低要求距离', fr: 'La distance minimale requise n\'a pas été maintenue'),
          LocalizedText(en: 'A pilot requested descent', zh: '飞行员请求下降', fr: 'Un pilote a demandé une descente'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'Loss of separation occurs when aircraft come closer than the prescribed minimum, which is a serious safety event.',
          zh: '当航空器距离小于规定最低限度时发生间隔丢失，这是严重的安全事件。',
          fr: 'La perte de séparation se produit quand des aéronefs se rapprochent plus que le minimum prescrit.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'Longitudinal separation refers to:',
          zh: '纵向间隔是指：',
          fr: 'La séparation longitudinale fait référence à :',
        ),
        options: [
          LocalizedText(en: 'Aircraft at different altitudes', zh: '航空器在不同高度', fr: 'Aéronefs à des altitudes différentes'),
          LocalizedText(en: 'Aircraft separated in the direction of flight', zh: '沿飞行方向分开的航空器', fr: 'Aéronefs séparés dans la direction du vol'),
          LocalizedText(en: 'Aircraft at different airports', zh: '航空器在不同机场', fr: 'Aéronefs dans des aéroports différents'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'Longitudinal separation maintains distance between aircraft flying one behind the other on the same route.',
          zh: '纵向间隔保持在同一航路上前后飞行的航空器之间的距离。',
          fr: 'La séparation longitudinale maintient la distance entre aéronefs volant l\'un derrière l\'autre sur la même route.',
        ),
      ),
    ],
  ),

  Lesson(
    id: 'runway_operations',
    level: LessonLevel.beginner,
    animationType: AnimationType.runwayFlow,
    title: LocalizedText(en: 'Runway Operations', zh: '跑道运行', fr: 'Opérations de piste'),
    summary: LocalizedText(
      en: 'Runway safety is the highest priority in airport operations.',
      zh: '跑道安全是机场运行的最高优先级。',
      fr: 'La sécurité des pistes est la priorité absolue dans les opérations aéroportuaires.',
    ),
    keyPoints: [
      LocalizedText(
        en: 'Runways are designated by magnetic heading (e.g., Runway 27L means 270° heading, left of parallel).',
        zh: '跑道以磁航向命名（如跑道27L表示270°方向，平行跑道中的左侧）。',
        fr: 'Les pistes sont désignées par le cap magnétique (ex. Piste 27L = cap 270°, gauche des parallèles).',
      ),
      LocalizedText(
        en: 'Runway incursion: an unauthorised presence on the runway — a top safety concern.',
        zh: '跑道侵入：未经授权进入跑道——最重要的安全关注点。',
        fr: 'Incursion de piste : présence non autorisée sur la piste — principale préoccupation de sécurité.',
      ),
      LocalizedText(
        en: 'Tower sequencing: controllers manage arrivals and departures to maximise runway throughput safely.',
        zh: '塔台排序：管制员管理进出港以安全最大化跑道吞吐量。',
        fr: 'Séquencement tour : les contrôleurs gèrent les arrivées et départs pour maximiser le débit de piste en toute sécurité.',
      ),
    ],
    quiz: [
      QuizQuestion(
        question: LocalizedText(
          en: 'Runway 09 points towards which direction?',
          zh: '09号跑道指向哪个方向？',
          fr: 'La piste 09 pointe vers quelle direction ?',
        ),
        options: [
          LocalizedText(en: 'West (270°)', zh: '西（270°）', fr: 'Ouest (270°)'),
          LocalizedText(en: 'East (090°)', zh: '东（090°）', fr: 'Est (090°)'),
          LocalizedText(en: 'North (360°)', zh: '北（360°）', fr: 'Nord (360°)'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'Runway numbers indicate the magnetic heading in tens of degrees. Runway 09 = 090° = East.',
          zh: '跑道编号表示磁航向的十位数。09号跑道 = 090° = 东。',
          fr: 'Les numéros de piste indiquent le cap magnétique en dizaines de degrés. Piste 09 = 090° = Est.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'What is a runway incursion?',
          zh: '什么是跑道侵入？',
          fr: 'Qu\'est-ce qu\'une incursion de piste ?',
        ),
        options: [
          LocalizedText(en: 'A normal landing procedure', zh: '正常降落程序', fr: 'Une procédure d\'atterrissage normale'),
          LocalizedText(en: 'Any unauthorised presence on an active runway', zh: '在使用中跑道上的任何未授权存在', fr: 'Toute présence non autorisée sur une piste active'),
          LocalizedText(en: 'A runway lighting failure', zh: '跑道灯光故障', fr: 'Une panne des feux de piste'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'A runway incursion is any occurrence where an aircraft, vehicle, or person is on a runway without clearance.',
          zh: '跑道侵入是指任何航空器、车辆或人员未经许可进入跑道的情况。',
          fr: 'Une incursion de piste est tout événement où un aéronef, véhicule ou personne se trouve sur une piste sans autorisation.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'Who is responsible for runway sequencing at an airport?',
          zh: '谁负责机场的跑道排序？',
          fr: 'Qui est responsable du séquencement de piste dans un aéroport ?',
        ),
        options: [
          LocalizedText(en: 'The airline operations centre', zh: '航空公司运营中心', fr: 'Le centre d\'opérations de la compagnie aérienne'),
          LocalizedText(en: 'The Tower controller', zh: '塔台管制员', fr: 'Le contrôleur de la Tour'),
          LocalizedText(en: 'The ground handling agent', zh: '地面代理', fr: 'L\'agent de handling'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'The Tower controller manages all runway movements — takeoffs, landings, and crossing traffic.',
          zh: '塔台管制员管理所有跑道运动——起飞、降落和穿越交通。',
          fr: 'Le contrôleur de la Tour gère tous les mouvements sur piste — décollages, atterrissages et trafic traversant.',
        ),
      ),
    ],
  ),

  Lesson(
    id: 'atc_phraseology',
    level: LessonLevel.intermediate,
    animationType: AnimationType.commsPulse,
    title: LocalizedText(en: 'ATC Phraseology', zh: 'ATC通话用语', fr: 'Phraséologie ATC'),
    summary: LocalizedText(
      en: 'Standard phrases prevent misunderstandings and ensure clear, efficient communication.',
      zh: '标准用语防止误解，确保清晰高效的通信。',
      fr: 'Les phrases standard préviennent les malentendus et assurent une communication claire et efficace.',
    ),
    keyPoints: [
      LocalizedText(
        en: '"Cleared" means ATC authorises an action. Never act without a clearance.',
        zh: '"Cleared"表示ATC授权某项操作。未获许可不得行动。',
        fr: '"Cleared" signifie que l\'ATC autorise une action. N\'agissez jamais sans autorisation.',
      ),
      LocalizedText(
        en: 'Read-back required: pilots must repeat key instructions to confirm correct receipt.',
        zh: '需要复诵：飞行员必须重复关键指令以确认正确收到。',
        fr: 'Accusé de réception obligatoire : les pilotes doivent répéter les instructions clés pour confirmer leur bonne réception.',
      ),
      LocalizedText(
        en: 'ICAO standard phraseology is used globally to minimise language barrier errors.',
        zh: 'ICAO标准用语在全球使用，以最小化语言障碍错误。',
        fr: 'La phraséologie standard de l\'OACI est utilisée mondialement pour minimiser les erreurs dues aux barrières linguistiques.',
      ),
    ],
    quiz: [
      QuizQuestion(
        question: LocalizedText(
          en: 'If a pilot does not read back a clearance, what should the controller do?',
          zh: '如果飞行员没有复诵许可，管制员应该怎么做？',
          fr: 'Si un pilote ne répète pas une autorisation, que doit faire le contrôleur ?',
        ),
        options: [
          LocalizedText(en: 'Assume the pilot understood', zh: '假设飞行员已理解', fr: 'Supposer que le pilote a compris'),
          LocalizedText(en: 'Re-issue the clearance and request read-back', zh: '重新发出许可并要求复诵', fr: 'Réémettre l\'autorisation et demander un accusé de réception'),
          LocalizedText(en: 'Transfer to another frequency', zh: '转换到另一频率', fr: 'Transférer sur une autre fréquence'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'Read-back is essential for safety. The controller must ensure the clearance is correctly acknowledged.',
          zh: '复诵对安全至关重要。管制员必须确保许可被正确确认。',
          fr: 'L\'accusé de réception est essentiel pour la sécurité. Le contrôleur doit s\'assurer que l\'autorisation est correctement confirmée.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'The word "CLEARED" in ATC means:',
          zh: 'ATC中"CLEARED"的含义是：',
          fr: 'Le mot "CLEARED" en ATC signifie :',
        ),
        options: [
          LocalizedText(en: 'Visibility is good', zh: '能见度良好', fr: 'La visibilité est bonne'),
          LocalizedText(en: 'Authorised to proceed as specified', zh: '获授权按指定方式进行', fr: 'Autorisé à procéder comme indiqué'),
          LocalizedText(en: 'The aircraft is clean (no flaps)', zh: '航空器处于干净形态（无襟翼）', fr: 'L\'aéronef est propre (sans volets)'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: '"Cleared" is an ATC authorisation for a specific action, such as takeoff, landing, or a route.',
          zh: '"Cleared"是ATC对特定操作（如起飞、降落或航路）的授权。',
          fr: '"Cleared" est une autorisation ATC pour une action spécifique, comme le décollage, l\'atterrissage ou une route.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'Why is ICAO standard phraseology important?',
          zh: '为什么ICAO标准用语很重要？',
          fr: 'Pourquoi la phraséologie standard de l\'OACI est-elle importante ?',
        ),
        options: [
          LocalizedText(en: 'It makes flights faster', zh: '它使飞行更快', fr: 'Elle accélère les vols'),
          LocalizedText(en: 'It reduces misunderstandings across language barriers', zh: '它减少语言障碍造成的误解', fr: 'Elle réduit les malentendus dus aux barrières linguistiques'),
          LocalizedText(en: 'It is only used in Europe', zh: '它仅在欧洲使用', fr: 'Elle n\'est utilisée qu\'en Europe'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'Standard phraseology gives controllers and pilots a shared language, reducing the risk of miscommunication.',
          zh: '标准用语给管制员和飞行员提供共同语言，降低通信错误风险。',
          fr: 'La phraséologie standard donne aux contrôleurs et pilotes un langage commun, réduisant le risque de malentendus.',
        ),
      ),
    ],
  ),

  Lesson(
    id: 'flight_phases',
    level: LessonLevel.intermediate,
    animationType: AnimationType.none,
    title: LocalizedText(en: 'Flight Phases', zh: '飞行阶段', fr: 'Phases de vol'),
    summary: LocalizedText(
      en: 'Each phase of flight involves different controllers and procedures.',
      zh: '每个飞行阶段涉及不同的管制员和程序。',
      fr: 'Chaque phase de vol implique des contrôleurs et des procédures différents.',
    ),
    keyPoints: [
      LocalizedText(
        en: 'Pre-departure → Clearance Delivery → Ground → Tower → Departure → En-route → Approach → Tower → Parking.',
        zh: '起飞前→放行→地面→塔台→离场→航路→进近→塔台→停机。',
        fr: 'Pré-départ → Délivrance → Sol → Tour → Départ → En-route → Approche → Tour → Parking.',
      ),
      LocalizedText(
        en: 'Each handoff between controllers must include position, altitude, and clearance information.',
        zh: '管制员之间的每次移交必须包括位置、高度和许可信息。',
        fr: 'Chaque transfert entre contrôleurs doit inclure la position, l\'altitude et les informations d\'autorisation.',
      ),
      LocalizedText(
        en: 'The en-route phase (cruise) covers the longest segment and is managed by Area Control Centres (ACC).',
        zh: '航路阶段（巡航）覆盖最长段，由区域管制中心（ACC）管理。',
        fr: 'La phase en route (croisière) couvre le plus long segment et est gérée par les Centres de Contrôle de Zone (ACC).',
      ),
    ],
    quiz: [
      QuizQuestion(
        question: LocalizedText(
          en: 'Which controller handles an aircraft during cruise between airports?',
          zh: '哪个管制员在机场之间巡航时处理航空器？',
          fr: 'Quel contrôleur s\'occupe d\'un aéronef en croisière entre aéroports ?',
        ),
        options: [
          LocalizedText(en: 'Tower controller', zh: '塔台管制员', fr: 'Contrôleur de tour'),
          LocalizedText(en: 'En-route (ACC) controller', zh: '航路（ACC）管制员', fr: 'Contrôleur en route (ACC)'),
          LocalizedText(en: 'Ground controller', zh: '地面管制员', fr: 'Contrôleur sol'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'The en-route controller at an Area Control Centre (ACC) manages aircraft during the cruise phase.',
          zh: '区域管制中心（ACC）的航路管制员管理巡航阶段的航空器。',
          fr: 'Le contrôleur en route dans un Centre de Contrôle de Zone (ACC) gère les aéronefs pendant la phase de croisière.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'What must be included in a controller handoff?',
          zh: '管制员移交中必须包含什么？',
          fr: 'Que doit inclure un transfert de contrôleur ?',
        ),
        options: [
          LocalizedText(en: 'Passenger count only', zh: '仅乘客数量', fr: 'Uniquement le nombre de passagers'),
          LocalizedText(en: 'Position, altitude, and clearance information', zh: '位置、高度和许可信息', fr: 'Position, altitude et informations d\'autorisation'),
          LocalizedText(en: 'Aircraft colour and type only', zh: '仅航空器颜色和类型', fr: 'Uniquement la couleur et le type d\'aéronef'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'A proper handoff ensures the receiving controller has all information needed to maintain safe separation.',
          zh: '正确的移交确保接收管制员拥有维持安全间隔所需的所有信息。',
          fr: 'Un transfert approprié assure que le contrôleur recevant dispose de toutes les informations pour maintenir une séparation sûre.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'Clearance Delivery is used to:',
          zh: '放行许可用于：',
          fr: 'La délivrance d\'autorisation est utilisée pour :',
        ),
        options: [
          LocalizedText(en: 'Approve the aircraft\'s route and flight plan before taxi', zh: '在滑行前批准航空器的航路和飞行计划', fr: 'Approuver la route et le plan de vol de l\'aéronef avant le roulage'),
          LocalizedText(en: 'Load bags into the aircraft', zh: '将行李装入航空器', fr: 'Charger les bagages dans l\'aéronef'),
          LocalizedText(en: 'Refuel the aircraft', zh: '为航空器加油', fr: 'Ravitailler l\'aéronef en carburant'),
        ],
        correctIndex: 0,
        explanation: LocalizedText(
          en: 'Clearance Delivery is the first ATC contact for departing flights, issuing the route, squawk code, and departure instructions.',
          zh: '放行许可是离港航班的第一个ATC联系，发出航路、应答机代码和离场指令。',
          fr: 'La délivrance est le premier contact ATC pour les vols au départ, émettant la route, le code transpondeur et les instructions de départ.',
        ),
      ),
    ],
  ),

  Lesson(
    id: 'conflict_awareness',
    level: LessonLevel.intermediate,
    animationType: AnimationType.separationDemo,
    title: LocalizedText(en: 'Conflict Awareness', zh: '冲突意识', fr: 'Conscience des conflits'),
    summary: LocalizedText(
      en: 'Recognising and resolving conflicts early is a key controller skill.',
      zh: '及早识别和解决冲突是管制员的关键技能。',
      fr: 'Reconnaître et résoudre les conflits tôt est une compétence clé du contrôleur.',
    ),
    keyPoints: [
      LocalizedText(
        en: 'STCA (Short-Term Conflict Alert) warns controllers when aircraft are projected to come too close.',
        zh: 'STCA（短期冲突预警）在航空器预计过近时警告管制员。',
        fr: 'STCA (Short-Term Conflict Alert) avertit les contrôleurs quand des aéronefs sont prévus trop proches.',
      ),
      LocalizedText(
        en: 'Resolution options: change heading, speed, or altitude of one or both aircraft.',
        zh: '解决方案：改变一架或两架航空器的航向、速度或高度。',
        fr: 'Options de résolution : changer le cap, la vitesse ou l\'altitude d\'un ou des deux aéronefs.',
      ),
      LocalizedText(
        en: 'Proactive planning — anticipating conflicts before they develop — reduces workload and risk.',
        zh: '主动规划——在冲突发展前预测——减少工作负荷和风险。',
        fr: 'La planification proactive — anticiper les conflits avant qu\'ils se développent — réduit la charge de travail et le risque.',
      ),
    ],
    quiz: [
      QuizQuestion(
        question: LocalizedText(
          en: 'What does STCA stand for?',
          zh: 'STCA代表什么？',
          fr: 'Que signifie STCA ?',
        ),
        options: [
          LocalizedText(en: 'Short-Term Conflict Alert', zh: '短期冲突预警', fr: 'Short-Term Conflict Alert'),
          LocalizedText(en: 'Standard Traffic Control Announcement', zh: '标准交通管制通知', fr: 'Standard Traffic Control Announcement'),
          LocalizedText(en: 'Speed and Track Control Aid', zh: '速度和航迹控制辅助', fr: 'Speed and Track Control Aid'),
        ],
        correctIndex: 0,
        explanation: LocalizedText(
          en: 'STCA is a safety net tool that alerts controllers when aircraft are predicted to lose separation.',
          zh: 'STCA是一个安全网工具，当航空器预计失去间隔时警告管制员。',
          fr: 'STCA est un outil de filet de sécurité qui alerte les contrôleurs quand des aéronefs sont prévus perdre leur séparation.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'Which of these resolves a conflict between two aircraft at the same altitude and converging?',
          zh: '以下哪项可解决两架同高度汇聚飞行的航空器之间的冲突？',
          fr: 'Lequel résout un conflit entre deux aéronefs à la même altitude et convergeants ?',
        ),
        options: [
          LocalizedText(en: 'Asking both pilots to speed up', zh: '要求两名飞行员加速', fr: 'Demander aux deux pilotes d\'accélérer'),
          LocalizedText(en: 'Issuing a climb to one aircraft', zh: '指示一架航空器爬升', fr: 'Ordonner une montée à un aéronef'),
          LocalizedText(en: 'Changing the callsign of one aircraft', zh: '更改一架航空器的呼号', fr: 'Changer l\'indicatif d\'un aéronef'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'Assigning a different altitude provides immediate vertical separation between conflicting aircraft.',
          zh: '分配不同高度可立即为冲突航空器提供垂直间隔。',
          fr: 'Assigner une altitude différente fournit une séparation verticale immédiate entre les aéronefs en conflit.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'Proactive conflict management means:',
          zh: '主动冲突管理意味着：',
          fr: 'La gestion proactive des conflits signifie :',
        ),
        options: [
          LocalizedText(en: 'Waiting until STCA triggers before acting', zh: '等到STCA触发后再行动', fr: 'Attendre que STCA se déclenche avant d\'agir'),
          LocalizedText(en: 'Anticipating conflicts and resolving them early', zh: '预测冲突并及早解决', fr: 'Anticiper les conflits et les résoudre tôt'),
          LocalizedText(en: 'Relying on pilots to avoid each other', zh: '依赖飞行员相互回避', fr: 'Compter sur les pilotes pour s\'éviter'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'Good controllers anticipate conflicts from the traffic picture and resolve them before they become critical.',
          zh: '优秀的管制员从交通态势预测冲突，并在其变得关键之前解决。',
          fr: 'Les bons contrôleurs anticipent les conflits depuis le tableau de trafic et les résolvent avant qu\'ils deviennent critiques.',
        ),
      ),
    ],
  ),

  Lesson(
    id: 'tower_approach_enroute',
    level: LessonLevel.advanced,
    animationType: AnimationType.none,
    title: LocalizedText(
      en: 'Tower, Approach, and En-route',
      zh: '塔台、进近与航路管制',
      fr: 'Tour, Approche et En-route',
    ),
    summary: LocalizedText(
      en: 'Three main ATC units each control a distinct phase and volume of airspace.',
      zh: '三个主要ATC单元各自控制不同的飞行阶段和空域范围。',
      fr: 'Trois grandes unités ATC contrôlent chacune une phase et un volume d\'espace aérien distincts.',
    ),
    keyPoints: [
      LocalizedText(
        en: 'Tower (TWR): controls the manoeuvring area — runways, taxiways, and the airport circuit.',
        zh: '塔台（TWR）：控制机动区——跑道、滑行道和机场起落航线。',
        fr: 'Tour (TWR) : contrôle la zone de manœuvre — pistes, voies de circulation et circuit aérodrome.',
      ),
      LocalizedText(
        en: 'Approach (APP): manages arrivals and departures in the Terminal Manoeuvring Area (TMA), typically up to FL100–FL245.',
        zh: '进近（APP）：管理终端管制区（TMA）内的进出港，通常至FL100-FL245。',
        fr: 'Approche (APP) : gère les arrivées et départs dans la Zone de Manœuvre Terminale (TMA), typiquement jusqu\'à FL100–FL245.',
      ),
      LocalizedText(
        en: 'En-route (ACC): controls cruise traffic in upper airspace, often from FL245 and above.',
        zh: '航路（ACC）：控制高空中的巡航交通，通常从FL245及以上。',
        fr: 'En route (ACC) : contrôle le trafic en croisière dans l\'espace aérien supérieur, souvent de FL245 et au-dessus.',
      ),
    ],
    quiz: [
      QuizQuestion(
        question: LocalizedText(
          en: 'Which unit controls aircraft on the taxiway?',
          zh: '哪个单位控制滑行道上的航空器？',
          fr: 'Quelle unité contrôle les aéronefs sur la voie de circulation ?',
        ),
        options: [
          LocalizedText(en: 'Area Control Centre (ACC)', zh: '区域管制中心（ACC）', fr: 'Centre de Contrôle de Zone (ACC)'),
          LocalizedText(en: 'Tower (TWR)', zh: '塔台（TWR）', fr: 'Tour (TWR)'),
          LocalizedText(en: 'Approach (APP)', zh: '进近（APP）', fr: 'Approche (APP)'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'Tower (TWR) controls ground movement including taxiways, holding points, and the active runway.',
          zh: '塔台（TWR）控制地面运动，包括滑行道、等待点和使用中跑道。',
          fr: 'La Tour (TWR) contrôle les mouvements au sol incluant les voies de circulation, points d\'attente et piste active.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'TMA stands for:',
          zh: 'TMA代表：',
          fr: 'TMA signifie :',
        ),
        options: [
          LocalizedText(en: 'Terminal Manoeuvring Area', zh: '终端管制区', fr: 'Zone de Manœuvre Terminale'),
          LocalizedText(en: 'Traffic Management Authority', zh: '交通管理机构', fr: 'Autorité de Gestion du Trafic'),
          LocalizedText(en: 'Tower Monitoring Area', zh: '塔台监控区', fr: 'Zone de Surveillance de la Tour'),
        ],
        correctIndex: 0,
        explanation: LocalizedText(
          en: 'TMA (Terminal Manoeuvring Area) is the controlled airspace around busy airports, managed by Approach control.',
          zh: 'TMA（终端管制区）是繁忙机场周围的管制空域，由进近管制管理。',
          fr: 'La TMA est l\'espace aérien contrôlé autour des aéroports chargés, géré par le contrôle d\'approche.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'At what level does en-route control typically begin?',
          zh: '航路管制通常从哪个高度层开始？',
          fr: 'À quel niveau le contrôle en route commence-t-il typiquement ?',
        ),
        options: [
          LocalizedText(en: 'Ground level', zh: '地面', fr: 'Au sol'),
          LocalizedText(en: 'Around FL245 and above', zh: '约FL245及以上', fr: 'Environ FL245 et au-dessus'),
          LocalizedText(en: 'At exactly FL100', zh: '恰好在FL100', fr: 'Exactement à FL100'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'En-route (ACC) control typically begins around FL245, though this varies by country and airspace design.',
          zh: '航路（ACC）管制通常从FL245开始，但因国家和空域设计而异。',
          fr: 'Le contrôle en route (ACC) commence typiquement vers FL245, bien que cela varie selon les pays et la conception de l\'espace aérien.',
        ),
      ),
    ],
  ),

  Lesson(
    id: 'future_atm',
    level: LessonLevel.expert,
    animationType: AnimationType.none,
    title: LocalizedText(en: 'Future ATM & Automation', zh: 'ATM的未来与自动化', fr: 'GTA futur et automatisation'),
    summary: LocalizedText(
      en: 'The future of ATM is digital, connected, and increasingly automated — but humans remain central.',
      zh: 'ATM的未来是数字化、互联和日益自动化的——但人类仍居核心。',
      fr: 'L\'avenir de la GTA est numérique, connecté et de plus en plus automatisé — mais l\'humain reste central.',
    ),
    keyPoints: [
      LocalizedText(
        en: 'SESAR (Europe) and NextGen (USA) are programmes modernising ATM with digital data links and 4D trajectories.',
        zh: 'SESAR（欧洲）和NextGen（美国）是通过数字数据链和4D轨迹实现ATM现代化的计划。',
        fr: 'SESAR (Europe) et NextGen (USA) sont des programmes modernisant la GTA avec des liaisons de données numériques et des trajectoires 4D.',
      ),
      LocalizedText(
        en: 'Remote towers allow controllers to manage smaller airports from centralised facilities.',
        zh: '远程塔台允许管制员从集中设施管理较小的机场。',
        fr: 'Les tours distantes permettent aux contrôleurs de gérer des aéroports plus petits depuis des installations centralisées.',
      ),
      LocalizedText(
        en: 'AI tools can assist with conflict detection, flow optimisation, and workload balancing — but require careful validation.',
        zh: 'AI工具可以协助冲突检测、流量优化和工作负荷平衡——但需要谨慎验证。',
        fr: 'Les outils IA peuvent aider à la détection de conflits, l\'optimisation des flux et l\'équilibrage de la charge de travail — mais nécessitent une validation soigneuse.',
      ),
    ],
    quiz: [
      QuizQuestion(
        question: LocalizedText(
          en: 'What is SESAR?',
          zh: 'SESAR是什么？',
          fr: 'Qu\'est-ce que SESAR ?',
        ),
        options: [
          LocalizedText(en: 'A European ATM modernisation programme', zh: '欧洲ATM现代化计划', fr: 'Un programme européen de modernisation de la GTA'),
          LocalizedText(en: 'A type of radar sensor', zh: '一种雷达传感器', fr: 'Un type de capteur radar'),
          LocalizedText(en: 'A pilot training standard', zh: '飞行员培训标准', fr: 'Une norme de formation des pilotes'),
        ],
        correctIndex: 0,
        explanation: LocalizedText(
          en: 'SESAR (Single European Sky ATM Research) is the European programme to modernise and harmonise ATM across Europe.',
          zh: 'SESAR（单一欧洲天空ATM研究）是在欧洲实现ATM现代化和统一的欧洲计划。',
          fr: 'SESAR (Recherche ATM pour le Ciel Unique Européen) est le programme européen de modernisation et d\'harmonisation de la GTA.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'Remote towers allow:',
          zh: '远程塔台允许：',
          fr: 'Les tours distantes permettent :',
        ),
        options: [
          LocalizedText(en: 'Controlling airports without any human oversight', zh: '无任何人工监督控制机场', fr: 'Contrôler des aéroports sans surveillance humaine'),
          LocalizedText(en: 'Managing smaller airports from a centralised facility', zh: '从集中设施管理较小机场', fr: 'Gérer des aéroports plus petits depuis une installation centralisée'),
          LocalizedText(en: 'Removing the need for radar entirely', zh: '完全取消雷达需求', fr: 'Éliminer entièrement le besoin de radar'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'Remote towers use cameras and digital feeds to give controllers a full view of small airports from a remote location.',
          zh: '远程塔台使用摄像头和数字信号，让管制员从远程位置全面查看小型机场。',
          fr: 'Les tours distantes utilisent des caméras et flux numériques pour donner aux contrôleurs une vue complète des petits aéroports à distance.',
        ),
      ),
      QuizQuestion(
        question: LocalizedText(
          en: 'Regarding AI in ATM, which statement is most accurate?',
          zh: '关于ATM中的AI，哪项陈述最准确？',
          fr: 'Concernant l\'IA en GTA, quelle affirmation est la plus précise ?',
        ),
        options: [
          LocalizedText(en: 'AI will replace all controllers by 2030', zh: 'AI将在2030年前取代所有管制员', fr: 'L\'IA remplacera tous les contrôleurs d\'ici 2030'),
          LocalizedText(en: 'AI can assist controllers but requires careful validation before operational use', zh: 'AI可以协助管制员，但在投入使用前需要谨慎验证', fr: 'L\'IA peut aider les contrôleurs mais nécessite une validation soigneuse avant usage opérationnel'),
          LocalizedText(en: 'AI is currently banned in ATM', zh: 'AI目前在ATM中被禁止', fr: 'L\'IA est actuellement interdite en GTA'),
        ],
        correctIndex: 1,
        explanation: LocalizedText(
          en: 'AI tools show great promise for assisting controllers, but aviation safety standards require rigorous testing before deployment.',
          zh: 'AI工具在协助管制员方面显示出巨大潜力，但航空安全标准要求在部署前进行严格测试。',
          fr: 'Les outils IA montrent de grandes promesses pour aider les contrôleurs, mais les normes de sécurité aéronautique exigent des tests rigoureux avant déploiement.',
        ),
      ),
    ],
  ),
];

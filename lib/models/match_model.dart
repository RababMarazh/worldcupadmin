class MatchModel {
  MatchModel({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.localDate,
    required this.localTime,
    required this.group,
    required this.type,
    required this.matchday,
    required this.stage,
    required this.matchId,
    required this.matchUrl,
    required this.stadiumId,
    required this.finished,
    required this.timeElapsed,
    required this.homeScore,
    required this.awayScore,
    required this.homeLogoUrl,
    required this.awayLogoUrl,
    this.homeScorers = '',
    this.awayScorers = '',
    this.homeYellow = '',
    this.awayYellow = '',
    this.homeRed = '',
    this.awayRed = '',
  });

  final String id;
  final String homeTeam;
  final String awayTeam;
  final String localDate;
  final String localTime;
  final String group;
  final String type;
  final String matchday;
  final String stage;
  final String matchId;
  final String matchUrl;
  final String stadiumId;
  final String finished;
  final String timeElapsed;
  final String homeScore;
  final String awayScore;
  final String homeLogoUrl;
  final String awayLogoUrl;
  final String homeScorers;
  final String awayScorers;
  final String homeYellow;
  final String awayYellow;
  final String homeRed;
  final String awayRed;

  DateTime? get dateTime {
    final cleanedDate = localDate
        .replaceAll('\n', ' ')
        .replaceAll('،', ',')
        .trim();
    var datePart = cleanedDate;
    var timePart = localTime.replaceAll('\n', ' ').trim();

    if (cleanedDate.contains(',')) {
      datePart = cleanedDate.split(',').last.trim();
    }

    final split = datePart.split(RegExp(r'\s+'));
    if (split.length > 1 && timePart.isEmpty) {
      datePart = split.first;
      timePart = split.sublist(1).join(' ');
    }

    if (datePart.isEmpty) return null;

    if (timePart.contains('UTC')) {
      timePart = timePart.split('UTC').first.trim();
    }
    if (timePart.contains('GMT')) {
      timePart = timePart.split('GMT').first.trim();
    }

    final normalized = datePart.replaceAll('/', '-');
    final segments = normalized.split('-');
    if (segments.length != 3) return null;

    int? year;
    int? month;
    int? day;
    if (segments[0].length == 4) {
      year = int.tryParse(segments[0]);
      month = int.tryParse(segments[1]);
      day = int.tryParse(segments[2]);
    } else {
      month = int.tryParse(segments[0]);
      day = int.tryParse(segments[1]);
      year = int.tryParse(segments[2]);
    }
    if (year == null || month == null || day == null) return null;

    var hour = 0;
    var minute = 0;
    if (timePart.isNotEmpty) {
      final timeSegments = timePart.split(':');
      hour = int.tryParse(timeSegments[0].trim()) ?? 0;
      minute = timeSegments.length > 1
          ? int.tryParse(timeSegments[1].trim()) ?? 0
          : 0;
    }

    return DateTime(year, month, day, hour, minute);
  }

  String get matchTime {
    final dt = dateTime;
    if (dt == null) return localTime.isNotEmpty ? localTime : localDate;
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String get dateLabel {
    final dt = dateTime;
    if (dt == null) return localDate;
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year}';
  }

  String get dateHeader {
    final dt = dateTime;
    if (dt == null) return localDate;
    return '${_weekday(dt.weekday)}, ${_month(dt.month)} ${dt.day.toString().padLeft(2, '0')}';
  }

  String get matchDescription {
    if (stage.isNotEmpty && matchday.isNotEmpty) {
      return '$stage · الجولة $matchday';
    }
    if (stage.isNotEmpty) {
      return stage;
    }
    if (matchday.isNotEmpty) {
      return 'الجولة $matchday';
    }
    return 'Match Details';
  }

  bool get isToday {
    final dt = dateTime;
    if (dt == null) return false;
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  String get fixedHomeLogoUrl => _getFixedLogoUrl(homeLogoUrl, homeTeam);
  String get fixedAwayLogoUrl => _getFixedLogoUrl(awayLogoUrl, awayTeam);

  static String _getFixedLogoUrl(String url, String teamName) {
    // If URL is working (doesn't contain jdwel.com), return as is
    if (url.isNotEmpty && !url.contains('jdwel.com')) {
      return url;
    }

    // Otherwise, get working logo from mapping
    return _getWorkingLogoUrl(teamName);
  }

  static String _getWorkingLogoUrl(String teamName) {
    // Complete mapping of team names to working logo URLs from reliable CDN
    const teamLogoMap = {
      'المكسيك': 'https://flagcdn.com/w320/mx.png',
      'جنوب أفريقيا': 'https://flagcdn.com/w320/za.png',
      'كوريا الجنوبية': 'https://flagcdn.com/w320/kr.png',
      'التشيك': 'https://flagcdn.com/w320/cz.png',
      'كندا': 'https://flagcdn.com/w320/ca.png',
      'البوسنة والهرسك': 'https://flagcdn.com/w320/ba.png',
      'الولايات المتحدة': 'https://flagcdn.com/w320/us.png',
      'باراغواي': 'https://flagcdn.com/w320/py.png',
      'قطر': 'https://flagcdn.com/w320/qa.png',
      'سويسرا': 'https://flagcdn.com/w320/ch.png',
      'البرازيل': 'https://flagcdn.com/w320/br.png',
      'المغرب': 'https://flagcdn.com/w320/ma.png',
      'هايتي': 'https://flagcdn.com/w320/ht.png',
      'اسكتلندا': 'https://flagcdn.com/w320/gb-sct.png',
      'أستراليا': 'https://flagcdn.com/w320/au.png',
      'تركيا': 'https://flagcdn.com/w320/tr.png',
      'ألمانيا': 'https://flagcdn.com/w320/de.png',
      'كوراساو': 'https://flagcdn.com/w320/cw.png',
      'هولندا': 'https://flagcdn.com/w320/nl.png',
      'اليابان': 'https://flagcdn.com/w320/jp.png',
      'ساحل العاج': 'https://flagcdn.com/w320/ci.png',
      'الإكوادور': 'https://flagcdn.com/w320/ec.png',
      'السويد': 'https://flagcdn.com/w320/se.png',
      'تونس': 'https://flagcdn.com/w320/tn.png',
      'الرأس الأخضر': 'https://flagcdn.com/w320/cv.png',
      'إسبانيا': 'https://flagcdn.com/w320/es.png',
      'بلجيكا': 'https://flagcdn.com/w320/be.png',
      'مصر': 'https://flagcdn.com/w320/eg.png',
      'السعودية': 'https://flagcdn.com/w320/sa.png',
      'أوروغواي': 'https://flagcdn.com/w320/uy.png',
      'إيران': 'https://flagcdn.com/w320/ir.png',
      'نيوزيلندا': 'https://flagcdn.com/w320/nz.png',
      'فرنسا': 'https://flagcdn.com/w320/fr.png',
      'السنغال': 'https://flagcdn.com/w320/sn.png',
      'العراق': 'https://flagcdn.com/w320/iq.png',
      'النرويج': 'https://flagcdn.com/w320/no.png',
      'الأرجنتين': 'https://flagcdn.com/w320/ar.png',
      'الجزائر': 'https://flagcdn.com/w320/dz.png',
      'النمسا': 'https://flagcdn.com/w320/at.png',
      'الأردن': 'https://flagcdn.com/w320/jo.png',
      'البرتغال': 'https://flagcdn.com/w320/pt.png',
      'جمهورية الكونغو الديمقراطية': 'https://flagcdn.com/w320/cd.png',
      'إنجلترا': 'https://flagcdn.com/w320/gb-eng.png',
      'كرواتيا': 'https://flagcdn.com/w320/hr.png',
      'غانا': 'https://flagcdn.com/w320/gh.png',
      'بنما': 'https://flagcdn.com/w320/pa.png',
      'أوزبكستان': 'https://flagcdn.com/w320/uz.png',
      'كولومبيا': 'https://flagcdn.com/w320/co.png',
    };

    return teamLogoMap[teamName] ?? 'https://flagcdn.com/w320/un.png';
  }

  static String _weekday(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday - 1];
  }

  static String _month(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month - 1];
  }

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    final dateValue =
        json['local_date'] as String? ??
        json['date'] as String? ??
        json['التاريخ'] as String? ??
        '';
    final timeValue =
        json['time'] as String? ?? json['التوقيت_GMT'] as String? ?? '';
    final homeTeam =
        json['home_team_name_en'] as String? ??
        json['team1'] as String? ??
        json['home_team'] as String? ??
        (json['الفريق_الأول'] is Map
            ? (json['الفريق_الأول']['الاسم'] as String?)
            : null) ??
        '';
    final awayTeam =
        json['away_team_name_en'] as String? ??
        json['team2'] as String? ??
        json['away_team'] as String? ??
        (json['الفريق_الثاني'] is Map
            ? (json['الفريق_الثاني']['الاسم'] as String?)
            : null) ??
        '';
    final homeLogo =
        json['home_logo_url'] as String? ??
        json['homeLogoUrl'] as String? ??
        json['home_logo'] as String? ??
        json['homeLogo'] as String? ??
        (json['الفريق_الأول'] is Map
            ? (json['الفريق_الأول']['الشعار'] as String?)
            : null) ??
        (json['team1'] is Map ? (json['team1']['logo'] as String?) : null) ??
        '';
    final awayLogo =
        json['away_logo_url'] as String? ??
        json['awayLogoUrl'] as String? ??
        json['away_logo'] as String? ??
        json['awayLogo'] as String? ??
        (json['الفريق_الثاني'] is Map
            ? (json['الفريق_الثاني']['الشعار'] as String?)
            : null) ??
        (json['team2'] is Map ? (json['team2']['logo'] as String?) : null) ??
        '';

    return MatchModel(
      id:
          json['id'] as String? ??
          json['doc_id'] as String? ??
          json['match_id']?.toString() ??
          json['معرف_المباراة']?.toString() ??
          '',
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      localDate: dateValue,
      localTime: timeValue,
      group: json['group'] as String? ?? '',
      type: json['type'] as String? ?? json['الدور'] as String? ?? '',
      matchday:
          json['matchday'] as String? ??
          json['round'] as String? ??
          json['الجولة']?.toString() ??
          '',
      stage: json['stage'] as String? ?? json['الدور'] as String? ?? '',
      matchId:
          json['match_id']?.toString() ??
          json['معرف_المباراة']?.toString() ??
          '',
      matchUrl:
          json['match_url'] as String? ??
          json['رابط_المباراة'] as String? ??
          '',
      stadiumId:
          json['stadium_id'] as String? ?? json['ground'] as String? ?? '',
      finished: json['finished'] as String? ?? '',
      timeElapsed: json['time_elapsed'] as String? ?? '',
      homeScore: json['home_score'] as String? ?? '',
      awayScore: json['away_score'] as String? ?? '',
      homeLogoUrl: homeLogo,
      awayLogoUrl: awayLogo,
      homeScorers: json['home_scorers'] as String? ?? '',
      awayScorers: json['away_scorers'] as String? ?? '',
      homeYellow: json['home_yellow'] as String? ?? '',
      awayYellow: json['away_yellow'] as String? ?? '',
      homeRed: json['home_red'] as String? ?? '',
      awayRed: json['away_red'] as String? ?? '',
    );
  }

  MatchModel copyWith({
    String? homeScore,
    String? awayScore,
    String? homeScorers,
    String? awayScorers,
    String? homeYellow,
    String? awayYellow,
    String? homeRed,
    String? awayRed,
  }) {
    return MatchModel(
      id: id,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      localDate: localDate,
      localTime: localTime,
      group: group,
      type: type,
      matchday: matchday,
      stage: stage,
      matchId: matchId,
      matchUrl: matchUrl,
      stadiumId: stadiumId,
      finished: finished,
      timeElapsed: timeElapsed,
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      homeLogoUrl: homeLogoUrl,
      awayLogoUrl: awayLogoUrl,
      homeScorers: homeScorers ?? this.homeScorers,
      awayScorers: awayScorers ?? this.awayScorers,
      homeYellow: homeYellow ?? this.homeYellow,
      awayYellow: awayYellow ?? this.awayYellow,
      homeRed: homeRed ?? this.homeRed,
      awayRed: awayRed ?? this.awayRed,
    );
  }
}

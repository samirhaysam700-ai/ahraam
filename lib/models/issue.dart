class Issue {
  final String flipId;
  final String date;
  final String codeBuy;

  Issue({required this.flipId, required this.date, required this.codeBuy});

  String get displayDate {
    try {
      final d = DateTime.parse(date);
      const months = [
        '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ];
      return '${d.day} ${months[d.month]} ${d.year}';
    } catch (_) {
      return date;
    }
  }

  String get fileName => 'ahram_${flipId}_$date.pdf';
}

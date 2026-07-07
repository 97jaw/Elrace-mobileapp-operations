/// Derives display rating from score / max (UI-only until backend rules are wired).
library performance_rating;

String ratingEnArForScore(int score, int maxScore) {
  if (maxScore <= 0) return '—';
  if (score <= 0) return '—';
  final f = score / maxScore;
  if (f >= 0.86) return 'More Than Satisfactory - جيد جداً';
  if (f >= 0.71) return 'Satisfactory - مرضٍ';
  if (f >= 0.51) return 'Fair - مُرضٍ';
  return 'Needs Improvement - يحتاج تحسين';
}

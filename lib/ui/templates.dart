/// The three generic starter schedules offered in onboarding.
enum StarterTemplate {
  student('Student', 'Lectures, study blocks, a later start', 'student.md'),
  nineToFive('9 to 5', 'Commute, work hours, evenings free', 'nine_to_five.md'),
  gymFocused('Gym-focused', 'Training first, meals around it, early nights', 'gym_focused.md');

  const StarterTemplate(this.title, this.subtitle, this.fileName);

  final String title;
  final String subtitle;

  /// Name the schedule file gets when the template is chosen.
  final String fileName;

  String get asset => 'assets/templates/$fileName';

  /// The template a schedule file came from, if it is one.
  static StarterTemplate? byFileName(String name) {
    for (final t in values) {
      if (t.fileName == name) return t;
    }
    return null;
  }
}

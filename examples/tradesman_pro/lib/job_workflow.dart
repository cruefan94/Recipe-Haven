class JobWorkflow {
  static const statuses = ['Quoted', 'Scheduled', 'In progress', 'Completed'];

  static String validated(String value) {
    if (!statuses.contains(value)) throw const FormatException('Invalid job status');
    return value;
  }

  static String validateTitle(String value) {
    final text = value.trim();
    if (text.isEmpty || text.length > 120) {
      throw const FormatException('Enter a job name up to 120 characters');
    }
    return text;
  }
}

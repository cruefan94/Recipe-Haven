import 'package:flutter_test/flutter_test.dart';
import 'package:tradesman_pro_starter/job_workflow.dart';

void main() {
  test('job stages are predefined and validated', () {
    expect(JobWorkflow.statuses.length, 4);
    expect(JobWorkflow.validated('Completed'), 'Completed');
    expect(() => JobWorkflow.validated('Unknown'), throwsFormatException);
  });
  test('trims customer-facing job title and rejects blank', () {
    expect(JobWorkflow.validateTitle('  Basement  '), 'Basement');
    expect(() => JobWorkflow.validateTitle('  '), throwsFormatException);
  });
}

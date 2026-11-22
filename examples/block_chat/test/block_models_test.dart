import 'package:block_chat/models/block_models.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('invites are high-entropy code shaped and not a neighbourhood name', () {
    expect(ChatValidation.invitation('A' * 40), 'a' * 40);
    expect(() => ChatValidation.invitation('1234'), throwsFormatException);
    expect(() => ChatValidation.invitation('F' * 41), throwsFormatException);
    expect(() => ChatValidation.invitation('../test'), throwsFormatException);
  });
  test('messages reject blank and overlong input', () {
    expect(ChatValidation.message('  hello  '), 'hello');
    expect(() => ChatValidation.message('  '), throwsFormatException);
    expect(() => ChatValidation.message('x' * 1001), throwsFormatException);
  });
  test('member permissions and per-block channels are explicit', () {
    const pending = NeighbourhoodBlock(
      id: 'a',name: 'Northside',role: 'member',status:'pending');
    const owner = NeighbourhoodBlock(
      id: 'b',name:'Westside',role:'owner',status:'approved');
    expect(pending.approved,false);
    expect(pending.administrator,false);
    expect(owner.approved,true);
    expect(owner.administrator,true);
    expect(ChatChannel.all.map((c)=>c.key),[
      'general','announcements','help','events',
    ]);
  });
  test('names are bounded', () {
    expect(ChatValidation.blockName(' Our Block '),'Our Block');
    expect(() => ChatValidation.blockName('x'),throwsFormatException);
    expect(() => ChatValidation.nickname(''),throwsFormatException);
  });
}

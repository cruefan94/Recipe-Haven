import 'package:block_chat/models/block_models.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('invites are high-entropy code shaped and not a neighbourhood name', () {
    expect(ChatValidation.invitation(List.filled(40,'A').join()), List.filled(40,'a').join());
    expect(() => ChatValidation.invitation('1234'), throwsFormatException);
    expect(() => ChatValidation.invitation(List.filled(41,'F').join()), throwsFormatException);
    expect(() => ChatValidation.invitation('../test'), throwsFormatException);
  });
  test('messages reject blank and overlong input', () {
    expect(ChatValidation.message('  hello  '), 'hello');
    expect(() => ChatValidation.message('  '), throwsFormatException);
    expect(() => ChatValidation.message(List.filled(1001,'x').join()), throwsFormatException);
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
    expect(ChatChannel.all.map((c)=>c.key).toList(),[
      'general','announcements','help','events',
    ]);
  });
  test('names are bounded', () {
    expect(ChatValidation.blockName(' Our Block '),'Our Block');
    expect(() => ChatValidation.blockName('x'),throwsFormatException);
    expect(() => ChatValidation.nickname(''),throwsFormatException);
  });
}

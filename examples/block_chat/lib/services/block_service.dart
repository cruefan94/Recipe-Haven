import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/block_models.dart';

/// No service-role credentials are present in this client.
/// The RLS migration and server-side RPCs authorize every privileged action.
class BlockService {
  BlockService(this.client);
  final SupabaseClient client;
  String get myUserId => client.auth.currentUser!.id;

  Future<List<NeighbourhoodBlock>> myBlocks() async {
    final memberships = await client.from('block_memberships')
        .select('block_id,role,status')
        .eq('user_id', myUserId);
    if (memberships.isEmpty) return [];
    final ids = <String>[];
    for (final row in memberships) {
      if (row['status'] == 'approved' || row['status'] == 'pending') {
        ids.add(row['block_id'] as String);
      }
    }
    if (ids.isEmpty) return [];
    final visible = await client.from('blocks').select('id,name').inFilter('id', ids);
    final names = <String,String>{};
    for (final row in visible) {
      names[row['id'] as String] = row['name'] as String;
    }
    final blocks = <NeighbourhoodBlock>[];
    for (final row in memberships) {
      final id = row['block_id'] as String;
      if (!names.containsKey(id)) continue;
      blocks.add(NeighbourhoodBlock(
        id: id, name: names[id]!, role: row['role'] as String,
        status: row['status'] as String,
      ));
    }
    blocks.sort((a,b) {
      if (a.approved != b.approved) return a.approved ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return blocks;
  }

  Future<void> createBlock(String name) async {
    await client.rpc('create_block',
      params: {'p_name': ChatValidation.blockName(name)});
  }

  Future<void> joinBlock(String code) async {
    await client.rpc('redeem_block_invite',
      params: {'p_code': ChatValidation.invitation(code)});
  }

  Future<String> createInvite(String id) async {
    final result = await client.rpc('make_block_invite',params: {'p_block':id});
    if (result is! String || result.isEmpty) {
      throw const FormatException('Could not create invitation');
    }
    return result;
  }

  Future<List<Map<String,dynamic>>> pendingMembers(String blockId) async {
    final result = await client.rpc('pending_block_members',
      params: {'p_block':blockId});
    return (result as List).cast<Map<String,dynamic>>();
  }

  Future<List<Map<String,dynamic>>> approvedMembers(String blockId) async {
    final result = await client.rpc('approved_block_members',
      params: {'p_block':blockId});
    return (result as List).cast<Map<String,dynamic>>();
  }

  Future<void> review(String blockId,String userId,bool approve) =>
    client.rpc('review_block_member',params: {
      'p_block':blockId,'p_user':userId,'p_approve':approve,
    }).then((_) {});

  Future<void> removeMember(String blockId,String userId) =>
    client.rpc('remove_block_member',params: {
      'p_block':blockId,'p_user':userId,
    }).then((_) {});

  /// Approved non-founders may leave. Pending applicants may cancel requests.
  Future<void> leaveBlock(String blockId) =>
    client.rpc('leave_block', params: {'p_block': blockId}).then((_) {});

  /// Never returns the original invitation secret or its hash.
  Future<List<Map<String,dynamic>>> activeInvites(String blockId) async {
    final rows = await client.rpc('active_block_invites',
      params: {'p_block': blockId});
    return (rows as List).cast<Map<String,dynamic>>();
  }

  Future<void> revokeInvite(String invitationId) =>
    client.rpc('revoke_block_invite',
      params: {'p_invite': invitationId}).then((_) {});

  Future<void> removeOwnMessage(int messageId) =>
    client.rpc('delete_own_block_message',
      params: {'p_message': messageId}).then((_) {});

  Stream<List<Map<String,dynamic>>> messages(String blockId,String channel) =>
    client.from('block_messages')
      .stream(primaryKey:['id'])
      .eq('block_id',blockId)
      .eq('channel',channel)
      .order('created_at',ascending:false)
      .limit(150);

  Future<void> send(String blockId,String channel,String raw) async {
    await client.from('block_messages').insert({
      'block_id':blockId,
      'channel':channel,
      'sender_id':myUserId,
      'body':ChatValidation.message(raw),
    });
  }

  Future<void> report(int messageId,String reason) =>
    client.rpc('report_block_message',params: {
      'p_message':messageId,'p_reason':reason,
    }).then((_) {});

  Future<List<Map<String,dynamic>>> pendingReports(String blockId) async {
    final result = await client.rpc('pending_block_reports',
      params: {'p_block':blockId});
    return (result as List).cast<Map<String,dynamic>>();
  }

  Future<void> moderate(int reportId,{required bool removeMessage}) =>
    client.rpc('moderate_block_report',params: {
      'p_report':reportId,'p_remove_message':removeMessage,
    }).then((_) {});

  Future<void> updateDisplayName(String name) async {
    await client.from('block_profiles').update({
      'display_name':ChatValidation.nickname(name),
    }).eq('user_id',myUserId);
  }

  Future<String> displayName() async {
    final row = await client.from('block_profiles').select('display_name')
        .eq('user_id',myUserId).single();
    return row['display_name'] as String;
  }
}

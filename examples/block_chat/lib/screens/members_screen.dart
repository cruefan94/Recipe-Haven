import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/block_models.dart';
import '../services/block_service.dart';

class BlockMembersScreen extends StatefulWidget {
  const BlockMembersScreen({super.key,required this.block,required this.service});
  final NeighbourhoodBlock block;
  final BlockService service;
  @override State<BlockMembersScreen> createState()=>_BlockMembersScreenState();
}

class _BlockMembersScreenState extends State<BlockMembersScreen> {
  late Future<List<Map<String,dynamic>>> members;
  late Future<List<Map<String,dynamic>>> pending;
  late Future<List<Map<String,dynamic>>> reports;
  bool operating=false;
  @override void initState(){super.initState();refresh();}
  void refresh(){
    members=widget.service.approvedMembers(widget.block.id);
    pending=widget.block.administrator
      ? widget.service.pendingMembers(widget.block.id)
      : Future.value(<Map<String,dynamic>>[]);
    reports=widget.block.administrator
      ? widget.service.pendingReports(widget.block.id)
      : Future.value(<Map<String,dynamic>>[]);
  }
  void toast(String message)=>ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content:Text(message)));

  Future<void> invite() async {
    if(operating)return;
    setState(()=>operating=true);
    try {
      final code=await widget.service.createInvite(widget.block.id);
      if(!mounted)return;
      await showDialog<void>(context:context,builder:(dialog)=>AlertDialog(
        title:const Text('New invitation'),
        content:Column(
          mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            const Text('Share this one-time code with one person. '
              'It expires in 48 hours and still requires administrator approval.'),
            const SizedBox(height:14),
            SelectableText(code,style:const TextStyle(
              fontWeight:FontWeight.w700,fontSize:15)),
          ],
        ),
        actions:[
          OutlinedButton.icon(
            onPressed:() async {
              await Clipboard.setData(ClipboardData(text:code));
              if(dialog.mounted)Navigator.pop(dialog);
              if(mounted)toast('Invitation code copied.');
            },
            icon:const Icon(Icons.copy),label:const Text('Copy code'),
          ),
          TextButton(onPressed:()=>Navigator.pop(dialog),
            child:const Text('Close')),
        ],
      ));
    } catch (_) {if(mounted)toast('Could not create invitation.');}
    finally {if(mounted)setState(()=>operating=false);}
  }

  Future<void> decide(String userId,bool approve) async {
    if(operating)return;
    setState(()=>operating=true);
    try {
      await widget.service.review(widget.block.id,userId,approve);
      if(mounted)setState(refresh);
    } catch (_) {if(mounted)toast('Could not update membership.');}
    finally {if(mounted)setState(()=>operating=false);}
  }

  Future<void> removeMember(Map<String,dynamic> row) async {
    if(operating)return;
    final confirmed=await showDialog<bool>(
      context:context,builder:(dialog)=>AlertDialog(
        title:const Text('Remove member?'),
        content:Text('Remove '+
          (row['display_name']?.toString() ?? 'this member')+
          ' from this Block? They will lose access to new messages.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialog,false),
            child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(dialog,true),
            child:const Text('Remove')),
        ],
      ),
    );
    if(confirmed!=true)return;
    setState(()=>operating=true);
    try {
      await widget.service.removeMember(widget.block.id,row['user_id'] as String);
      if(mounted)setState(refresh);
    } catch (_) {if(mounted)toast('Could not remove this member.');}
    finally {if(mounted)setState(()=>operating=false);}
  }

  Future<void> moderate(int reportId,{required bool removeMessage}) async {
    if(operating)return;
    setState(()=>operating=true);
    try {
      await widget.service.moderate(reportId,removeMessage:removeMessage);
      if(mounted)setState(refresh);
    } catch (_) {if(mounted)toast('Could not review report.');}
    finally {if(mounted)setState(()=>operating=false);}
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.block.name+' members'),
      actions:[IconButton(onPressed:()=>setState(refresh),
        tooltip:'Refresh',icon:const Icon(Icons.refresh))]),
    body:SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[
      if(widget.block.administrator)...[
        Card(child:Padding(padding:const EdgeInsets.all(16),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Grow your Block',
              style:Theme.of(context).textTheme.titleMedium),
            const SizedBox(height:8),
            const Text('Only administrators can create invitations. '
              'Each person needs a separate code and approval.'),
            const SizedBox(height:12),
            FilledButton.icon(onPressed:operating?null:invite,
              icon:const Icon(Icons.person_add_alt),
              label:const Text('Create invitation')),
          ]),
        )),
        const SizedBox(height:16),
        Text('Join requests',style:Theme.of(context).textTheme.titleLarge),
        FutureBuilder<List<Map<String,dynamic>>>(future:pending,
          builder:(context,snapshot){
            if(snapshot.hasError){return const ListTile(
              title:Text('Join requests unavailable.'));}
            if(!snapshot.hasData){return const LinearProgressIndicator();}
            if(snapshot.data!.isEmpty){return const ListTile(
              title:Text('No one is awaiting approval.'));}
            return Column(children:[
              for(final row in snapshot.data!)
                Card(child:ListTile(
                  title:Text(row['display_name']?.toString()??'Neighbour'),
                  subtitle:const Text('Request to join'),
                  trailing:Wrap(spacing:0,children:[
                    IconButton(tooltip:'Reject',onPressed:operating?null:
                      ()=>decide(row['user_id'] as String,false),
                      icon:const Icon(Icons.close)),
                    IconButton(tooltip:'Approve',onPressed:operating?null:
                      ()=>decide(row['user_id'] as String,true),
                      icon:const Icon(Icons.check_circle_outline)),
                  ]),
                )),
            ]);
          }),
        const SizedBox(height:18),
      ],
      Text('People in this Block',style:Theme.of(context).textTheme.titleLarge),
      FutureBuilder<List<Map<String,dynamic>>>(future:members,
        builder:(context,snapshot){
          if(snapshot.hasError){return const ListTile(
            title:Text('Members unavailable.'));}
          if(!snapshot.hasData)return const LinearProgressIndicator();
          return Column(children:[
            for(final row in snapshot.data!)
              Card(child:ListTile(
                leading:const CircleAvatar(child:Icon(Icons.person_outline)),
                title:Text(row['display_name']?.toString()??'Neighbour'),
                subtitle:Text(row['role']?.toString()??'member'),
                trailing:widget.block.administrator&&row['role']=='member'
                  ?IconButton(tooltip:'Remove member',onPressed:operating?null:
                    ()=>removeMember(row),
                    icon:const Icon(Icons.person_remove_outlined))
                  :null,
              )),
          ]);
        }),
      if(widget.block.administrator)...[
        const SizedBox(height:20),
        Text('Reported messages',style:Theme.of(context).textTheme.titleLarge),
        FutureBuilder<List<Map<String,dynamic>>>(future:reports,
          builder:(context,snapshot){
            if(snapshot.hasError){return const ListTile(
              title:Text('Reports unavailable.'));}
            if(!snapshot.hasData)return const LinearProgressIndicator();
            if(snapshot.data!.isEmpty){return const ListTile(
              title:Text('No reports awaiting review.'));}
            return Column(children:[
              for(final row in snapshot.data!)
                Card(child:Padding(padding:const EdgeInsets.all(12),
                  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(row['reason']?.toString()??'',
                      style:const TextStyle(fontWeight:FontWeight.bold)),
                    const SizedBox(height:7),
                    Text(row['message_excerpt']?.toString()??''),
                    const SizedBox(height:8),
                    Wrap(spacing:8,children:[
                      OutlinedButton(onPressed:operating?null:()=>
                        moderate(row['report_id'] as int,removeMessage:false),
                        child:const Text('Dismiss report')),
                      FilledButton(onPressed:operating?null:()=>
                        moderate(row['report_id'] as int,removeMessage:true),
                        child:const Text('Remove message')),
                    ]),
                  ]),
                )),
            ]);
          }),
      ],
      const SizedBox(height:24),
      const Text('Invitations are not proof of residence. '
        'Avoid sharing addresses or private personal information.',
        style:TextStyle(fontSize:12,color:Colors.white70)),
    ])),
  );
}

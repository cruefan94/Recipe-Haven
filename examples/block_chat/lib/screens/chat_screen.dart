import 'package:flutter/material.dart';
import '../models/block_models.dart';
import '../services/block_service.dart';
import 'members_screen.dart';

class BlockChatScreen extends StatefulWidget {
  const BlockChatScreen({
    super.key,required this.block,required this.service,
  });
  final NeighbourhoodBlock block;
  final BlockService service;
  @override State<BlockChatScreen> createState()=>_BlockChatScreenState();
}

class _BlockChatScreenState extends State<BlockChatScreen> {
  final input=TextEditingController();
  late Stream<List<Map<String,dynamic>>> messages;
  int currentChannel=0;
  bool posting=false;

  ChatChannel get channel=>ChatChannel.all[currentChannel];
  bool get mayPost=>channel.key!='announcements'||widget.block.administrator;

  @override void initState(){
    super.initState();
    load();
  }
  void load(){
    messages=widget.service.messages(widget.block.id,channel.key);
  }
  @override void dispose(){input.dispose();super.dispose();}
  void notify(String text)=>ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content:Text(text)));

  Future<void> send() async {
    if(posting||!mayPost)return;
    final value=input.text;
    try {ChatValidation.message(value);}
    on FormatException catch(e){notify(e.message);return;}
    setState(()=>posting=true);
    try {
      await widget.service.send(widget.block.id,channel.key,value);
      input.clear();
    } catch (_) {
      if(mounted)notify('Could not send your message. Check your connection or try again.');
    } finally {
      if(mounted)setState(()=>posting=false);
    }
  }

  Future<void> report(int messageId) async {
    final reason=await showDialog<String>(
      context:context,builder:(dialog)=>SimpleDialog(
        title:const Text('Report this message'),
        children:[
          for(final option in [
            'Harassment','Spam','Safety concern','Inappropriate content',
          ])
            SimpleDialogOption(
              onPressed:()=>Navigator.pop(dialog,option),
              child:Padding(padding:const EdgeInsets.symmetric(vertical:9),
                child:Text(option)),
            ),
          TextButton(onPressed:()=>Navigator.pop(dialog),
            child:const Text('Cancel')),
        ],
      ),
    );
    if(reason==null)return;
    try {
      await widget.service.report(messageId,reason);
      if(mounted)notify('Report sent to Block administrators.');
    } catch (_) {
      if(mounted)notify('Could not submit this report.');
    }
  }

  String timeLabel(Object? raw){
    if(raw is! String)return '';
    final stamp=DateTime.tryParse(raw)?.toLocal();
    if(stamp==null)return '';
    return stamp.hour.toString().padLeft(2,'0')+':'+
      stamp.minute.toString().padLeft(2,'0');
  }

  Widget bubble(Map<String,dynamic> row){
    final own=row['sender_id']==widget.service.myUserId;
    final removed=row['redacted_at']!=null;
    final text=row['body']?.toString()??'';
    final id=row['id'];
    return Align(
      alignment:own?Alignment.centerRight:Alignment.centerLeft,
      child:ConstrainedBox(
        constraints:BoxConstraints(
          maxWidth:MediaQuery.sizeOf(context).width*0.84,
        ),
        child:Card(
          color:own?const Color(0xFF285D55):const Color(0xFF1B3140),
          margin:const EdgeInsets.symmetric(vertical:5,horizontal:12),
          child:Padding(
            padding:const EdgeInsets.fromLTRB(14,10,10,8),
            child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              mainAxisSize:MainAxisSize.min,
              children:[
                Row(mainAxisSize:MainAxisSize.min,children:[
                  Flexible(child:Text(
                    own?'You':row['sender_label']?.toString()??'Neighbour',
                    maxLines:1,overflow:TextOverflow.ellipsis,
                    style:const TextStyle(
                      fontWeight:FontWeight.bold,fontSize:12,
                      color:Color(0xFFA6E3D4)))),
                  if(!own&&!removed&&id is int)
                    PopupMenuButton<String>(
                      tooltip:'Message actions',
                      icon:const Icon(Icons.more_horiz,size:18),
                      onSelected:(action){
                        if(action=='report')report(id);
                      },
                      itemBuilder:(_)=>const [
                        PopupMenuItem(value:'report',
                          child:Text('Report message')),
                      ],
                    ),
                ]),
                Text(text,
                  style:TextStyle(
                    fontSize:15,
                    fontStyle:removed?FontStyle.italic:FontStyle.normal,
                    color:removed?Colors.white70:Colors.white,
                  )),
                const SizedBox(height:5),
                Align(
                  alignment:Alignment.centerRight,
                  child:Text(timeLabel(row['created_at']),
                    style:const TextStyle(
                      color:Colors.white60,fontSize:10)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(
      title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(widget.block.name,
          maxLines:1,overflow:TextOverflow.ellipsis,
          style:const TextStyle(fontWeight:FontWeight.w800)),
        Text(channel.description,maxLines:1,overflow:TextOverflow.ellipsis,
          style:Theme.of(context).textTheme.bodySmall),
      ]),
      actions:[
        IconButton(
          tooltip:'Block members and invitations',
          icon:const Icon(Icons.groups_outlined),
          onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(
            builder:(_)=>BlockMembersScreen(
              block:widget.block,service:widget.service),
          )),
        ),
      ],
    ),
    body:SafeArea(child:Column(children:[
      Expanded(child:StreamBuilder<List<Map<String,dynamic>>>(
        stream:messages,
        builder:(context,snapshot){
          if(snapshot.hasError)return Center(child:Column(
            mainAxisSize:MainAxisSize.min,
            children:[
              const Text('Messages could not be loaded.'),
              const SizedBox(height:10),
              OutlinedButton(onPressed:()=>setState(load),
                child:const Text('Try again')),
            ],
          ));
          if(!snapshot.hasData)return const Center(
            child:CircularProgressIndicator());
          final entries=snapshot.data!;
          if(entries.isEmpty)return Center(
            child:Padding(padding:const EdgeInsets.all(26),
              child:Column(mainAxisSize:MainAxisSize.min,children:[
                const Icon(Icons.forum_outlined,size:48,
                  color:Color(0xFF6CDDCB)),
                const SizedBox(height:12),
                Text('No messages in '+channel.name+' yet.'),
                const SizedBox(height:4),
                if(mayPost)const Text('Start the conversation!'),
              ]),
            ),
          );
          return ListView.builder(
            reverse:true,
            padding:const EdgeInsets.only(top:12,bottom:8),
            itemCount:entries.length,
            itemBuilder:(context,index)=>bubble(entries[index]),
          );
        },
      )),
      if(mayPost)
        Container(
          padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
          decoration:const BoxDecoration(color:Color(0xFF102430)),
          child:Row(children:[
            Expanded(child:TextField(
              controller:input,
              minLines:1,maxLines:4,maxLength:1000,
              textCapitalization:TextCapitalization.sentences,
              textInputAction:TextInputAction.send,
              onSubmitted:(_)=>send(),
              decoration:const InputDecoration(
                hintText:'Message your Block',
                counterText:'',
                border:OutlineInputBorder(),
              ),
            )),
            const SizedBox(width:8),
            IconButton.filled(
              tooltip:'Send message',
              onPressed:posting?null:send,
              icon:Icon(posting?Icons.hourglass_top:Icons.send),
            ),
          ]),
        )
      else
        const Padding(padding:EdgeInsets.all(14),
          child:Text('Only Block administrators can post announcements.')),
    ])),
    bottomNavigationBar:NavigationBar(
      selectedIndex:currentChannel,
      onDestinationSelected:(index)=>setState((){
        currentChannel=index;
        load();
      }),
      labelBehavior:NavigationDestinationLabelBehavior.alwaysShow,
      destinations:const [
        NavigationDestination(icon:Icon(Icons.chat_bubble_outline),
          label:'Chat'),
        NavigationDestination(icon:Icon(Icons.campaign_outlined),
          label:'Notices'),
        NavigationDestination(icon:Icon(Icons.handshake_outlined),
          label:'Help'),
        NavigationDestination(icon:Icon(Icons.event_outlined),
          label:'Events'),
      ],
    ),
  );
}

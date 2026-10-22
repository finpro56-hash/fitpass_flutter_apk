import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

const appName = 'FitProgress';
final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isEmpty || key.isEmpty) {
    runApp(const SetupRequiredApp());
    return;
  }
  await Supabase.initialize(url: url, anonKey: key);
  runApp(const FitProgressApp());
}

class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: appTheme,
    home: const Scaffold(body: Center(child: Padding(padding: EdgeInsets.all(28), child: Text('Supabase configuration is missing. Run with --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_PUBLISHABLE_KEY=...', textAlign: TextAlign.center)))),
  );
}

final appTheme = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF16A085), brightness: Brightness.light), useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFF5F7F8), appBarTheme: const AppBarTheme(backgroundColor: Colors.white, surfaceTintColor: Colors.white), cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE8ECEF))));

class FitProgressApp extends StatelessWidget {
  const FitProgressApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner: false, title: appName, theme: appTheme, home: const AuthGate());
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: supabase.auth.onAuthStateChange,
    builder: (context, snapshot) => supabase.auth.currentUser == null ? const SignInPage() : const ProfileGate(),
  );
}

class SignInPage extends StatefulWidget { const SignInPage({super.key}); @override State<SignInPage> createState() => _SignInPageState(); }
class _SignInPageState extends State<SignInPage> {
  final email = TextEditingController(); final password = TextEditingController(); final name = TextEditingController();
  bool create = false, busy = false, showPassword = false; String? error;
  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    try {
      if (create) {
        await supabase.auth.signUp(email: email.text.trim(), password: password.text, data: {'display_name': name.text.trim()});
      } else { await supabase.auth.signInWithPassword(email: email.text.trim(), password: password.text); }
    } on AuthException catch (e) { setState(() => error = e.message); }
      catch (e) { setState(() => error = 'Could not connect. Check your configuration and network.'); }
    if (mounted) setState(() => busy = false);
  }
  @override void dispose() { email.dispose(); password.dispose(); name.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 64, height: 64, decoration: BoxDecoration(color: const Color(0xFFDDF7EF), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.fitness_center, color: Color(0xFF087F68), size: 34)), const SizedBox(height: 24),
    const Text('FitProgress', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text(create ? 'Create your account to get started.' : 'Your gym, training and progress in one place.', style: const TextStyle(color: Colors.black54)), const SizedBox(height: 28),
    if (create) ...[TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder())), const SizedBox(height: 14)],
    TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder())), const SizedBox(height: 14),
    TextField(controller: password, obscureText: !showPassword, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => showPassword = !showPassword)))),
    if (error != null) ...[const SizedBox(height: 12), Text(error!, style: const TextStyle(color: Colors.red))], const SizedBox(height: 20),
    SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : submit, child: busy ? const SizedBox(height: 20,width:20,child:CircularProgressIndicator(strokeWidth:2)) : Text(create ? 'Create account' : 'Sign in'))), const SizedBox(height: 10),
    Center(child: TextButton(onPressed: () => setState(() { create = !create; error = null; }), child: Text(create ? 'Already have an account? Sign in' : 'New to FitProgress? Create account'))),
    const SizedBox(height: 16), const Text('New accounts start without a gym role. Ask your gym admin to add you, or create your gym from the setup screen if you are the owner.', style: TextStyle(color: Colors.black54, fontSize: 12)),
  ])))));
}

class ProfileGate extends StatefulWidget { const ProfileGate({super.key}); @override State<ProfileGate> createState() => _ProfileGateState(); }
class _ProfileGateState extends State<ProfileGate> {
  bool loading = true; String? name, error; List<Map<String,dynamic>> memberships = [];
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final uid = supabase.auth.currentUser!.id;
      final p = await supabase.from('profiles').select('display_name').eq('id', uid).maybeSingle();
      final m = await supabase.from('gym_memberships').select('gym_id,role,is_active,gyms(id,name)').eq('user_id', uid).eq('is_active', true);
      if (mounted) setState(() { name = (p?['display_name'] as String?)?.trim(); memberships = List<Map<String,dynamic>>.from(m); loading = false; });
    } catch (e) { if (mounted) setState(() { error = 'Could not load profile or gym membership. ${e.toString()}'; loading = false; }); }
  }
  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (memberships.isNotEmpty) return DashboardPage(displayName: (name?.isNotEmpty == true ? name! : 'there'), membership: memberships.first);
    return SetupGymPage(displayName: name ?? '');
  }
}

class SetupGymPage extends StatefulWidget { final String displayName; const SetupGymPage({super.key, required this.displayName}); @override State<SetupGymPage> createState() => _SetupGymPageState(); }
class _SetupGymPageState extends State<SetupGymPage> {
  final gym = TextEditingController(); bool busy = false; String? error;
  Future<void> createGym() async {
    if (gym.text.trim().length < 2) { setState(() => error = 'Enter a gym name (at least 2 characters).'); return; }
    setState(() { busy = true; error = null; });
    try { await supabase.rpc('fp_create_gym', params: {'p_name': gym.text.trim()}); if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ProfileGate())); }
    catch (e) { setState(() => error = 'Gym creation failed: $e'); }
    if (mounted) setState(() => busy = false);
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text(appName), actions: [IconButton(onPressed: () => supabase.auth.signOut(), icon: const Icon(Icons.logout))]), body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.apartment, size: 42, color: Color(0xFF0C9478)), const SizedBox(height: 18), Text('Welcome${widget.displayName.isNotEmpty ? ', ${widget.displayName}' : ''}!', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('Create a gym workspace, or ask your gym admin to add your account.'), const SizedBox(height: 24), TextField(controller: gym, decoration: const InputDecoration(labelText: 'Gym name', hintText: 'e.g. FitProgress Fitness', border: OutlineInputBorder())), if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))), const SizedBox(height: 18), SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : createGym, child: busy ? const CircularProgressIndicator() : const Text('Create gym as admin'))), const SizedBox(height: 8), const Text('No setup secret is needed. The signed-in account that creates the gym becomes its admin.', style: TextStyle(fontSize: 12, color: Colors.black54))]))))));
}

class DashboardPage extends StatefulWidget { final String displayName; final Map<String,dynamic> membership; const DashboardPage({super.key, required this.displayName, required this.membership}); @override State<DashboardPage> createState() => _DashboardPageState(); }
class _DashboardPageState extends State<DashboardPage> {
  int tab = 0; bool busy = false; String? error; List<Map<String,dynamic>> members = []; List<Map<String,dynamic>> rows = [];
  String get role => widget.membership['role'] as String; String get gymId => widget.membership['gym_id'] as String; String get gymName => (widget.membership['gyms'] as Map?)?['name']?.toString() ?? 'Your gym'; String get uid => supabase.auth.currentUser!.id;
  final sections = const ['Overview','Attendance','Workouts','Diet','Payments','Members'];
  @override void initState() { super.initState(); loadTab(); }
  Future<void> loadTab([int selectedTab]) async {
    final activeTab = selectedTab ?? tab;
    setState(() { busy = true; error = null; });
    try {
      if (activeTab == 5 && role == 'admin') {
        final ms = await supabase.from('gym_memberships').select('user_id,role,is_active,profiles(display_name,phone)').eq('gym_id', gymId).eq('is_active', true);
        members = List<Map<String,dynamic>>.from(ms);
      } else if (activeTab == 1) {
        var q = supabase.from('attendance').select('id,client_user_id,attended_at,status,note').eq('gym_id', gymId).order('attended_at', ascending: false).limit(100);
        if (role == 'client') q = q.eq('client_user_id', uid);
        rows = List<Map<String,dynamic>>.from(await q);
      } else if (activeTab == 2) {
        var q = supabase.from('workout_plans').select('id,client_user_id,title,notes,created_at,is_active').eq('gym_id', gymId).order('created_at', ascending: false).limit(100);
        if (role == 'client') q = q.eq('client_user_id', uid);
        if (role == 'trainer') { final assigned = await assignedClientIds(); q = q.inFilter('client_user_id', assigned.isEmpty ? ['00000000-0000-0000-0000-000000000000'] : assigned); }
        rows = List<Map<String,dynamic>>.from(await q);
      } else if (activeTab == 3) {
        var q = supabase.from('diet_plans').select('id,client_user_id,title,notes,created_at,is_active').eq('gym_id', gymId).order('created_at', ascending: false).limit(100);
        if (role == 'client') q = q.eq('client_user_id', uid);
        if (role == 'trainer') { final assigned = await assignedClientIds(); q = q.inFilter('client_user_id', assigned.isEmpty ? ['00000000-0000-0000-0000-000000000000'] : assigned); }
        rows = List<Map<String,dynamic>>.from(await q);
      } else if (activeTab == 4) {
        var q = supabase.from('payments').select('id,client_user_id,amount_paise,payment_date,status,method').eq('gym_id', gymId).order('payment_date', ascending: false).limit(100);
        if (role != 'admin') q = q.eq('client_user_id', uid);
        rows = List<Map<String,dynamic>>.from(await q);
      }
    } catch (e) { error = 'Unable to load this section. $e'; }
    if (mounted) setState(() => busy = false);
  }
  Future<List<String>> assignedClientIds() async { final a = await supabase.from('trainer_client_assignments').select('client_user_id').eq('gym_id', gymId).eq('trainer_user_id', uid); return List<Map<String,dynamic>>.from(a).map((e) => e['client_user_id'].toString()).toList(); }
  Future<void> addAttendance() async {
    if (role != 'trainer' && role != 'admin') return;
    final target = await chooseClient(); if (target == null) return;
    try { await supabase.from('attendance').insert({'gym_id': gymId, 'client_user_id': target['user_id'], 'recorded_by': uid, 'status':'present', 'attended_at': DateTime.now().toUtc().toIso8601String()}); await loadTab(); }
    catch (e) { setState(() => error = 'Attendance could not be saved: $e'); }
  }
  Future<Map<String,dynamic>?> chooseClient() async {
    final data = await supabase.from('gym_memberships').select('user_id,profiles(display_name)').eq('gym_id', gymId).eq('role','client').eq('is_active',true);
    var options = List<Map<String,dynamic>>.from(data);
    if (role == 'trainer') { final ids = await assignedClientIds(); options = options.where((x) => ids.contains(x['user_id'])).toList(); }
    if (!mounted || options.isEmpty) { setState(() => error = 'No clients available for your role. Ask the admin to assign clients to your trainer account.'); return null; }
    return showDialog<Map<String,dynamic>>(context: context, builder: (ctx) => SimpleDialog(title: const Text('Select client'), children: options.map((m) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx,m), child: Text(((m['profiles'] as Map?)?['display_name'] ?? 'Client').toString()))).toList());
  }
  Future<void> addPlan({required bool diet}) async {
    final title = TextEditingController(); final note = TextEditingController(); final meal = TextEditingController();
    final target = role == 'client' ? {'user_id':uid} : await chooseClient(); if (target == null || !mounted) return;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(diet ? 'New diet plan' : 'New workout plan'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller:title,decoration:const InputDecoration(labelText:'Plan title')), TextField(controller:note,decoration:const InputDecoration(labelText:'Notes')), if (diet) TextField(controller:meal,decoration:const InputDecoration(labelText:'Meal summary (optional)'))])), actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,title.text.trim().isNotEmpty),child:const Text('Save'))]));
    if (ok != true) return;
    try {
      final table = diet ? 'diet_plans' : 'workout_plans';
      final created = await supabase.from(table).insert({'gym_id':gymId,'client_user_id':target['user_id'],'created_by':uid,'title':title.text.trim(),'notes':note.text.trim(),'is_active':true}).select('id').single();
      if (diet && meal.text.trim().isNotEmpty) { await supabase.from('diet_meals').insert({'plan_id':created['id'],'meal_type':'breakfast','meal_name':meal.text.trim(),'sort_order':0}); }
      await loadTab();
    } catch(e) { setState(()=>error='Plan could not be saved: $e'); }
  }
  Future<void> addPayment() async {
    if(role!='admin') return; final target=await chooseClient(); if(target==null) return;
    final amount=TextEditingController(); final method=TextEditingController(text:'UPI');
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Record payment'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Amount (₹)')),TextField(controller:method,decoration:const InputDecoration(labelText:'Method'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,double.tryParse(amount.text.trim())!=null&&double.parse(amount.text.trim())>0),child:const Text('Save'))]));
    if(ok!=true)return; try{await supabase.from('payments').insert({'gym_id':gymId,'client_user_id':target['user_id'],'recorded_by':uid,'amount_paise':(double.parse(amount.text.trim())*100).round(),'method':method.text.trim(),'status':'paid','payment_date':DateFormat('yyyy-MM-dd').format(DateTime.now())});await loadTab();}catch(e){setState(()=>error='Payment could not be saved: $e');}
  }
  @override Widget build(BuildContext context) {
    final available = role=='admin' ? [0,1,2,3,4,5] : role=='trainer' ? [0,1,2,3,5] : [0,1,2,3,4];
    final actualTab = available.contains(tab) ? tab : 0;
    return Scaffold(appBar: AppBar(title: Text(gymName), actions:[IconButton(tooltip:'Refresh',onPressed:loadTab,icon:const Icon(Icons.refresh)),IconButton(tooltip:'Sign out',onPressed:()=>supabase.auth.signOut(),icon:const Icon(Icons.logout))]), body: RefreshIndicator(onRefresh:loadTab,child:ListView(padding:const EdgeInsets.all(16),children:[
      Text('Hello, ${widget.displayName} 👋',style:const TextStyle(fontSize:25,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text('${role[0].toUpperCase()}${role.substring(1)} dashboard',style:const TextStyle(color:Colors.black54)),const SizedBox(height:18),
      if(actualTab==0) ...overview() else if(actualTab==5 && role=='admin') ...memberList() else ...dataSection(actualTab),
    ])), bottomNavigationBar: NavigationBar(selectedIndex: available.indexOf(actualTab), onDestinationSelected:(i){final nextTab=available[i];setState(()=>tab=nextTab);loadTab(nextTab);}, destinations: available.map((i)=>NavigationDestination(icon:Icon([Icons.dashboard_outlined,Icons.fact_check_outlined,Icons.fitness_center,Icons.restaurant_outlined,Icons.payments_outlined,Icons.groups_outlined][i]),label:sections[i])).toList()));
  }
  List<Widget> overview() => [
    Card(child:Padding(padding:const EdgeInsets.all(18),child:Row(children:[Container(width:48,height:48,decoration:BoxDecoration(color:const Color(0xFFDDF7EF),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.apartment,color:Color(0xFF087F68))),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Workspace',style:TextStyle(color:Colors.black54)),Text(gymName,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),Text('Timezone: India Standard Time',style:const TextStyle(fontSize:12,color:Colors.black54))]))]))),const SizedBox(height:12),
    if(role=='admin') ...[actionTile(Icons.groups,'Manage members','View members and roles',()=>{setState(()=>tab=5),loadTab()}),actionTile(Icons.payments,'Record payment','Add a payment for a client',addPayment)],
    if(role=='trainer'||role=='admin') actionTile(Icons.fact_check,'Mark attendance','Record attendance for a client',addAttendance),
    actionTile(Icons.fitness_center,'Workout plans','View or create workout plans',()=>{setState(()=>tab=2),loadTab()}),actionTile(Icons.restaurant,'Diet plans','View or create diet plans',()=>{setState(()=>tab=3),loadTab()}),
    const SizedBox(height:10),const Text('Your data is protected by Supabase row-level security. Clients only see their own records; trainers are limited to assigned clients.',style:TextStyle(color:Colors.black54,fontSize:12)),
  ];
  Widget actionTile(IconData icon,String title,String subtitle,VoidCallback onTap)=>Card(child:ListTile(leading:CircleAvatar(backgroundColor:const Color(0xFFE7F6F1),child:Icon(icon,color:const Color(0xFF087F68))),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w600)),subtitle:Text(subtitle),trailing:const Icon(Icons.chevron_right),onTap:onTap));
  List<Widget> memberList()=>[const Text('Gym members',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),const SizedBox(height:10),if(busy)const Center(child:CircularProgressIndicator()),if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),...members.map((m){final p=m['profiles'] as Map?;return Card(child:ListTile(leading:CircleAvatar(child:Text(((p?['display_name']??'U').toString().isNotEmpty?(p?['display_name']??'U').toString()[0]:'U').toUpperCase())),title:Text((p?['display_name']??'Member').toString()),subtitle:Text((m['role']??'client').toString()),trailing:const Icon(Icons.verified_user_outlined)));}),const SizedBox(height:8),const Text('Member invitations and account creation should be handled through Supabase Auth, then assigned here by an authenticated admin.',style:TextStyle(fontSize:12,color:Colors.black54))];
  List<Widget> dataSection(int selected)=>[
    Row(children:[Expanded(child:Text(sections[selected],style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold))),if(selected==1&&(role=='trainer'||role=='admin'))IconButton.filledTonal(onPressed:addAttendance,icon:const Icon(Icons.add)),if(selected==2&&(role=='trainer'||role=='admin'))IconButton.filledTonal(onPressed:()=>addPlan(diet:false),icon:const Icon(Icons.add)),if(selected==3&&role!='admin')IconButton.filledTonal(onPressed:()=>addPlan(diet:true),icon:const Icon(Icons.add)),if(selected==4&&role=='admin')IconButton.filledTonal(onPressed:addPayment,icon:const Icon(Icons.add))]),const SizedBox(height:10),if(busy)const Center(child:Padding(padding:EdgeInsets.all(20),child:CircularProgressIndicator())),if(error!=null)Padding(padding:const EdgeInsets.only(bottom:10),child:Text(error!,style:const TextStyle(color:Colors.red))),if(!busy&&rows.isEmpty&&error==null)const Card(child:Padding(padding:EdgeInsets.all(22),child:Center(child:Text('Nothing here yet.')))),...rows.map((r)=>recordCard(selected,r))
  ];
  Widget recordCard(int selected,Map<String,dynamic> r){
    String title='',subtitle=''; IconData icon=Icons.info_outline;
    if(selected==1){title=(r['status']??'present').toString().toUpperCase();subtitle='${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(r['attended_at'].toString()).toLocal())}';if(role!='client')subtitle+=' • Client ${r['client_user_id'].toString().substring(0,8)}';icon=Icons.fact_check;}
    if(selected==2||selected==3){title=(r['title']??'Plan').toString();subtitle=(r['notes']??'No notes').toString();if(role!='client')subtitle+='\nClient ${r['client_user_id'].toString().substring(0,8)}';icon=selected==2?Icons.fitness_center:Icons.restaurant;}
    if(selected==4){title='₹${((r['amount_paise'] as num)/100).toStringAsFixed(2)} • ${(r['status']??'paid').toString()}';subtitle='${r['payment_date']} • ${(r['method']??'Payment').toString()}';icon=Icons.payments;}
    return Card(child:ListTile(leading:CircleAvatar(backgroundColor:const Color(0xFFE7F6F1),child:Icon(icon,color:const Color(0xFF087F68))),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w600)),subtitle:Text(subtitle),isThreeLine:subtitle.contains('\n')));
  }
}

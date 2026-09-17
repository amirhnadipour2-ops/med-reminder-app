import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  runApp(const MedReminderApp());
}

class MedReminderApp extends StatelessWidget {
  const MedReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'یادآور دارو',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
      ),
      home: const HomeScreen(),
    );
  }
}

class Medicine {
  final String id;
  final String name;
  final String dose;
  final String time;
  final String type; // 'weekly' or 'interval'
  final String details;

  Medicine({
    required this.id,
    required this.name,
    required this.dose,
    required this.time,
    required this.type,
    required this.details,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'dose': dose,
        'time': time,
        'type': type,
        'details': details,
      };

  factory Medicine.fromMap(Map<String, dynamic> map) => Medicine(
        id: map['id'],
        name: map['name'],
        dose: map['dose'],
        time: map['time'],
        type: map['type'],
        details: map['details'],
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Medicine> medicines = [];

  @override
  void initState() {
    super.initState();
    _loadMedicines();
    _requestNotificationPermission();
  }

  void _requestNotificationPermission() {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _loadMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('med_list');
    if (data != null) {
      final List decoded = jsonDecode(data);
      setState(() {
        medicines = decoded.map((item) => Medicine.fromMap(item)).toList();
      });
    }
  }

  Future<void> _saveMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded =
        jsonEncode(medicines.map((m) => m.toMap()).toList());
    await prefs.setString('med_list', encoded);
  }

  Future<void> _scheduleNotification(int id, String title, String body, int hour, int minute) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'med_channel_id',
      'یادآور داروها',
      channelDescription: 'اعلان‌های زمان مصرف داروها',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  void _addMedicineDialog() {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    String selectedType = 'روزانه';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'ثبت داروی جدید',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نام دارو (مثال: سرترالین)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: doseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'دوز یا مقدار مصرف (مثال: ۱ عدد یا ۵۰ میلی‌گرم)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('نوع مصرف: '),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: selectedType,
                      items: const [
                        DropdownMenuItem(value: 'روزانه', child: Text('روزانه (تکرار منظم)')),
                        DropdownMenuItem(value: 'هفتگی', child: Text('هفتگی')),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          selectedType = val!;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListTile(
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  title: Text('ساعت مصرف: ${selectedTime.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (picked != null) {
                      setModalState(() {
                        selectedTime = picked;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;

                    final notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                    final newMed = Medicine(
                      id: notifId.toString(),
                      name: nameCtrl.text.trim(),
                      dose: doseCtrl.text.trim().isEmpty ? '۱ دوز' : doseCtrl.text.trim(),
                      time: selectedTime.format(context),
                      type: selectedType,
                      details: 'ساعت ${selectedTime.format(context)}',
                    );

                    await _scheduleNotification(
                      notifId,
                      'زمان مصرف دارو 💊',
                      'وقت مصرف ${newMed.name} (${newMed.dose}) است.',
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    setState(() {
                      medicines.add(newMed);
                    });
                    _saveMedicines();

                    Navigator.pop(ctx);
                  },
                  child: const Text('ذخیره و تنظیم هشدار', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deleteMedicine(int index) async {
    final med = medicines[index];
    final int? notifId = int.tryParse(med.id);
    if (notifId != null) {
      await flutterLocalNotificationsPlugin.cancel(notifId);
    }
    setState(() {
      medicines.removeAt(index);
    });
    _saveMedicines();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('یادآور هوشمند دارو', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: medicines.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.medication_outlined, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'هیچ دارویی ثبت نشده است.\nبا زدن دکمه پایین داروی جدید اضافه کنید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: medicines.length,
                itemBuilder: (context, index) {
                  final med = medicines[index];
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.alarm, color: Colors.white),
                      ),
                      title: Text(
                        med.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      subtitle: Text('دوز: ${med.dose} | زمان: ${med.time} (${med.type})'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteMedicine(index),
                      ),
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          onPressed: _addMedicineDialog,
          icon: const Icon(Icons.add),
          label: const Text('افزودن دارو'),
        ),
      ),
    );
  }
}

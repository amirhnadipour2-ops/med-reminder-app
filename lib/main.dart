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
  tz.setLocalLocation(tz.getLocation('Asia/Tehran'));

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
      ),
      home: const HomeScreen(),
    );
  }
}

class Medicine {
  final String id; // notification id as string
  final String name;
  final String dose;
  final String time; // formatted string (e.g., 08:30)
  final String type; // 'روزانه' یا 'هفتگی'
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
        id: (map['id'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        dose: (map['dose'] ?? '').toString(),
        time: (map['time'] ?? '').toString(),
        type: (map['type'] ?? '').toString(),
        details: (map['details'] ?? '').toString(),
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
    _requestAndroidPermissions();
  }

  Future<void> _requestAndroidPermissions() async {
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            Android shows the runtime notification permission dialog.
    await androidPlugin?.requestNotificationsPermission();

    // Needed when using exact alarms mode (Android 12+ may require user approval).
    await androidPlugin?.requestExactAlarmsPermission();
  }

  Future<void> _loadMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('med_list');
    if (data == null) return;

    try {
      final List decoded = jsonDecode(data);
      setState(() {
        medicines = decoded
            .whereType<Map>()
            .map((m) => Medicine.fromMap(m.cast<String, dynamic>()))
            .toList();
      });
    } catch (_) {
      // ignore corrupted data
    }
  }

  Future<void> _saveMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(medicines.map((m) => m.toMap()).toList());
    await prefs.setString('med_list',toList());
    await prefs.setString('med_list',({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'med_channel_id',
      'یادآور داروها',
      channelDescription: 'اعلان‌های زمان مصرف داروها',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ثبت داروی جدید',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نام دارو',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: doseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'دوز/مقدار مصرف',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('نوع: '),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: selectedType,
                      items: const [
                        DropdownMenuItem(
                            value: 'روزانه', child: Text('روزانه')),
                        DropdownMenuItem(value: 'هفتگی', child: Text('هفتگی')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setModalState(() => selectedType = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ListTile(
                  title: Text('ساعت: ${selectedTime.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.black12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (picked != null) {
                      setModalState(() => selectedTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;

                      final dose = doseCtrl.text.trim().isEmpty
                          ? '۱ دوز'
                          : doseCtrl.text.trim();

                      final notifId =
                          DateTime.now().millisecondsSinceEpoch ~/ 1000;

                      final med = Medicine(
                        id: notifId.toString(),
                        name: name,
                        dose: dose,
                        time: selectedTime.format(context),
                        type: selectedType,
                        details: '',
                      );

                      await _scheduleDailyNotification(
                        id: notifId,
                        title: 'زمان مصرف دارو',
                        body: 'وقت مصرف ${med.name} (${med.dose}) است.',
                        hour: selectedTime.hour,
                        minute: selectedTime.minute,
                      );

                      setState(() => medicines.add(med));
                      await _saveMedicines();

                      if (mounted) Navigator.pop(ctx);
                    },
                    child: const Text('ذخیره و تنظیم هشدار'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteMedicine(int index) async {
    final med = medicines[index];
    final notifId = int.tryParse(med.id);
    if (notifId != null) {
      await flutterLocalNotificationsPlugin.cancel(notifId);
    }
    setState(() => medicines.removeAt(index));
    await _saveMedicines();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('یادآور دارو'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: medicines.isEmpty
            ? const Center(child: Text('هنوز دارویی ثبت نشده است.'))
            : ListView.builder(
                itemCount: medicines.length,
                itemBuilder: (context, index) {
                  final med = medicines[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text(med.name),
                      subtitle:
                          Text('دوز: ${med.dose} | زمان: ${med.time} (${med.type})'),
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteMedicine(index),
                      ),
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          onPressed: _addMedicineDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

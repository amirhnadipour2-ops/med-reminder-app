import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  tz.initializeTimeZones();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);

  await notificationsPlugin.initialize(initSettings);

  final androidPlatform = notificationsPlugin.resolvePlatformSpecificImplementation
      AndroidFlutterLocalNotificationsPlugin>();

  await androidPlatform?.requestNotificationsPermission();
  await androidPlatform?.requestExactAlarmsPermission();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
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
        fontFamily: 'Roboto',
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
  final String type;
  bool isTaken;

  Medicine({
    required this.id,
    required this.name,
    required this.dose,
    required this.time,
    required this.type,
    this.isTaken = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'dose': dose,
        'time': time,
        'type': type,
        'isTaken': isTaken,
      };

  factory Medicine.fromMap(Map<String, dynamic> map) => Medicine(
        id: (map['id'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        dose: (map['dose'] ?? '').toString(),
        time: (map['time'] ?? '').toString(),
        type: (map['type'] ?? 'روزانه').toString(),
        isTaken: map['isTaken'] ?? false,
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
  }

  Future<void> _loadMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('medicines_data');
    if (data != null) {
      try {
        final List decoded = jsonDecode(data);
        setState(() {
          medicines = decoded
              .whereType<Map>()
              .map((item) => Medicine.fromMap(item.cast<String, dynamic>()))
              .toList();
        });
      } catch (_) {}
    }
  }

  Future<void> _saveMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded =
        jsonEncode(medicines.map((m) => m.toMap()).toList());
    await prefs.setString('medicines_data', encoded);
  }

  Future<void> _checkAndRequestPermissions() async {
    final androidPlatform = notificationsPlugin.resolvePlatformSpecificImplementation
        AndroidFlutterLocalNotificationsPlugin>();

    final notifGranted = await androidPlatform?.areNotificationsEnabled() ?? false;
    final exactAlarmGranted =
        await androidPlatform?.canScheduleExactNotifications() ?? false;

    if (!notifGranted) {
      await androidPlatform?.requestNotificationsPermission();
    }
    if (!exactAlarmGranted) {
      await androidPlatform?.requestExactAlarmsPermission();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notifGranted && exactAlarmGranted
                ? 'مجوزها فعال هستند'
                : 'در حال درخواست مجوز... اگر دیالوگ باز نشد، از تنظیمات گوشی فعال کن',
          ),
        ),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'med_channel',
      'یادآور دارو',
      channelDescription: 'نوتیفیکیشن‌های یادآوری مصرف دارو',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await notificationsPlugin.zonedSchedule(
      0,
      'تست یادآور دارو',
      'سیستم نوتیفیکیشن برنامه با موفقیت فعال شد!',
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  void _addMedicineDialog() {
    final nameController = TextEditingController();
    final doseController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    String selectedType = 'روزانه';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  'افزودن داروی جدید',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'نام دارو',
                    hintText: 'مثال: آسپرین، سرترالین',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: doseController,
                  decoration: const InputDecoration(
                    labelText: 'دوز یا تعداد',
                    hintText: 'مثال: ۱ عدد، ۵۰ میلی‌گرم',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('دوره مصرف: '),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: selectedType,
                      items: const [
                        DropdownMenuItem(value: 'روزانه', child: Text('روزانه')),
                        DropdownMenuItem(value: 'هفتگی', child: Text('هفتگی')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedType = val);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.black26),
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
                      setModalState(() => selectedTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;

                    final newMed = Medicine(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text.trim(),
                      dose: doseController.text.trim().isEmpty
                          ? '۱ دوز'
                          : doseController.text.trim(),
                      time: selectedTime.format(context),
                      type: selectedType,
                    );

                    setState(() {
                      medicines.add(newMed);
                    });
                    await _saveMedicines();

                    if (mounted) Navigator.pop(ctx);
                  },
                  child: const Text('ذخیره دارو', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deleteMedicine(int index) async {
    setState(() {
      medicines.removeAt(index);
    });
    await _saveMedicines();
  }

  void _toggleTaken(int index) async {
    setState(() {
      medicines[index].isTaken = !medicines[index].isTaken;
    });
    await _saveMedicines();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('یادآور هوشمند دارو'),
          centerTitle: true,
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_active),
              tooltip: 'بررسی و تست نوتیفیکیشن',
              onPressed: () async {
                await _checkAndRequestPermissions();
                await _sendTestNotification();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('نوتیفیکیشن تست ۵ ثانیه دیگر ارسال می‌شود...'),
                    ),
                  );
                }
              },
            )
          ],
        ),
        body: medicines.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.medical_services_outlined,
                        size: 70, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'هنوز هیچ دارویی ثبت نشده است.\nاز دکمه پایین برای افزودن دارو استفاده کنید.',
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
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: IconButton(
                        icon: Icon(
                          med.isTaken
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: med.isTaken ? Colors.green : Colors.grey,
                        ),
                        onPressed: () => _toggleTaken(index),
                      ),
                      title: Text(
                        med.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: med.isTaken
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Text(
                          'دوز: ${med.dose} | ساعت: ${med.time} (${med.type})'),
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();
  final String timeZoneName = await _getLocalTimeZone();
  tz.setLocalLocation(tz.getLocation(timeZoneName));

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);
  await notificationsPlugin.initialize(initSettings);

  final androidPlatform = notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlatform?.requestNotificationsPermission();
  await androidPlatform?.requestExactAlarmsPermission();

  runApp(const MedReminderApp());
}

Future<String> _getLocalTimeZone() async {
  try {
    return 'Asia/Tehran';
  } catch (_) {
    return 'UTC';
  }
}

class MedReminderApp extends StatelessWidget {
  const MedReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'یادآور دارو',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class Medication {
  final int id;
  final String name;
  final String dose;
  final TimeOfDay time;

  const Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dose': dose,
        'hour': time.hour,
        'minute': time.minute,
      };

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
        id: json['id'] as int,
        name: json['name'] as String,
        dose: json['dose'] as String,
        time: TimeOfDay(
          hour: json['hour'] as int,
          minute: json['minute'] as int,
        ),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Medication> _medications = [];

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList('medications') ?? [];
    setState(() {
      _medications = raw
          .map((e) => Medication.fromJson(
              jsonDecode(e) as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> _saveMedications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'medications',
      _medications.map((m) => jsonEncode(m.toJson())).toList(),
    );
  }

  Future<void> _addMedication(Medication med) async {
    setState(() => _medications.add(med));
    await _saveMedications();
    await _scheduleNotification(med);
  }

  Future<void> _removeMedication(int id) async {
    setState(() => _medications.removeWhere((m) => m.id == id));
    await _saveMedications();
    await notificationsPlugin.cancel(id);
  }

  Future<void> _scheduleNotification(Medication med) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      med.time.hour,
      med.time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await notificationsPlugin.zonedSchedule(
      med.id,
      'یادآور دارو',
      '${med.name} — ${med.dose}',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'med_reminder_channel',
          'یادآور دارو',
          channelDescription: 'اطلاع‌رسانی زمان مصرف دارو',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _checkAndRequestPermissions() async {
    final androidPlatform = notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final notifGranted =
        await androidPlatform?.areNotificationsEnabled() ?? false;
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
                : 'در حال درخواست مجوز... در صورت نیاز از تنظیمات فعال کنید',
          ),
        ),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    await notificationsPlugin.show(
      99999,
      'تست اعلان',
      'سیستم اعلان‌های یادآور دارو به درستی فعال است.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'med_reminder_channel',
          'یادآور دارو',
          channelDescription: 'اطلاع‌رسانی زمان مصرف دارو',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddMedicationSheet(onAdd: _addMedication),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('یادآور دارو'),
        centerTitle: true,
        actions:requestNotificationsPermission();
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
                : 'در حال درخواست مجوز... در صورت نیاز از تنظیمات فعال کنید',
          ),
        ),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    await notificationsPlugin.show(
      99999,
      'تست اعلان',
      'سیستم اعلان‌های یادآور دارو به درستی فعال است.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'med_reminder_channel',
          'یادآور دارو',
          channelDescription: 'اطلاع‌رسانی زمان مصرف دارو',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddMedicationSheet(onAdd: _addMedication),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('یادآور دارو'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'بررسی و تست نوتیفیکیشن',
            onPressed: () async {
              await _checkAndRequestPermissions();
              await _sendTestNotification();
            },
          ),
        ],
      ),
      body: _medications.isEmpty
          ? const Center(child: Text('هنوز داروی ثبت‌شده‌ای ندارید.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _medications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                finalpickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final dose = _doseController.text.trim();
    if (name.isEmpty || dose.isEmpty) return;

    final med = Medication(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      name: name,
      dose: dose,
      time: _selectedTime,
    );

    await widget.onAdd(med);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('افزودن دارو',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'نام دارو',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _doseController,
            decoration: const InputDecoration(
              labelText: 'دوز (مثلاً: ۱ قرص)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.access_time),
            label: Text(
                'زمان: ${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }
}

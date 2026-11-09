import 'dart:async';
import 'package:flutter/material.dart';

void main() => runApp(const StudyFlowApp());

// ===================== CONSTANTS & HELPERS =====================
final messengerKey = GlobalKey<ScaffoldMessengerState>();
const purple = Color(0xFF6C5CE7);
const bg = Color(0xFFF6F4FF);
const lav = Color(0xFFEDE9FF);

const typeNames = <String, String>{
  'custom': 'Custom (time based)',
  'study': 'Study (with attendance)',
  'workout': 'Workout',
  'skill': 'Skill learning',
  'sleep': 'Sleep (hours)',
  'water': 'Water (glasses)',
  'food': 'Healthy food (meals)',
};
const defaultTargets = <String, double>{
  'custom': 30, 'study': 240, 'workout': 30, 'skill': 60,
  'sleep': 8, 'water': 8, 'food': 3,
};
const iconChoices = <IconData>[
  Icons.school, Icons.fitness_center, Icons.bedtime, Icons.water_drop,
  Icons.restaurant, Icons.lightbulb, Icons.self_improvement, Icons.menu_book,
  Icons.code, Icons.directions_run, Icons.music_note, Icons.brush,
  Icons.language, Icons.spa,
];
const colorChoices = <Color>[
  Color(0xFF6C5CE7), Color(0xFFE17055), Color(0xFF0984E3), Color(0xFF00B5D8),
  Color(0xFF00B894), Color(0xFFF39C12), Color(0xFFD63031), Color(0xFFE84393),
];

String dkey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String fmtMin(int m) => m >= 60 ? '${m ~/ 60}h ${m % 60}m' : '${m}m';
String fmtNum(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
String fmtSec(int s) {
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, x = s % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${x.toString().padLeft(2, '0')}';
}

String fmtTime(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
}

String fmtDate(DateTime d) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
}

// Whole days from today until [d] (negative = in the past). Uses UTC to avoid daylight-saving errors.
int daysUntil(DateTime d) {
  final n = DateTime.now();
  return DateTime.utc(d.year, d.month, d.day)
      .difference(DateTime.utc(n.year, n.month, n.day))
      .inDays;
}

String dueText(int dl) => dl < 0
    ? 'overdue by ${-dl} day${dl == -1 ? '' : 's'}'
    : dl == 0
        ? 'today'
        : dl == 1
            ? 'tomorrow'
            : 'in $dl days';

void snack(String m) => messengerKey.currentState?.showSnackBar(
    SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

Future<String?> askText(BuildContext c, String title, String hint) {
  final ctl = TextEditingController();
  return showDialog<String>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
          controller: ctl, autofocus: true, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('Save')),
      ],
    ),
  );
}

// ===================== MODELS =====================
class SubItem {
  String name;
  int status = 0; // 0 Not started, 1 In progress, 2 Completed
  SubItem(this.name);
}

class FreeSession {
  DateTime date;
  int sec;
  FreeSession(this.date, this.sec);
}

class Item {
  String name;
  final List<SubItem> subs = [];
  int months = 0; // target period (used by New Skills)
  double targetHours = 0; // planned total hours (used by New Skills)
  DateTime startDate = DateTime.now();
  final List<FreeSession> logs = []; // manually logged time
  Item(this.name);
  DateTime get endDate =>
      DateTime(startDate.year, startDate.month + months, startDate.day);
}

class AttRecord {
  String item;
  bool attended;
  DateTime date;
  AttRecord(this.item, this.attended, this.date);
}

class SleepLog {
  DateTime date;
  double hours;
  SleepLog(this.date, this.hours);
}

class Meal {
  String name;
  bool healthy;
  DateTime date;
  int calories;
  Meal(this.name, this.healthy, this.date, this.calories);
}

// A manual "planned vs actual" entry (minutes).
class PlanLog {
  DateTime date;
  int plannedMin;
  int actualMin;
  String note;
  PlanLog(this.date, this.plannedMin, this.actualMin, this.note);
}

class Assignment {
  String title;
  String? subject;
  DateTime due;
  String notes;
  bool done = false;
  DateTime? doneOn;
  Assignment(this.title, this.subject, this.due, this.notes);
}

class Exam {
  String title;
  String? subject;
  DateTime date;
  String notes;
  bool done = false;
  Exam(this.title, this.subject, this.date, this.notes);
}

class Deadline {
  final DateTime date;
  final String title;
  final String where;
  final bool exam;
  Deadline(this.date, this.title, this.where, this.exam);
}

class Category {
  String name;
  IconData icon;
  Color color;
  String type;
  double target;
  final List<Item> items = [];
  final List<AttRecord> att = [];
  final List<SleepLog> sleep = [];
  final Map<String, int> water = {};
  final List<Meal> meals = [];
  final List<FreeSession> sessions = [];
  final List<PlanLog> plans = [];
  final List<Assignment> assignments = [];
  final List<Exam> exams = [];
  int attTarget = 75;
  int waterEvery = 0; // minutes, 0 = off
  int calorieGoal = 2000; // daily calorie goal set by the user
  DateTime? lastWater;
  TimeOfDay? bedtime;
  String? bedKey;

  Category(this.name, this.icon, this.color, this.type, this.target);

  bool get isTime => type != 'sleep' && type != 'water' && type != 'food';
  String get unit => type == 'sleep'
      ? 'hours'
      : type == 'water'
          ? 'glasses'
          : type == 'food'
              ? 'healthy meals'
              : 'minutes';
  String get itemLabel => const {
        'study': 'Subject', 'workout': 'Exercise', 'skill': 'Skill',
        'sleep': 'Routine', 'water': 'Plan', 'food': 'Meal plan', 'custom': 'Item',
      }[type]!;
  String get subLabel => const {
        'study': 'Chapter', 'workout': 'Step', 'skill': 'Topic',
        'sleep': 'Step', 'water': 'Step', 'food': 'Dish', 'custom': 'Sub-item',
      }[type]!;

  int attTotal([String? s]) => att.where((r) => s == null || r.item == s).length;
  int attCount([String? s]) =>
      att.where((r) => (s == null || r.item == s) && r.attended).length;
  double? attPct([String? s]) {
    final t = attTotal(s);
    if (t == 0) return null;
    return attCount(s) * 100 / t;
  }
}

class Task {
  String title;
  Category cat;
  String? item;
  int minutes;
  TimeOfDay? start;
  int remindBefore; // -1 = none
  DateTime date;
  bool done = false;
  bool notified = false;
  int actualSec = 0;
  List<String> subtasks;
  Task(this.title, this.cat, this.item, this.minutes, this.start, this.remindBefore,
      this.date, this.subtasks);
}

// ===================== APP STATE =====================
class AppState extends ChangeNotifier {
  final List<Category> cats = [];
  final List<Task> tasks = [];
  DateTime viewDate = DateTime.now();

  // timer
  Task? timerTask;
  Category? timerCat;
  bool active = false;
  bool running = false;
  int _accum = 0;
  DateTime? _start;
  Timer? _ticker;
  Timer? _reminder;

  AppState() {
    cats.addAll([
      Category('Study', Icons.school, const Color(0xFF6C5CE7), 'study', 240),
      Category('Workout', Icons.fitness_center, const Color(0xFFE17055), 'workout', 30),
      Category('Sleep', Icons.bedtime, const Color(0xFF0984E3), 'sleep', 8),
      Category('Water', Icons.water_drop, const Color(0xFF00B5D8), 'water', 8),
      Category('Healthy Food', Icons.restaurant, const Color(0xFF00B894), 'food', 3),
      Category('New Skills', Icons.lightbulb, const Color(0xFFF39C12), 'skill', 60),
    ]);
    _reminder = Timer.periodic(const Duration(seconds: 10), (_) => _checkReminders());
  }

  void changed() => notifyListeners();
  void setDate(DateTime d) {
    viewDate = d;
    notifyListeners();
  }

  // ---------- reminders (in-app) ----------
  bool reminderPassed(Task t) {
    if (t.start == null || t.remindBefore < 0) return true;
    final st = DateTime(t.date.year, t.date.month, t.date.day, t.start!.hour, t.start!.minute);
    return st.subtract(Duration(minutes: t.remindBefore)).isBefore(DateTime.now());
  }

  void _checkReminders() {
    final now = DateTime.now();
    for (final t in tasks) {
      if (t.done || t.notified || t.start == null || t.remindBefore < 0) continue;
      final st = DateTime(t.date.year, t.date.month, t.date.day, t.start!.hour, t.start!.minute);
      final fire = st.subtract(Duration(minutes: t.remindBefore));
      if (!now.isBefore(fire) && now.difference(st).inMinutes < 120) {
        t.notified = true;
        messengerKey.currentState?.showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 12),
          content: Text(
              '⏰ ${t.cat.name}: ${t.title} ${t.remindBefore == 0 ? "starts now" : "starts in ${t.remindBefore} min"}'),
          action: SnackBarAction(label: 'Start', onPressed: () => startTimer(task: t)),
        ));
        notifyListeners();
      }
    }
    for (final c in cats) {
      if (c.type == 'water' && c.waterEvery > 0 && c.lastWater != null &&
          now.difference(c.lastWater!).inMinutes >= c.waterEvery) {
        c.lastWater = now;
        snack('💧 Time to drink a glass of water');
      }
      if (c.type == 'sleep' && c.bedtime != null) {
        final bt = DateTime(now.year, now.month, now.day, c.bedtime!.hour, c.bedtime!.minute);
        if (c.bedKey != dkey(now) && !now.isBefore(bt) && now.difference(bt).inMinutes < 60) {
          c.bedKey = dkey(now);
          snack('🌙 Bedtime reminder: time to wind down');
        }
      }
    }
  }

  // ---------- timer ----------
  int get elapsed =>
      _accum + (running && _start != null ? DateTime.now().difference(_start!).inSeconds : 0);

  void _tick() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
  }

  void startTimer({Task? task, Category? cat}) {
    if (active) {
      snack('Finish or cancel the running timer first.');
      return;
    }
    timerTask = task;
    timerCat = task?.cat ?? cat;
    if (timerCat == null) return;
    active = true;
    running = true;
    _accum = 0;
    _start = DateTime.now();
    _tick();
    notifyListeners();
  }

  void pauseTimer() {
    _accum = elapsed;
    running = false;
    _start = null;
    _ticker?.cancel();
    notifyListeners();
  }

  void resumeTimer() {
    running = true;
    _start = DateTime.now();
    _tick();
    notifyListeners();
  }

  void _resetTimer() {
    _ticker?.cancel();
    active = false;
    running = false;
    _accum = 0;
    _start = null;
    timerTask = null;
    timerCat = null;
  }

  void completeTimer() {
    final s = elapsed;
    if (s > 0) {
      if (timerTask != null) {
        timerTask!.actualSec += s;
        timerTask!.done = true;
      } else if (timerCat != null) {
        timerCat!.sessions.add(FreeSession(DateTime.now(), s));
      }
    }
    _resetTimer();
    notifyListeners();
  }

  void cancelTimer() {
    _resetTimer();
    notifyListeners();
  }

  // ---------- queries ----------
  List<Task> tasksOn(DateTime d, [Category? c]) {
    final l = tasks.where((t) => sameDay(t.date, d) && (c == null || t.cat == c)).toList();
    int mins(Task t) => t.start == null ? 100000 : t.start!.hour * 60 + t.start!.minute;
    l.sort((a, b) => mins(a).compareTo(mins(b)));
    return l;
  }

  int taskSec(Task t) => t.done ? (t.actualSec > 0 ? t.actualSec : t.minutes * 60) : t.actualSec;

  int secOn(Category c, DateTime d) =>
      tasksOn(d, c).fold<int>(0, (a, t) => a + taskSec(t)) +
      c.sessions.where((s) => sameDay(s.date, d)).fold<int>(0, (a, s) => a + s.sec);

  // ---------- planned vs actual (minutes) ----------
  // Planned = task durations + manual planned entries.
  int plannedMinOn(Category c, DateTime d) =>
      tasksOn(d, c).fold<int>(0, (a, t) => a + t.minutes) +
      c.plans.where((p) => sameDay(p.date, d)).fold<int>(0, (a, p) => a + p.plannedMin);

  // Actual = task actual time + timer sessions + manual actual entries.
  int actualMinOn(Category c, DateTime d) =>
      (secOn(c, d) / 60).round() +
      c.plans.where((p) => sameDay(p.date, d)).fold<int>(0, (a, p) => a + p.actualMin);

  double value(Category c, DateTime d) {
    switch (c.type) {
      case 'sleep':
        return c.sleep.where((s) => sameDay(s.date, d)).fold<double>(0, (a, s) => a + s.hours);
      case 'water':
        return (c.water[dkey(d)] ?? 0).toDouble();
      case 'food':
        return c.meals.where((m) => sameDay(m.date, d) && m.healthy).length.toDouble();
      default:
        return secOn(c, d) / 60;
    }
  }

  double progress(Category c, DateTime d) =>
      c.target <= 0 ? 0 : (value(c, d) / c.target).clamp(0.0, 1.0);

  String label(Category c, DateTime d) {
    final v = value(c, d);
    switch (c.type) {
      case 'sleep':
        return '${v.toStringAsFixed(1)} / ${fmtNum(c.target)} h';
      case 'water':
        return '${v.round()} / ${c.target.round()} glasses';
      case 'food':
        return '${v.round()}/${c.target.round()} healthy meals • ${caloriesOn(c, d)} kcal';
      default:
        return '${fmtMin(v.round())} / ${fmtMin(c.target.round())}';
    }
  }

  // Stars are always recomputed from real records, so they can never be duplicated.
  int stars(Category c) {
    int s = tasks.where((t) => t.cat == c && t.done).length;
    for (final i in c.items) {
      s += i.subs.where((x) => x.status == 2).length * (c.type == 'study' ? 2 : 1);
    }
    if (c.type == 'study') {
      s += c.attCount() ~/ 5;
      s += c.assignments.where((a) => a.done).length;
    }
    final dates = <String>{};
    for (final t in tasks.where((t) => t.cat == c)) {
      dates.add(dkey(t.date));
    }
    for (final x in c.sessions) {
      dates.add(dkey(x.date));
    }
    for (final x in c.sleep) {
      dates.add(dkey(x.date));
    }
    dates.addAll(c.water.keys);
    for (final x in c.meals) {
      dates.add(dkey(x.date));
    }
    for (final k in dates) {
      final v = value(c, DateTime.parse(k));
      if (c.target > 0 && v > 0 && v >= c.target) s += 3;
    }
    return s;
  }

  int get totalStars => cats.fold<int>(0, (a, c) => a + stars(c));

  int caloriesOn(Category c, DateTime d) =>
      c.meals.where((m) => sameDay(m.date, d)).fold<int>(0, (a, m) => a + m.calories);

  // Hours actually spent on a skill: completed tasks linked to it + manual logs.
  double skillHours(Category c, Item it) {
    final fromTasks = tasks
        .where((t) => t.cat == c && t.item == it.name)
        .fold<int>(0, (a, t) => a + taskSec(t));
    final fromLogs = it.logs.fold<int>(0, (a, l) => a + l.sec);
    return (fromTasks + fromLogs) / 3600;
  }

  // Pending assignments and upcoming exams from all Study categories.
  List<Deadline> deadlines() {
    final out = <Deadline>[];
    for (final c in cats) {
      for (final a in c.assignments) {
        if (!a.done) out.add(Deadline(a.due, a.title, a.subject ?? c.name, false));
      }
      for (final e in c.exams) {
        if (!e.done && daysUntil(e.date) >= 0) {
          out.add(Deadline(e.date, e.title, e.subject ?? c.name, true));
        }
      }
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }
}

final app = AppState();

// ===================== COMMON WIDGETS =====================
class Panel extends StatelessWidget {
  final Widget child;
  const Panel({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: child,
      );
}

Widget page(String title, Widget body, {Widget? fab, List<Widget>? actions}) => Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: bg,
        actions: actions,
      ),
      floatingActionButton: fab,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 860), child: body),
      ),
    );

const heading = TextStyle(fontWeight: FontWeight.w700, fontSize: 16);

Widget miniStat(String label, String value, {Color? color}) => Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      ]),
    );

class HBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final double maxValue;
  final String suffix;
  final List<Color>? colors;
  const HBarChart(
      {super.key,
      required this.labels,
      required this.values,
      required this.maxValue,
      this.suffix = '',
      this.colors});
  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return const Text('No data yet.', style: TextStyle(color: Colors.grey));
    }
    return Column(children: [
      for (int i = 0; i < labels.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(width: 100, child: Text(labels[i], overflow: TextOverflow.ellipsis)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: maxValue <= 0 ? 0 : (values[i] / maxValue).clamp(0.0, 1.0),
                  minHeight: 16,
                  color: colors == null ? null : colors![i],
                  backgroundColor: lav,
                ),
              ),
            ),
            SizedBox(
                width: 64,
                child: Text('${fmtNum(double.parse(values[i].toStringAsFixed(1)))}$suffix',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
        ),
    ]);
  }
}

// Two bars per row: planned (grey) and actual (category color), in minutes.
class PlanVsActualChart extends StatelessWidget {
  final List<String> labels;
  final List<int> planned;
  final List<int> actual;
  final Color color;
  const PlanVsActualChart(
      {super.key,
      required this.labels,
      required this.planned,
      required this.actual,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final all = [...planned, ...actual];
    if (all.isEmpty || all.every((v) => v == 0)) {
      return const Text('No planned or actual time yet.', style: TextStyle(color: Colors.grey));
    }
    final maxV = all.reduce((a, b) => a > b ? a : b).toDouble();
    Widget bar(int v, Color col) => ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
              value: maxV <= 0 ? 0 : v / maxV, minHeight: 9, color: col, backgroundColor: lav),
        );
    Widget dot(Color col, String t) => Row(children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(t, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 14),
        ]);
    return Column(children: [
      Row(children: [dot(Colors.grey, 'Planned'), dot(color, 'Actual')]),
      const SizedBox(height: 4),
      for (int i = 0; i < labels.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(
                width: 80,
                child: Text(labels[i],
                    overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
            Expanded(
              child: Column(children: [
                bar(planned[i], Colors.grey),
                const SizedBox(height: 3),
                bar(actual[i], color),
              ]),
            ),
            SizedBox(
                width: 100,
                child: Text('${fmtMin(planned[i])} / ${fmtMin(actual[i])}',
                    textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
          ]),
        ),
    ]);
  }
}

class DateBar extends StatelessWidget {
  const DateBar({super.key});
  @override
  Widget build(BuildContext context) {
    final d = app.viewDate;
    return Row(children: [
      IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => app.setDate(DateTime(d.year, d.month, d.day - 1))),
      Expanded(
        child: TextButton(
          onPressed: () async {
            final p = await showDatePicker(
                context: context,
                initialDate: d,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100));
            if (p != null) app.setDate(p);
          },
          child: Text(fmtDate(d), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      ),
      IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => app.setDate(DateTime(d.year, d.month, d.day + 1))),
      TextButton(onPressed: () => app.setDate(DateTime.now()), child: const Text('Today')),
    ]);
  }
}

// ===================== TASK DIALOG & TILE =====================
void taskDialog(BuildContext context, {Task? edit, Category? cat}) {
  if (app.cats.isEmpty) {
    snack('Create a category first.');
    return;
  }
  final fixedCat = cat != null || edit != null;
  Category sel = edit?.cat ?? cat ?? app.cats.first;
  final title = TextEditingController(text: edit?.title ?? '');
  final total = edit?.minutes ?? 60;
  final hrs = TextEditingController(text: '${total ~/ 60}');
  final mins = TextEditingController(text: '${total % 60}');
  final subs = TextEditingController(text: edit?.subtasks.join(', ') ?? '');
  String? item = edit?.item;
  DateTime date = edit?.date ?? app.viewDate;
  TimeOfDay? start = edit?.start;
  int remind = edit?.remindBefore ?? -1;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      return AlertDialog(
        title: Text(edit == null ? 'Add Task' : 'Edit Task'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (!fixedCat)
                DropdownButtonFormField<Category>(
                  value: sel,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final c in app.cats)
                      DropdownMenuItem(
                          value: c,
                          child: Row(children: [
                            Icon(c.icon, color: c.color, size: 18),
                            const SizedBox(width: 8),
                            Text(c.name)
                          ]))
                  ],
                  onChanged: (v) => setS(() {
                    sel = v ?? sel;
                    item = null;
                  }),
                )
              else
                Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(avatar: Icon(sel.icon, color: sel.color, size: 18), label: Text(sel.name))),
              TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Task name (e.g. Study Matrices, Yoga)')),
              if (sel.items.isNotEmpty)
                DropdownButtonFormField<String?>(
                  value: sel.items.any((i) => i.name == item) ? item : null,
                  decoration: InputDecoration(labelText: '${sel.itemLabel} (optional)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('— none —')),
                    for (final i in sel.items) DropdownMenuItem<String?>(value: i.name, child: Text(i.name))
                  ],
                  onChanged: (v) => setS(() => item = v),
                ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: hrs,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Hours'))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: mins,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Minutes'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(fmtDate(date)),
                    onPressed: () async {
                      final p = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100));
                      if (p != null) setS(() => date = p);
                    },
                  ),
                ),
              ]),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time, size: 16),
                    label: Text(start == null ? 'Start time (optional)' : fmtTime(start!)),
                    onPressed: () async {
                      final p = await showTimePicker(
                          context: ctx, initialTime: start ?? TimeOfDay.now());
                      if (p != null) setS(() => start = p);
                    },
                  ),
                ),
                if (start != null)
                  IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setS(() {
                            start = null;
                            remind = -1;
                          })),
              ]),
              if (start != null)
                DropdownButtonFormField<int>(
                  value: remind,
                  decoration: const InputDecoration(labelText: 'Reminder'),
                  items: const [
                    DropdownMenuItem(value: -1, child: Text('No reminder')),
                    DropdownMenuItem(value: 0, child: Text('At start time')),
                    DropdownMenuItem(value: 5, child: Text('5 min before')),
                    DropdownMenuItem(value: 10, child: Text('10 min before')),
                    DropdownMenuItem(value: 15, child: Text('15 min before')),
                    DropdownMenuItem(value: 30, child: Text('30 min before')),
                  ],
                  onChanged: (v) => setS(() => remind = v ?? -1),
                ),
              TextField(
                  controller: subs,
                  decoration: const InputDecoration(
                      labelText: 'Subtasks (comma separated, optional)',
                      hintText: 'Warm-up, Surya Namaskar, Stretching')),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final tm = (int.tryParse(hrs.text) ?? 0) * 60 + (int.tryParse(mins.text) ?? 0);
              if (title.text.trim().isEmpty || tm <= 0) {
                snack('Enter a task name and a duration.');
                return;
              }
              final subList = subs.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              final String? chosenItem = sel.items.any((i) => i.name == item) ? item : null;
              if (edit != null) {
                edit.title = title.text.trim();
                edit.cat = sel;
                edit.item = chosenItem;
                edit.minutes = tm;
                edit.start = start;
                edit.remindBefore = remind;
                edit.date = date;
                edit.subtasks = subList;
                edit.notified = app.reminderPassed(edit);
              } else {
                final t = Task(title.text.trim(), sel, chosenItem, tm, start, remind, date, subList);
                t.notified = app.reminderPassed(t);
                app.tasks.add(t);
              }
              app.changed();
              Navigator.pop(ctx);
            },
            child: Text(edit == null ? 'Add' : 'Save'),
          ),
        ],
      );
    }),
  );
}

class TaskTile extends StatelessWidget {
  final Task t;
  const TaskTile(this.t, {super.key});
  @override
  Widget build(BuildContext context) {
    final info = [
      t.cat.name,
      if (t.item != null) t.item!,
      fmtMin(t.minutes),
      if (t.start != null) fmtTime(t.start!),
    ].join(' • ');
    return Panel(
      child: Row(children: [
        Checkbox(
          value: t.done,
          onChanged: (v) {
            t.done = v ?? false;
            app.changed();
            if (t.done) snack('Nice work! Task completed ⭐');
          },
        ),
        Icon(t.cat.icon, color: t.cat.color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    decoration: t.done ? TextDecoration.lineThrough : null)),
            Text('$info${t.start != null && t.remindBefore >= 0 ? "  🔔" : ""}',
                style: const TextStyle(color: Colors.black54)),
            if (t.subtasks.isNotEmpty)
              Text('Subtasks: ${t.subtasks.join(" → ")}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
            if (t.actualSec > 0)
              Text('Actual: ${fmtSec(t.actualSec)}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ]),
        ),
        IconButton(
            tooltip: 'Start timer',
            icon: const Icon(Icons.play_circle_outline),
            onPressed: t.done ? null : () => app.startTimer(task: t)),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') {
              taskDialog(context, edit: t);
            } else if (v == 'dup') {
              final c = Task(t.title, t.cat, t.item, t.minutes, t.start, t.remindBefore, t.date,
                  [...t.subtasks]);
              c.notified = app.reminderPassed(c);
              app.tasks.insert(app.tasks.indexOf(t) + 1, c);
              app.changed();
            } else if (v == 'del') {
              app.tasks.remove(t);
              app.changed();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'dup', child: Text('Duplicate')),
            PopupMenuItem(value: 'del', child: Text('Delete')),
          ],
        ),
      ]),
    );
  }
}

// ===================== APP & SHELL =====================
class StudyFlowApp extends StatelessWidget {
  const StudyFlowApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'STUDYFLOW',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: messengerKey,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: purple),
          scaffoldBackgroundColor: bg,
        ),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  static const labels = ['Home', 'Schedule', 'Stats', 'Rewards'];
  static const icons = [Icons.dashboard, Icons.event_note, Icons.insights, Icons.star];

  @override
  Widget build(BuildContext context) {
    const pages = [HomePage(), SchedulePage(), StatsPage(), RewardsPage()];
    final wide = MediaQuery.of(context).size.width >= 800;
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: i,
            onDestinationSelected: (v) => setState(() => i = v),
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.white,
            leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('STUDYFLOW', style: TextStyle(fontWeight: FontWeight.w800))),
            destinations: [
              for (int k = 0; k < 4; k++)
                NavigationRailDestination(icon: Icon(icons[k]), label: Text(labels[k]))
            ],
          ),
          Expanded(child: pages[i]),
        ]),
      );
    }
    return Scaffold(
      body: pages[i],
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => i = v),
        destinations: [
          for (int k = 0; k < 4; k++) NavigationDestination(icon: Icon(icons[k]), label: labels[k])
        ],
      ),
    );
  }
}

// ===================== HOME =====================
void addCategoryDialog(BuildContext context) {
  final name = TextEditingController();
  String type = 'custom';
  IconData icon = iconChoices.first;
  Color color = colorChoices.first;
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      return AlertDialog(
        title: const Text('New Category'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name (e.g. Meditation, Reading)')),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  for (final e in typeNames.entries) DropdownMenuItem(value: e.key, child: Text(e.value))
                ],
                onChanged: (v) => setS(() => type = v ?? type),
              ),
              const SizedBox(height: 12),
              const Text('Icon'),
              Wrap(children: [
                for (final ic in iconChoices)
                  IconButton(
                      onPressed: () => setS(() => icon = ic),
                      icon: Icon(ic, color: icon == ic ? color : Colors.grey)),
              ]),
              const Text('Color'),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                for (final c in colorChoices)
                  GestureDetector(
                    onTap: () => setS(() => color = c),
                    child: CircleAvatar(
                        radius: 14,
                        backgroundColor: c,
                        child: color == c ? const Icon(Icons.check, size: 16, color: Colors.white) : null),
                  ),
              ]),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              app.cats.add(Category(name.text.trim(), icon, color, type, defaultTargets[type]!));
              app.changed();
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      );
    }),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final now = DateTime.now();
        final todays = app.tasksOn(now);
        final pending = todays.where((t) => !t.done).toList();
        final dl = app.deadlines();
        return page(
          'STUDYFLOW',
          ListView(padding: const EdgeInsets.all(16), children: [
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Hello, Student 👋',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                Text(fmtDate(now)),
                const SizedBox(height: 6),
                Text(
                    '${todays.length - pending.length}/${todays.length} tasks done today  •  ${app.totalStars} ⭐ total',
                    style: const TextStyle(color: Colors.black54)),
              ]),
            ),
            const TimerCard(),
            Row(children: [
              const Expanded(child: Text('My Categories', style: heading)),
              FilledButton.icon(
                  onPressed: () => addCategoryDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New Category')),
            ]),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (ctx, box) {
              final cols = box.maxWidth > 640 ? 3 : 2;
              final w = (box.maxWidth - (cols - 1) * 10) / cols;
              return Wrap(spacing: 10, runSpacing: 10, children: [
                for (final c in app.cats) catCard(context, c, w),
              ]);
            }),
            const SizedBox(height: 14),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Assignments & Exams', style: heading),
                if (dl.isEmpty)
                  const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('No pending assignments or upcoming exams. Add them in Study.',
                          style: TextStyle(color: Colors.grey))),
                for (final d in dl.take(6))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(d.exam ? Icons.quiz : Icons.assignment,
                        color: d.exam ? Colors.deepPurple : Colors.indigo),
                    title: Text(d.title),
                    subtitle: Text('${d.exam ? "Exam" : "Assignment"} • ${d.where} • ${fmtDate(d.date)}'),
                    trailing: Text(dueText(daysUntil(d.date)),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: daysUntil(d.date) < 0
                                ? Colors.redAccent
                                : (daysUntil(d.date) <= 2 ? Colors.orange : Colors.black54))),
                  ),
              ]),
            ),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Today's Upcoming (${pending.length})", style: heading),
                if (pending.isEmpty)
                  const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Nothing pending. Add tasks in Schedule or inside a category.',
                          style: TextStyle(color: Colors.grey))),
                for (final t in pending.take(6))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(t.cat.icon, color: t.cat.color),
                    title: Text(t.title),
                    subtitle: Text(t.cat.name),
                    trailing: Text(t.start == null ? fmtMin(t.minutes) : '${fmtTime(t.start!)} • ${fmtMin(t.minutes)}'),
                  ),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget catCard(BuildContext context, Category c, double w) {
    final now = DateTime.now();
    return SizedBox(
      width: w,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryPage(c))),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.color.withAlpha(70))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(backgroundColor: c.color.withAlpha(40), child: Icon(c.icon, color: c.color)),
              const Spacer(),
              Text('${app.stars(c)} ⭐', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                  value: app.progress(c, now), minHeight: 10, color: c.color, backgroundColor: lav),
            ),
            const SizedBox(height: 4),
            Text(app.label(c, now), style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

class TimerCard extends StatefulWidget {
  const TimerCard({super.key});
  @override
  State<TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends State<TimerCard> {
  Category? sel;
  @override
  Widget build(BuildContext context) {
    if (sel == null || !app.cats.contains(sel)) {
      sel = app.cats.isEmpty ? null : app.cats.first;
    }
    final what = app.timerTask != null
        ? '${app.timerTask!.cat.name}: ${app.timerTask!.title}'
        : app.timerCat != null
            ? '${app.timerCat!.name} (free session)'
            : 'Start a free session or tap ▶ on any task';
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Timer', style: heading),
        const SizedBox(height: 4),
        Text(what, style: const TextStyle(color: Colors.black54)),
        Center(
          child: Text(fmtSec(app.elapsed),
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: 2)),
        ),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.center, children: [
          if (!app.active && sel != null)
            DropdownButton<Category>(
              value: sel,
              items: [for (final c in app.cats) DropdownMenuItem(value: c, child: Text(c.name))],
              onChanged: (v) => setState(() => sel = v),
            ),
          if (!app.active)
            FilledButton.icon(
                onPressed: sel == null ? null : () => app.startTimer(cat: sel),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start')),
          if (app.active && app.running)
            FilledButton.tonalIcon(
                onPressed: app.pauseTimer, icon: const Icon(Icons.pause), label: const Text('Pause')),
          if (app.active && !app.running)
            FilledButton.tonalIcon(
                onPressed: app.resumeTimer, icon: const Icon(Icons.play_arrow), label: const Text('Resume')),
          if (app.active)
            FilledButton.icon(
                onPressed: () {
                  app.completeTimer();
                  snack('Session saved!');
                },
                icon: const Icon(Icons.check),
                label: const Text('Complete')),
          if (app.active)
            OutlinedButton.icon(
                onPressed: app.cancelTimer, icon: const Icon(Icons.close), label: const Text('Cancel')),
        ]),
      ]),
    );
  }
}

// ===================== SCHEDULE =====================
class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final list = app.tasksOn(app.viewDate);
        final planned = list.fold<int>(0, (a, t) => a + t.minutes);
        final doneMin = list.fold<int>(0, (a, t) => a + app.taskSec(t)) ~/ 60;
        return page(
          'Schedule',
          ListView(padding: const EdgeInsets.all(16), children: [
            const DateBar(),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${list.length} tasks  •  Planned ${fmtMin(planned)}  •  Completed ${fmtMin(doneMin)}',
                    style: heading),
                const SizedBox(height: 6),
                for (final c in app.cats.where((c) => list.any((t) => t.cat == c)))
                  Text(
                      '${c.name}: ${fmtMin(list.where((t) => t.cat == c).fold<int>(0, (a, t) => a + t.minutes))} planned',
                      style: const TextStyle(color: Colors.black54)),
              ]),
            ),
            if (list.isEmpty)
              const Panel(
                  child: Text('No tasks on this day. Tap "Add Task".',
                      style: TextStyle(color: Colors.grey))),
            for (final t in list) TaskTile(t),
            const SizedBox(height: 80),
          ]),
          fab: FloatingActionButton.extended(
            onPressed: () => taskDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Task'),
          ),
        );
      },
    );
  }
}

// ===================== CATEGORY PAGE =====================
class CategoryPage extends StatelessWidget {
  final Category c;
  const CategoryPage(this.c, {super.key});

  @override
  Widget build(BuildContext context) {
    final tabs = <String>['My ${c.itemLabel}s', 'Tasks'];
    final views = <Widget>[ItemsTab(c), TasksTab(c)];
    if (c.type == 'study') {
      tabs.addAll(['Attendance', 'Assignments', 'Exams']);
      views.addAll([AttendanceTab(c), AssignmentsTab(c), ExamsTab(c)]);
    }
    if (c.type == 'sleep') {
      tabs.add('Sleep Log');
      views.add(SleepTab(c));
    }
    if (c.type == 'water') {
      tabs.add('Water');
      views.add(WaterTab(c));
    }
    if (c.type == 'food') {
      tabs.add('Meals');
      views.add(FoodTab(c));
    }
    tabs.add('Plan vs Actual');
    views.add(PlanTab(c));

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: bg,
          title: Row(children: [
            Icon(c.icon, color: c.color),
            const SizedBox(width: 8),
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.flag, size: 16),
              label: Text('Target ${fmtNum(c.target)} ${c.unit == "minutes" ? "min" : c.unit}'),
              onPressed: () async {
                final v = await askText(context, 'Daily target (${c.unit})', 'e.g. ${fmtNum(c.target)}');
                final n = double.tryParse(v ?? '');
                if (n != null && n > 0) {
                  c.target = n;
                  app.changed();
                }
              },
            ),
            IconButton(
              tooltip: 'Delete category',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Delete ${c.name}?'),
                    content: const Text('All its items, tasks and logs will be removed.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) {
                  app.tasks.removeWhere((t) => t.cat == c);
                  app.cats.remove(c);
                  app.changed();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
          bottom: TabBar(isScrollable: true, tabs: [for (final t in tabs) Tab(text: t)]),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: TabBarView(children: views),
          ),
        ),
      ),
    );
  }
}

// ---------- Items (subjects / exercises / skills ...) ----------
void itemDialog(BuildContext context, Category c, {Item? edit}) {
  final isSkill = c.type == 'skill';
  final name = TextEditingController(text: edit?.name ?? '');
  final months = TextEditingController(text: edit == null ? '3' : '${edit.months}');
  final hours = TextEditingController(text: edit == null ? '50' : fmtNum(edit.targetHours));
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(edit == null ? 'Add ${c.itemLabel}' : 'Edit ${c.itemLabel}'),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              autofocus: true,
              decoration: InputDecoration(labelText: '${c.itemLabel} name')),
          if (isSkill) ...[
            TextField(
                controller: months,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Target period (months)')),
            TextField(
                controller: hours,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total hours to spend (target)')),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final n = name.text.trim();
            if (n.isEmpty) return;
            final m = int.tryParse(months.text) ?? 0;
            final h = double.tryParse(hours.text) ?? 0;
            if (isSkill && (m <= 0 || h <= 0)) {
              snack('Enter the months and the total hours for this skill.');
              return;
            }
            if (edit != null) {
              for (final t in app.tasks) {
                if (t.cat == c && t.item == edit.name) t.item = n;
              }
              for (final a in c.assignments) {
                if (a.subject == edit.name) a.subject = n;
              }
              for (final e in c.exams) {
                if (e.subject == edit.name) e.subject = n;
              }
              edit.name = n;
              if (isSkill) {
                edit.months = m;
                edit.targetHours = h;
              }
            } else {
              final it = Item(n);
              if (isSkill) {
                it.months = m;
                it.targetHours = h;
              }
              c.items.add(it);
            }
            app.changed();
            Navigator.pop(ctx);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class ItemsTab extends StatelessWidget {
  final Category c;
  const ItemsTab(this.c, {super.key});
  bool get isSkill => c.type == 'skill';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (ctx, _) => ListView(padding: const EdgeInsets.all(16), children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: Text('Add ${c.itemLabel}'),
            onPressed: () => itemDialog(ctx, c),
          ),
        ),
        const SizedBox(height: 12),
        if (c.items.isEmpty)
          Panel(
              child: Text(
                  'No ${c.itemLabel.toLowerCase()}s yet. Create your own, then add ${c.subLabel.toLowerCase()}s inside.',
                  style: const TextStyle(color: Colors.grey))),
        for (final it in c.items) itemCard(ctx, it),
      ]),
    );
  }

  Widget skillPanel(BuildContext ctx, Item it) {
    final spent = app.skillHours(c, it);
    final target = it.targetHours;
    final remaining = target > spent ? target - spent : 0.0;
    final pct = target <= 0 ? 0.0 : (spent / target).clamp(0.0, 1.0);
    final now = DateTime.now();
    final end = it.endDate;
    final totalDays = end.difference(it.startDate).inDays;
    final elapsedDays = now.difference(it.startDate).inDays.clamp(0, totalDays).toInt();
    final daysLeft = end.difference(now).inDays < 0 ? 0 : end.difference(now).inDays;
    final timePct = totalDays <= 0 ? 0.0 : elapsedDays / totalDays;
    final perWeek = daysLeft > 0 ? remaining / daysLeft * 7 : remaining;
    String status;
    if (spent >= target) {
      status = '🎉 Target reached! Amazing consistency.';
    } else if (daysLeft <= 0) {
      status = 'The period has ended with ${remaining.toStringAsFixed(1)} h left. Use Edit target to extend it.';
    } else if (pct + 0.02 >= timePct) {
      status = 'You are on track. Keep going!';
    } else {
      status = 'A little behind plan. About ${perWeek.toStringAsFixed(1)} h per week gets you there.';
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: lav, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Target: ${fmtNum(target)} h in ${it.months} month(s)  •  ends ${fmtDate(end)}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
              value: pct, minHeight: 14, color: c.color, backgroundColor: Colors.white),
        ),
        const SizedBox(height: 6),
        Text('Spent: ${spent.toStringAsFixed(1)} h  •  Remaining: ${remaining.toStringAsFixed(1)} h  •  ${(pct * 100).round()}%'),
        Text('Time used: $elapsedDays of $totalDays days  •  $daysLeft days left',
            style: const TextStyle(color: Colors.black54)),
        Text(status, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.timer, size: 16),
            label: const Text('Log hours'),
            onPressed: () async {
              final v = await askText(ctx, 'Hours spent on ${it.name}', 'e.g. 1.5');
              final h = double.tryParse(v ?? '');
              if (h != null && h > 0) {
                it.logs.add(FreeSession(DateTime.now(), (h * 3600).round()));
                app.changed();
              }
            },
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit target'),
            onPressed: () => itemDialog(ctx, c, edit: it),
          ),
        ]),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('Tasks linked to this skill also count toward the hours spent.',
              style: TextStyle(color: Colors.black45, fontSize: 12)),
        ),
      ]),
    );
  }

  Widget itemCard(BuildContext ctx, Item it) {
    final total = it.subs.length;
    final done = it.subs.where((s) => s.status == 2).length;
    final prog = it.subs.where((s) => s.status == 1).length;
    final pct = total == 0 ? 0.0 : done / total;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(it.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text(c.subLabel),
            onPressed: () async {
              final v = await askText(ctx, 'Add ${c.subLabel} to ${it.name}', 'Name');
              if (v != null && v.isNotEmpty) {
                it.subs.add(SubItem(v));
                app.changed();
              }
            },
          ),
          IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                c.items.remove(it);
                app.changed();
              }),
        ]),
        if (isSkill) skillPanel(ctx, it),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: pct, minHeight: 12, color: c.color, backgroundColor: lav),
        ),
        const SizedBox(height: 6),
        Text('${c.subLabel}s  •  Total: $total  •  Completed: $done  •  In Progress: $prog  •  Remaining: ${total - done - prog}  •  ${(pct * 100).round()}%',
            style: const TextStyle(color: Colors.black54)),
        for (final s in it.subs)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              s.status == 2
                  ? Icons.check_circle
                  : s.status == 1
                      ? Icons.timelapse
                      : Icons.radio_button_unchecked,
              color: s.status == 2 ? Colors.green : (s.status == 1 ? Colors.orange : Colors.grey),
            ),
            title: Text(s.name),
            subtitle: Text(const ['Not Started', 'In Progress', 'Completed'][s.status]),
            trailing: PopupMenuButton<int>(
              onSelected: (v) {
                if (v == 3) {
                  it.subs.remove(s);
                } else {
                  s.status = v;
                  if (v == 2) snack('${c.subLabel} completed! ⭐');
                }
                app.changed();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 0, child: Text('Not Started')),
                PopupMenuItem(value: 1, child: Text('In Progress')),
                PopupMenuItem(value: 2, child: Text('Completed')),
                PopupMenuItem(value: 3, child: Text('Delete')),
              ],
            ),
          ),
      ]),
    );
  }
}

// ---------- Tasks inside a category ----------
class TasksTab extends StatelessWidget {
  final Category c;
  const TasksTab(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (ctx, _) {
        final list = app.tasksOn(app.viewDate, c);
        return ListView(padding: const EdgeInsets.all(16), children: [
          const DateBar(),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Task'),
                onPressed: () => taskDialog(ctx, cat: c)),
          ),
          const SizedBox(height: 4),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Today progress: ${app.label(c, app.viewDate)}',
                  style: const TextStyle(color: Colors.black54))),
          if (list.isEmpty)
            const Panel(child: Text('No tasks for this day.', style: TextStyle(color: Colors.grey))),
          for (final t in list) TaskTile(t),
        ]);
      },
    );
  }
}

// ---------- PLAN vs ACTUAL (all categories) ----------
void actualDialog(BuildContext context, Task t) {
  final cur = (t.actualSec / 60).round();
  final hrs = TextEditingController(text: '${cur ~/ 60}');
  final mins = TextEditingController(text: '${cur % 60}');
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Actual time: ${t.title}'),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Planned: ${fmtMin(t.minutes)}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: hrs,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Hours spent'))),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    controller: mins,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minutes spent'))),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final m = (int.tryParse(hrs.text) ?? 0) * 60 + (int.tryParse(mins.text) ?? 0);
            if (m < 0) {
              snack('Enter a valid time.');
              return;
            }
            t.actualSec = m * 60;
            app.changed();
            Navigator.pop(ctx);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

void planLogDialog(BuildContext context, Category c) {
  DateTime date = app.viewDate;
  final ph = TextEditingController(text: '1');
  final pm = TextEditingController(text: '0');
  final ah = TextEditingController(text: '0');
  final am = TextEditingController(text: '0');
  final note = TextEditingController();
  Widget numField(TextEditingController ctl, String label) => Expanded(
      child: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label)));
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      return AlertDialog(
        title: Text('Plan vs Actual: ${c.name}'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(fmtDate(date)),
                onPressed: () async {
                  final p = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100));
                  if (p != null) setS(() => date = p);
                },
              ),
              const SizedBox(height: 10),
              const Text('Time I planned', style: TextStyle(fontWeight: FontWeight.w700)),
              Row(children: [numField(ph, 'Hours'), const SizedBox(width: 10), numField(pm, 'Minutes')]),
              const SizedBox(height: 10),
              const Text('Time I actually put in', style: TextStyle(fontWeight: FontWeight.w700)),
              Row(children: [numField(ah, 'Hours'), const SizedBox(width: 10), numField(am, 'Minutes')]),
              TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Note (optional)')),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final p = (int.tryParse(ph.text) ?? 0) * 60 + (int.tryParse(pm.text) ?? 0);
              final a = (int.tryParse(ah.text) ?? 0) * 60 + (int.tryParse(am.text) ?? 0);
              if (p < 0 || a < 0 || (p == 0 && a == 0)) {
                snack('Enter a planned and/or actual time.');
                return;
              }
              c.plans.add(PlanLog(date, p, a, note.text.trim()));
              app.changed();
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      );
    }),
  );
}

class PlanTab extends StatelessWidget {
  final Category c;
  const PlanTab(this.c, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (ctx, _) {
        final d = app.viewDate;
        final planned = app.plannedMinOn(c, d);
        final actual = app.actualMinOn(c, d);
        final diff = actual - planned;
        final dayTasks = app.tasksOn(d, c);
        final logs = c.plans.where((p) => sameDay(p.date, d)).toList();
        final days = [for (int i = 6; i >= 0; i--) DateTime(d.year, d.month, d.day - i)];
        const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final maxV = [planned, actual, 1].reduce((a, b) => a > b ? a : b).toDouble();

        String msg;
        if (planned == 0 && actual == 0) {
          msg = 'Nothing planned or logged for this day yet.';
        } else if (planned == 0) {
          msg = 'You put in ${fmtMin(actual)} without a plan. Nice effort!';
        } else {
          final pct = (actual * 100 / planned).round();
          if (pct >= 100) {
            msg = 'You met your plan ($pct%). Great work!';
          } else if (pct >= 70) {
            msg = 'Close to your plan ($pct%). Almost there!';
          } else {
            msg = 'You completed $pct% of your plan. Planning a little less can help, and every minute still counts.';
          }
        }

        return ListView(padding: const EdgeInsets.all(16), children: [
          const DateBar(),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Plan vs Actual Entry'),
                onPressed: () => planLogDialog(ctx, c)),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('This day: planned vs actual', style: heading),
              const SizedBox(height: 10),
              Row(children: [
                miniStat('Planned', fmtMin(planned)),
                miniStat('Actual', fmtMin(actual)),
                miniStat(diff >= 0 ? 'Extra' : 'Short by',
                    fmtMin(diff.abs()),
                    color: diff >= 0 ? Colors.green : Colors.orange),
              ]),
              const SizedBox(height: 10),
              HBarChart(
                labels: const ['Planned', 'Actual'],
                values: [planned.toDouble(), actual.toDouble()],
                maxValue: maxV,
                suffix: 'm',
                colors: [Colors.grey, c.color],
              ),
              Text(msg, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 4),
              const Text(
                  'Actual = task actual time + timer sessions + your manual entries.',
                  style: TextStyle(color: Colors.black45, fontSize: 12)),
            ]),
          ),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tasks of this day', style: heading),
              if (dayTasks.isEmpty)
                const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('No tasks on this day. Add some in the Tasks tab.',
                        style: TextStyle(color: Colors.grey))),
              for (final t in dayTasks)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(t.done ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: t.done ? Colors.green : Colors.grey),
                  title: Text(t.title),
                  subtitle: Text(
                      'Planned ${fmtMin(t.minutes)} • Actual ${t.actualSec > 0 ? fmtMin((t.actualSec / 60).round()) : (t.done ? "not entered (counted as planned)" : "—")}'),
                  trailing: IconButton(
                      tooltip: 'Enter actual time',
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => actualDialog(ctx, t)),
                ),
            ]),
          ),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('My manual entries', style: heading),
              if (logs.isEmpty)
                const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('No manual entries for this day.',
                        style: TextStyle(color: Colors.grey))),
              for (final p in logs)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.compare_arrows),
                  title: Text('Planned ${fmtMin(p.plannedMin)} • Actual ${fmtMin(p.actualMin)}'),
                  subtitle: p.note.isEmpty ? null : Text(p.note),
                  trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () {
                        c.plans.remove(p);
                        app.changed();
                      }),
                ),
              const Text(
                  'Manual entries are for your own review. They do not change stars or daily progress.',
                  style: TextStyle(color: Colors.black45, fontSize: 12)),
            ]),
          ),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Last 7 days (ending on selected date)', style: heading),
              const SizedBox(height: 8),
              PlanVsActualChart(
                labels: [for (final x in days) '${wd[x.weekday - 1]} ${x.day}'],
                planned: [for (final x in days) app.plannedMinOn(c, x)],
                actual: [for (final x in days) app.actualMinOn(c, x)],
                color: c.color,
              ),
            ]),
          ),
        ]);
      },
    );
  }
}

// ---------- Assignments (Study only) ----------
void assignmentDialog(BuildContext context, Category c, {Assignment? edit}) {
  final title = TextEditingController(text: edit?.title ?? '');
  final notes = TextEditingController(text: edit?.notes ?? '');
  String? subject = edit?.subject;
  DateTime due = edit?.due ?? DateTime.now();
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      return AlertDialog(
        title: Text(edit == null ? 'Add Assignment' : 'Edit Assignment'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: title,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Assignment title')),
              if (c.items.isNotEmpty)
                DropdownButtonFormField<String?>(
                  value: c.items.any((i) => i.name == subject) ? subject : null,
                  decoration: const InputDecoration(labelText: 'Subject (optional)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('— none —')),
                    for (final i in c.items) DropdownMenuItem<String?>(value: i.name, child: Text(i.name))
                  ],
                  onChanged: (v) => setS(() => subject = v),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.event, size: 16),
                label: Text('Last date: ${fmtDate(due)}'),
                onPressed: () async {
                  final p = await showDatePicker(
                      context: ctx,
                      initialDate: due,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100));
                  if (p != null) setS(() => due = p);
                },
              ),
              TextField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Notes (optional)')),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty) {
                snack('Enter the assignment title.');
                return;
              }
              final String? subj = c.items.any((i) => i.name == subject) ? subject : null;
              if (edit != null) {
                edit.title = title.text.trim();
                edit.subject = subj;
                edit.due = due;
                edit.notes = notes.text.trim();
              } else {
                c.assignments.add(Assignment(title.text.trim(), subj, due, notes.text.trim()));
              }
              app.changed();
              Navigator.pop(ctx);
            },
            child: Text(edit == null ? 'Add' : 'Save'),
          ),
        ],
      );
    }),
  );
}

class AssignmentsTab extends StatelessWidget {
  final Category c;
  const AssignmentsTab(this.c, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (ctx, _) {
        final list = [...c.assignments]..sort((a, b) {
            if (a.done != b.done) return a.done ? 1 : -1;
            return a.due.compareTo(b.due);
          });
        final total = list.length;
        final done = list.where((a) => a.done).length;
        final overdue = list.where((a) => !a.done && daysUntil(a.due) < 0).length;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Assignment'),
                onPressed: () => assignmentDialog(ctx, c)),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Assignment Tracker', style: heading),
              const SizedBox(height: 8),
              Row(children: [
                miniStat('Total', '$total'),
                miniStat('Submitted', '$done', color: Colors.green),
                miniStat('Pending', '${total - done}'),
                miniStat('Overdue', '$overdue', color: overdue > 0 ? Colors.redAccent : null),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    minHeight: 12,
                    color: c.color,
                    backgroundColor: lav),
              ),
            ]),
          ),
          if (list.isEmpty)
            const Panel(
                child: Text('No assignments yet. Tap "Add Assignment" and set the last date.',
                    style: TextStyle(color: Colors.grey))),
          for (final a in list) card(ctx, a),
        ]);
      },
    );
  }

  Widget card(BuildContext ctx, Assignment a) {
    String status;
    Color col;
    if (a.done) {
      status = 'Submitted${a.doneOn != null ? " on ${fmtDate(a.doneOn!)}" : ""}';
      col = Colors.green;
    } else {
      final dl = daysUntil(a.due);
      if (dl < 0) {
        status = 'Overdue by ${-dl} day${dl == -1 ? '' : 's'}. You can still finish it.';
        col = Colors.redAccent;
      } else if (dl == 0) {
        status = 'Due today';
        col = Colors.orange;
      } else {
        status = 'Due in $dl day${dl == 1 ? '' : 's'}';
        col = dl <= 2 ? Colors.orange : Colors.black54;
      }
    }
    return Panel(
      child: Row(children: [
        Checkbox(
          value: a.done,
          onChanged: (v) {
            a.done = v ?? false;
            a.doneOn = a.done ? DateTime.now() : null;
            app.changed();
            if (a.done) snack('Assignment submitted! ⭐');
          },
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    decoration: a.done ? TextDecoration.lineThrough : null)),
            Text('${a.subject ?? c.name} • Last date: ${fmtDate(a.due)}',
                style: const TextStyle(color: Colors.black54)),
            Text(status, style: TextStyle(color: col, fontWeight: FontWeight.w600)),
            if (a.notes.isNotEmpty)
              Text(a.notes, style: const TextStyle(color: Colors.black45, fontSize: 12)),
          ]),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') {
              assignmentDialog(ctx, c, edit: a);
            } else {
              c.assignments.remove(a);
              app.changed();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'del', child: Text('Delete')),
          ],
        ),
      ]),
    );
  }
}

// ---------- Exams (Study only) ----------
void examDialog(BuildContext context, Category c, {Exam? edit}) {
  final title = TextEditingController(text: edit?.title ?? '');
  final notes = TextEditingController(text: edit?.notes ?? '');
  String? subject = edit?.subject;
  DateTime date = edit?.date ?? DateTime.now();
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      return AlertDialog(
        title: Text(edit == null ? 'Add Exam' : 'Edit Exam'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: title,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Exam name (e.g. Mid-term, Unit test)')),
              if (c.items.isNotEmpty)
                DropdownButtonFormField<String?>(
                  value: c.items.any((i) => i.name == subject) ? subject : null,
                  decoration: const InputDecoration(labelText: 'Subject (optional)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('— none —')),
                    for (final i in c.items) DropdownMenuItem<String?>(value: i.name, child: Text(i.name))
                  ],
                  onChanged: (v) => setS(() => subject = v),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.event, size: 16),
                label: Text('Exam date: ${fmtDate(date)}'),
                onPressed: () async {
                  final p = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100));
                  if (p != null) setS(() => date = p);
                },
              ),
              TextField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Notes (syllabus, venue... optional)')),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty) {
                snack('Enter the exam name.');
                return;
              }
              final String? subj = c.items.any((i) => i.name == subject) ? subject : null;
              if (edit != null) {
                edit.title = title.text.trim();
                edit.subject = subj;
                edit.date = date;
                edit.notes = notes.text.trim();
              } else {
                c.exams.add(Exam(title.text.trim(), subj, date, notes.text.trim()));
              }
              app.changed();
              Navigator.pop(ctx);
            },
            child: Text(edit == null ? 'Add' : 'Save'),
          ),
        ],
      );
    }),
  );
}

class ExamsTab extends StatelessWidget {
  final Category c;
  const ExamsTab(this.c, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (ctx, _) {
        final list = [...c.exams]..sort((a, b) {
            if (a.done != b.done) return a.done ? 1 : -1;
            return a.date.compareTo(b.date);
          });
        final upcoming = list.where((e) => !e.done && daysUntil(e.date) >= 0).toList();
        final next = upcoming.isEmpty ? null : upcoming.first;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Exam'),
                onPressed: () => examDialog(ctx, c)),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Exam Tracker', style: heading),
              const SizedBox(height: 6),
              if (next == null)
                const Text('No upcoming exams.', style: TextStyle(color: Colors.grey))
              else ...[
                Text(next.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Text('${next.subject ?? c.name} • ${fmtDate(next.date)}',
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 4),
                Text(
                    daysUntil(next.date) == 0
                        ? 'Today. Good luck! 🍀'
                        : 'Starts ${dueText(daysUntil(next.date))}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: purple)),
              ],
              const SizedBox(height: 6),
              Text('${upcoming.length} upcoming • ${list.where((e) => e.done).length} taken',
                  style: const TextStyle(color: Colors.black54)),
            ]),
          ),
          if (list.isEmpty)
            const Panel(
                child: Text('No exams yet. Tap "Add Exam" and set the date.',
                    style: TextStyle(color: Colors.grey))),
          for (final e in list) card(ctx, e),
        ]);
      },
    );
  }

  Widget card(BuildContext ctx, Exam e) {
    String status;
    Color col;
    if (e.done) {
      status = 'Exam taken';
      col = Colors.green;
    } else {
      final dl = daysUntil(e.date);
      if (dl < 0) {
        status = 'Held ${-dl} day${dl == -1 ? '' : 's'} ago. Tick the box when marked as taken.';
        col = Colors.black54;
      } else if (dl == 0) {
        status = 'Today! Good luck 🍀';
        col = Colors.orange;
      } else {
        status = 'In $dl day${dl == 1 ? '' : 's'}';
        col = dl <= 3 ? Colors.orange : Colors.black54;
      }
    }
    return Panel(
      child: Row(children: [
        Checkbox(
          value: e.done,
          onChanged: (v) {
            e.done = v ?? false;
            app.changed();
          },
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    decoration: e.done ? TextDecoration.lineThrough : null)),
            Text('${e.subject ?? c.name} • ${fmtDate(e.date)}',
                style: const TextStyle(color: Colors.black54)),
            Text(status, style: TextStyle(color: col, fontWeight: FontWeight.w600)),
            if (e.notes.isNotEmpty)
              Text(e.notes, style: const TextStyle(color: Colors.black45, fontSize: 12)),
          ]),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') {
              examDialog(ctx, c, edit: e);
            } else {
              c.exams.remove(e);
              app.changed();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'del', child: Text('Delete')),
          ],
        ),
      ]),
    );
  }
}

// ---------- Attendance (Study only) ----------
void attendanceDialog(BuildContext context, Category c) {
  if (c.items.isEmpty) {
    snack('Add a subject first (My Subjects tab).');
    return;
  }
  String subject = c.items.first.name;
  DateTime date = DateTime.now();
  final conducted = TextEditingController(text: '1');
  final attended = TextEditingController(text: '1');
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      return AlertDialog(
        title: const Text('Record Attendance'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(fmtDate(date)),
              onPressed: () async {
                final p = await showDatePicker(
                    context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (p != null) setS(() => date = p);
              },
            ),
            DropdownButtonFormField<String>(
              value: subject,
              items: [for (final i in c.items) DropdownMenuItem(value: i.name, child: Text(i.name))],
              onChanged: (v) => setS(() => subject = v ?? subject),
            ),
            TextField(
                controller: conducted,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Classes conducted')),
            TextField(
                controller: attended,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Classes attended')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(conducted.text) ?? 0;
              final a = int.tryParse(attended.text) ?? -1;
              if (n <= 0 || a < 0 || a > n) {
                snack('Attended must be between 0 and conducted.');
                return;
              }
              for (int k = 0; k < n; k++) {
                c.att.add(AttRecord(subject, k < a, date));
              }
              app.changed();
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      );
    }),
  );
}

class AttendanceTab extends StatelessWidget {
  final Category c;
  const AttendanceTab(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (ctx, _) {
        final overall = c.attPct();
        final names = c.items.map((i) => i.name).where((n) => c.attTotal(n) > 0).toList();
        return ListView(padding: const EdgeInsets.all(16), children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Record Attendance'),
                onPressed: () => attendanceDialog(ctx, c)),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Overall Attendance', style: heading)),
                TextButton.icon(
                  icon: const Icon(Icons.flag, size: 16),
                  label: Text('Target ${c.attTarget}%'),
                  onPressed: () async {
                    final v = await askText(ctx, 'Target attendance %', 'e.g. 75');
                    final n = int.tryParse(v ?? '');
                    if (n != null && n > 0 && n <= 100) {
                      c.attTarget = n;
                      app.changed();
                    }
                  },
                ),
              ]),
              if (overall == null)
                const Text('No classes recorded yet.', style: TextStyle(color: Colors.grey))
              else ...[
                Text('${overall.toStringAsFixed(2)}%',
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                Text('${c.attCount()} attended of ${c.attTotal()} classes  •  ${c.attTotal() - c.attCount()} absent'),
              ],
            ]),
          ),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Subject-wise Attendance (%)', style: heading),
              const SizedBox(height: 8),
              HBarChart(
                  labels: names,
                  values: [for (final n in names) c.attPct(n)!],
                  maxValue: 100,
                  suffix: '%',
                  colors: [for (final _ in names) c.color]),
            ]),
          ),
          for (final i in c.items) subjectAtt(i.name),
          if (c.att.isNotEmpty)
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Recent History', style: heading),
                for (final r in c.att.reversed.take(8))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(r.attended ? Icons.check_circle : Icons.cancel,
                        color: r.attended ? Colors.green : Colors.redAccent),
                    title: Text(r.item),
                    subtitle: Text(fmtDate(r.date)),
                    trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () {
                          c.att.remove(r);
                          app.changed();
                        }),
                  ),
              ]),
            ),
        ]);
      },
    );
  }

  Widget subjectAtt(String name) {
    final t = c.attTotal(name), a = c.attCount(name);
    final p = c.attPct(name);
    String msg;
    if (p == null) {
      msg = 'No classes recorded yet.';
    } else if (p >= c.attTarget) {
      final canMiss = (a * 100 / c.attTarget - t).floor();
      msg = 'Good attendance! You can miss $canMiss more class(es) and still meet your target.';
    } else if (c.attTarget >= 100) {
      msg = 'A 100% target cannot be recovered after a missed class.';
    } else {
      final need = ((c.attTarget * t - 100 * a) / (100 - c.attTarget)).ceil();
      msg = p >= c.attTarget - 5
          ? 'Approaching your target. Attend the next $need class(es) in a row to reach it.'
          : 'Below target, but recoverable. Attend the next $need class(es) in a row.';
    }
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          Text(p == null ? '—' : '${p.toStringAsFixed(2)}%',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        Text('Conducted: $t  •  Attended: $a  •  Absent: ${t - a}'),
        Text(msg, style: const TextStyle(color: Colors.black54)),
      ]),
    );
  }
}

// ---------- Sleep ----------
void sleepDialog(BuildContext context, Category c) {
  TimeOfDay bed = const TimeOfDay(hour: 22, minute: 30);
  TimeOfDay wake = const TimeOfDay(hour: 6, minute: 30);
  DateTime date = DateTime.now();
  final hoursCtl = TextEditingController();
  double calc() {
    var m = (wake.hour * 60 + wake.minute) - (bed.hour * 60 + bed.minute);
    if (m <= 0) m += 1440;
    return m / 60;
  }

  hoursCtl.text = calc().toStringAsFixed(1);
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      return AlertDialog(
        title: const Text('Log Sleep'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text('Woke up on ${fmtDate(date)}'),
              onPressed: () async {
                final p = await showDatePicker(
                    context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (p != null) setS(() => date = p);
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.bedtime, size: 16),
              label: Text('Bedtime ${fmtTime(bed)}'),
              onPressed: () async {
                final p = await showTimePicker(context: ctx, initialTime: bed);
                if (p != null) {
                  bed = p;
                  setS(() => hoursCtl.text = calc().toStringAsFixed(1));
                }
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.wb_sunny, size: 16),
              label: Text('Wake-up ${fmtTime(wake)}'),
              onPressed: () async {
                final p = await showTimePicker(context: ctx, initialTime: wake);
                if (p != null) {
                  wake = p;
                  setS(() => hoursCtl.text = calc().toStringAsFixed(1));
                }
              },
            ),
            TextField(
                controller: hoursCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sleep hours (editable)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final h = double.tryParse(hoursCtl.text) ?? 0;
              if (h <= 0 || h > 24) {
                snack('Enter valid sleep hours.');
                return;
              }
              c.sleep.removeWhere((s) => sameDay(s.date, date));
              c.sleep.add(SleepLog(date, h));
              app.changed();
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      );
    }),
  );
}

class SleepTab extends StatelessWidget {
  final Category c;
  const SleepTab(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (ctx, _) {
        final today = app.value(c, DateTime.now());
        final logs = [...c.sleep]..sort((a, b) => a.date.compareTo(b.date));
        final last = logs.length > 7 ? logs.sublist(logs.length - 7) : logs;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Log Sleep'),
                onPressed: () => sleepDialog(ctx, c)),
            OutlinedButton.icon(
              icon: const Icon(Icons.notifications_active, size: 18),
              label: Text(c.bedtime == null ? 'Set bedtime reminder' : 'Bedtime reminder ${fmtTime(c.bedtime!)}'),
              onPressed: () async {
                final p = await showTimePicker(
                    context: ctx, initialTime: c.bedtime ?? const TimeOfDay(hour: 22, minute: 30));
                if (p != null) {
                  c.bedtime = p;
                  c.bedKey = null;
                  app.changed();
                }
              },
            ),
            if (c.bedtime != null)
              TextButton(
                  onPressed: () {
                    c.bedtime = null;
                    app.changed();
                  },
                  child: const Text('Clear')),
          ]),
          const SizedBox(height: 12),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Last logged sleep (today)', style: heading),
              Text(today == 0 ? 'Not logged yet' : '${today.toStringAsFixed(1)} h of ${fmtNum(c.target)} h target',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              if (today > 0)
                Text(today >= c.target
                    ? 'Great rest! You reached your sleep goal.'
                    : 'A little short of your goal. An earlier night can help.',
                    style: const TextStyle(color: Colors.black54)),
            ]),
          ),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Recent sleep (hours)', style: heading),
              const SizedBox(height: 8),
              HBarChart(
                labels: [for (final l in last) '${l.date.day}/${l.date.month}'],
                values: [for (final l in last) l.hours],
                maxValue: c.target > 10 ? c.target : 10,
                suffix: 'h',
                colors: [for (final _ in last) c.color],
              ),
            ]),
          ),
          if (logs.isNotEmpty)
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('History', style: heading),
                for (final l in logs.reversed.take(10))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bedtime),
                    title: Text('${l.hours.toStringAsFixed(1)} hours'),
                    subtitle: Text(fmtDate(l.date)),
                    trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () {
                          c.sleep.remove(l);
                          app.changed();
                        }),
                  ),
              ]),
            ),
        ]);
      },
    );
  }
}

// ---------- Water ----------
class WaterTab extends StatelessWidget {
  final Category c;
  const WaterTab(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (ctx, _) {
        final k = dkey(DateTime.now());
        final n = c.water[k] ?? 0;
        final p = c.target <= 0 ? 0.0 : (n / c.target).clamp(0.0, 1.0);
        final keys = c.water.keys.toList()..sort();
        final lastKeys = keys.length > 7 ? keys.sublist(keys.length - 7) : keys;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Panel(
            child: Column(children: [
              const Text("Today's Water", style: heading),
              const SizedBox(height: 12),
              SizedBox(
                width: 150,
                height: 150,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox(
                      width: 150,
                      height: 150,
                      child: CircularProgressIndicator(
                          value: p, strokeWidth: 12, color: c.color, backgroundColor: lav)),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$n', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
                    Text('of ${c.target.round()} glasses', style: const TextStyle(color: Colors.black54)),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton.outlined(
                    onPressed: n > 0
                        ? () {
                            c.water[k] = n - 1;
                            app.changed();
                          }
                        : null,
                    icon: const Icon(Icons.remove)),
                const SizedBox(width: 12),
                FilledButton.icon(
                    onPressed: () {
                      c.water[k] = n + 1;
                      if (n + 1 == c.target.round()) snack('💧 Water goal reached! +3 ⭐');
                      app.changed();
                    },
                    icon: const Icon(Icons.water_drop),
                    label: const Text('+1 glass')),
              ]),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.notifications_active, size: 18),
                label: Text(c.waterEvery == 0 ? 'Set drink reminder' : 'Reminder: every ${c.waterEvery} min'),
                onPressed: () async {
                  final v = await showDialog<int>(
                    context: ctx,
                    builder: (d) => SimpleDialog(title: const Text('Remind me every...'), children: [
                      for (final m in [0, 1, 30, 60, 90, 120])
                        SimpleDialogOption(
                            onPressed: () => Navigator.pop(d, m),
                            child: Text(m == 0 ? 'Off' : (m == 1 ? '1 min (demo)' : '$m minutes'))),
                    ]),
                  );
                  if (v != null) {
                    c.waterEvery = v;
                    c.lastWater = DateTime.now();
                    app.changed();
                  }
                },
              ),
            ]),
          ),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Recent days (glasses)', style: heading),
              const SizedBox(height: 8),
              HBarChart(
                labels: [for (final x in lastKeys) x.substring(5)],
                values: [for (final x in lastKeys) (c.water[x] ?? 0).toDouble()],
                maxValue: c.target > 1 ? c.target : 8,
                colors: [for (final _ in lastKeys) c.color],
              ),
            ]),
          ),
        ]);
      },
    );
  }
}

// ---------- Food ----------
class FoodTab extends StatelessWidget {
  final Category c;
  const FoodTab(this.c, {super.key});

  void mealDialog(BuildContext ctx) {
    final name = TextEditingController();
    final cal = TextEditingController();
    bool isHealthy = true;
    showDialog(
      context: ctx,
      builder: (d) => StatefulBuilder(builder: (d, setS) {
        return AlertDialog(
          title: const Text('Log Meal'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'What did you eat?')),
            TextField(
                controller: cal,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Calories (kcal)')),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(isHealthy ? 'Healthy meal 🥗' : 'Not so healthy 🍟'),
                value: isHealthy,
                onChanged: (v) => setS(() => isHealthy = v)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  final k = int.tryParse(cal.text.trim()) ?? 0;
                  if (name.text.trim().isEmpty || k < 0) {
                    snack('Enter a meal name and calories.');
                    return;
                  }
                  c.meals.add(Meal(name.text.trim(), isHealthy, DateTime.now(), k));
                  app.changed();
                  Navigator.pop(d);
                },
                child: const Text('Save')),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (ctx, _) {
        final now = DateTime.now();
        final todays = c.meals.where((m) => sameDay(m.date, now)).toList();
        final healthy = todays.where((m) => m.healthy).length;
        final eaten = app.caloriesOn(c, now);
        final goal = c.calorieGoal;
        final p = goal <= 0 ? 0.0 : (eaten / goal).clamp(0.0, 1.0);
        final days = [for (int i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i)];
        final calVals = [for (final d in days) app.caloriesOn(c, d).toDouble()];
        final maxCal = [...calVals, goal.toDouble(), 1.0].reduce((a, b) => a > b ? a : b);
        String msg;
        if (goal <= 0) {
          msg = 'Set a daily calorie goal to track your progress.';
        } else if (eaten <= goal) {
          msg = '${goal - eaten} kcal left for today.';
        } else {
          msg = '${eaten - goal} kcal above your goal today. That is okay, tomorrow is a fresh start.';
        }
        return ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Log Meal'),
                onPressed: () => mealDialog(ctx)),
            OutlinedButton.icon(
              icon: const Icon(Icons.local_fire_department, size: 18),
              label: Text('Calorie goal: $goal kcal'),
              onPressed: () async {
                final v = await askText(ctx, 'Daily calorie goal (kcal)', 'e.g. 2000');
                final n = int.tryParse(v ?? '');
                if (n != null && n > 0) {
                  c.calorieGoal = n;
                  app.changed();
                }
              },
            ),
          ]),
          const SizedBox(height: 12),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Today's Calories", style: heading),
              const SizedBox(height: 6),
              Text('$eaten kcal eaten of $goal kcal',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                    value: p, minHeight: 14, color: c.color, backgroundColor: lav),
              ),
              const SizedBox(height: 6),
              Text(msg, style: const TextStyle(color: Colors.black54)),
            ]),
          ),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Last 7 days: calories eaten', style: heading),
              const SizedBox(height: 8),
              HBarChart(
                labels: [for (final d in days) '${d.day}/${d.month}'],
                values: calVals,
                maxValue: maxCal,
                suffix: '',
                colors: [for (final _ in days) c.color],
              ),
              Text('Goal: $goal kcal per day', style: const TextStyle(color: Colors.black54)),
            ]),
          ),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Today's Meals", style: heading),
              Text('$healthy healthy of ${todays.length} meals  •  target ${c.target.round()} healthy',
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 8),
              HBarChart(
                labels: const ['Healthy', 'Other'],
                values: [healthy.toDouble(), (todays.length - healthy).toDouble()],
                maxValue: todays.length.toDouble(),
                colors: const [Color(0xFF00B894), Color(0xFFE17055)],
              ),
              if (todays.isEmpty)
                const Text('No meals logged today.', style: TextStyle(color: Colors.grey)),
              for (final m in todays)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(m.healthy ? Icons.eco : Icons.fastfood,
                      color: m.healthy ? Colors.green : Colors.orange),
                  title: Text(m.name),
                  subtitle: Text('${m.calories} kcal'),
                  trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () {
                        c.meals.remove(m);
                        app.changed();
                      }),
                ),
            ]),
          ),
        ]);
      },
    );
  }
}

// ===================== STATS =====================
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final now = DateTime.now();
        final days = [for (int i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i)];
        const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final timeCats = app.cats.where((c) => c.isTime).toList();
        final dayMin = [
          for (final d in days) timeCats.fold<double>(0, (a, c) => a + app.value(c, d))
        ];
        final timeToday = timeCats.where((c) => app.value(c, now) > 0).toList();
        final planned7 = [
          for (final c in app.cats) days.fold<int>(0, (a, d) => a + app.plannedMinOn(c, d))
        ];
        final actual7 = [
          for (final c in app.cats) days.fold<int>(0, (a, d) => a + app.actualMinOn(c, d))
        ];
        return page(
          'Stats',
          ListView(padding: const EdgeInsets.all(16), children: [
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Today's progress by category (%)", style: heading),
                const SizedBox(height: 8),
                HBarChart(
                  labels: [for (final c in app.cats) c.name],
                  values: [for (final c in app.cats) app.progress(c, now) * 100],
                  maxValue: 100,
                  suffix: '%',
                  colors: [for (final c in app.cats) c.color],
                ),
              ]),
            ),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Planned vs actual: last 7 days, by category', style: heading),
                const SizedBox(height: 8),
                PlanVsActualChart(
                  labels: [for (final c in app.cats) c.name],
                  planned: planned7,
                  actual: actual7,
                  color: purple,
                ),
              ]),
            ),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Last 7 days: active minutes (time-based categories)', style: heading),
                const SizedBox(height: 8),
                HBarChart(
                  labels: [for (final d in days) wd[d.weekday - 1]],
                  values: dayMin,
                  maxValue: dayMin.fold<double>(1, (a, b) => a > b ? a : b),
                  suffix: 'm',
                ),
              ]),
            ),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Time by category today (minutes)', style: heading),
                const SizedBox(height: 8),
                HBarChart(
                  labels: [for (final c in timeToday) c.name],
                  values: [for (final c in timeToday) app.value(c, now)],
                  maxValue: timeToday.fold<double>(1, (a, c) => a > app.value(c, now) ? a : app.value(c, now)),
                  suffix: 'm',
                  colors: [for (final c in timeToday) c.color],
                ),
              ]),
            ),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Stars by category', style: heading),
                const SizedBox(height: 8),
                HBarChart(
                  labels: [for (final c in app.cats) c.name],
                  values: [for (final c in app.cats) app.stars(c).toDouble()],
                  maxValue: app.cats.fold<double>(1, (a, c) => a > app.stars(c) ? a : app.stars(c).toDouble()),
                  colors: [for (final c in app.cats) c.color],
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

// ===================== REWARDS =====================
class RewardsPage extends StatelessWidget {
  const RewardsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final now = DateTime.now();
        final doneTasks = app.tasks.where((t) => t.done).length;
        final subDone = app.cats.fold<int>(
            0, (a, c) => a + c.items.fold<int>(0, (b, i) => b + i.subs.where((s) => s.status == 2).length));
        final met = app.cats.where((c) => c.target > 0 && app.value(c, now) >= c.target).length;
        final ach = <List<dynamic>>[
          ['First task completed', doneTasks >= 1],
          ['10 tasks completed', doneTasks >= 10],
          ['First chapter / step completed', subDone >= 1],
          ['First assignment submitted', app.cats.any((c) => c.assignments.any((a) => a.done))],
          ['Hit a daily target', met >= 1],
          ['Hit 3 daily targets in one day', met >= 3],
          ['Created your own category', app.cats.any((c) => c.type == 'custom')],
        ];
        return page(
          'Rewards',
          ListView(padding: const EdgeInsets.all(16), children: [
            Panel(
              child: Column(children: [
                const Icon(Icons.star, size: 56, color: Colors.amber),
                Text('${app.totalStars} stars',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                const Text('Earned from your real activity', style: TextStyle(color: Colors.black54)),
              ]),
            ),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Stars by category', style: heading),
                for (final c in app.cats)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(c.icon, color: c.color),
                    title: Text(c.name),
                    trailing: Text('${app.stars(c)} ⭐', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
              ]),
            ),
            const Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('How stars are earned', style: heading),
                SizedBox(height: 6),
                Text('• Complete a task: 1 star'),
                Text('• Complete a chapter in Study: 2 stars (other categories: 1)'),
                Text('• Submit an assignment: 1 star'),
                Text('• Reach a category daily target: 3 stars per day'),
                Text('• Every 5 classes attended: 1 star'),
              ]),
            ),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Achievements', style: heading),
                for (final a in ach)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(a[1] as bool ? Icons.emoji_events : Icons.lock_outline,
                        color: a[1] as bool ? Colors.amber : Colors.grey),
                    title: Text(a[0] as String),
                    subtitle: Text(a[1] as bool ? 'Unlocked' : 'Locked'),
                  ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}
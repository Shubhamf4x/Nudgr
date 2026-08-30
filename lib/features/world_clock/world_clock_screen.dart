import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../../core/theme/app_text_styles.dart';
import 'world_clock_city.dart';

class WorldClockScreen extends StatefulWidget {
  const WorldClockScreen({super.key});

  @override
  State<WorldClockScreen> createState() => _WorldClockScreenState();
}

class _WorldClockScreenState extends State<WorldClockScreen> {
  Timer? _timer;
  // Ticking clock lives in a ValueNotifier so each second only rebuilds the
  // time texts, not the whole screen (header + list + cards).
  final ValueNotifier<DateTime> _nowNotifier = ValueNotifier<DateTime>(DateTime.now());
  bool _is24Hour = false;
  List<WorldClockCity> _cities = [];
  final TextEditingController _searchController = TextEditingController();
  List<WorldClockCity> _searchResults = [];
  bool _isSearching = false;

  static const List<WorldClockCity> _defaultCities = [
    WorldClockCity(name: 'Tokyo', timezone: 'Asia/Tokyo', offset: 9),
    WorldClockCity(name: 'Sydney', timezone: 'Australia/Sydney', offset: 11),
    WorldClockCity(name: 'New York', timezone: 'America/New_York', offset: -5),
    WorldClockCity(name: 'Los Angeles', timezone: 'America/Los_Angeles', offset: -8),
    WorldClockCity(name: 'London', timezone: 'Europe/London', offset: 0),
  ];

  static const List<WorldClockCity> _allCities = [
    WorldClockCity(name: 'Tokyo', timezone: 'Asia/Tokyo', offset: 9),
    WorldClockCity(name: 'Sydney', timezone: 'Australia/Sydney', offset: 11),
    WorldClockCity(name: 'London', timezone: 'Europe/London', offset: 0),
    WorldClockCity(name: 'New York', timezone: 'America/New_York', offset: -5),
    WorldClockCity(name: 'Los Angeles', timezone: 'America/Los_Angeles', offset: -8),
    WorldClockCity(name: 'Singapore', timezone: 'Asia/Singapore', offset: 8),
    WorldClockCity(name: 'Dubai', timezone: 'Asia/Dubai', offset: 4),
    WorldClockCity(name: 'Paris', timezone: 'Europe/Paris', offset: 1),
    WorldClockCity(name: 'Mumbai', timezone: 'Asia/Kolkata', offset: 5.5),
    WorldClockCity(name: 'Delhi', timezone: 'Asia/Kolkata', offset: 5.5),
    WorldClockCity(name: 'Berlin', timezone: 'Europe/Berlin', offset: 1),
    WorldClockCity(name: 'Moscow', timezone: 'Europe/Moscow', offset: 3),
    WorldClockCity(name: 'Seoul', timezone: 'Asia/Seoul', offset: 9),
    WorldClockCity(name: 'Bangkok', timezone: 'Asia/Bangkok', offset: 7),
    WorldClockCity(name: 'Istanbul', timezone: 'Europe/Istanbul', offset: 3),
    WorldClockCity(name: 'Cairo', timezone: 'Africa/Cairo', offset: 2),
    WorldClockCity(name: 'Lagos', timezone: 'Africa/Lagos', offset: 1),
    WorldClockCity(name: 'Nairobi', timezone: 'Africa/Nairobi', offset: 3),
    WorldClockCity(name: 'Toronto', timezone: 'America/Toronto', offset: -5),
    WorldClockCity(name: 'Vancouver', timezone: 'America/Vancouver', offset: -8),
    WorldClockCity(name: 'Chicago', timezone: 'America/Chicago', offset: -6),
    WorldClockCity(name: 'Mexico City', timezone: 'America/Mexico_City', offset: -6),
    WorldClockCity(name: 'Buenos Aires', timezone: 'America/Argentina/Buenos_Aires', offset: -3),
    WorldClockCity(name: 'Johannesburg', timezone: 'Africa/Johannesburg', offset: 2),
    WorldClockCity(name: 'Athens', timezone: 'Europe/Athens', offset: 2),
    WorldClockCity(name: 'Warsaw', timezone: 'Europe/Warsaw', offset: 1),
    WorldClockCity(name: 'Stockholm', timezone: 'Europe/Stockholm', offset: 1),
    WorldClockCity(name: 'Helsinki', timezone: 'Europe/Helsinki', offset: 2),
    WorldClockCity(name: 'Hong Kong', timezone: 'Asia/Hong_Kong', offset: 8),
    WorldClockCity(name: 'Taipei', timezone: 'Asia/Taipei', offset: 8),
    WorldClockCity(name: 'Shanghai', timezone: 'Asia/Shanghai', offset: 8),
    WorldClockCity(name: 'Beijing', timezone: 'Asia/Shanghai', offset: 8),
    WorldClockCity(name: 'Karachi', timezone: 'Asia/Karachi', offset: 5),
    WorldClockCity(name: 'Dhaka', timezone: 'Asia/Dhaka', offset: 6),
    WorldClockCity(name: 'Kathmandu', timezone: 'Asia/Kathmandu', offset: 5.75),
    WorldClockCity(name: 'Colombo', timezone: 'Asia/Colombo', offset: 5.5),
    WorldClockCity(name: 'Perth', timezone: 'Australia/Perth', offset: 8),
    WorldClockCity(name: 'Melbourne', timezone: 'Australia/Melbourne', offset: 11),
    WorldClockCity(name: 'Auckland', timezone: 'Pacific/Auckland', offset: 13),
    WorldClockCity(name: 'Honolulu', timezone: 'Pacific/Honolulu', offset: -10),
    WorldClockCity(name: 'Anchorage', timezone: 'America/Anchorage', offset: -9),
    WorldClockCity(name: 'Denver', timezone: 'America/Denver', offset: -7),
    WorldClockCity(name: 'Phoenix', timezone: 'America/Phoenix', offset: -7),
    WorldClockCity(name: 'Miami', timezone: 'America/New_York', offset: -5),
    WorldClockCity(name: 'Seattle', timezone: 'America/Los_Angeles', offset: -8),
    WorldClockCity(name: 'San Francisco', timezone: 'America/Los_Angeles', offset: -8),
    WorldClockCity(name: 'Boston', timezone: 'America/New_York', offset: -5),
    WorldClockCity(name: 'Washington DC', timezone: 'America/New_York', offset: -5),
    WorldClockCity(name: 'Atlanta', timezone: 'America/New_York', offset: -5),
    WorldClockCity(name: 'Dallas', timezone: 'America/Chicago', offset: -6),
    WorldClockCity(name: 'Houston', timezone: 'America/Chicago', offset: -6),
    WorldClockCity(name: 'Lima', timezone: 'America/Lima', offset: -5),
    WorldClockCity(name: 'Bogota', timezone: 'America/Bogota', offset: -5),
    WorldClockCity(name: 'Santiago', timezone: 'America/Santiago', offset: -4),
    WorldClockCity(name: 'Manila', timezone: 'Asia/Manila', offset: 8),
    WorldClockCity(name: 'Jakarta', timezone: 'Asia/Jakarta', offset: 7),
    WorldClockCity(name: 'Kuala Lumpur', timezone: 'Asia/Kuala_Lumpur', offset: 8),
    WorldClockCity(name: 'Ho Chi Minh', timezone: 'Asia/Ho_Chi_Minh', offset: 7),
    WorldClockCity(name: 'Riyadh', timezone: 'Asia/Riyadh', offset: 3),
    WorldClockCity(name: 'Doha', timezone: 'Asia/Qatar', offset: 3),
    WorldClockCity(name: 'Abu Dhabi', timezone: 'Asia/Dubai', offset: 4),
    WorldClockCity(name: 'Tehran', timezone: 'Asia/Tehran', offset: 3.5),
    WorldClockCity(name: 'Reykjavik', timezone: 'Atlantic/Reykjavik', offset: 0),
    WorldClockCity(name: 'Lisbon', timezone: 'Europe/Lisbon', offset: 0),
    WorldClockCity(name: 'Madrid', timezone: 'Europe/Madrid', offset: 1),
    WorldClockCity(name: 'Rome', timezone: 'Europe/Rome', offset: 1),
    WorldClockCity(name: 'Zurich', timezone: 'Europe/Zurich', offset: 1),
    WorldClockCity(name: 'Vienna', timezone: 'Europe/Vienna', offset: 1),
    WorldClockCity(name: 'Prague', timezone: 'Europe/Prague', offset: 1),
    WorldClockCity(name: 'Budapest', timezone: 'Europe/Budapest', offset: 1),
    WorldClockCity(name: 'Bucharest', timezone: 'Europe/Bucharest', offset: 2),
    WorldClockCity(name: 'Kyiv', timezone: 'Europe/Kyiv', offset: 2),
    WorldClockCity(name: 'Dublin', timezone: 'Europe/Dublin', offset: 0),
    WorldClockCity(name: 'Copenhagen', timezone: 'Europe/Copenhagen', offset: 1),
    WorldClockCity(name: 'Oslo', timezone: 'Europe/Oslo', offset: 1),
    WorldClockCity(name: 'Amsterdam', timezone: 'Europe/Amsterdam', offset: 1),
    WorldClockCity(name: 'Brussels', timezone: 'Europe/Brussels', offset: 1),
  ];

  @override
  void initState() {
    super.initState();
    tz_data.initializeTimeZones();
    _loadCities();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _nowNotifier.value = DateTime.now();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nowNotifier.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('world_clock_cities');
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        _cities = saved.map((s) {
          final p = s.split('|');
          return WorldClockCity(name: p[0], timezone: p[1], offset: double.parse(p[2]));
        }).toList();
      });
    } else {
      setState(() => _cities = List.from(_defaultCities));
      _saveCities();
    }
  }

  Future<void> _saveCities() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _cities.map((c) => '${c.name}|${c.timezone}|${c.offset}').toList();
    await prefs.setStringList('world_clock_cities', data);
  }

  String _formatTime(DateTime time) {
    if (_is24Hour) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final p = time.hour >= 12 ? 'PM' : 'AM';
    return '$h:${time.minute.toString().padLeft(2, '0')} $p';
  }

  String _getUtcLabel(double offset) {
    final sign = offset >= 0 ? '+' : '';
    if (offset % 1 == 0) return 'UTC$sign${offset.toInt()}';
    final h = offset.toInt();
    final m = ((offset - h) * 60).toInt();
    return 'UTC$sign$h:${m.toString().padLeft(2, '0')}';
  }

  bool _isDaytime(DateTime time) => time.hour >= 6 && time.hour < 18;

  /// DST-correct city time using the IANA timezone identifier.
  /// Falls back to the stored fixed offset when the id is unknown.
  DateTime _getCityTime(WorldClockCity city, DateTime now) {
    try {
      final location = tz.getLocation(city.timezone);
      return tz.TZDateTime.from(now, location);
    } catch (_) {
      final utc = now.toUtc();
      return utc.add(
        Duration(hours: city.offset.toInt(), minutes: ((city.offset % 1) * 60).toInt()),
      );
    }
  }

  /// Actual UTC offset for the city right now (accounts for DST).
  double _getCurrentOffset(WorldClockCity city, DateTime now) {
    try {
      final location = tz.getLocation(city.timezone);
      final cityTime = tz.TZDateTime.from(now, location);
      final offset = cityTime.timeZoneOffset;
      return offset.inHours + (offset.inMinutes % 60) / 60.0;
    } catch (_) {
      return city.offset;
    }
  }

  WorldClockCity _getDeviceCity() {
    final now = DateTime.now();
    final off = now.timeZoneOffset;
    final total = off.inHours + off.inMinutes % 60 / 60.0;
    for (final c in _allCities) {
      if ((c.offset - total).abs() < 0.01) return c;
    }
    return WorldClockCity(name: now.timeZoneName, timezone: now.timeZoneName, offset: total);
  }

  void _searchCities(String q) {
    if (q.trim().isEmpty) {
      // Empty query -> show popular suggestions instead of an empty state.
      setState(() {
        _isSearching = true;
        _searchResults = List<WorldClockCity>.from(_defaultCities);
      });
      return;
    }
    final lower = q.toLowerCase();
    setState(() {
      _isSearching = true;
      final matches =
          _allCities.where((c) => c.name.toLowerCase().contains(lower)).toList();
      // Also match on timezone ids (e.g. "Asia", "Europe/Athens").
      if (matches.length < 5) {
        final tzMatches = _allCities.where((c) =>
            c.timezone.toLowerCase().contains(lower) &&
            !matches.contains(c));
        matches.addAll(tzMatches);
      }
      _searchResults = matches;
    });
  }

  void _addCity(WorldClockCity city) {
    if (_cities.any((c) => c.name == city.name)) return;
    setState(() {
      _cities.add(city);
      _searchController.clear();
      _searchResults = [];
      _isSearching = false;
    });
    _saveCities();
  }

  void _removeCity(WorldClockCity city) {
    setState(() => _cities.removeWhere((c) => c.name == city.name));
    _saveCities();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deviceCity = _getDeviceCity();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 20),
            Expanded(
              child: _isSearching
                  ? _buildSearchResults(isDark)
                  : _buildClockList(isDark, deviceCity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('World Time', style: AppTextStyles.googleSans(fontSize: 28, fontWeight: FontWeight.w800)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _showAddCitySheet,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A28) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.4)),
                  ),
                  child: const Center(child: Icon(Icons.add_rounded, size: 20, color: Color(0xFF6C63FF))),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _is24Hour = !_is24Hour),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A28) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _is24Hour ? '24h' : '12h',
                    style: AppTextStyles.googleSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6C63FF)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClockList(bool isDark, WorldClockCity deviceCity) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: _cities.length + 1,
      onReorderItem: (oldIndex, newIndex) {
        // Index 0 is the "Your Time" card — not reorderable.
        if (oldIndex == 0 || newIndex == 0) return;
        final actualOld = oldIndex - 1;
        final actualNew = newIndex - 1;
        if (actualOld < 0 || actualNew < 0) return;
        setState(() {
          final city = _cities.removeAt(actualOld);
          _cities.insert(actualNew, city);
        });
        _saveCities();
      },
      itemBuilder: (context, index) {
        if (index == 0) {
          return KeyedSubtree(
            key: const ValueKey('__your_time__'),
            child: _buildYourTimeCard(deviceCity, isDark),
          );
        }
        final city = _cities[index - 1];
        return KeyedSubtree(
          key: ValueKey(city.name),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildClockCard(city, isDark),
          ),
        );
      },
    );
  }

  Widget _buildYourTimeCard(WorldClockCity city, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF8B85FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: ValueListenableBuilder<DateTime>(
        valueListenable: _nowNotifier,
        builder: (context, now, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Time', style: AppTextStyles.googleSans(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8))),
                  const SizedBox(height: 4),
                  Text(city.name, style: AppTextStyles.googleSans(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatTime(now), style: AppTextStyles.googleSans(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text(_getUtcLabel(city.offset), style: AppTextStyles.googleSans(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildClockCard(WorldClockCity city, bool isDark) {
    return Dismissible(
      key: Key(city.name),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeCity(city),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A28) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<DateTime>(
                    valueListenable: _nowNotifier,
                    builder: (context, now, _) => Text(
                      _getUtcLabel(_getCurrentOffset(city, now)),
                      style: AppTextStyles.googleSans(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(city.name, style: AppTextStyles.googleSans(fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            ValueListenableBuilder<DateTime>(
              valueListenable: _nowNotifier,
              builder: (context, now, _) {
                final time = _getCityTime(city, now);
                return Text(_isDaytime(time) ? '\u2600' : '\u263E', style: const TextStyle(fontSize: 18));
              },
            ),
            const SizedBox(width: 16),
            ValueListenableBuilder<DateTime>(
              valueListenable: _nowNotifier,
              builder: (context, now, _) => Text(
                _formatTime(_getCityTime(city, now)),
                style: AppTextStyles.googleSans(fontSize: 28, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _searchCities,
            style: AppTextStyles.googleSans(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search cities...',
              hintStyle: AppTextStyles.googleSans(color: Colors.grey),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
              suffixIcon: GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() { _searchResults = []; _isSearching = false; });
                },
                child: const Icon(Icons.close_rounded, color: Colors.grey),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1A1A28) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Text(
                    'No cities found',
                    style: AppTextStyles.googleSans(color: Colors.grey, fontSize: 14),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_searchController.text.isEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 8, 20, 4),
                        child: Text(
                          'Suggestions',
                          style: AppTextStyles.googleSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, i) {
                          final city = _searchResults[i];
                          final alreadyAdded = _cities.any((c) => c.name == city.name);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            title: Text(city.name, style: AppTextStyles.googleSans(fontWeight: FontWeight.w600)),
                            subtitle: Text(city.timezone, style: AppTextStyles.googleSans(fontSize: 12, color: Colors.grey)),
                            trailing: alreadyAdded
                                ? Icon(Icons.check_rounded, color: Colors.grey.shade400, size: 20)
                                : const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF6C63FF), size: 22),
                            onTap: alreadyAdded ? null : () => _addCity(city),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  void _showAddCitySheet() {
    _searchController.clear();
    setState(() {
      _isSearching = true;
      _searchResults = List<WorldClockCity>.from(_defaultCities);
    });
  }
}

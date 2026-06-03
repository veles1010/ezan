import '../models/daily_prayer_times.dart';
import '../services/prayer_times_api_service.dart';
import 'prayer_times_repository.dart';

class ApiPrayerTimesRepository implements PrayerTimesRepository {
  ApiPrayerTimesRepository({PrayerTimesApiService? apiService})
      : _apiService = apiService ?? PrayerTimesApiService();

  static const List<String> _supportedCities = <String>[
    'Adana',
    'Ad\u0131yaman',
    'Afyonkarahisar',
    'A\u011fr\u0131',
    'Aksaray',
    'Amasya',
    'Ankara',
    'Antalya',
    'Ardahan',
    'Artvin',
    'Ayd\u0131n',
    'Bal\u0131kesir',
    'Bart\u0131n',
    'Batman',
    'Bayburt',
    'Bilecik',
    'Bing\u00f6l',
    'Bitlis',
    'Bolu',
    'Burdur',
    'Bursa',
    '\u00c7anakkale',
    '\u00c7ank\u0131r\u0131',
    '\u00c7orum',
    'Denizli',
    'Diyarbak\u0131r',
    'D\u00fczce',
    'Edirne',
    'Elaz\u0131\u011f',
    'Erzincan',
    'Erzurum',
    'Eski\u015fehir',
    'Gaziantep',
    'Giresun',
    'G\u00fcm\u00fc\u015fhane',
    'Hakkari',
    'Hatay',
    'I\u011fd\u0131r',
    'Isparta',
    '\u0130stanbul',
    '\u0130zmir',
    'Kahramanmara\u015f',
    'Karab\u00fck',
    'Karaman',
    'Kars',
    'Kastamonu',
    'Kayseri',
    'Kilis',
    'K\u0131r\u0131kkale',
    'K\u0131rklareli',
    'K\u0131r\u015fehir',
    'Kocaeli',
    'Konya',
    'K\u00fctahya',
    'Malatya',
    'Manisa',
    'Mardin',
    'Mersin',
    'Mu\u011fla',
    'Mu\u015f',
    'Nev\u015fehir',
    'Ni\u011fde',
    'Ordu',
    'Osmaniye',
    'Rize',
    'Sakarya',
    'Samsun',
    'Siirt',
    'Sinop',
    'Sivas',
    '\u015eanl\u0131urfa',
    '\u015e\u0131rnak',
    'Tekirda\u011f',
    'Tokat',
    'Trabzon',
    'Tunceli',
    'U\u015fak',
    'Van',
    'Yalova',
    'Yozgat',
    'Zonguldak',
  ];

  final PrayerTimesApiService _apiService;

  @override
  List<String> get availableCities => List<String>.unmodifiable(
        _supportedCities,
      );

  @override
  Future<DailyPrayerTimes> getDailyPrayerTimes({
    required String city,
    required DateTime date,
  }) {
    return _apiService.fetchDailyPrayerTimes(city: city, date: date);
  }
}

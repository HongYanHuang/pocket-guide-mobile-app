# Client Audio - Simple Guide

## One API Call Gets Everything! 🎯

**Super simple**: One endpoint returns complete tour data WITH audio URLs.

No separate calls. No URL construction. Just one request with everything you need.

---

## The API

```
GET /tours/{tour_id}?language={language}
```

**Returns:**
- ✅ Complete tour itinerary
- ✅ All POI details
- ✅ Audio URLs for each POI (ready to use!)
- ✅ Audio availability flags

---

## Example Request

```bash
GET http://your-api.com/tours/rome-tour-20260320-175540-6b0704?language=zh-tw
```

## Example Response

```json
{
  "metadata": {
    "tour_id": "rome-tour-20260320-175540-6b0704",
    "city": "rome",
    "duration_days": 1,
    "total_pois": 4,
    "created_at": "2026-03-20T17:55:40.284346",
    "title_display": "羅馬歷史之旅 · 1 Day",
    "languages": ["zh-tw"]
  },
  "itinerary": [
    {
      "day": 1,
      "pois": [
        {
          "poi": "Basilica di San Clemente",
          "poi_id": "basilica-di-san-clemente",
          "reason": "獨特的時光機教堂,可下探三層歷史",
          "estimated_hours": 1.2,
          "priority": "high",
          "coordinates": {
            "latitude": 41.8893347,
            "longitude": 12.4975757
          },
          "operation_hours": {...},
          "audio_url": "/pois/rome/basilica-di-san-clemente/audio/audio_zh-tw.mp3",
          "audio_available": true
        },
        {
          "poi": "Colosseum",
          "poi_id": "colosseum",
          "reason": "羅馬最具代表性的古蹟",
          "estimated_hours": 2.0,
          "priority": "high",
          "coordinates": {...},
          "audio_url": "/pois/rome/colosseum/audio/audio_zh-tw.mp3",
          "audio_available": true
        }
      ],
      "total_hours": 5.2,
      "total_walking_km": 3.5,
      "start_time": "09:00"
    }
  ],
  "optimization_scores": {
    "distance_score": 0.85,
    "coherence_score": 0.92
  }
}
```

**Everything in ONE response!**

---

## Client Implementation

### Flutter/Dart

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';

class TourService {
  final String baseUrl = 'http://your-api.com';
  final AudioPlayer player = AudioPlayer();

  // Get complete tour with audio URLs
  Future<Tour> getTour(String tourId, String language) async {
    final url = '$baseUrl/tours/$tourId?language=$language';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Tour.fromJson(data);
    }
    throw Exception('Failed to load tour');
  }

  // Play POI audio
  Future<void> playPOIAudio(POI poi) async {
    if (!poi.audioAvailable || poi.audioUrl == null) {
      throw Exception('Audio not available');
    }

    final fullUrl = baseUrl + poi.audioUrl!;
    await player.play(UrlSource(fullUrl));
  }
}

// Models
class Tour {
  final TourMetadata metadata;
  final List<TourDay> itinerary;

  Tour({required this.metadata, required this.itinerary});

  factory Tour.fromJson(Map<String, dynamic> json) {
    return Tour(
      metadata: TourMetadata.fromJson(json['metadata']),
      itinerary: (json['itinerary'] as List)
          .map((day) => TourDay.fromJson(day))
          .toList(),
    );
  }
}

class TourDay {
  final int day;
  final List<POI> pois;
  final double totalHours;
  final double totalWalkingKm;

  TourDay({
    required this.day,
    required this.pois,
    required this.totalHours,
    required this.totalWalkingKm,
  });

  factory TourDay.fromJson(Map<String, dynamic> json) {
    return TourDay(
      day: json['day'],
      pois: (json['pois'] as List).map((p) => POI.fromJson(p)).toList(),
      totalHours: json['total_hours'],
      totalWalkingKm: json['total_walking_km'],
    );
  }
}

class POI {
  final String name;
  final String poiId;
  final String reason;
  final double estimatedHours;
  final String? audioUrl;
  final bool audioAvailable;

  POI({
    required this.name,
    required this.poiId,
    required this.reason,
    required this.estimatedHours,
    this.audioUrl,
    required this.audioAvailable,
  });

  factory POI.fromJson(Map<String, dynamic> json) {
    return POI(
      name: json['poi'],
      poiId: json['poi_id'] ?? '',
      reason: json['reason'],
      estimatedHours: json['estimated_hours'].toDouble(),
      audioUrl: json['audio_url'],
      audioAvailable: json['audio_available'] ?? false,
    );
  }
}

// Usage
void main() async {
  final service = TourService();

  // Load tour
  final tour = await service.getTour('rome-tour-20260320-175540-6b0704', 'zh-tw');

  print('Tour: ${tour.metadata.titleDisplay}');
  print('Days: ${tour.itinerary.length}');

  // Play first POI audio
  final firstPOI = tour.itinerary[0].pois[0];
  print('Playing: ${firstPOI.name}');

  if (firstPOI.audioAvailable) {
    await service.playPOIAudio(firstPOI);
  }
}
```

### React / JavaScript

```javascript
import React, { useState, useEffect } from 'react';
import axios from 'axios';

const BASE_URL = 'http://your-api.com';

function TourPlayer({ tourId, language = 'zh-tw' }) {
  const [tour, setTour] = useState(null);
  const [currentPOI, setCurrentPOI] = useState(null);
  const [audio] = useState(new Audio());

  useEffect(() => {
    loadTour();
  }, [tourId, language]);

  const loadTour = async () => {
    try {
      const response = await axios.get(
        `${BASE_URL}/tours/${tourId}?language=${language}`
      );
      setTour(response.data);
    } catch (error) {
      console.error('Failed to load tour:', error);
    }
  };

  const playPOI = (poi) => {
    if (!poi.audio_available) {
      alert('Audio not available');
      return;
    }

    audio.src = BASE_URL + poi.audio_url;
    audio.play();
    setCurrentPOI(poi);
  };

  const pause = () => audio.pause();
  const stop = () => {
    audio.pause();
    audio.currentTime = 0;
  };

  if (!tour) return <div>Loading...</div>;

  return (
    <div className="tour-player">
      <h1>{tour.metadata.title_display}</h1>

      {tour.itinerary.map((day) => (
        <div key={day.day} className="tour-day">
          <h2>Day {day.day}</h2>
          <p>Total time: {day.total_hours} hours</p>
          <p>Walking: {day.total_walking_km} km</p>

          {day.pois.map((poi, index) => (
            <div key={index} className="poi-card">
              <h3>{poi.poi}</h3>
              <p>{poi.reason}</p>
              <p>Duration: {poi.estimated_hours} hours</p>

              {poi.audio_available ? (
                <button onClick={() => playPOI(poi)}>
                  🔊 Play Audio
                </button>
              ) : (
                <span>No audio</span>
              )}
            </div>
          ))}
        </div>
      ))}

      {currentPOI && (
        <div className="player-controls">
          <p>Now playing: {currentPOI.poi}</p>
          <button onClick={pause}>Pause</button>
          <button onClick={stop}>Stop</button>
        </div>
      )}
    </div>
  );
}

export default TourPlayer;
```

### React Native

```javascript
import React, { useState, useEffect } from 'react';
import { View, Text, Button, FlatList } from 'react-native';
import Sound from 'react-native-sound';

const BASE_URL = 'http://your-api.com';

function TourScreen({ tourId, language = 'zh-tw' }) {
  const [tour, setTour] = useState(null);
  const [currentSound, setCurrentSound] = useState(null);

  useEffect(() => {
    loadTour();
    return () => {
      if (currentSound) {
        currentSound.release();
      }
    };
  }, []);

  const loadTour = async () => {
    try {
      const response = await fetch(
        `${BASE_URL}/tours/${tourId}?language=${language}`
      );
      const data = await response.json();
      setTour(data);
    } catch (error) {
      console.error('Failed to load tour:', error);
    }
  };

  const playPOI = (poi) => {
    if (!poi.audio_available) return;

    // Stop current sound
    if (currentSound) {
      currentSound.stop();
      currentSound.release();
    }

    // Play new sound
    const sound = new Sound(
      BASE_URL + poi.audio_url,
      '',
      (error) => {
        if (error) {
          console.error('Failed to load audio:', error);
          return;
        }
        sound.play();
      }
    );

    setCurrentSound(sound);
  };

  if (!tour) return <Text>Loading...</Text>;

  return (
    <View>
      <Text style={styles.title}>{tour.metadata.title_display}</Text>

      <FlatList
        data={tour.itinerary}
        keyExtractor={(day) => day.day.toString()}
        renderItem={({ item: day }) => (
          <View>
            <Text>Day {day.day}</Text>

            {day.pois.map((poi, index) => (
              <View key={index} style={styles.poiCard}>
                <Text style={styles.poiName}>{poi.poi}</Text>
                <Text>{poi.reason}</Text>

                {poi.audio_available && (
                  <Button
                    title="🔊 Play Audio"
                    onPress={() => playPOI(poi)}
                  />
                )}
              </View>
            ))}
          </View>
        )}
      />
    </View>
  );
}
```

---

## What Client Gets

### Complete Tour Structure

Every POI in the itinerary includes:

```javascript
{
  // POI basic info
  "poi": "Colosseum",
  "poi_id": "colosseum",                  // ✅ URL-safe ID
  "reason": "...",
  "estimated_hours": 2.0,
  "priority": "high",

  // Location
  "coordinates": {
    "latitude": 41.890169,
    "longitude": 12.492269
  },

  // Operating info
  "operation_hours": {...},

  // Audio (NEW!)
  "audio_url": "/pois/rome/colosseum/audio/audio_zh-tw.mp3",  // ✅ Ready to use
  "audio_available": true                                      // ✅ Clear flag
}
```

---

## Backend Handles Everything

**What we do for you:**
- ✅ Convert POI names to URL-safe IDs
- ✅ Check if audio files exist
- ✅ Generate correct URLs for the language
- ✅ Set availability flags
- ✅ Handle all edge cases

**What you do:**
- ✅ Call one API
- ✅ Use the provided URLs
- ✅ Play the audio

**Zero complexity on client side!**

---

## Error Handling

```dart
Future<void> loadAndPlayTour(String tourId) async {
  try {
    final tour = await service.getTour(tourId, 'zh-tw');

    // Check audio availability
    final poisWithAudio = tour.itinerary
        .expand((day) => day.pois)
        .where((poi) => poi.audioAvailable)
        .length;

    print('Audio available: $poisWithAudio/${tour.metadata.totalPois} POIs');

    // Play first available audio
    for (final day in tour.itinerary) {
      for (final poi in day.pois) {
        if (poi.audioAvailable) {
          await service.playPOIAudio(poi);
          return;
        }
      }
    }

    print('No audio available for this tour');

  } on HttpException catch (e) {
    if (e.statusCode == 403) {
      print('Tour is private - login required');
    } else if (e.statusCode == 404) {
      print('Tour not found');
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

---

## Performance Tips

### 1. Cache Tour Data

```dart
class TourCache {
  static final Map<String, Tour> _cache = {};

  static Future<Tour> getTour(String tourId, String language) async {
    final key = '$tourId-$language';

    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final tour = await service.getTour(tourId, language);
    _cache[key] = tour;
    return tour;
  }
}
```

### 2. Preload Next POI

```dart
void preloadNext(Tour tour, int currentDay, int currentPOIIndex) {
  // Get next POI
  POI? nextPOI;

  if (currentPOIIndex + 1 < tour.itinerary[currentDay - 1].pois.length) {
    nextPOI = tour.itinerary[currentDay - 1].pois[currentPOIIndex + 1];
  }

  // Preload audio
  if (nextPOI != null && nextPOI.audioAvailable) {
    player.setSourceUrl(baseUrl + nextPOI.audioUrl!);
  }
}
```

### 3. Download for Offline

```dart
Future<void> downloadTourAudio(Tour tour) async {
  final dir = await getApplicationDocumentsDirectory();

  for (final day in tour.itinerary) {
    for (final poi in day.pois) {
      if (!poi.audioAvailable) continue;

      final url = baseUrl + poi.audioUrl!;
      final fileName = '${tour.metadata.tourId}_${poi.poiId}.mp3';
      final filePath = '${dir.path}/$fileName';

      // Download
      final response = await http.get(Uri.parse(url));
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      print('Downloaded: ${poi.name}');
    }
  }
}
```

---

## Summary

### One Endpoint, Complete Data

```
GET /tours/{tour_id}?language=zh-tw
```

**Returns:**
- ✅ Full tour itinerary
- ✅ All POI details
- ✅ Audio URLs (ready to play)
- ✅ Audio availability flags

### Client Implementation

**3 simple steps:**

1. **Load tour**: `GET /tours/{tour_id}?language=zh-tw`
2. **Parse response**: Tour data with audio URLs included
3. **Play audio**: `player.play(baseUrl + poi.audioUrl)`

**That's it!** 🎉

---

## Quick Example

```dart
// 1. Load tour
final tour = await http.get('/tours/rome-tour-abc123?language=zh-tw');
final data = json.decode(tour.body);

// 2. Get first POI
final poi = data['itinerary'][0]['pois'][0];

// 3. Play audio
if (poi['audio_available']) {
  await player.play(UrlSource(baseUrl + poi['audio_url']));
}
```

**Done! Audio is playing.** 🎵

---

**Ready to use now!**

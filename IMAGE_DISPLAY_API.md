# POI and Tour Images - Client Implementation Guide

## Overview

POI and tour images are **automatically included** in the standard API responses. No separate API calls needed!

When you request POI or tour data, images (if available) are included in the `images` field.

---

## ✨ Key Benefits

✅ **No Extra API Calls** - Images are already in POI/tour responses
✅ **Backward Compatible** - `images` field is optional (null if no images)
✅ **Simple Integration** - Just check if `images` exists
✅ **Automatic Updates** - When admins upload images, they appear immediately

---

## API Responses with Images

### Get POI (with images included)

```http
GET /pois/{city}/{poi_id}
```

**Example:**
```http
GET /pois/rome/colosseum
```

**Response:**
```json
{
  "poi_id": "colosseum",
  "poi_name": "Colosseum",
  "city": "rome",
  "metadata": {
    "coordinates": {...},
    "operation_hours": {...},
    "visit_info": {...}
  },
  "images": {
    "cover": {
      "url": "/pois/rome/colosseum/images/image_001.jpg",
      "caption": "Front view of the Colosseum",
      "order": 0
    },
    "gallery": [
      {
        "url": "/pois/rome/colosseum/images/image_002.jpg",
        "caption": "Interior view",
        "order": 1
      }
    ]
  }
}
```

**If No Images:**
```json
{
  "poi_id": "colosseum",
  "poi_name": "Colosseum",
  "city": "rome",
  "metadata": {...},
  "images": null
}
```

---

### Get Tour (with images included)

```http
GET /tours/{tour_id}?language=en
```

**Example:**
```http
GET /tours/rome-tour-20260304-095656-185fb3?language=en
```

**Response:**
```json
{
  "metadata": {
    "tour_id": "rome-tour-20260304-095656-185fb3",
    "city": "rome",
    "created_at": "2026-03-04T09:56:56.000000",
    "title_display": "Ancient Rome History · 3 Days"
  },
  "itinerary": [...],
  "input_parameters": {...},
  "optimization_scores": {...},
  "images": {
    "cover": {
      "url": "/tours/rome-tour-20260304-095656-185fb3/images/cover.jpg",
      "caption": "Ancient Rome Tour Highlights"
    },
    "gallery": [
      {
        "url": "/tours/rome-tour-20260304-095656-185fb3/images/gallery_001.jpg",
        "caption": "Day 1 Route Overview",
        "order": 0
      }
    ]
  }
}
```

**If No Images:**
```json
{
  "metadata": {...},
  "itinerary": [...},
  "images": null
}
```

---

## Flutter Implementation

### 1. Update Data Models

Add `images` field to your existing POI and Tour models:

```dart
// POI Model
class POI {
  final String poiId;
  final String poiName;
  final String city;
  final POIMetadata? metadata;
  final POIImages? images;  // ✅ Add this

  POI({
    required this.poiId,
    required this.poiName,
    required this.city,
    this.metadata,
    this.images,
  });

  factory POI.fromJson(Map<String, dynamic> json) {
    return POI(
      poiId: json['poi_id'],
      poiName: json['poi_name'],
      city: json['city'],
      metadata: json['metadata'] != null 
          ? POIMetadata.fromJson(json['metadata']) 
          : null,
      images: json['images'] != null
          ? POIImages.fromJson(json['images'])
          : null,  // ✅ Parse images
    );
  }
}

// POI Images Model
class POIImages {
  final ImageData? cover;
  final List<ImageData> gallery;

  POIImages({
    this.cover,
    required this.gallery,
  });

  factory POIImages.fromJson(Map<String, dynamic> json) {
    return POIImages(
      cover: json['cover'] != null 
          ? ImageData.fromJson(json['cover'])
          : null,
      gallery: (json['gallery'] as List?)
          ?.map((img) => ImageData.fromJson(img))
          .toList() ?? [],
    );
  }
}

// Image Data Model
class ImageData {
  final String url;
  final String? caption;
  final int order;

  ImageData({
    required this.url,
    this.caption,
    required this.order,
  });

  factory ImageData.fromJson(Map<String, dynamic> json) {
    return ImageData(
      url: json['url'],
      caption: json['caption'],
      order: json['order'] ?? 0,
    );
  }
}

// Tour Model
class Tour {
  final TourMetadata metadata;
  final List<TourDay> itinerary;
  final Map<String, dynamic> inputParameters;
  final OptimizationScores optimizationScores;
  final TourImages? images;  // ✅ Add this

  Tour({
    required this.metadata,
    required this.itinerary,
    required this.inputParameters,
    required this.optimizationScores,
    this.images,
  });

  factory Tour.fromJson(Map<String, dynamic> json) {
    return Tour(
      metadata: TourMetadata.fromJson(json['metadata']),
      itinerary: (json['itinerary'] as List)
          .map((day) => TourDay.fromJson(day))
          .toList(),
      inputParameters: json['input_parameters'] ?? {},
      optimizationScores: OptimizationScores.fromJson(json['optimization_scores']),
      images: json['images'] != null
          ? TourImages.fromJson(json['images'])
          : null,  // ✅ Parse images
    );
  }
}

// Tour Images Model (same structure as POIImages)
class TourImages {
  final ImageData? cover;
  final List<ImageData> gallery;

  TourImages({
    this.cover,
    required this.gallery,
  });

  factory TourImages.fromJson(Map<String, dynamic> json) {
    return TourImages(
      cover: json['cover'] != null 
          ? ImageData.fromJson(json['cover'])
          : null,
      gallery: (json['gallery'] as List?)
          ?.map((img) => ImageData.fromJson(img))
          .toList() ?? [],
    );
  }
}
```

---

### 2. Display POI Images

```dart
class POIDetailScreen extends StatelessWidget {
  final POI poi;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(poi.poiName)),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display cover image if available
            if (poi.images?.cover != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  '$baseUrl${poi.images!.cover!.url}',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

            if (poi.images?.cover?.caption != null)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  poi.images!.cover!.caption!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),

            SizedBox(height: 24),

            // POI metadata and details...
            Text(poi.poiName, style: Theme.of(context).textTheme.headlineMedium),
            
            // Display gallery if available
            if (poi.images?.gallery.isNotEmpty ?? false) ...[
              SizedBox(height: 24),
              Text('Gallery', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: poi.images!.gallery.length,
                itemBuilder: (context, index) {
                  final image = poi.images!.gallery[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      '$baseUrl${image.url}',
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

---

### 3. Display Tour Images

```dart
class TourDetailScreen extends StatelessWidget {
  final Tour tour;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tour.metadata.titleDisplay ?? 'Tour')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display cover image if available
            if (tour.images?.cover != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  '$baseUrl${tour.images!.cover!.url}',
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

            if (tour.images?.cover?.caption != null)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  tour.images!.cover!.caption!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),

            SizedBox(height: 24),

            // Tour details (itinerary, etc.)...
            
            // Display gallery if available
            if (tour.images?.gallery.isNotEmpty ?? false) ...[
              SizedBox(height: 24),
              Text('Photo Gallery', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: tour.images!.gallery.length,
                itemBuilder: (context, index) {
                  final image = tour.images!.gallery[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          '$baseUrl${image.url}',
                          fit: BoxFit.cover,
                        ),
                        if (image.caption != null)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black54],
                                ),
                              ),
                              child: Text(
                                image.caption!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

---

## Reusable Image Widget

```dart
class NetworkImageWithFallback extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const NetworkImageWithFallback({
    Key? key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget image = Image.network(
      imageUrl,
      height: height,
      width: width,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: height,
          width: width,
          color: Colors.grey[200],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: height,
          width: width,
          color: Colors.grey[300],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, size: 40, color: Colors.grey[600]),
              SizedBox(height: 8),
              Text(
                'Image unavailable',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        );
      },
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }
}

// Usage:
NetworkImageWithFallback(
  imageUrl: '$baseUrl${poi.images!.cover!.url}',
  height: 200,
  borderRadius: BorderRadius.circular(12),
)
```

---

## Best Practices

### 1. Always Check for Null

```dart
// ✅ Good
if (poi.images?.cover != null) {
  // Display cover image
}

// ❌ Bad - will crash if images is null
Image.network('$baseUrl${poi.images!.cover!.url}')
```

### 2. Use Cached Network Image

For better performance, use `cached_network_image`:

```yaml
dependencies:
  cached_network_image: ^3.3.0
```

```dart
import 'package:cached_network_image/cached_network_image.dart';

CachedNetworkImage(
  imageUrl: '$baseUrl${image.url}',
  height: 200,
  fit: BoxFit.cover,
  placeholder: (context, url) => Container(
    height: 200,
    color: Colors.grey[200],
    child: Center(child: CircularProgressIndicator()),
  ),
  errorWidget: (context, url, error) => Icon(Icons.error),
)
```

### 3. Handle Empty States Gracefully

```dart
Widget buildPOIImages(POI poi) {
  // No images available
  if (poi.images == null || 
      (poi.images!.cover == null && poi.images!.gallery.isEmpty)) {
    return SizedBox.shrink(); // Or show placeholder
  }

  // Has images - display them
  return Column(...);
}
```

### 4. Lazy Load Images

Only load images when the user scrolls to them:

```dart
import 'package:visibility_detector/visibility_detector.dart';

VisibilityDetector(
  key: Key('poi-images'),
  onVisibilityChanged: (info) {
    if (info.visibleFraction > 0.5 && shouldLoadImages) {
      setState(() => shouldLoadImages = true);
    }
  },
  child: shouldLoadImages
      ? Image.network(imageUrl)
      : Container(height: 200, color: Colors.grey[200]),
)
```

---

## Migration from Separate API Calls

If you previously used separate image APIs:

**Before (2 API calls):**
```dart
// 1. Get POI
final poi = await apiService.getPOI('rome', 'colosseum');

// 2. Get images separately
final images = await apiService.getPOIImages('rome', 'colosseum');
```

**After (1 API call):**
```dart
// Get POI with images included
final poi = await apiService.getPOI('rome', 'colosseum');

// Images are already in poi.images
if (poi.images?.cover != null) {
  print('Cover: ${poi.images!.cover!.url}');
}
```

---

## Testing Checklist

- [ ] POI with cover image displays correctly
- [ ] POI with gallery images displays correctly
- [ ] POI without images (null) handles gracefully
- [ ] Tour with cover image displays correctly
- [ ] Tour with gallery images displays correctly
- [ ] Tour without images (null) handles gracefully
- [ ] Image loading states show spinner
- [ ] Image error states show placeholder
- [ ] Images are cached after first load
- [ ] Tapping image opens fullscreen preview

---

## FAQ

**Q: Do I need separate API calls for images?**
A: No! Images are automatically included in POI and tour responses.

**Q: What if a POI/tour has no images?**
A: The `images` field will be `null`. Always check before displaying.

**Q: Are images required?**
A: No, images are completely optional. Old POIs/tours without images will have `images: null`.

**Q: What image format is returned?**
A: All images are automatically converted to JPEG by the backend.

**Q: Do images change often?**
A: Admins can upload/delete images anytime. Consider implementing cache invalidation.

**Q: Do I need authentication to view images?**
A: No, images are public. Only upload/delete require admin auth.

**Q: What if the image URL is broken?**
A: Always use `errorBuilder` in `Image.network()` to show a placeholder.

---

## Example API Responses

### POI with Full Images
```json
{
  "poi_id": "colosseum",
  "poi_name": "Colosseum",
  "city": "rome",
  "metadata": {...},
  "images": {
    "cover": {
      "url": "/pois/rome/colosseum/images/image_001.jpg",
      "caption": "Front view",
      "order": 0
    },
    "gallery": [
      {
        "url": "/pois/rome/colosseum/images/image_002.jpg",
        "caption": "Interior",
        "order": 1
      },
      {
        "url": "/pois/rome/colosseum/images/image_003.jpg",
        "caption": "Arena floor",
        "order": 2
      }
    ]
  }
}
```

### POI without Images
```json
{
  "poi_id": "fountain",
  "poi_name": "Trevi Fountain",
  "city": "rome",
  "metadata": {...},
  "images": null
}
```

### Tour with Cover Only
```json
{
  "metadata": {...},
  "itinerary": [...],
  "images": {
    "cover": {
      "url": "/tours/rome-tour-123/images/cover.jpg",
      "caption": "Rome Tour"
    },
    "gallery": []
  }
}
```

---

## Support

For backend/API issues, see:
- `docs/IMAGE_UPLOAD_DESIGN.md` - Complete technical specification
- `CLI_CHEATSHEET.md` - API reference

The separate image APIs (`GET /pois/{city}/{poi_id}/images` and `GET /tours/{tour_id}/images`) still exist for backward compatibility, but you don't need to use them anymore!

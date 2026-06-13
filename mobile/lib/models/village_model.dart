import 'package:cloud_firestore/cloud_firestore.dart';

class VillageModel {
  final String id;
  final String name;
  final String nameGu;
  final double lat;
  final double lng;
  final bool isActive;
  final String taluka;

  const VillageModel({
    required this.id,
    required this.name,
    required this.nameGu,
    required this.lat,
    required this.lng,
    this.isActive = true,
    this.taluka = 'Mahuva',
  });

  factory VillageModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return VillageModel(
      id: doc.id,
      name: d['name'] ?? '',
      nameGu: d['nameGu'] ?? '',
      lat: (d['lat'] ?? 0).toDouble(),
      lng: (d['lng'] ?? 0).toDouble(),
      isActive: d['isActive'] ?? true,
      taluka: d['taluka'] ?? 'Mahuva',
    );
  }

  static final fallbackVillages = [
    const VillageModel(id: 'anaval',     name: 'Anaval',     nameGu: 'આણવલ',    lat: 20.8394, lng: 73.2637),
    const VillageModel(id: 'kos',        name: 'Kos',        nameGu: 'કૉસ',     lat: 20.8480, lng: 73.2350),
    const VillageModel(id: 'tarkani',    name: 'Tarkani',    nameGu: 'તારકણી',  lat: 20.8550, lng: 73.2580),
    const VillageModel(id: 'angaldhara', name: 'Angaldhara', nameGu: 'અંગળધરા', lat: 20.8180, lng: 73.2280),
    const VillageModel(id: 'dholikuva',  name: 'Dholikuva',  nameGu: 'ઢોળીકૂવા', lat: 20.8650, lng: 73.2800),
    const VillageModel(id: 'lakhavadi',  name: 'Lakhavadi',  nameGu: 'લખાવડી',  lat: 20.8050, lng: 73.2150),
    const VillageModel(id: 'unai',       name: 'Unai',       nameGu: 'ઉનાઈ',    lat: 20.8550, lng: 73.2100),
    const VillageModel(id: 'doldha',     name: 'Doldha',     nameGu: 'ડોળધા',   lat: 20.7950, lng: 73.2600),
    const VillageModel(id: 'kamboya',    name: 'Kamboya',    nameGu: 'કાંબોયા', lat: 20.8750, lng: 73.2200),
  ];
}

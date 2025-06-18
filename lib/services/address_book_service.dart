import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/address_book_entry.dart';

class AddressBookService {
  static final AddressBookService _instance = AddressBookService._internal();
  factory AddressBookService() => _instance;
  AddressBookService._internal();

  static const String _storageKey = 'gotham_address_book';

  Future<List<AddressBookEntry>> getAllEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      
      if (jsonString == null) return [];
      
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => AddressBookEntry.fromJson(json)).toList();
    } catch (e) {
      print('Error loading address book entries: $e');
      return [];
    }
  }

  Future<void> addEntry(AddressBookEntry entry) async {
    try {
      final entries = await getAllEntries();
      
      // Check for duplicate addresses
      if (entries.any((e) => e.address == entry.address)) {
        throw Exception('Address already exists in address book');
      }
      
      // Check for duplicate names
      if (entries.any((e) => e.name.toLowerCase() == entry.name.toLowerCase())) {
        throw Exception('Name already exists in address book');
      }
      
      entries.add(entry);
      await _saveEntries(entries);
    } catch (e) {
      print('Error adding address book entry: $e');
      rethrow;
    }
  }

  Future<void> updateEntry(AddressBookEntry entry) async {
    try {
      final entries = await getAllEntries();
      final index = entries.indexWhere((e) => e.id == entry.id);
      
      if (index == -1) {
        throw Exception('Entry not found');
      }
      
      // Check for duplicate addresses (excluding current entry)
      if (entries.any((e) => e.id != entry.id && e.address == entry.address)) {
        throw Exception('Address already exists in address book');
      }
      
      // Check for duplicate names (excluding current entry)
      if (entries.any((e) => e.id != entry.id && e.name.toLowerCase() == entry.name.toLowerCase())) {
        throw Exception('Name already exists in address book');
      }
      
      entries[index] = entry;
      await _saveEntries(entries);
    } catch (e) {
      print('Error updating address book entry: $e');
      rethrow;
    }
  }

  Future<void> deleteEntry(String id) async {
    try {
      final entries = await getAllEntries();
      entries.removeWhere((e) => e.id == id);
      await _saveEntries(entries);
    } catch (e) {
      print('Error deleting address book entry: $e');
      rethrow;
    }
  }

  Future<AddressBookEntry?> getEntryById(String id) async {
    try {
      final entries = await getAllEntries();
      return entries.firstWhere((e) => e.id == id, orElse: () => throw Exception('Entry not found'));
    } catch (e) {
      print('Error getting address book entry: $e');
      return null;
    }
  }

  Future<AddressBookEntry?> getEntryByAddress(String address) async {
    try {
      final entries = await getAllEntries();
      return entries.firstWhere((e) => e.address == address, orElse: () => throw Exception('Entry not found'));
    } catch (e) {
      print('Error getting address book entry by address: $e');
      return null;
    }
  }

  Future<List<AddressBookEntry>> searchEntries(String query) async {
    try {
      final entries = await getAllEntries();
      final lowerQuery = query.toLowerCase();
      
      return entries.where((entry) {
        return entry.name.toLowerCase().contains(lowerQuery) ||
               entry.address.toLowerCase().contains(lowerQuery) ||
               (entry.description?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    } catch (e) {
      print('Error searching address book entries: $e');
      return [];
    }
  }

  Future<bool> hasEntry(String address) async {
    try {
      final entries = await getAllEntries();
      return entries.any((e) => e.address == address);
    } catch (e) {
      print('Error checking if address exists: $e');
      return false;
    }
  }

  Future<void> importEntries(List<AddressBookEntry> newEntries) async {
    try {
      final existingEntries = await getAllEntries();
      final mergedEntries = <AddressBookEntry>[];
      
      // Add existing entries
      mergedEntries.addAll(existingEntries);
      
      // Add new entries (skip duplicates)
      for (final newEntry in newEntries) {
        if (!existingEntries.any((e) => e.address == newEntry.address)) {
          mergedEntries.add(newEntry);
        }
      }
      
      await _saveEntries(mergedEntries);
    } catch (e) {
      print('Error importing address book entries: $e');
      rethrow;
    }
  }

  Future<String> exportEntries() async {
    try {
      final entries = await getAllEntries();
      final jsonList = entries.map((e) => e.toJson()).toList();
      return json.encode(jsonList);
    } catch (e) {
      print('Error exporting address book entries: $e');
      rethrow;
    }
  }

  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      print('Error clearing address book: $e');
      rethrow;
    }
  }

  Future<Map<String, int>> getStats() async {
    try {
      final entries = await getAllEntries();
      final bech32Count = entries.where((e) => e.address.startsWith('gt1')).length;
      final p2shCount = entries.where((e) => e.address.startsWith('3')).length;
      final p2pkhCount = entries.where((e) => e.address.startsWith('1')).length;
      final withDescriptionCount = entries.where((e) => e.description != null).length;
      
      return {
        'total': entries.length,
        'bech32': bech32Count,
        'p2sh': p2shCount,
        'p2pkh': p2pkhCount,
        'withDescription': withDescriptionCount,
      };
    } catch (e) {
      print('Error getting address book stats: $e');
      return {};
    }
  }

  Future<void> _saveEntries(List<AddressBookEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = entries.map((e) => e.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      print('Error saving address book entries: $e');
      rethrow;
    }
  }
}
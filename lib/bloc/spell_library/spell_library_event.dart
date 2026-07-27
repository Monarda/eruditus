import 'package:equatable/equatable.dart';

abstract class SpellLibraryEvent extends Equatable {
  const SpellLibraryEvent();
  @override
  List<Object?> get props => [];
}

class LibraryRequested extends SpellLibraryEvent {
  const LibraryRequested();
}

class SearchQueryChanged extends SpellLibraryEvent {
  final String query;
  const SearchQueryChanged(this.query);
  @override
  List<Object?> get props => [query];
}

class FilterChanged extends SpellLibraryEvent {
  final String filter; // 'All' | 'Published' | 'My Spells'
  const FilterChanged(this.filter);
  @override
  List<Object?> get props => [filter];
}

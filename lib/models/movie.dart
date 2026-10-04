import 'genre_ids.dart';

class MovieList {
  int? page;
  int? totalMovies;
  int? totalPages;
  List<Movie>? movies;

  MovieList({this.page, this.totalMovies, this.totalPages, this.movies});

  MovieList.fromJson(Map<String, dynamic> json) {
    page = json['page'];
    totalMovies = json['total_results'];
    totalPages = json['total_pages'];
    if (json['results'] != null) {
      movies = [];
      json['results'].forEach((v) {
        movies!.add(Movie.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['page'] = page;
    data['total_results'] = totalMovies;
    data['total_pages'] = totalPages;
    if (movies != null) {
      data['results'] = movies!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class CollectionMovieList {
  List<Movie>? movies;
  CollectionMovieList({
    this.movies,
  });

  CollectionMovieList.fromJson(Map<String, dynamic> json) {
    if (json['parts'] != null) {
      movies = [];
      json['parts'].forEach((v) {
        movies!.add(Movie.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (movies != null) {
      data['parts'] = movies!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class CollectionDetails {
  String? overview;
  CollectionDetails({this.overview});
  CollectionDetails.fromJson(Map<String, dynamic> json) {
    if (json['overview'] != null) {
      overview = json['overview'];
    }
  }
}

class Movie {
  int? voteCount;
  int? id;
  bool? video;
  num? voteAverage;
  String? title;
  num? popularity;
  String? posterPath;
  String? originalLanguage;
  String? originalTitle;
  // TMDB genre ids. Saved with bookmarks from the local tables' version 2;
  // older rows and cloud copies have none.
  List<int>? genreIds;
  String? backdropPath;
  bool? adult;
  String? overview;
  String? releaseDate;
  String? dateAdded = DateTime.now().toString();

  Movie({
    this.voteCount,
    this.id,
    this.video,
    this.voteAverage,
    this.title,
    this.popularity,
    this.posterPath,
    this.originalLanguage,
    this.originalTitle,
    this.genreIds,
    this.backdropPath,
    this.adult,
    this.overview,
    this.dateAdded,
    this.releaseDate,
  });

  Movie.fromJson(Map<String, dynamic> json) {
    voteCount = json['vote_count'];
    id = json['id'];
    video = json['video'];
    voteAverage = json['vote_average'];
    title = json['title'];
    popularity = json['popularity'];
    posterPath = json['poster_path'];
    originalLanguage = json['original_language'];
    originalTitle = json['original_title'];
    genreIds = parseGenreIds(json['genre_ids']);
    backdropPath = json['backdrop_path'];
    adult = json['adult'];
    overview = json['overview'];
    releaseDate = json['release_date'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['vote_count'] = voteCount;
    data['id'] = id;
    data['video'] = video;
    data['vote_average'] = voteAverage;
    data['title'] = title;
    data['popularity'] = popularity;
    data['poster_path'] = posterPath;
    data['original_language'] = originalLanguage;
    data['original_title'] = originalTitle;
    if (genreIds != null) data['genre_ids'] = genreIds;
    data['backdrop_path'] = backdropPath;
    data['adult'] = adult;
    data['overview'] = overview;
    data['release_date'] = releaseDate;

    return data;
  }

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{};
    map['id'] = id;
    map['title'] = title;
    // Stored as "28,12"; left out when unknown so an update keeps what the
    // row already has.
    if (encodeGenreIds(genreIds) case final ids?) map['genre_ids'] = ids;
    map['poster_path'] = posterPath;
    map['vote_count'] = voteCount;
    // map['video'] = video;
    map['vote_average'] = voteAverage;
    map['popularity'] = popularity;
    map['original_language'] = originalLanguage;
    map['original_title'] = originalTitle;
    map['backdrop_path'] = backdropPath;
    // map['adult'] = adult;
    map['overview'] = overview;
    map['release_date'] = releaseDate;
    map['date_added'] = dateAdded;

    return map;
  }

  Movie.fromMapObject(Map<String, dynamic> map) {
    dateAdded = map['date_added'] as String?;
    id = map['id'];
    title = map['title'];
    genreIds = parseGenreIds(map['genre_ids']);
    posterPath = map['poster_path'];
    voteCount = map['vote_count'];
    //video = map['video'];
    voteAverage = map['vote_average'];
    popularity = map['popularity'];
    originalLanguage = map['original_language'];
    originalTitle = map['original_title'];
    backdropPath = map['backdrop_path'];
    // adult = map['adult'];
    overview = map['overview'];
    releaseDate = map['release_date'];
  }
}

class MovieDetails {
  int? runtime;
  String? tagline;
  String? originalTitle;
  String? status;
  int? budget;
  bool? isAdult;
  int? revenue;
  int? id;
  dynamic imdbId;

  List<ProductionCompanies>? productionCompanies;
  List<ProductionCountries>? productionCountries;
  List<SpokenLanguages>? spokenLanguages;
  // BelongsToCollection? belongsToCollection;

  MovieDetails({
    this.runtime,
    this.tagline,
    this.status,
    this.budget,
    this.id,
    this.revenue,
    this.isAdult,
    this.originalTitle,
    this.productionCompanies,
    this.productionCountries,
    this.spokenLanguages,
    this.imdbId,
    /*this.belongsToCollection*/
  });
  MovieDetails.fromJson(Map<String, dynamic> json) {
    runtime = json['runtime'];
    tagline = json['tagline'];
    status = json['status'];
    budget = json['budget'];
    revenue = json['revenue'];
    imdbId = json['imdb_id'];
    isAdult = json['adult'];
    id = json['id'];
    // belongsToCollection = json['belongs_to_collection'];
    originalTitle = json['original_title'];
    if (json['production_companies'] != null) {
      productionCompanies = [];
      json['production_companies'].forEach((v) {
        productionCompanies?.add(ProductionCompanies.fromJson(v));
      });
    }
    if (json['production_countries'] != null) {
      productionCountries = [];
      json['production_countries'].forEach((v) {
        productionCountries?.add(ProductionCountries.fromJson(v));
      });
    }
    if (json['spoken_languages'] != null) {
      spokenLanguages = [];
      json['spoken_languages'].forEach((v) {
        spokenLanguages?.add(SpokenLanguages.fromJson(v));
      });
    }
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (productionCompanies != null) {
      data['production_companies'] =
          productionCompanies?.map((v) => v.toJson()).toList();
    }
    if (productionCountries != null) {
      data['production_countries'] =
          productionCountries?.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class ProductionCompanies {
  String? name;
  ProductionCompanies({this.name});
  ProductionCompanies.fromJson(Map<String, dynamic> json) {
    name = json['name'];
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;

    return data;
  }
}

class ProductionCountries {
  String? name;
  ProductionCountries({this.name});
  ProductionCountries.fromJson(Map<String, dynamic> json) {
    name = json['name'];
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;

    return data;
  }
}

class SpokenLanguages {
  String? englishName;
  SpokenLanguages({this.englishName});
  SpokenLanguages.fromJson(Map<String, dynamic> json) {
    englishName = json['english_name'];
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['english_name'] = englishName;
    return data;
  }
}

class PersonMoviesList {
  List<Movie>? movies;
  PersonMoviesList({this.movies});
  PersonMoviesList.fromJson(Map<String, dynamic> json) {
    if (json['cast'] != null) {
      movies = [];
      json['cast'].forEach((v) {
        movies!.add(Movie.fromJson(v));
      });
    }
    if (json['crew'] != null) {
      if (json['cast'] == null) {
        movies = [];
      }
      json['crew'].forEach((v) {
        movies!.add(Movie.fromJson(v));
      });
    }
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (movies != null) {
      data['cast'] = movies!.map((v) => v.toJson()).toList();
    }
    if (movies != null) {
      data['crew'] = movies!.map((v) => v.toJson()).toList();
    }

    return data;
  }
}

class ExternalLinks {
  String? facebookUsername;
  String? instagramUsername;
  String? twitterUsername;
  String? imdbId;

  ExternalLinks({
    this.facebookUsername,
    this.imdbId,
    this.instagramUsername,
    this.twitterUsername,
  });
  ExternalLinks.fromJson(Map<String, dynamic> json) {
    facebookUsername = json['facebook_id'];
    instagramUsername = json['instagram_id'];
    imdbId = json['imdb_id'];
    twitterUsername = json['twitter_id'];
  }
}

class BelongsToCollection {
  int? id;
  String? name;
  String? posterPath;
  String? backdropPath;
  BelongsToCollection({this.backdropPath, this.id, this.name, this.posterPath});
  BelongsToCollection.fromJson(Map<String, dynamic> json) {
    if (json['belongs_to_collection'] == null) {
      id = null;
      name = null;
      posterPath = null;
      backdropPath = null;
    } else {
      if (json['belongs_to_collection']['id'] != null) {
        id = json['belongs_to_collection']['id'];
      }
      if (json['belongs_to_collection']['name'] != null) {
        name = json['belongs_to_collection']['name'];
      }
      if (json['belongs_to_collection']['poster_path'] != null) {
        posterPath = json['belongs_to_collection']['poster_path'];
      }
      if (json['belongs_to_collection']['backdrop_path'] != null) {
        backdropPath = json['belongs_to_collection']['backdrop_path'];
      }
    }
  }

  /// The same collection read from its own record rather than from a film that belongs to one.
  ///
  /// `/collection/{id}` answers with these fields at the top level, so a collection reached directly
  /// — from a link, with no film in hand — can still be shown with its name and its backdrop.
  BelongsToCollection.fromCollectionJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    posterPath = json['poster_path'];
    backdropPath = json['backdrop_path'];
  }
}

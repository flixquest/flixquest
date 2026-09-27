import 'genre_ids.dart';

class TVList {
  int? page;
  int? totalTV;
  int? totalPages;
  List<TV>? tvSeries;

  TVList({this.page, this.totalTV, this.totalPages, this.tvSeries});

  TVList.fromJson(Map<String, dynamic> json) {
    page = json['page'];
    totalTV = json['total_results'];
    totalPages = json['total_pages'];
    if (json['results'] != null) {
      tvSeries = [];
      json['results'].forEach((v) {
        tvSeries!.add(TV.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['page'] = page;
    data['total_results'] = totalTV;
    data['total_pages'] = totalPages;
    if (tvSeries != null) {
      data['results'] = tvSeries!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class TV {
  int? voteCount;
  int? id;
  num? voteAverage;
  String? name;
  num? popularity;
  String? posterPath;
  String? originalLanguage;
  String? originalName;
  List<int>? genreIds;
  String? backdropPath;
  String? overview;
  String? firstAirDate;
  bool? adult;
  String? dateAdded = DateTime.now().toString();

  TV({
    this.voteCount,
    this.id,
    this.voteAverage,
    this.name,
    this.popularity,
    this.posterPath,
    this.originalLanguage,
    this.originalName,
    this.genreIds,
    this.backdropPath,
    this.overview,
    this.firstAirDate,
    this.adult,
    this.dateAdded,
  });

  TV.fromJson(Map<String, dynamic> json) {
    voteCount = json['vote_count'];
    id = json['id'];
    adult = json['adult'];
    voteAverage = json['vote_average'];
    name = json['name'];
    popularity = json['popularity'];
    posterPath = json['poster_path'];
    originalLanguage = json['original_language'];
    originalName = json['original_name'];
    backdropPath = json['backdrop_path'];
    overview = json['overview'];
    firstAirDate = json['first_air_date'];
    genreIds = parseGenreIds(json['genre_ids']);
    // originCountry = json['origin_country'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['vote_count'] = voteCount;
    data['id'] = id;
    data['adult'] = adult;
    data['vote_average'] = voteAverage;
    data['name'] = name;
    data['popularity'] = popularity;
    data['poster_path'] = posterPath;
    data['original_language'] = originalLanguage;
    data['original_title'] = originalName;
    if (genreIds != null) data['genre_ids'] = genreIds;
    data['backdrop_path'] = backdropPath;
    data['overview'] = overview;
    data['first_air_date'] = firstAirDate;
    // data['origin_country'] = originCountry;
    return data;
  }

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{};
    map['id'] = id;
    // Stored as "28,12"; left out when unknown so an update keeps what the
    // row already has.
    if (encodeGenreIds(genreIds) case final ids?) map['genre_ids'] = ids;
    map['poster_path'] = posterPath;
    map['vote_count'] = voteCount;
    map['name'] = name;
    // map['video'] = video;
    map['vote_average'] = voteAverage;
    map['popularity'] = popularity;
    map['original_language'] = originalLanguage;
    map['original_title'] = originalName;
    map['backdrop_path'] = backdropPath;
    // map['adult'] = adult;
    map['overview'] = overview;
    map['first_air_date'] = firstAirDate;
    map['date_added'] = dateAdded;

    return map;
  }

  TV.fromMapObject(Map<String, dynamic> map) {
    id = map['id'];
    genreIds = parseGenreIds(map['genre_ids']);
    posterPath = map['poster_path'];
    voteCount = map['vote_count'];
    //video = map['video'];
    name = map['name'];
    voteAverage = map['vote_average'];
    popularity = map['popularity'];
    originalLanguage = map['original_language'];
    originalName = map['original_title'];
    backdropPath = map['backdrop_path'];
    // adult = map['adult'];
    overview = map['overview'];
    firstAirDate = map['first_air_date'];
  }
}

class TVDetails {
  List<dynamic>? runtime;
  String? tagline;
  String? originalTitle;
  String? status;
  bool? inProduction;
  int? numberOfSeasons;
  int? numberOfEpisodes;
  int? id;
  String? backdropPath;
  List<ProductionCompanies>? productionCompanies;
  List<ProductionCountries>? productionCountries;
  List<SpokenLanguages>? spokenLanguages;
  List<Seasons>? seasons;
  List<EpisodeList>? episodes;
  List<CreatedBy>? createdBy;
  List<Networks>? networks;

  TVDetails({
    this.runtime,
    this.tagline,
    this.status,
    this.episodes,
    this.originalTitle,
    this.inProduction,
    this.numberOfEpisodes,
    this.numberOfSeasons,
    this.productionCompanies,
    this.productionCountries,
    this.spokenLanguages,
    this.id,
    this.backdropPath,
    this.createdBy,
    this.seasons,
    this.networks,
  });

  TVDetails.fromJson(Map<String, dynamic> json) {
    runtime = json['episode_run_time'];
    tagline = json['tagline'];
    status = json['status'];
    id = json['id'];
    backdropPath = json['backdrop_path'];
    originalTitle = json['original_name'];
    numberOfEpisodes = json['number_of_episodes'];
    numberOfSeasons = json['number_of_seasons'];
    inProduction = json['in_production'];
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
    if (json['seasons'] != null) {
      seasons = [];
      json['seasons'].forEach((v) {
        seasons?.add(Seasons.fromJson(v));
      });
    }
    if (json['episodes'] != null) {
      episodes = [];
      json['episodes'].forEach((v) {
        episodes?.add(EpisodeList.fromJson(v));
      });
    }
    if (json['created_by'] != null) {
      createdBy = [];
      json['created_by'].forEach((v) {
        createdBy?.add(CreatedBy.fromJson(v));
      });
    }
    if (json['networks'] != null) {
      networks = [];
      json['networks'].forEach((v) {
        networks?.add(Networks.fromJson(v));
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

class Seasons {
  String? name;
  int? seasonNumber;
  String? posterPath;
  int? seasonId;
  String? overview;
  String? airDate;
  int? episodeCount;
  Seasons(
      {this.airDate,
      this.episodeCount,
      this.name,
      this.overview,
      this.posterPath,
      this.seasonId,
      this.seasonNumber});
  Seasons.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    seasonNumber = json['season_number'];
    posterPath = json['poster_path'];
    seasonId = json['id'];
    overview = json['overview'];
    airDate = json['air_date'];
    episodeCount = json['episode_count'];
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['season_number'] = seasonNumber;
    data['poster_path'] = posterPath;
    data['id'] = seasonId;
    data['overview'] = overview;
    data['air_date'] = airDate;
    data['episode_count'] = episodeCount;
    return data;
  }
}

class Networks {
  String? networkName;
  String? networkLogoPath;
  int? id;
  Networks({this.networkLogoPath, this.networkName});
  Networks.fromJson(Map<String, dynamic> json) {
    networkName = json['name'];
    networkLogoPath = json['logo_path'];
    id = json['id'];
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = networkName;
    data['id'] = id;
    data['logo_path'] = networkLogoPath;
    return data;
  }
}

class EpisodeList {
  int? episodeNumber;
  int? episodeId;
  String? name;
  String? airDate;
  String? stillPath;
  int? seasonNumber;
  num? voteAverage;
  num? voteCount;
  String? overview;
  List<EpisodeCrew>? episodeCrew;
  List<EpisodeGuestStars>? episodeGuestStars;

  EpisodeList(
      {this.airDate,
      this.episodeNumber,
      this.name,
      this.stillPath,
      this.episodeId,
      this.episodeCrew,
      this.overview,
      this.seasonNumber,
      this.voteAverage,
      this.voteCount,
      this.episodeGuestStars});
  EpisodeList.fromJson(Map<String, dynamic> json) {
    episodeNumber = json['episode_number'];
    name = json['name'];
    airDate = json['air_date'];
    stillPath = json['still_path'];
    overview = json['overview'];
    seasonNumber = json['season_number'];
    voteAverage = json['vote_average'];
    voteCount = json['vote_count'];
    episodeId = json['id'];
    if (json['crew'] != null) {
      episodeCrew = [];
      json['crew'].forEach((v) {
        episodeCrew?.add(EpisodeCrew.fromJson(v));
      });
    }
    if (json['guest_stars'] != null) {
      episodeGuestStars = [];
      json['guest_stars'].forEach((v) {
        episodeGuestStars?.add(EpisodeGuestStars.fromJson(v));
      });
    }
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['episode_number'] = episodeNumber;
    data['name'] = name;
    data['air_date'] = airDate;
    data['still_path'] = stillPath;
    data['overview'] = overview;
    data['season_number'] = seasonNumber;
    data['vote_average'] = voteAverage;
    data['vote_count'] = voteCount;
    data['id'] = episodeId;
    if (episodeCrew != null) {
      data['crew'] = episodeCrew?.map((v) => v.toJson()).toList();
    }
    if (episodeGuestStars != null) {
      data['guest_stars'] = episodeGuestStars?.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class EpisodeCrew {
  String? department;
  String? job;
  bool? adult;
  int? gender;
  int? id;
  String? knownForDepartment;
  String? name;
  String? profilePath;
  EpisodeCrew(
      {this.adult,
      this.department,
      this.gender,
      this.id,
      this.job,
      this.knownForDepartment,
      this.name,
      this.profilePath});
  EpisodeCrew.fromJson(Map<String, dynamic> json) {
    department = json['department'];
    job = json['job'];
    adult = json['adult'];
    gender = json['gender'];
    id = json['id'];
    knownForDepartment = json['known_for_department'];
    name = json['name'];
    profilePath = json['profile_path'];
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['department'] = department;
    data['job'] = job;
    data['adult'] = adult;
    data['gender'] = gender;
    data['id'] = id;
    data['known_for_department'] = knownForDepartment;
    data['name'] = name;
    data['profile_path'] = profilePath;
    return data;
  }
}

class EpisodeGuestStars {
  String? character;
  bool? adult;
  int? gender;
  int? id;
  String? knownForDepartment;
  String? name;
  String? profilePath;
  EpisodeGuestStars(
      {this.adult,
      this.character,
      this.gender,
      this.id,
      this.knownForDepartment,
      this.name,
      this.profilePath});

  EpisodeGuestStars.fromJson(Map<String, dynamic> json) {
    character = json['character'];
    adult = json['adult'];
    gender = json['gender'];
    id = json['id'];
    knownForDepartment = json['known_for_department'];
    name = json['name'];
    profilePath = json['profile_path'];
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['character'] = character;
    data['adult'] = adult;
    data['gender'] = gender;
    data['id'] = id;
    data['known_for_department'] = knownForDepartment;
    data['name'] = name;
    data['profile_path'] = profilePath;
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

class CreatedBy {
  int? id;
  String? name;
  String? profilePath;
  int? gender;
  CreatedBy({this.gender, this.id, this.name, this.profilePath});
  CreatedBy.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    profilePath = json['profile_path'];
    gender = json['gender'];
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['profile_path'] = profilePath;
    data['gender'] = gender;
    return data;
  }
}

class PersonTVList {
  List<TV>? tv;
  PersonTVList({this.tv});
  PersonTVList.fromJson(Map<String, dynamic> json) {
    if (json['cast'] != null) {
      tv = [];
      json['cast'].forEach((v) {
        tv!.add(TV.fromJson(v));
      });
    }
    if (json['crew'] != null) {
      if (json['cast'] == null) {
        tv = [];
      }
      json['crew'].forEach((v) {
        tv!.add(TV.fromJson(v));
      });
    }
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (tv != null) {
      data['cast'] = tv!.map((v) => v.toJson()).toList();
    }
    if (tv != null) {
      data['crew'] = tv!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}
